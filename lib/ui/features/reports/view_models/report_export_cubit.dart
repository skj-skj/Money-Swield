import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/report_repository.dart';
import '../../../../data/services/report_export_service.dart';
import '../../../../data/services/xlsx/xlsx_writer.dart' show TooManyRows;
import '../../../../domain/periods.dart';
import '../../../../domain/report.dart';
import '../../../../domain/report_document.dart';
import '../../../core/emit_if_open.dart';
import '../report_document_builder.dart';
import '../views/report_texts.dart';

/// Where an export is: building the document (strings), writing the file
/// (PDF pages), or handing it on.
enum ExportStep { building, writing, saving }

/// Why an export failed (§8.9 says each in words).
enum ExportFailure { pdf, excel, tooManyRows, save, noShareTarget }

sealed class ExportState {
  const ExportState();
}

final class ExportIdle extends ExportState {
  const ExportIdle();
}

final class ExportWorking extends ExportState {
  const ExportWorking(this.format, this.step, {this.page = 0, this.pages = 0});

  final ReportExport format;
  final ExportStep step;

  /// PDF pages written so far, of [pages] (0 while unknown).
  final int page;
  final int pages;
}

/// What a finished export did.
sealed class ExportOutcome {
  const ExportOutcome();
}

/// Saved to `Download/Expense Tracker/`.
final class ExportSaved extends ExportOutcome {
  const ExportSaved(this.saved, this.mimeType);

  final SavedReport saved;
  final String mimeType;
}

/// Saved through the system dialog (Save as…).
final class ExportSavedAs extends ExportOutcome {
  const ExportSavedAs();
}

final class ExportShared extends ExportOutcome {
  const ExportShared();
}

/// Cancelled in the busy dialog, or the save dialog was: nothing to say.
final class ExportCancelledOutcome extends ExportOutcome {
  const ExportCancelledOutcome();
}

final class ExportFailed extends ExportOutcome {
  const ExportFailed(this.reason);

  final ExportFailure reason;
}

final class ExportDone extends ExportState {
  const ExportDone(this.outcome);

  final ExportOutcome outcome;
}

/// Makes a report's file from the report on screen (phase-8.md §7.2; no
/// new read, so the file shows the screen's numbers, §9), then saves or
/// shares it. One export at a time: a second tap while one runs is
/// ignored (a double tap makes one file). [cancel] stops the document
/// build (between chunks) and the PDF (between pages) and deletes the
/// partial file; during the Excel write it drops the result.
class ReportExportCubit extends CubitSignal<ExportState>
    with EmitIfOpen<ExportState> {
  ReportExportCubit({required this._service, required this._now})
    : super(initialState: const ExportIdle());

  final ReportExportService _service;
  final DateTime Function() _now;

  CancelToken? _cancel;

  bool get isWorking => value is ExportWorking;

  void cancel() => _cancel?.cancel();

  /// Builds, writes and hands on the file. Returns the outcome (also
  /// emitted as [ExportDone]); null when another export was running.
  /// [report] is grouped by [options]' sections (`options.grouping`).
  Future<ExportOutcome?> export({
    required ReportExportOptions options,
    required ExportAction action,
    required Report report,
    required ReportData data,
    required ReportTexts texts,
    required WeekStart weekStart,
  }) async {
    if (isWorking) return null;
    final cancel = _cancel = CancelToken();
    emitIfOpen(ExportWorking(options.format, ExportStep.building));
    final outcome = await _run(
      options: options,
      action: action,
      report: report,
      data: data,
      texts: texts,
      weekStart: weekStart,
      cancel: cancel,
    );
    _cancel = null;
    emitIfOpen(ExportDone(outcome));
    return outcome;
  }

  Future<ExportOutcome> _run({
    required ReportExportOptions options,
    required ExportAction action,
    required Report report,
    required ReportData data,
    required ReportTexts texts,
    required WeekStart weekStart,
    required CancelToken cancel,
  }) async {
    final format = options.format;
    final now = _now();
    final name = reportFileName(report.range, format, weekStart, todayOn(now));
    final builder = ReportDocumentBuilder(
      report: report,
      data: data,
      texts: texts,
      options: options,
      madeAt: now,
      isCancelled: () => cancel.isCancelled,
    );
    final String path;
    final watch = Stopwatch()..start();
    try {
      if (format == ReportExport.pdf) {
        final doc = await builder.pdf();
        debugPrint('Report PDF built in ${watch.elapsedMilliseconds} ms');
        if (cancel.isCancelled) return const ExportCancelledOutcome();
        emitIfOpen(ExportWorking(format, ExportStep.writing));
        path = await _service.writePdf(
          doc,
          name,
          cancel: cancel,
          progress: (page, pages) => emitIfOpen(
            ExportWorking(format, ExportStep.writing, page: page, pages: pages),
          ),
        );
      } else {
        final book = await builder.xlsx();
        debugPrint('Report workbook built in ${watch.elapsedMilliseconds} ms');
        if (cancel.isCancelled) return const ExportCancelledOutcome();
        emitIfOpen(ExportWorking(format, ExportStep.writing));
        path = await _service.writeXlsx(book, name);
      }
    } on ExportCancelled {
      return const ExportCancelledOutcome();
    } on ReportWriteCancelled {
      return const ExportCancelledOutcome();
    } on TooManyRows {
      return const ExportFailed(ExportFailure.tooManyRows);
    } catch (error, stackTrace) {
      debugPrint('Making the report failed: $error\n$stackTrace');
      return ExportFailed(
        format == ReportExport.pdf ? ExportFailure.pdf : ExportFailure.excel,
      );
    }
    debugPrint('Report file written at ${watch.elapsedMilliseconds} ms');
    // Cancelled while the Excel file was written (one isolate call): its
    // result is dropped, nothing saved or shared.
    if (cancel.isCancelled) {
      await _service.discard(path);
      return const ExportCancelledOutcome();
    }
    emitIfOpen(ExportWorking(format, ExportStep.saving));
    final mime = mimeTypeOf(format);
    try {
      final outcome = switch (action) {
        ExportAction.save => ExportSaved(
          await _service.save(path, name, mime),
          mime,
        ),
        ExportAction.saveAs =>
          await _service.saveAs(path, name, mime)
              ? const ExportSavedAs()
              : const ExportCancelledOutcome(),
        ExportAction.share => await _shared(path, mime, name),
      };
      // Saved (or the save dialog cancelled): the report cache is emptied
      // at once (owner, 2026-10-11). A shared file stays for its receiver;
      // the startup clean-up removes it after a day.
      if (action != ExportAction.share) await _service.clearCache();
      return outcome;
    } on NoAppForReport {
      return const ExportFailed(ExportFailure.noShareTarget);
    } catch (error, stackTrace) {
      debugPrint('Saving the report failed: $error\n$stackTrace');
      return const ExportFailed(ExportFailure.save);
    }
  }

  Future<ExportOutcome> _shared(String path, String mime, String title) async {
    await _service.share(path, mime, title);
    return const ExportShared();
  }

  /// Opens a saved report (right after Save); throws [NoAppForReport].
  Future<void> open(ExportSaved saved) =>
      _service.open(saved.saved.uri, saved.mimeType);
}
