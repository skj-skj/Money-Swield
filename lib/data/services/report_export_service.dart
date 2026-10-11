import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'document_service.dart';
import 'report_pdf.dart';
import 'xlsx/xlsx_writer.dart' as xlsx;

/// A report saved to `Download/<AppName>/`: its MediaStore URI (for Open)
/// and the name MediaStore gave it (" (1)" on a clash).
typedef SavedReport = ({String uri, String name});

/// No app on the phone can receive (Share) or open (Open) the file.
class NoAppForReport implements Exception {
  const NoAppForReport();
}

/// The PDF was cancelled while being written; its file is gone.
class ReportWriteCancelled implements Exception {
  const ReportWriteCancelled();
}

/// Set by Cancel; the writer checks it between pages.
class CancelToken {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  void onCancel(void Function() listener) => _listeners.add(listener);
}

/// Writes a report's files and hands them on (phase-8.md §6.3, §6.6).
abstract interface class ReportExportService {
  /// Writes [doc] as `cache/reports/<stamp>/<name>` (a new folder per
  /// export, so a second export never rewrites a file another app may
  /// still be reading) and returns the path. Throws
  /// [ReportWriteCancelled] after [cancel]; the partial file is deleted.
  Future<String> writePdf(
    PdfDoc doc,
    String name, {
    CancelToken? cancel,
    void Function(int page, int pages)? progress,
  });

  /// [book] as `cache/reports/<stamp>/<name>`; throws `TooManyRows`.
  Future<String> writeXlsx(xlsx.XlsxWorkbook book, String name);

  /// Copies [path] to `Download/Expense Tracker/` (insert-only).
  Future<SavedReport> save(String path, String name, String mimeType);

  /// The system save dialog (Save as…); false when cancelled.
  Future<bool> saveAs(String path, String name, String mimeType);

  /// The share sheet; throws [NoAppForReport].
  Future<void> share(String path, String mimeType, String title);

  /// Opens a saved report; throws [NoAppForReport].
  Future<void> open(String uri, String mimeType);

  /// Deletes an export's file and its folder: it was cancelled after it
  /// was written. A failure is logged.
  Future<void> discard(String path);

  /// After Save or Save as… (owner, 2026-10-11: "once the PDF is saved,
  /// delete all files in cache"): everything under `cache/reports/` and
  /// `cache/report_work/`, this export's copy, PDF parts and earlier
  /// shares alike. Exports run one at a time, so none is in progress. A
  /// share from an earlier export is gone too: its receiver has had it
  /// since (a share alone keeps its copy, [deleteOld] removes it after a
  /// day). A failure is logged.
  Future<void> clearCache();

  /// At startup: `cache/report_work/` entirely, export folders older than
  /// a day (a shared file stays a day for the app it was shared to,
  /// P8-16). Saved reports are the user's and never touched.
  Future<void> deleteOld();
}

/// [ReportExportService] on the app's cache folder and its channels
/// (`expense_tracker/report_pdf`, `expense_tracker/documents`).
class ChannelReportExportService implements ReportExportService {
  ChannelReportExportService({
    required this._cacheDir,
    required this._documents,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The app's cache folder (`getTemporaryDirectory`).
  final Future<Directory> Function() _cacheDir;
  final DocumentService _documents;
  final DateTime Function() _now;

  static const _pdfChannel = MethodChannel('expense_tracker/report_pdf');
  static const _documentsChannel = MethodChannel('expense_tracker/documents');

  /// The folder name under `Download/`: application-design's `<AppName>`,
  /// not translated (one folder whatever the language).
  static const downloadsFolder = 'Expense Tracker';

  /// How long an exported file stays in the cache.
  static const keepFor = Duration(days: 1);

  final _progress = <String, void Function(int, int)>{};
  int _sequence = 0;

  Future<void> _onPdfCall(MethodCall call) async {
    if (call.method != 'progress') return;
    final args = call.arguments as Map<Object?, Object?>;
    _progress[args['id']]?.call(args['page']! as int, args['pages']! as int);
  }

  /// A stamp no other export of this run shares: the time and a counter.
  String _stamp() => '${_now().microsecondsSinceEpoch}-${_sequence++}';

  /// A new `cache/reports/<stamp>/` folder for one export.
  Future<String> _newFolder(String stamp) async {
    final dir = Directory(p.join((await _cacheDir()).path, 'reports', stamp));
    await dir.create(recursive: true);
    return dir.path;
  }

  @override
  Future<String> writePdf(
    PdfDoc doc,
    String name, {
    CancelToken? cancel,
    void Function(int page, int pages)? progress,
  }) async {
    final stamp = _stamp();
    final cache = (await _cacheDir()).path;
    // A file, not a channel argument: 50,000 rows are several MB. Outside
    // the shared folder.
    final work = File(p.join(cache, 'report_work', '$stamp.json'));
    final out = p.join(await _newFolder(stamp), name);
    try {
      await work.create(recursive: true);
      await work.writeAsString(jsonEncode(doc.toJson()), flush: true);
      if (cancel?.isCancelled ?? false) throw const ReportWriteCancelled();
      // Set here, not in the constructor: dependencies are also built
      // where no Flutter binding exists (startup checks, tests).
      _pdfChannel.setMethodCallHandler(_onPdfCall);
      if (progress != null) _progress[stamp] = progress;
      cancel?.onCancel(
        () => _pdfChannel.invokeMethod<void>('cancel', {'id': stamp}),
      );
      await _pdfChannel.invokeMethod<int>('write', {
        'id': stamp,
        'jsonPath': work.path,
        'outPath': out,
      });
      return out;
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') throw const ReportWriteCancelled();
      rethrow;
    } finally {
      _progress.remove(stamp);
      await _deleteQuietly(work);
    }
  }

  @override
  Future<String> writeXlsx(xlsx.XlsxWorkbook book, String name) async {
    final out = File(p.join(await _newFolder(_stamp()), name));
    // Zipping 50,000 rows off the UI isolate.
    final bytes = await Isolate.run(() => xlsx.writeXlsx(book));
    try {
      await out.writeAsBytes(bytes, flush: true);
    } catch (_) {
      await _deleteQuietly(out);
      rethrow;
    }
    return out.path;
  }

  @override
  Future<SavedReport> save(String path, String name, String mimeType) async {
    final saved = await _documentsChannel.invokeMapMethod<String, String>(
      'saveToDownloads',
      {
        'sourcePath': path,
        'folder': downloadsFolder,
        'displayName': name,
        'mimeType': mimeType,
      },
    );
    return (uri: saved!['uri']!, name: saved['name']!);
  }

  @override
  Future<bool> saveAs(String path, String name, String mimeType) => _documents
      .saveDocument(sourcePath: path, suggestedName: name, mimeType: mimeType);

  @override
  Future<void> share(String path, String mimeType, String title) => _orNoApp(
    () => _documentsChannel.invokeMethod<void>('share', {
      'path': path,
      'mimeType': mimeType,
      'title': title,
    }),
    'noShareTarget',
  );

  @override
  Future<void> open(String uri, String mimeType) => _orNoApp(
    () => _documentsChannel.invokeMethod<void>('open', {
      'uri': uri,
      'mimeType': mimeType,
    }),
    'noViewer',
  );

  Future<void> _orNoApp(Future<void> Function() call, String code) async {
    try {
      await call();
    } on PlatformException catch (error) {
      if (error.code == code) throw const NoAppForReport();
      rethrow;
    }
  }

  @override
  Future<void> discard(String path) async {
    final file = File(path);
    await _deleteQuietly(file);
    try {
      final folder = file.parent;
      if (await folder.exists() && await folder.list().isEmpty) {
        await folder.delete();
      }
    } catch (error) {
      debugPrint('Deleting ${file.parent.path} failed: $error');
    }
  }

  @override
  Future<void> clearCache() async {
    await clearReports((await _cacheDir()).path);
  }

  /// [clearCache] on [cache], for tests.
  @visibleForTesting
  static Future<void> clearReports(String cache) async {
    for (final name in ['reports', 'report_work']) {
      final dir = Directory(p.join(cache, name));
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (error) {
        debugPrint('Deleting ${dir.path} failed: $error');
      }
    }
  }

  @override
  Future<void> deleteOld() async {
    final cache = (await _cacheDir()).path;
    await deleteOldReports(cache, _now());
  }

  /// [deleteOld] on [cache] at [now], for tests.
  @visibleForTesting
  static Future<void> deleteOldReports(String cache, DateTime now) async {
    final work = Directory(p.join(cache, 'report_work'));
    if (await work.exists()) await work.delete(recursive: true);
    final reports = Directory(p.join(cache, 'reports'));
    if (!await reports.exists()) return;
    await for (final entry in reports.list()) {
      try {
        final changed = (await entry.stat()).modified;
        if (now.difference(changed) > keepFor) {
          await entry.delete(recursive: true);
        }
      } catch (error) {
        debugPrint('Deleting an old report failed: $error');
      }
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Deleting ${file.path} failed: $error');
    }
  }
}
