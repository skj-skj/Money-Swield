import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/models/dashboard_options.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/ui/core/charts/charts.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/list_frames.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/amount_chips_row.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/day_header.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// Phase 5's flows through the real app (phase-5.md §12 "Widgets"), on a
/// 360 dp wide screen like the Oppo A77s: an overflow anywhere fails.
void main() {
  late AppDependencies deps;
  late TestClock clock;

  setUp(() async {
    // Mon 5 Oct 2026, noon local: names without a year are this year's.
    clock = TestClock(DateTime(2026, 10, 5, 12).toUtc());
    deps = await openTestDependencies(clock: clock);
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
        paymentMethodId: 1,
        eventIds: eventIds,
      ),
    );
  }

  final card = find.byKey(const ValueKey('trendCard'));
  final headline = find.byKey(const ValueKey('trendHeadline'));

  String headlineText(WidgetTester tester) =>
      tester.widget<Text>(headline).data!;

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await tester.pumpAndSettle();
  }

  Future<void> openHomeSettings(WidgetTester tester) async {
    await openTab(tester, 'Settings');
    await tester.tap(find.byKey(const ValueKey('settingsHome')));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String row, String option) async {
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  /// The sheet's Group by is below its lists: scrolled into view first.
  Future<void> pickGrouping(WidgetTester tester, String label) async {
    final segment = find.descendant(
      of: find.byKey(const ValueKey('groupBy')),
      matching: find.text(label),
    );
    await tester.scrollUntilVisible(
      segment,
      200,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(segment);
    await tester.pump();
  }

  /// Taps the tile [name] in the filter sheet's picker [pickerKey].
  Future<void> tapTile(
    WidgetTester tester,
    String pickerKey,
    String name,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(pickerKey)),
        matching: find.text(name),
      ),
    );
    await tester.pump();
  }

  /// Settings → the Card vibration tile → [option].
  Future<void> pickVibration(WidgetTester tester, String option) async {
    await openTab(tester, 'Settings');
    final tile = find.byKey(const ValueKey('settingsVibration'));
    await tester.scrollUntilVisible(tile, 100);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> backHome(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTab(tester, 'Home');
  }

  group('trend card', () {
    testWidgets('month total, currency carousel loops, tap a point', (
      tester,
    ) async {
      useOppoSize(tester);
      await add('2026-10-05', minor: 10000);
      await add('2026-10-02', minor: 5050);
      await add('2026-10-05', minor: 8500, code: 'USD');
      await add('2026-09-30', minor: 99900); // last month: not in it
      await pumpApp(tester, dependencies: deps);

      expect(find.descendant(of: card, matching: find.text('Oct')), findsOne);
      expect(headlineText(tester), '₹150.50');
      expect(find.text('INR · usd'), findsOneWidget);

      await tester.drag(card, const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(headlineText(tester), r'$85.00');
      await tester.drag(card, const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(headlineText(tester), '₹150.50', reason: 'endless loop');
      await tester.drag(card, const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(headlineText(tester), r'$85.00');
      await tester.drag(card, const Offset(250, 0));
      await tester.pumpAndSettle();

      // Today's point (5 Oct is the 5th of 31 slots).
      final chart = tester.getRect(
        find
            .descendant(
              of: find.byType(SeriesChart),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      await tester.tapAt(
        Offset(chart.left + chart.width / 31 * 4.5, chart.center.dy),
      );
      await tester.pump();
      expect(find.text('Mon, Oct 5 · ₹100.00'), findsOneWidget);
      expect(headlineText(tester), '₹150.50', reason: 'still the total');
    });

    testWidgets('one currency: a sideways swipe springs back', (tester) async {
      useOppoSize(tester);
      await add('2026-10-05');
      await pumpApp(tester, dependencies: deps);
      await tester.drag(card, const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(headlineText(tester), '₹100.00');
    });

    testWidgets('swipe up / down turns it like a reel; the turn is saved', (
      tester,
    ) async {
      useOppoSize(tester);
      await add('2026-10-05');
      await add('2026-03-05', minor: 1);
      await pumpApp(tester, dependencies: deps);
      expect(headlineText(tester), '₹100.00');
      // Mid-drag faces, springing back, flicks and detents:
      // trend_card_gestures_test. Here: the turn in the app, and it's saved.

      await tester.drag(card, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.descendant(of: card, matching: find.text('2026')), findsOne);
      expect(headlineText(tester), '₹100.01');
      expect(
        tester.widgetList(
          find.descendant(
            of: find.byType(SeriesChart),
            matching: find.byType(CustomPaint),
          ),
        ),
        isNotEmpty,
      );

      for (var i = 0; i < 2; i++) {
        await tester.drag(card, const Offset(0, 200));
        await tester.pumpAndSettle();
      }
      expect(
        find.descendant(of: card, matching: find.text('Oct Week 2')),
        findsOne,
      );
      expect((await deps.settings.load()).cardPeriod, Period.week);
    });

    testWidgets('with animations off it switches on release; TalkBack '
        'actions turn it', (tester) async {
      useOppoSize(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final semantics = tester.ensureSemantics();
      await add('2026-10-05');
      await pumpApp(tester, dependencies: deps);

      await tester.drag(card, const Offset(0, -200));
      await tester.pump();
      expect(find.descendant(of: card, matching: find.text('2026')), findsOne);

      final withActions = find.semantics.byPredicate(
        (node) =>
            node.getSemanticsData().customSemanticsActionIds?.isNotEmpty ??
            false,
      );
      final labels = [
        for (final id
            in withActions
                .evaluate()
                .single
                .getSemanticsData()
                .customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(labels, containsAll(['Next period', 'Previous period']));
      expect(labels, isNot(contains('Next currency')), reason: 'one currency');
      tester.semantics.customAction(
        withActions,
        const CustomSemanticsAction(label: 'Next period'),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: card, matching: find.text('Oct Week 2')),
        findsOne,
      );
      semantics.dispose();
    });

    testWidgets('locked: the list scrolls under it; scrolling: it scrolls '
        'away, and a drag on it turns it', (tester) async {
      useOppoSize(tester);
      for (var i = 1; i <= 20; i++) {
        await add('2026-10-${'$i'.padLeft(2, '0')}');
      }
      await pumpApp(tester, dependencies: deps);
      final top = tester.getTopLeft(card).dy;
      await tester.drag(find.byType(DayHeader).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(card).dy, top, reason: 'locked');

      await openHomeSettings(tester);
      await choose(tester, 'Trend card', 'Scrolls with the list');
      await backHome(tester);
      final start = tester.getTopLeft(card).dy;

      // A drag on the card turns it and doesn't scroll.
      await tester.drag(card, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(card).dy, start);
      expect(find.descendant(of: card, matching: find.text('2026')), findsOne);

      // A drag on the list scrolls the card away.
      await tester.drag(find.byType(DayHeader).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(card.hitTestable(), findsNothing);
    });

    testWidgets('chart style: filled line, bars, line; Restore default look '
        'keeps it (P5-33)', (tester) async {
      useOppoSize(tester);
      await add('2026-10-05');
      await pumpApp(tester, dependencies: deps);
      ChartKind style() =>
          tester.widget<SeriesChart>(find.byType(SeriesChart)).kind;
      expect(style(), ChartKind.area);

      await openHomeSettings(tester);
      await choose(tester, 'Trend chart', 'Bars');
      await backHome(tester);
      expect(style(), ChartKind.bars);

      await openTab(tester, 'Settings');
      await tester.tap(find.byKey(const ValueKey('settingsLook')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore default look'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();
      await backHome(tester);
      expect(style(), ChartKind.bars);
    });
  });

  group('card size and the new chart styles (owner, 2026-10-06)', () {
    double chartHeight(WidgetTester tester) =>
        tester.widget<SeriesChart>(find.byType(SeriesChart)).height;

    testWidgets('large, medium and small: the chart and the card shrink', (
      tester,
    ) async {
      useOppoSize(tester);
      await add('2026-10-05');
      await pumpApp(tester, dependencies: deps);
      expect(chartHeight(tester), 80, reason: 'Medium is the default');
      final medium = tester.getSize(card).height;

      await openHomeSettings(tester);
      await choose(tester, 'Card size', 'Large');
      await backHome(tester);
      expect(chartHeight(tester), 120);
      final large = tester.getSize(card).height;

      await openHomeSettings(tester);
      await choose(tester, 'Card size', 'Small');
      await backHome(tester);
      expect(chartHeight(tester), 44);
      expect(tester.getSize(card).height, lessThan(medium));
      expect(medium, lessThan(large));
      expect((await deps.settings.load()).trendCardSize, TrendCardSize.small);
    });

    testWidgets('Settings → Home → Card vibration: felt when picked, and '
        'on Home at each face (owner, 2026-10-07)', (tester) async {
      final felt = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            felt.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      useOppoSize(tester);
      await add('2026-10-05');
      await pumpApp(tester, dependencies: deps);
      // The default, Light: a click as the card turns one face.
      await tester.fling(card, const Offset(0, -80), 1500);
      await tester.pumpAndSettle();
      expect(felt, ['HapticFeedbackType.selectionClick']);

      felt.clear();
      // Its own Settings tile since the owner's change of 2026-10-11.
      await pickVibration(tester, 'Strong');
      expect(felt, ['HapticFeedbackType.heavyImpact'], reason: 'a preview');
      await openTab(tester, 'Home');
      felt.clear();
      await tester.fling(card, const Offset(0, -80), 1500);
      await tester.pumpAndSettle();
      expect(felt, ['HapticFeedbackType.heavyImpact']);

      await pickVibration(tester, 'Off');
      await openTab(tester, 'Home');
      felt.clear();
      await tester.fling(card, const Offset(0, -80), 1500);
      await tester.pumpAndSettle();
      expect(felt, isEmpty);
      expect((await deps.settings.load()).trendCardHaptics, CardHaptics.off);
    });

    testWidgets('Settings → Home → Restore defaults asks, then puts the six '
        'back', (tester) async {
      useOppoSize(tester);
      await add('2026-10-05');
      await deps.settings.setTrendChartStyle(TrendChartStyle.bar);
      await deps.settings.setTrendCardSize(TrendCardSize.small);
      await deps.settings.setTrendCardPosition(TrendCardPosition.scrolls);
      await deps.settings.setWeekStart(WeekStart.sunday);
      await deps.settings.setWeekLabel(WeekLabel.number);
      await pumpApp(tester, dependencies: deps);
      await openHomeSettings(tester);
      await tester.tap(find.byKey(const ValueKey('restoreHomeDefaults')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Bars'), findsOneWidget, reason: 'cancelled');

      await tester.tap(find.byKey(const ValueKey('restoreHomeDefaults')));
      await tester.pumpAndSettle();
      expect(find.text('Restore the Home defaults?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();
      for (final shown in [
        'Smooth line, filled',
        'Locked at the top',
        'Medium',
        'Monday',
        'Oct Week 2',
      ]) {
        expect(find.text(shown), findsOneWidget, reason: shown);
      }
      await backHome(tester);
      expect(chartHeight(tester), 80);
      expect(
        tester.widget<SeriesChart>(find.byType(SeriesChart)).kind,
        ChartKind.area,
      );
    });

    testWidgets('running total: climbs to the headline; a tap says "Up to"', (
      tester,
    ) async {
      useOppoSize(tester);
      await add('2026-10-02', minor: 5000);
      await add('2026-10-05', minor: 10000);
      await deps.settings.setTrendChartStyle(TrendChartStyle.runningTotal);
      await pumpApp(tester, dependencies: deps);
      final chart = tester.widget<SeriesChart>(find.byType(SeriesChart));
      expect(chart.kind, ChartKind.area);
      // 1 Oct 0, 2 Oct ⅓ of the total, 5 Oct onwards the whole total.
      expect(chart.fractions.take(6), [0, 1 / 3, 1 / 3, 1 / 3, 1, 1]);
      expect(chart.fractions.last, 1);
      chart.onTap(4);
      await tester.pump();
      expect(find.text('Up to Mon, Oct 5 · ₹150.00'), findsOneWidget);
      expect(headlineText(tester), '₹150.00');
    });

    testWidgets('dots', (tester) async {
      useOppoSize(tester);
      await add('2026-10-05');
      await deps.settings.setTrendChartStyle(TrendChartStyle.dots);
      await pumpApp(tester, dependencies: deps);
      expect(
        tester.widget<SeriesChart>(find.byType(SeriesChart)).kind,
        ChartKind.dots,
      );
    });

    testWidgets('mid-turn both faces are opaque: neither shows through', (
      tester,
    ) async {
      useOppoSize(tester);
      await add('2026-10-05');
      await pumpApp(tester, dependencies: deps);
      final gesture = await tester.startGesture(tester.getCenter(card));
      await gesture.moveBy(const Offset(0, -20));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      final faceColor = Theme.of(tester.element(card))
          .colorScheme
          .surfaceContainerLow;
      final opaque = tester
          .widgetList<ColoredBox>(
            find.descendant(of: card, matching: find.byType(ColoredBox)),
          )
          .where((box) => box.color == faceColor);
      expect(opaque, hasLength(2));
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('filters', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('filterButton')));
      await tester.pumpAndSettle();
    }

    testWidgets('the sheet applies however it closes; the card follows', (
      tester,
    ) async {
      useOppoSize(tester);
      await add('2026-10-05', title: 'Lunch', minor: 25000, categoryId: 1);
      await add('2026-10-04', title: 'Lunch box', minor: 5000, categoryId: 3);
      await add('2026-10-03', title: 'Dinner', minor: 70000, categoryId: 1);
      await pumpApp(tester, dependencies: deps);
      expect(headlineText(tester), '₹1,000.00');

      await openSheet(tester);
      await tester.enterText(find.byKey(const ValueKey('filterSearch')), 'lun');
      await tapTile(tester, 'filterCategories', 'Food');
      await pickGrouping(tester, 'Month');
      // Closed with Back, not Show results: applied all the same.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('"lun"'), findsOneWidget);
      expect(find.text('🍽️ Food'), findsOneWidget);
      expect(find.text('By month'), findsOneWidget);
      expect(find.text('Dinner'), findsNothing);
      expect(find.text('Lunch box'), findsNothing);
      expect(find.text('Lunch'), findsOneWidget);
      expect(headlineText(tester), '₹250.00');
      expect(find.byKey(const ValueKey('trendFiltered')), findsOneWidget);
      // The month frame's subtotal: exactly what the filter shows.
      expect(find.text('₹250.00'), findsWidgets);
      expect((await deps.settings.load()).listGrouping, Period.month);

      // ✕ on the text: Food rows only.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('filterChipText')),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dinner'), findsOneWidget);
      expect(headlineText(tester), '₹950.00');

      // Nothing matches → Clear filters → everything.
      await openSheet(tester);
      await tester.enterText(find.byKey(const ValueKey('filterSearch')), 'zzz');
      await tester.tap(find.byKey(const ValueKey('showResults')));
      await tester.pumpAndSettle();
      expect(find.text('No expenses match these filters'), findsOneWidget);
      // Clear of the floating Add button (it once sat under it).
      final clear = tester.getRect(find.byKey(const ValueKey('clearFilters')));
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(clear.overlaps(fab), isFalse, reason: '$clear vs $fab');
      await tester.tap(find.byKey(const ValueKey('clearFilters')));
      await tester.pumpAndSettle();
      expect(find.text('Lunch box'), findsOneWidget);
      expect(find.byKey(const ValueKey('trendFiltered')), findsNothing);
      expect(headlineText(tester), '₹1,000.00');
    });

    for (final code in ['en', 'es', 'hi']) {
      testWidgets('no match, $code, largest font: Clear filters stays clear '
          'of the floating Add button', (tester) async {
        // The Oppo's 806 dp less its 36 dp status bar.
        tester.view.physicalSize = const Size(720, 1612);
        tester.view.devicePixelRatio = 2;
        tester.view.padding = const FakeViewPadding(top: 72);
        tester.view.viewPadding = const FakeViewPadding(top: 72);
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await deps.settings.setLocale(Locale(code));
        // Enough expenses for the usual-amounts row, which pushes the
        // empty state down (on the Oppo it once sat 7 dp under the button).
        for (var i = 0; i < 6; i++) {
          await add('2026-10-05', minor: 10000 + i * 100);
        }
        await pumpApp(tester, dependencies: deps);
        await openSheet(tester);
        await tester.enterText(
          find.byKey(const ValueKey('filterSearch')),
          'zzz',
        );
        await tester.tap(find.byKey(const ValueKey('showResults')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AmountChipsRow>(find.byType(AmountChipsRow)).chips,
          isNotEmpty,
        );
        final clearFilters = find.byKey(const ValueKey('clearFilters'));
        final fab = tester.getRect(find.byType(FloatingActionButton));
        // Where it is on screen, it is never under the button…
        expect(
          tester.getRect(clearFilters).overlaps(fab),
          isFalse,
          reason: '${tester.getRect(clearFilters)} vs $fab',
        );
        // …and with a font this large it may start below the fold: then
        // the list scrolls far enough to lift it clear above the button.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pumpAndSettle();
        final clear = tester.getRect(clearFilters);
        expect(clear.bottom, lessThanOrEqualTo(fab.top), reason: '$clear');
        await tester.tap(clearFilters);
        await tester.pumpAndSettle();
        expect(find.text('Lunch'), findsWidgets);
      });
    }

    testWidgets('the sheet: Group by first; categories and events are tile '
        'pickers, several at a time, each searched on its own', (tester) async {
      useOppoSize(tester);
      await add('2026-10-05', title: 'Lunch', categoryId: 1);
      await pumpApp(tester, dependencies: deps);
      await openSheet(tester);
      final groupBy = tester.getTopLeft(find.byKey(const ValueKey('groupBy')));
      expect(
        groupBy.dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('filterSearch'))).dy,
        ),
      );
      expect(find.text('New category'), findsNothing, reason: 'no New');

      await tapTile(tester, 'filterCategories', 'Food');
      await tapTile(tester, 'filterCategories', 'Bills');
      await tapTile(tester, 'filterEvents', 'Party');
      // The categories' own search, independent of the text filter.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('filterCategories')),
          matching: find.byTooltip('Search'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('filterCategories')),
          matching: find.byType(TextField),
        ),
        'Tra',
      );
      await tester.pumpAndSettle();
      await tapTile(tester, 'filterCategories', 'Travel');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('filterSearch')))
            .controller!
            .text,
        isEmpty,
      );
      // Back closes the picker's search first, then the sheet.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('groupBy')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('🧾 Bills +2'), findsOneWidget);
      expect(find.text('🎉 Party'), findsOneWidget);
    });

    testWidgets('delete from a filtered list: totals drop, Undo brings them '
        'back', (tester) async {
      useOppoSize(tester);
      await add('2026-10-05', title: 'Lunch', minor: 25000);
      await add('2026-10-05', title: 'Lunch 2', minor: 1000);
      await pumpApp(tester, dependencies: deps);
      await openSheet(tester);
      await tester.enterText(
        find.byKey(const ValueKey('filterSearch')),
        'lunch',
      );
      await tester.tap(find.byKey(const ValueKey('showResults')));
      await tester.pumpAndSettle();
      expect(headlineText(tester), '₹260.00');

      await tester.tap(find.text('Lunch 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(headlineText(tester), '₹250.00');
      expect(find.text('"lunch"'), findsOneWidget, reason: 'filter kept');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(headlineText(tester), '₹260.00');
      expect(find.text('Lunch 2'), findsOneWidget);
    });
  });

  group('frames', () {
    testWidgets('five currencies in a week: Show subtotal opens them, '
        'default first', (tester) async {
      useOppoSize(tester);
      for (final code in ['USD', 'EUR', 'JPY', 'KWD', 'INR']) {
        await add('2026-10-05', minor: 1000, code: code);
      }
      await pumpApp(tester, dependencies: deps);
      expect(find.text('Show subtotal'), findsWidgets);
      await tester.tap(find.text('Show subtotal').first);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Oct Week 2')),
        findsOne,
      );
      final lines = [
        for (final text in tester.widgetList<Text>(
          find.descendant(of: dialog, matching: find.byType(Text)),
        ))
          text.data,
      ];
      expect(lines, [
        'Oct Week 2',
        '₹10.00',
        '€10.00',
        '¥1,000',
        'din 1.000',
        r'$10.00',
        'Close',
      ]);
    });

    testWidgets('one currency fits on the border; at font scale 2 it '
        'becomes the button', (tester) async {
      useOppoSize(tester);
      await add('2026-10-05', minor: 456000);
      await pumpApp(tester, dependencies: deps);
      Finder onFrame(String text) =>
          find.descendant(of: find.byType(FrameTop), matching: find.text(text));
      expect(onFrame('₹4,560.00'), findsOneWidget);
      expect(onFrame('Show subtotal'), findsNothing);

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(onFrame('Show subtotal'), findsOneWidget);
    });

    testWidgets('a group cut by the first page shows the whole subtotal', (
      tester,
    ) async {
      useOppoSize(tester);
      for (var i = 0; i < 40; i++) {
        await add('2026-10-0${5 + i % 3}', minor: 100);
      }
      await pumpApp(tester, dependencies: deps);
      expect(
        find.descendant(
          of: find.byType(FrameTop),
          matching: find.text('₹40.00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Day grouping: a frame per day, no day header; Week: day '
        'headers with the day total', (tester) async {
      useOppoSize(tester);
      await add('2026-10-05', minor: 33000);
      await add('2026-10-04', minor: 120000);
      await pumpApp(tester, dependencies: deps);
      expect(find.byType(DayHeader), findsNWidgets(2));
      expect(find.text('Mon, Oct 5 – ₹330.00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('filterButton')));
      await tester.pumpAndSettle();
      await pickGrouping(tester, 'Day');
      await tester.tap(find.byKey(const ValueKey('showResults')));
      await tester.pumpAndSettle();
      expect(find.byType(DayHeader), findsNothing);
      expect(find.text('Mon, Oct 5'), findsOneWidget);
      expect(find.text('Sun, Oct 4'), findsOneWidget);
    });

    testWidgets('sticky: the frame top and the day header stay at the top', (
      tester,
    ) async {
      useOppoSize(tester);
      for (var i = 0; i < 6; i++) {
        await add('2026-10-05', title: 'Mon $i');
        await add('2026-10-04', title: 'Sun $i');
      }
      await pumpApp(tester, dependencies: deps);
      final week = find.text('Oct Week 2');
      final monday = find.textContaining('Mon, Oct 5 –');
      final listTop = tester.getTopLeft(week).dy;
      await tester.drag(find.text('Mon 3'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(week).dy, closeTo(listTop - 0, 60));
      expect(
        tester.getTopLeft(monday).dy,
        greaterThan(tester.getTopLeft(week).dy),
      );
      // Past Monday: Sunday's header takes its place under the frame top.
      await tester.drag(find.byType(DayHeader).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.textContaining('Sun, Oct 4 –')).dy,
        lessThan(tester.getTopLeft(week).dy + 80),
      );
    });
  });

  group('settings grid', () {
    testWidgets('eight tiles in rows of two, Card vibration after Home '
        '(owner, 2026-10-11; no Reports tile: nothing left to choose), Bin '
        'beside Photos; Bin opens the bin', (tester) async {
      useOppoSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openTab(tester, 'Settings');
      final keys = [
        'settingsLanguage',
        'settingsLook',
        'settingsHome',
        'settingsVibration',
        'settingsDefaults',
        'settingsBackup',
        'settingsPhotos',
        'settingsBin',
      ];
      Rect rectOf(String key) {
        final finder = find.byKey(ValueKey(key));
        return tester.getRect(finder);
      }

      expect(find.text('Smooth line, filled · Locked · Monday'), findsOne);
      expect(find.text('INR · 💵 Cash'), findsOne);
      // The last row is below the fold at 800 dp.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settingsBin')),
        100,
      );
      final rects = [for (final key in keys) rectOf(key)];
      for (var row = 0; row < 4; row++) {
        final left = rects[row * 2];
        final right = rects[row * 2 + 1];
        expect(left.top, right.top);
        expect(left.height, right.height, reason: 'same height');
        expect(left.left, lessThan(right.left));
      }
      expect(rects[2].top, greaterThan(rects[0].bottom));
      expect(rects[7].left, greaterThan(rects[6].left));
      expect(rects[6].top, greaterThan(rects[4].bottom));
      expect(find.text('Camera 1080p · Gallery 1080p'), findsOne);
      expect(find.byKey(const ValueKey('settingsReports')), findsNothing);
      // The vibration's summary is its strength.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settingsVibration')),
          matching: find.text('Light'),
        ),
        findsOne,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settingsBin')),
        100,
      );
      await tester.tap(find.byKey(const ValueKey('settingsBin')));
      await tester.pumpAndSettle();
      expect(find.text('Deleted expenses stay here for 30 days.'), findsOne);
    });

    testWidgets('Week starts on Sunday: Home\'s weeks and the card follow', (
      tester,
    ) async {
      useOppoSize(tester);
      await add('2026-10-04', minor: 100); // Sunday
      await add('2026-10-05', minor: 1000);
      await pumpApp(tester, dependencies: deps);
      await tester.drag(card, const Offset(0, 200)); // Month → Week
      await tester.pumpAndSettle();
      expect(headlineText(tester), '₹10.00');
      expect(find.text('Oct Week 1'), findsOneWidget, reason: 'Sun 4 Oct');

      await openHomeSettings(tester);
      await choose(tester, 'Week starts on', 'Sunday');
      await choose(tester, 'Week names', 'Week 40');
      await backHome(tester);
      expect(headlineText(tester), '₹11.00', reason: 'Sun 4 – Sat 10 Oct');
      expect(find.text('Week 40'), findsWidgets);
      final chartLabels = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(SeriesChart),
          matching: find.byType(Text),
        ),
      );
      expect(chartLabels.first.data, 'S', reason: 'the week starts on Sunday');
    });
  });

  testWidgets('midnight: the card shows the new week (R5)', (tester) async {
    useOppoSize(tester);
    clock.now = DateTime(2026, 10, 4, 23, 59, 50).toUtc(); // Sunday
    await add('2026-10-04', minor: 100);
    await add('2026-10-05', minor: 700);
    await deps.settings.setCardPeriod(Period.week);
    await pumpApp(tester, dependencies: deps);
    expect(headlineText(tester), '₹1.00');

    clock.now = DateTime(2026, 10, 5, 0, 0, 30).toUtc();
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(headlineText(tester), '₹7.00');
    expect(
      find.descendant(of: card, matching: find.text('Oct Week 2')),
      findsOne,
    );
  });

  testWidgets('fresh install: no card, no filter bar, the empty state', (
    tester,
  ) async {
    useOppoSize(tester);
    await pumpApp(tester, dependencies: deps);
    expect(card, findsNothing);
    expect(find.byKey(const ValueKey('filterButton')), findsNothing);
    expect(find.text('No expenses yet'), findsOneWidget);
  });

  group('languages at 360 dp, with long names', () {
    for (final (code, firstLabel) in [('es', 'L'), ('hi', 'सो')]) {
      testWidgets('$code: names, labels and totals fit', (tester) async {
        useOppoSize(tester);
        await deps.settings.setLocale(Locale(code));
        final long = await deps.categories.add(
          name: 'A category with a very long name indeed, really very long',
          emoji: '🧪',
        );
        await add('2026-10-05', minor: 1105000, categoryId: long.id);
        await add('2026-10-05', minor: 999, code: 'USD');
        await pumpApp(tester, dependencies: deps);
        // intl's short month, starting with a capital letter (R13).
        final month = toBeginningOfSentenceCase(
          DateFormat.MMM(code).format(DateTime(2026, 10)),
          code,
        );
        expect(find.descendant(of: card, matching: find.text(month)), findsOne);

        await tester.drag(card, const Offset(0, 200)); // Month → Week
        await tester.pumpAndSettle();
        final labels = tester.widgetList<Text>(
          find.descendant(
            of: find.byType(SeriesChart),
            matching: find.byType(Text),
          ),
        );
        expect(labels.first.data, firstLabel);

        // A long category in the filter bar; then the grid.
        await tester.tap(find.byKey(const ValueKey('filterButton')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('filterCategories')),
            matching: find.textContaining('A category with'),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('showResults')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('filterChipCategories')), findsOne);
        await tester.tap(find.byType(NavigationDestination).last);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('settingsHome')), findsOne);
      });
    }

    testWidgets('es with a Mexican phone: dot decimals', (tester) async {
      useOppoSize(tester);
      tester.platformDispatcher.localeTestValue = const Locale('es', 'MX');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await deps.settings.setLocale(const Locale('es'));
      await add('2026-10-05', minor: 1105000);
      await pumpApp(tester, dependencies: deps);
      expect(headlineText(tester), contains('11,050.00'));
    });
  });
}
