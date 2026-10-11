import 'dart:async';

import 'package:my_expense_tracker_app/data/services/report_export_service.dart';
import 'package:my_expense_tracker_app/data/services/report_pdf.dart';
import 'package:my_expense_tracker_app/data/services/xlsx/xlsx_writer.dart'
    as xlsx;

/// [ReportExportService] without files or channels: it records what it was
/// asked and answers as told (phase-8.md §12 "fake channel").
class FakeReportExportService implements ReportExportService {
  final pdfs = <PdfDoc>[];
  final books = <xlsx.XlsxWorkbook>[];
  final saved = <String>[];
  final savedAs = <String>[];
  final shared = <String>[];
  final opened = <String>[];
  final discarded = <String>[];
  int clearCalls = 0;
  int deleteOldCalls = 0;

  /// Folders handed out, one per export.
  var _folder = 0;

  /// Answers of the next calls.
  bool saveAsResult = true;
  bool noShareTarget = false;
  bool noViewer = false;
  Exception? writeError;
  Exception? saveError;

  /// When set, the file is written only once this completes (to test
  /// Cancel and a double tap while working).
  Completer<void>? holdWrite;

  /// When set, [save] copies only once this completes.
  Completer<void>? holdSave;

  /// When set, [deleteOld] finishes only once this completes.
  Completer<void>? holdDeleteOld;

  /// PDF progress reported while writing: (page, pages).
  List<(int, int)> progress = const [];

  /// Every write's path, in order.
  final paths = <String>[];

  Future<String> _write(String name) async {
    if (holdWrite case final hold?) await hold.future;
    if (writeError case final error?) throw error;
    final path = 'cache/reports/${_folder++}/$name';
    paths.add(path);
    return path;
  }

  @override
  Future<String> writePdf(
    PdfDoc doc,
    String name, {
    CancelToken? cancel,
    void Function(int page, int pages)? progress,
  }) async {
    pdfs.add(doc);
    for (final (page, pages) in this.progress) {
      progress?.call(page, pages);
    }
    final path = await _write(name);
    if (cancel?.isCancelled ?? false) throw const ReportWriteCancelled();
    return path;
  }

  @override
  Future<String> writeXlsx(xlsx.XlsxWorkbook book, String name) async {
    books.add(book);
    // The real writer runs it; a too-long sheet throws the same way.
    xlsx.writeXlsx(book);
    return _write(name);
  }

  @override
  Future<SavedReport> save(String path, String name, String mimeType) async {
    if (holdSave case final hold?) await hold.future;
    if (saveError case final error?) throw error;
    saved.add(path);
    return (uri: 'content://media/downloads/${saved.length}', name: name);
  }

  @override
  Future<bool> saveAs(String path, String name, String mimeType) async {
    if (saveAsResult) savedAs.add(path);
    return saveAsResult;
  }

  @override
  Future<void> share(String path, String mimeType, String title) async {
    if (noShareTarget) throw const NoAppForReport();
    shared.add(path);
  }

  @override
  Future<void> open(String uri, String mimeType) async {
    if (noViewer) throw const NoAppForReport();
    opened.add(uri);
  }

  @override
  Future<void> discard(String path) async => discarded.add(path);

  @override
  Future<void> clearCache() async => clearCalls++;

  @override
  Future<void> deleteOld() async {
    deleteOldCalls++;
    if (holdDeleteOld case final hold?) await hold.future;
  }
}
