import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_expense_tracker_app/data/repositories/report_repository.dart';
import 'package:my_expense_tracker_app/data/services/report_export_service.dart';
import 'package:my_expense_tracker_app/data/services/xlsx/xlsx_writer.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/domain/report.dart';
import 'package:my_expense_tracker_app/domain/report_document.dart';
import 'package:my_expense_tracker_app/domain/report_filter.dart';
import 'package:my_expense_tracker_app/domain/report_range.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/money_formatter.dart';
import 'package:my_expense_tracker_app/ui/core/period_names.dart';
import 'package:my_expense_tracker_app/ui/features/reports/view_models/report_export_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/reports/views/report_texts.dart';
import 'package:path/path.dart' as p;

import '../../../../helpers/fake_report_export_service.dart';

/// phase-8.md §7.2 and §12 "Cubits: ReportExportCubit"; the export
/// service's cache cleanup (§6.3).
void main() {
  setUpAll(initializeDateFormatting);

  late FakeReportExportService files;
  late ReportExportCubit cubit;

  setUp(() {
    files = FakeReportExportService();
    cubit = ReportExportCubit(
      service: files,
      now: () => DateTime.utc(2026, 10, 10, 6),
    );
    addTearDown(cubit.close);
  });

  final l10n = lookupAppLocalizations(const Locale('en'));
  final texts = ReportTexts(
    l10n: l10n,
    dateLocale: 'en_IN',
    formatter: MoneyFormatter.forLocale('en_IN'),
    names: PeriodNames(
      l10n: l10n,
      locale: 'en_IN',
      today: '2026-10-10',
      weekLabel: WeekLabel.month,
    ),
  );
  const data = ReportData(
    rows: [],
    categories: {},
    events: {},
    paymentMethods: {},
  );
  final report = buildReport(
    [
      const ReportRow(
        id: 1,
        title: 'Lunch',
        amountMinor: 100,
        currencyCode: 'INR',
        occurredAtMs: 0,
        utcOffsetMinutes: 0,
        day: '2026-10-05',
        categoryId: 1,
        paymentMethodId: 1,
      ),
    ],
    range: const ReportRange(ReportPeriod.month, '2026-10-01', '2026-10-31'),
    filter: ReportFilter.none,
    grouping: const ReportExportOptions().grouping,
    defaultCurrency: 'INR',
  );

  Future<ExportOutcome?> run(
    ExportAction action, {
    ReportExport format = ReportExport.pdf,
  }) => cubit.export(
    options: ReportExportOptions(format: format),
    action: action,
    report: report,
    data: data,
    texts: texts,
    weekStart: WeekStart.monday,
  );

  test('PDF → Save: saved, named after the month; the cache emptied '
      '(owner, 2026-10-11)', () async {
    final outcome = await run(ExportAction.save);
    expect(outcome, isA<ExportSaved>());
    expect(files.paths.single, endsWith('expense-report-2026-10.pdf'));
    expect(files.saved, hasLength(1));
    expect(files.clearCalls, 1);
    expect(cubit.value, isA<ExportDone>());
  });

  test('Excel → Save as; cancelled dialog → nothing to say', () async {
    expect(
      await run(ExportAction.saveAs, format: ReportExport.xlsx),
      isA<ExportSavedAs>(),
    );
    expect(files.paths.single, endsWith('.xlsx'));
    files.saveAsResult = false;
    expect(await run(ExportAction.saveAs), isA<ExportCancelledOutcome>());
    // Saved or not, nothing needs the cache after the dialog.
    expect(files.clearCalls, 2);
  });

  test('Share keeps its cache copy; no share target', () async {
    expect(await run(ExportAction.share), isA<ExportShared>());
    expect(files.discarded, isEmpty);
    expect(files.clearCalls, 0);
    files.noShareTarget = true;
    final outcome = await run(ExportAction.share);
    expect((outcome! as ExportFailed).reason, ExportFailure.noShareTarget);
  });

  test('failures: PDF, Excel, too many rows, save', () async {
    files.writeError = Exception('disk');
    expect(
      ((await run(ExportAction.save))! as ExportFailed).reason,
      ExportFailure.pdf,
    );
    expect(
      ((await run(ExportAction.save, format: ReportExport.xlsx))!
              as ExportFailed)
          .reason,
      ExportFailure.excel,
    );
    files
      ..writeError = const TooManyRows('x', 2000000)
      ..saveError = null;
    expect(
      ((await run(ExportAction.save))! as ExportFailed).reason,
      ExportFailure.tooManyRows,
    );
    files
      ..writeError = null
      ..saveError = Exception('MediaStore');
    expect(
      ((await run(ExportAction.save))! as ExportFailed).reason,
      ExportFailure.save,
    );
  });

  test('a second export while one works is ignored: one file', () async {
    files.holdWrite = Completer<void>();
    final first = run(ExportAction.save);
    await pumpEventQueue();
    expect(cubit.isWorking, isTrue);
    expect(await run(ExportAction.save), isNull);
    files.holdWrite!.complete();
    expect(await first, isA<ExportSaved>());
    expect(files.paths, hasLength(1));
  });

  test('cancel while writing: nothing saved; Excel result dropped', () async {
    for (final format in ReportExport.values) {
      files.holdWrite = Completer<void>();
      final running = run(ExportAction.save, format: format);
      await pumpEventQueue();
      cubit.cancel();
      files.holdWrite!.complete();
      expect(await running, isA<ExportCancelledOutcome>(), reason: '$format');
    }
    expect(files.saved, isEmpty);
    // The Excel file written before Cancel was heard is deleted.
    expect(files.discarded, hasLength(1));
  });

  test('PDF progress reaches the state', () async {
    files.progress = const [(10, 40), (40, 40)];
    final states = <ExportState>[];
    final sub = cubit.state.subscribe(states.add);
    await run(ExportAction.save);
    sub();
    expect(
      states.whereType<ExportWorking>().map((s) => (s.page, s.pages)),
      containsAll([(10, 40), (40, 40)]),
    );
  });

  test('ChannelReportExportService.clearReports: every export folder, '
      'shared ones too, and the work folder', () async {
    final cache = await Directory.systemTemp.createTemp('reports_clear');
    addTearDown(() => cache.delete(recursive: true));
    final saved = await File(p.join(cache.path, 'reports', 'a', 'r.pdf'))
        .create(recursive: true);
    final empty = await Directory(p.join(cache.path, 'reports', 'b'))
        .create(recursive: true);
    final part = await File(p.join(cache.path, 'report_work', 'p', '1.pdf'))
        .create(recursive: true);
    final other = await File(p.join(cache.path, 'photos', 'x.jpg'))
        .create(recursive: true);
    await ChannelReportExportService.clearReports(cache.path);
    expect(await saved.exists(), isFalse);
    expect(await empty.exists(), isFalse);
    expect(await part.exists(), isFalse);
    // Only the report folders: the rest of the cache isn't the report's.
    expect(await other.exists(), isTrue);
    // Nothing there: fine.
    await ChannelReportExportService.clearReports(cache.path);
  });

  group('ChannelReportExportService.deleteOldReports', () {
    test('the work folder always; export folders older than a day', () async {
      final cache = await Directory.systemTemp.createTemp('reports_test');
      addTearDown(() => cache.delete(recursive: true));
      final work = await File(p.join(cache.path, 'report_work', 'x.json'))
          .create(recursive: true);
      final old = await Directory(p.join(cache.path, 'reports', 'old'))
          .create(recursive: true);
      final fresh = await Directory(p.join(cache.path, 'reports', 'fresh'))
          .create(recursive: true);
      final now = DateTime.now();
      await ChannelReportExportService.deleteOldReports(
        cache.path,
        now.add(const Duration(hours: 25)),
      );
      expect(await work.exists(), isFalse);
      expect(await old.exists(), isFalse);
      expect(await fresh.exists(), isFalse);
      final kept = await Directory(p.join(cache.path, 'reports', 'kept'))
          .create(recursive: true);
      await ChannelReportExportService.deleteOldReports(cache.path, now);
      expect(await kept.exists(), isTrue);
    });

    test('nothing there: fine', () async {
      final cache = await Directory.systemTemp.createTemp('reports_empty');
      addTearDown(() => cache.delete(recursive: true));
      await ChannelReportExportService.deleteOldReports(
        cache.path,
        DateTime.now(),
      );
    });
  });
}
