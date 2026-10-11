import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/services/report_pdf.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/models/dashboard_options.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/report.dart';
import 'package:my_expense_tracker_app/domain/report_document.dart';
import 'package:my_expense_tracker_app/domain/report_filter.dart';
import 'package:my_expense_tracker_app/domain/report_range.dart';
import 'package:my_expense_tracker_app/ui/core/charts/donut_chart.dart';

import '../../../helpers/fake_report_export_service.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

/// Phase 8's flows through the real app (phase-8.md §12 "Widgets", the
/// owner's overhaul of 2026-10-10), on the Oppo's 360 dp: an overflow
/// anywhere fails.
void main() {
  late AppDependencies deps;
  late TestClock clock;
  late FakeReportExportService files;

  setUp(() async {
    // Sat 10 Oct 2026, noon local.
    clock = TestClock(DateTime(2026, 10, 10, 12).toUtc());
    files = FakeReportExportService();
    deps = await openTestDependencies(clock: clock, reportExports: files);
    await deps.settings.setOnboardingCompleted();
  });

  void useOppoSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3; // 360 × 800 dp
    addTearDown(tester.view.reset);
  }

  /// An expense at noon local time on [day].
  Future<Expense> add(
    String day, {
    String title = 'Lunch',
    int minor = 10000,
    String code = 'INR',
    int categoryId = 1,
    int methodId = 1,
    Set<int> eventIds = const {},
  }) {
    final at = DateTime.parse('$day 12:00:00');
    return deps.expenses.add(
      ExpenseInput(
        title: title,
        description: null,
        amount: Money(minor, code),
        occurredAt: at.toUtc(),
        utcOffsetMinutes: at.timeZoneOffset.inMinutes,
        categoryId: categoryId,
        paymentMethodId: methodId,
        eventIds: eventIds,
      ),
    );
  }

  final headline = find.byKey(const ValueKey('reportHeadline'));
  final card = find.byKey(const ValueKey('reportCard'));
  final generate = find.byKey(const ValueKey('reportGenerate'));

  String headlineText(WidgetTester tester) =>
      tester.widget<Text>(headline).data!;

  Future<void> openReports(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(NavigationDestination, 'Reports'));
    await tester.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester tester, Offset by) async {
    await tester.fling(card, by, 1000);
    await tester.pumpAndSettle();
  }

  Future<void> tapInSheet(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('this month\'s bars at first; swipe up → donut → bars; '
      'no trend; saved', (tester) async {
    useOppoSize(tester);
    await add('2026-10-02', minor: 30000, categoryId: 1);
    await add('2026-10-03', minor: 10000, categoryId: 2);
    await add('2026-09-30', minor: 99900, categoryId: 3);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    // Named once, in the period row; the card says what it shows.
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Grouped by Category'), findsOneWidget);
    expect(headlineText(tester), '₹400.00');
    expect(find.byKey(const ValueKey('reportBars')), findsOneWidget);
    await swipe(tester, const Offset(0, -80));
    expect(find.byKey(const ValueKey('reportDonut')), findsOneWidget);
    expect(find.text('2'), findsWidgets); // the centre: 2 expenses
    expect((await deps.settings.loadReport()).prefs.chart, ReportChart.donut);
    await swipe(tester, const Offset(0, -80));
    expect(find.byKey(const ValueKey('reportBars')), findsOneWidget);
    // The breakdown rows and Group by are gone (owner, 2026-10-10).
    expect(find.text('Group by'), findsNothing);
    expect(generate, findsOneWidget);
  });

  testWidgets('a USD expense → swipe left: the card follows', (tester) async {
    useOppoSize(tester);
    await add('2026-10-02', minor: 30000, categoryId: 1);
    await add('2026-10-04', minor: 500, code: 'USD', categoryId: 3);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    await swipe(tester, const Offset(-150, 0));
    expect(headlineText(tester), '\$5.00');
  });

  testWidgets('a tap on Other lists what it holds, largest first', (
    tester,
  ) async {
    useOppoSize(tester);
    // 7 categories: the card shows 5 and Other with the 2 smallest.
    for (var c = 1; c <= 7; c++) {
      await add('2026-10-02', minor: c * 1000, categoryId: c);
    }
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    await tester.tap(find.text('Other (2)'));
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey('reportOtherList'));
    expect(list, findsOneWidget);
    final titles = [
      for (final t in tester.widgetList<ListTile>(
        find.descendant(of: list, matching: find.byType(ListTile)),
      ))
        (t.title! as Text).data,
    ];
    expect(titles, hasLength(2));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(list, findsNothing);
  });

  testWidgets('‹ › step months; the name goes back to the current one', (
    tester,
  ) async {
    useOppoSize(tester);
    await add('2026-09-15', minor: 4200);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    await tester.tap(find.byKey(const ValueKey('reportPrevious')));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsWidgets);
    expect(headlineText(tester), '₹42.00');
    await tester.tap(find.byKey(const ValueKey('reportRangeName')));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsWidgets);
  });

  testWidgets('Range → dialog; All time greys the dates; Show', (tester) async {
    useOppoSize(tester);
    await add('2019-03-12', minor: 100);
    await add('2026-10-02', minor: 200);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    await tester.tap(find.text('Range'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rangeAllTime')));
    await tester.pumpAndSettle();
    final from = tester.widget<ListTile>(
      find.descendant(
        of: find.byKey(const ValueKey('rangeFrom')),
        matching: find.byType(ListTile),
      ),
    );
    expect(from.enabled, isFalse);
    await tester.tap(find.byKey(const ValueKey('rangeShow')));
    await tester.pumpAndSettle();
    expect(headlineText(tester), '₹3.00');
    final prefs = (await deps.settings.loadReport()).prefs;
    expect(prefs.period, ReportPeriod.range);
    expect(prefs.range, const ReportRange.allTime());
  });

  testWidgets('Range then Cancel changes nothing', (tester) async {
    useOppoSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    await tester.tap(find.text('Range'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final button = tester.widget<SegmentedButton<ReportPeriod>>(
      find.byKey(const ValueKey('reportPeriod')),
    );
    expect(button.selected, {ReportPeriod.month});
  });

  testWidgets('no expense: the empty card, Generate disabled', (tester) async {
    useOppoSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    expect(find.text('No expenses in October 2026.'), findsWidgets);
    expect(tester.widget<ButtonStyleButton>(generate).onPressed, isNull);
    expect(find.text('Nothing to export'), findsOneWidget);
  });

  testWidgets('back on Reports goes to Home', (tester) async {
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('TalkBack: the card reads its range, face and total', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    useOppoSize(tester);
    await add('2026-10-02', minor: 100);
    await add('2026-10-02', minor: 100, code: 'USD');
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    expect(
      find.bySemanticsLabel(RegExp(r'^October 2026, Bars, total ')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('Settings (owner, 2026-10-11): no Reports tile (nothing left '
      'to choose); a Card vibration tile of its own, felt once; no longer '
      'in Settings → Home', (tester) async {
    useOppoSize(tester);
    await add('2026-10-02');
    final felt = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          felt.add('${call.arguments}');
        }
        return null;
      },
    );
    final settings = await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settingsReports')), findsNothing);
    final vibration = find.byKey(const ValueKey('settingsVibration'));
    await tester.scrollUntilVisible(vibration, 100);
    await tester.tap(vibration);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strong'));
    await tester.pumpAndSettle();
    expect(settings.value.trendCardHaptics, CardHaptics.strong);
    expect(felt, ['HapticFeedbackType.heavyImpact']);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settingsHome')),
      -100,
    );
    await tester.tap(find.byKey(const ValueKey('settingsHome')));
    await tester.pumpAndSettle();
    expect(find.text('Card vibration'), findsNothing);
  });

  testWidgets('filter sheet: payment methods, no Group by; chip ✕; saved', (
    tester,
  ) async {
    useOppoSize(tester);
    await add('2026-10-02', title: 'Lunch', minor: 100, methodId: 1);
    await add('2026-10-04', title: 'Taxi', minor: 400, methodId: 2);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    await tester.tap(find.byKey(const ValueKey('reportFilterButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('groupBy')), findsNothing);
    final methods = find.byKey(const ValueKey('filterPaymentMethods'));
    await tapInSheet(
      tester,
      find.descendant(of: methods, matching: find.text('UPI')),
    );
    await tester.tap(find.byKey(const ValueKey('showResults')));
    await tester.pumpAndSettle();
    expect(headlineText(tester), '₹4.00');
    final chip = find.byKey(const ValueKey('filterChipPaymentMethods'));
    expect(chip, findsOneWidget);
    expect((await deps.settings.loadReport()).prefs.filter.paymentMethodIds, {
      2,
    });
    await tester.tap(
      find.descendant(of: chip, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    expect(headlineText(tester), '₹5.00');
  });

  testWidgets('a restart opens on the saved period, filter and face', (
    tester,
  ) async {
    useOppoSize(tester);
    await add('2026-10-06', title: 'Dinner', minor: 100, methodId: 1);
    await deps.settings.setReportPeriod(ReportPeriod.week);
    await deps.settings.setReportChart(ReportChart.donut);
    await deps.settings.setReportFilter(
      const ReportFilter(
        base: ExpenseFilter(text: 'dinner'),
        paymentMethodIds: {1},
      ),
    );
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    final button = tester.widget<SegmentedButton<ReportPeriod>>(
      find.byKey(const ValueKey('reportPeriod')),
    );
    expect(button.selected, {ReportPeriod.week});
    expect(find.text('Oct Week 2'), findsWidgets);
    expect(find.byKey(const ValueKey('reportDonut')), findsOneWidget);
    expect(find.byKey(const ValueKey('filterChipText')), findsOneWidget);
    expect(headlineText(tester), '₹1.00');
  });

  testWidgets('a deleted chosen event: "Filter changed", and the filter '
      'is saved without it', (tester) async {
    useOppoSize(tester);
    await add('2026-10-02', minor: 100);
    final party = await deps.events.add(name: 'Party', emoji: '🎉');
    await deps.settings.setReportFilter(
      ReportFilter(base: ExpenseFilter(eventIds: {party.id})),
    );
    await deps.events.delete(party.id);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    expect(
      find.text('Filter changed: a chosen item was deleted.'),
      findsOneWidget,
    );
    expect((await deps.settings.loadReport()).prefs.filter, ReportFilter.none);
  });

  group('Generate report (owner, 2026-10-10)', () {
    /// 360 dp wide and tall enough for the whole sheet, so a tap never
    /// lands on the sheet's buttons over a half-scrolled list.
    void useTallOppo(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 7200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> openGenerate(WidgetTester tester) async {
      await tester.tap(generate);
      await tester.pumpAndSettle();
    }

    Finder segment(String key, String label) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.text(label),
    );

    testWidgets('by event, Excel, Save → opened at once, the cache copy '
        'deleted; options remembered', (tester) async {
      useTallOppo(tester);
      await add('2026-10-02', title: 'Gift', minor: 7000, eventIds: {1});
      await add('2026-10-03', title: 'Cake', minor: 2000, eventIds: {2});
      await add('2026-10-04', title: 'Both', minor: 3000, eventIds: {1, 2});
      await pumpApp(tester, dependencies: deps);
      await openReports(tester);
      await openGenerate(tester);
      expect(find.text('Generate a report'), findsOneWidget);
      await tapInSheet(tester, segment('generateGroupBy', 'Event'));
      await tapInSheet(tester, segment('generateFormat', 'Excel (.xlsx)'));
      await tapInSheet(tester, find.byKey(const ValueKey('generateSave')));
      expect(files.books, hasLength(1));
      final sheets = [for (final s in files.books.single.sheets) s.name];
      expect(sheets.first, 'Overall');
      expect(sheets, hasLength(3)); // Overall + 2 events
      expect(files.saved, hasLength(1));
      // Opened at once, no snackbar (owner, 2026-10-11); the report cache
      // emptied once saved.
      expect(files.opened, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
      expect(files.clearCalls, 1);
      final prefs = (await deps.settings.loadReport()).prefs;
      expect(prefs.export.groupBy, GroupDimension.event);
      expect(prefs.export.format, ReportExport.xlsx);
    });

    testWidgets('PDF: chart kind and the Others toggle reach the file', (
      tester,
    ) async {
      useTallOppo(tester);
      for (var c = 1; c <= 8; c++) {
        await add('2026-10-02', minor: c * 100, categoryId: c);
      }
      await pumpApp(tester, dependencies: deps);
      await openReports(tester);
      await openGenerate(tester);
      await tapInSheet(tester, segment('generateChart', 'Pie'));
      await tapInSheet(tester, find.byKey(const ValueKey('generateOthers')));
      await tapInSheet(tester, find.byKey(const ValueKey('generateSave')));
      final charts = files.pdfs.single.blocks.whereType<PdfChart>().toList();
      expect(charts.first.kind, ExportChart.pie);
      // Others off: every category its own slice in the overall chart.
      expect(charts.first.slices, hasLength(8));
    });

    testWidgets('the sheet\'s filter becomes the screen\'s, also when '
        'closed without generating', (tester) async {
      useTallOppo(tester);
      await add('2026-10-02', title: 'Lunch', minor: 100, methodId: 1);
      await add('2026-10-04', title: 'Taxi', minor: 400, methodId: 2);
      await pumpApp(tester, dependencies: deps);
      await openReports(tester);
      await openGenerate(tester);
      await tapInSheet(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('filterPaymentMethods')),
          matching: find.text('UPI'),
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(files.pdfs, isEmpty);
      expect(headlineText(tester), '₹4.00');
    });

    testWidgets('Save as… cancelled says nothing; Share without a target '
        'says so; two exports, two folders', (tester) async {
      useTallOppo(tester);
      await add('2026-10-02');
      await pumpApp(tester, dependencies: deps);
      await openReports(tester);
      files.saveAsResult = false;
      await openGenerate(tester);
      await tapInSheet(tester, find.byKey(const ValueKey('generateSaveAs')));
      expect(find.byType(SnackBar), findsNothing);
      files.noShareTarget = true;
      await openGenerate(tester);
      await tapInSheet(tester, find.byKey(const ValueKey('generateShare')));
      expect(
        find.text('No app on this phone can receive the file.'),
        findsOneWidget,
      );
      expect(files.paths.toSet(), hasLength(2));
    });

    testWidgets('Cancel in the busy dialog, or back: nothing saved', (
      tester,
    ) async {
      useTallOppo(tester);
      await add('2026-10-02');
      await pumpApp(tester, dependencies: deps);
      await openReports(tester);
      for (final viaBack in [false, true]) {
        files.holdWrite = Completer<void>();
        await openGenerate(tester);
        final save = find.byKey(const ValueKey('generateSave'));
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const ValueKey('exportBusyText')), findsOneWidget);
        if (viaBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byKey(const ValueKey('exportCancel')));
        }
        await tester.pump();
        files.holdWrite!.complete();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('exportBusyText')), findsNothing);
        expect(files.saved, isEmpty, reason: 'viaBack $viaBack');
        expect(find.byType(SnackBar), findsNothing);
      }
    });
    testWidgets('while the file is being saved, Cancel is off: the copy '
        'can no longer be stopped', (tester) async {
      useTallOppo(tester);
      await add('2026-10-02', minor: 100);
      files.holdSave = Completer<void>();
      await pumpApp(tester, dependencies: deps);
      await openReports(tester);
      await openGenerate(tester);
      final save = find.byKey(const ValueKey('generateSave'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final cancel = find.byKey(const ValueKey('exportCancel'));
      expect(tester.widget<TextButton>(cancel).onPressed, isNull);
      files.holdSave!.complete();
      await tester.pumpAndSettle();
      expect(files.saved, hasLength(1));
    });

    testWidgets('a report that failed to load while the sheet was open says '
        'so instead of doing nothing', (tester) async {
      useTallOppo(tester);
      await add('2026-10-02', minor: 100);
      await pumpApp(tester, dependencies: deps);
      await openReports(tester);
      await openGenerate(tester);
      // The next read fails; a write elsewhere and a resume trigger it.
      await deps.database.execute('DROP TABLE expense_events');
      deps.dataVersion.bump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tapInSheet(tester, find.byKey(const ValueKey('generateSave')));
      expect(files.saved, isEmpty);
      expect(find.text("Couldn't load the report."), findsWidgets);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  testWidgets('a ₹0 group reads 0.0 %, not "< 0.1 %"', (tester) async {
    useOppoSize(tester);
    await add('2026-10-02', minor: 10000, categoryId: 1);
    await add('2026-10-02', minor: 0, categoryId: 2);
    await deps.settings.setReportChart(ReportChart.donut);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    expect(find.text('100.0 %'), findsOneWidget);
    expect(find.text('0.0 %'), findsOneWidget);
    expect(find.text('< 0.1 %'), findsNothing);
  });

  testWidgets('layout: at 360 dp and the largest font the donut leaves its '
      'legend room (found on the Oppo in Hindi)', (tester) async {
    useOppoSize(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (var c = 1; c <= 7; c++) {
      await add('2026-10-02', minor: c * 1000, categoryId: c);
    }
    await deps.settings.setReportChart(ReportChart.donut);
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    final ring = tester.getSize(find.byType(DonutChart)).width;
    final cardWidth = tester.getSize(card).width;
    expect(ring, lessThanOrEqualTo(cardWidth * 0.38));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Save with no app to open it: says where it was saved', (
    tester,
  ) async {
    useOppoSize(tester);
    await add('2026-10-02');
    files.noViewer = true;
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('generateSave'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Saved to Download/Expense Tracker. No app on this phone can open it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Highlights under the card follow the currency; Generate is '
      'pinned at the bottom (owner, 2026-10-11)', (tester) async {
    useOppoSize(tester);
    await add('2026-10-02', title: 'Rent', minor: 1500000, methodId: 2);
    await add('2026-10-03', title: 'Tea', minor: 2000, eventIds: {1});
    await add('2026-10-04', title: 'Cab', minor: 2500, code: 'USD');
    await pumpApp(tester, dependencies: deps);
    await openReports(tester);
    String valueOf(String key) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .join(' | ');
    expect(valueOf('hiExpenses'), contains('2'));
    // ₹15,020.00 over 1–10 Oct: 10 days.
    expect(valueOf('hiPerDay'), contains('₹1,502.00'));
    expect(valueOf('hiPerDay'), contains('over 10 days'));
    expect(valueOf('hiLargest'), contains('Rent'));
    expect(valueOf('hiTopMethod'), contains('UPI'));
    expect(valueOf('hiTopEvent'), contains('Birthday'));
    await swipe(tester, const Offset(-150, 0));
    expect(valueOf('hiLargest'), contains('Cab'));
    expect(find.byKey(const ValueKey('hiTopEvent')), findsNothing);
    // The button sits at the bottom, above the tab bar, whatever scrolls.
    final button = tester.getRect(generate);
    final bar = tester.getRect(find.byType(NavigationBar));
    expect(bar.top - button.bottom, lessThan(40));
    expect(tester.takeException(), isNull);
  });
}
