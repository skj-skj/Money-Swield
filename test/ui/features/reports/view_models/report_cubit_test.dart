import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/models/dashboard_options.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/domain/report.dart';
import 'package:my_expense_tracker_app/domain/report_document.dart';
import 'package:my_expense_tracker_app/domain/report_filter.dart';
import 'package:my_expense_tracker_app/domain/report_range.dart';
import 'package:my_expense_tracker_app/ui/features/reports/view_models/report_cubit.dart';

import '../../../../helpers/test_database.dart';

/// phase-8.md §7.1 and §12 "Cubits" (owner's overhaul, 2026-10-10).
void main() {
  late AppDependencies deps;
  late TestClock clock;

  setUp(() async {
    // Sat 10 Oct 2026, noon local.
    clock = TestClock(DateTime(2026, 10, 10, 12).toUtc());
    deps = await openTestDependencies(clock: clock);
  });

  ReportCubit cubit() {
    final c = ReportCubit(
      reports: deps.reports,
      settings: deps.settings,
      dataVersion: deps.dataVersion,
      now: clock.call,
      defaultCurrency: 'INR',
      weekStart: WeekStart.monday,
    );
    addTearDown(c.close);
    return c;
  }

  Future<Expense> add(
    String day,
    int minor, {
    String code = 'INR',
    int category = 1,
    Set<int> events = const {},
  }) {
    final at = DateTime.parse('$day 12:00:00');
    return deps.expenses.add(
      ExpenseInput(
        title: 'x',
        description: null,
        amount: Money(minor, code),
        occurredAt: at.toUtc(),
        utcOffsetMinutes: at.timeZoneOffset.inMinutes,
        categoryId: category,
        paymentMethodId: 1,
        eventIds: events,
      ),
    );
  }

  BigInt? total(ReportCubit c, [String code = 'INR']) =>
      c.value.report?.totals[code]?.amount;

  test('first start: this month, bars, no filter, default options', () async {
    await add('2026-10-02', 100);
    final c = cubit();
    await c.start();
    expect(c.value.phase, ReportPhase.loaded);
    expect(
      c.value.range,
      currentRange(ReportPeriod.month, '2026-10-10', WeekStart.monday),
    );
    expect(c.value.face, ReportChart.bars);
    expect(c.value.filter, ReportFilter.none);
    expect(c.exportOptions, const ReportExportOptions());
    expect(total(c), BigInt.from(100));
    // The card is by category, whatever the export groups by.
    expect(c.value.report!.grouping, ReportGrouping.byCategory);
  });

  test('a later start: the saved period (current one), face, filter, '
      'options; Range on its dates', () async {
    await deps.settings.setReportPeriod(ReportPeriod.year);
    await deps.settings.setReportChart(ReportChart.donut);
    const filter = ReportFilter(paymentMethodIds: {1});
    await deps.settings.setReportFilter(filter);
    const options = ReportExportOptions(
      groupBy: GroupDimension.event,
      format: ReportExport.xlsx,
    );
    await deps.settings.setReportExportOptions(options);
    var c = cubit();
    await c.start();
    expect(c.value.range.from, '2026-01-01');
    expect(c.value.face, ReportChart.donut);
    expect(c.value.filter, filter);
    expect(c.exportOptions, options);
    final range = defaultCustomRange('2026-10-10');
    await c.setCustomRange(range);
    c = cubit();
    await c.start();
    expect(c.value.range, range);
  });

  test(
    'step, bounds, backToCurrent; Range only through setCustomRange',
    () async {
      await add('2026-09-15', 42);
      final c = cubit();
      await c.start();
      c.step(-1);
      await pumpEventQueue();
      expect(c.value.range.from, '2026-09-01');
      expect(total(c), BigInt.from(42));
      c.backToCurrent();
      await pumpEventQueue();
      expect(c.value.range.from, '2026-10-01');
      expect(
        () => c.setPeriod(ReportPeriod.range),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => c.setCustomRange(
          const ReportRange(ReportPeriod.range, '2026-10-31', '2026-10-01'),
        ),
        throwsArgumentError,
      );
      await c.setCustomRange(const ReportRange.allTime());
      expect(c.value.range.isAllTime, isTrue);
      expect(
        (await deps.settings.loadReport()).prefs.period,
        ReportPeriod.range,
      );
    },
  );

  test(
    'setFilter: trims, saves, reloads; the same filter reads nothing',
    () async {
      await add('2026-10-02', 100, category: 1);
      await add('2026-10-02', 200, category: 2);
      final c = cubit();
      await c.start();
      await c.setFilter(
        const ReportFilter(
          base: ExpenseFilter(text: '  x ', categoryIds: {2}),
        ),
      );
      expect(c.value.filter.base.text, 'x');
      expect(total(c), BigInt.from(200));
      expect((await deps.settings.loadReport()).prefs.filter, c.value.filter);
      final report = c.value.report;
      await c.setFilter(
        const ReportFilter(
          base: ExpenseFilter(text: 'x', categoryIds: {2}),
        ),
      );
      expect(identical(c.value.report, report), isTrue);
      await c.setFilter(const ReportFilter(base: ExpenseFilter(text: '   ')));
      expect(c.value.filter, ReportFilter.none);
    },
  );

  test(
    'deleted ids dropped with a notice naming what it knew; saved',
    () async {
      await add('2026-10-02', 100);
      final party = await deps.events.add(name: 'Party', emoji: '🎉');
      final c = cubit();
      await c.start();
      await c.setFilter(
        ReportFilter(base: ExpenseFilter(eventIds: {party.id})),
      );
      await deps.events.delete(party.id);
      await c.load();
      expect(c.value.filter, ReportFilter.none);
      expect(c.value.notice!.count, 1);
      expect(c.value.notice!.events.single.name, 'Party');
      // The report shows what the pruned filter lets through, not the
      // rows read for the old one (none had the deleted event).
      expect(total(c), BigInt.from(100));
      expect(
        (await deps.settings.loadReport()).prefs.filter,
        ReportFilter.none,
      );
    },
  );

  test('turnFace over the two faces, wrapping', () async {
    final c = cubit();
    await c.start();
    expect(c.turnFace(1), ReportChart.donut);
    expect(c.turnFace(1), ReportChart.bars);
    expect(c.turnFace(-1), ReportChart.donut);
    expect(c.turnFace(2), ReportChart.donut);
  });

  test('currency kept while the report has it, else the default; select '
      'and clear', () async {
    await add('2026-10-02', 100);
    await add('2026-10-02', 5, code: 'USD');
    await add('2026-09-02', 7, code: 'USD');
    final c = cubit();
    await c.start();
    c.moveCurrency(1);
    expect(c.value.currency, 'USD');
    c.select(0);
    expect(c.value.selected, 0);
    c.select(0);
    expect(c.value.selected, isNull);
    c.step(-1); // September: USD only
    await pumpEventQueue();
    expect(c.value.currency, 'USD');
    c.step(1);
    await pumpEventQueue();
    expect(c.value.currency, 'USD');
  });

  test('newDay: a current month follows today; a stepped one stays', () async {
    final c = cubit();
    await c.start();
    clock.now = DateTime(2026, 11, 1, 9).toUtc();
    await c.newDay();
    expect(c.value.range.from, '2026-11-01');
    c.step(-2); // September
    await pumpEventQueue();
    clock.now = DateTime(2026, 12, 1, 9).toUtc();
    await c.newDay();
    expect(c.value.range.from, '2026-09-01');
  });

  test('reloadIfChanged reads only after a write', () async {
    final c = cubit();
    await c.start();
    expect(await c.reloadIfChanged(), isFalse);
    await add('2026-10-02', 100);
    expect(await c.reloadIfChanged(), isTrue);
    expect(total(c), BigInt.from(100));
  });

  test('a late load never replaces a newer one', () async {
    await add('2026-09-15', 1);
    await add('2026-10-02', 2);
    final c = cubit();
    await c.start();
    c.step(-1);
    c.step(1);
    await pumpEventQueue();
    expect(c.value.range.from, '2026-10-01');
    expect(total(c), BigInt.from(2));
  });

  test('setExportOptions remembers; the same does nothing', () async {
    final c = cubit();
    await c.start();
    const options = ReportExportOptions(
      chart: ExportChart.pie,
      groupOthers: false,
    );
    await c.setExportOptions(options);
    expect(c.exportOptions, options);
    expect((await deps.settings.loadReport()).prefs.export, options);
  });

  test('a search still matches descriptions (read only for a text '
      'filter)', () async {
    final at = DateTime.parse('2026-10-02 12:00:00');
    await deps.expenses.add(
      ExpenseInput(
        title: 'Dinner',
        description: 'with the café team',
        amount: const Money(700, 'INR'),
        occurredAt: at.toUtc(),
        utcOffsetMinutes: at.timeZoneOffset.inMinutes,
        categoryId: 1,
        paymentMethodId: 1,
        eventIds: const {},
      ),
    );
    await add('2026-10-03', 100);
    final c = cubit();
    await c.start();
    expect(c.value.data!.rows.every((r) => r.description == null), isTrue);
    await c.setFilter(const ReportFilter(base: ExpenseFilter(text: 'CAFÉ')));
    expect(total(c), BigInt.from(700));
  });
}
