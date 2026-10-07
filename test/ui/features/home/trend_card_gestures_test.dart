import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/domain/models/dashboard_options.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/period_names.dart';
import 'package:my_expense_tracker_app/ui/features/home/view_models/trend_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/trend_card.dart';

/// The trend card's swipes (phase-5.md §8.2, §12e). The reel turns like a
/// mechanical dial: a quick flick turns exactly one face, a held drag one
/// face per card height, with a detent and a haptic tick at each face
/// (owner, 2026-10-07). The whole card takes the swipe, padding included
/// (found on the Oppo). The carousel: a drag while a fling still slides
/// finishes that page at once (regression from the 2026-10-06 review).
void main() {
  const today = '2026-10-05';
  late List<int> turns;
  late List<int> pages;

  /// The haptic calls made, e.g. `HapticFeedbackType.selectionClick`.
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<Finder> pumpCard(
    WidgetTester tester, {
    CardHaptics cardHaptics = CardHaptics.light,
  }) async {
    turns = [];
    pages = [];
    final faces = {
      for (final p in const [Period.week, Period.month, Period.year])
        p: TrendFace(periodOf(today, p, WeekStart.monday), const [
          (today, 'INR', 100),
          (today, 'USD', 5),
        ], 'INR'),
    };
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TrendCard(
              state: TrendLoaded(
                faces: faces,
                period: Period.month,
                currency: 'INR',
                filtered: false,
                today: today,
              ),
              names: PeriodNames(
                l10n: AppLocalizations.of(context),
                locale: 'en',
                today: today,
                weekLabel: WeekLabel.month,
              ),
              style: TrendChartStyle.bar,
              size: TrendCardSize.large,
              haptics: cardHaptics,
              defaultCurrency: 'INR',
              onTurn: turns.add,
              onCurrency: pages.add,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    return find.byKey(const ValueKey('trendCard'));
  }

  /// A drag by [offset] from [from] (the card's centre by default) that
  /// stops before lifting (no fling).
  Future<void> slowDrag(
    WidgetTester tester,
    Finder card,
    Offset offset, {
    Offset? from,
    int steps = 4,
  }) async {
    final gesture = await tester.startGesture(from ?? tester.getCenter(card));
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(offset / steps.toDouble());
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Held still before lifting: no fling.
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
  }

  testWidgets('a quick flick turns exactly one face, however fast', (
    tester,
  ) async {
    final card = await pumpCard(tester);
    for (final speed in [700.0, 2000.0, 6000.0]) {
      await tester.fling(card, const Offset(0, -80), speed);
      await tester.pumpAndSettle();
    }
    expect(turns, [1, 1, 1]);
    await tester.fling(card, const Offset(0, 80), 6000);
    await tester.pumpAndSettle();
    expect(turns, [1, 1, 1, -1]);
  });

  testWidgets('a held drag turns a face per card height', (tester) async {
    final card = await pumpCard(tester);
    final height = tester.getSize(card).height;
    // Down by 2.3 card heights, held still, then lifted: two faces back.
    await slowDrag(tester, card, Offset(0, height * 2.3), steps: 12);
    await tester.pumpAndSettle();
    expect(turns, [-2]);
  });

  testWidgets('a held drag shows the faces it passes', (tester) async {
    final card = await pumpCard(tester);
    final height = tester.getSize(card).height;
    final gesture = await tester.startGesture(tester.getCenter(card));
    // Month now; past the slop, 1.5 heights up is between Year and Week.
    await gesture.moveBy(const Offset(0, -20));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset(0, -height * 0.25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('2026'), findsOneWidget, reason: 'Year');
    expect(find.text('Oct Week 2'), findsOneWidget, reason: 'Week');
    expect(find.text('Oct'), findsNothing, reason: 'Month passed');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the reel sticks at a face: a short drag springs back', (
    tester,
  ) async {
    final card = await pumpCard(tester);
    final height = tester.getSize(card).height;
    // 40 % of a card, held, lifted: back on the same face.
    await slowDrag(tester, card, Offset(0, -height * 0.4));
    await tester.pumpAndSettle();
    expect(turns, isEmpty);
    // 80 % (the first step only takes up the touch slop): clicks on into
    // the next face.
    await slowDrag(tester, card, Offset(0, -height * 0.8));
    await tester.pumpAndSettle();
    expect(turns, [1]);
  });

  testWidgets('a tick at each face, none when off', (tester) async {
    var card = await pumpCard(tester);
    var height = tester.getSize(card).height;
    await slowDrag(tester, card, Offset(0, height * 2.3), steps: 12);
    await tester.pumpAndSettle();
    expect(
      haptics.where((h) => h == 'HapticFeedbackType.selectionClick'),
      hasLength(greaterThanOrEqualTo(2)),
      reason: 'passed two faces: $haptics',
    );

    haptics.clear();
    card = await pumpCard(tester, cardHaptics: CardHaptics.strong);
    await tester.fling(card, const Offset(0, -80), 2000);
    await tester.pumpAndSettle();
    expect(haptics, ['HapticFeedbackType.heavyImpact']);

    haptics.clear();
    card = await pumpCard(tester, cardHaptics: CardHaptics.off);
    height = tester.getSize(card).height;
    await slowDrag(tester, card, Offset(0, height * 2.3), steps: 12);
    await tester.pumpAndSettle();
    expect(turns, [-2]);
    expect(haptics, isEmpty);
  });

  testWidgets("a swipe from the card's padding turns it too", (tester) async {
    final card = await pumpCard(tester);
    final rect = tester.getRect(card);
    // In the card's top padding, above the title: no child paints there.
    await slowDrag(
      tester,
      card,
      Offset(0, rect.height * 0.8),
      from: Offset(rect.right - 40, rect.top + 8),
    );
    await tester.pumpAndSettle();
    expect(turns, [-1]);
  });

  testWidgets('a finger on a turning reel catches it there', (tester) async {
    final card = await pumpCard(tester);
    final height = tester.getSize(card).height;
    await tester.fling(card, const Offset(0, -80), 2000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(turns, isEmpty, reason: 'still turning');
    // Caught part-way, then held and dragged on about a card more: one
    // face further than the flick's.
    await slowDrag(tester, card, Offset(0, -height * 1.3), steps: 13);
    await tester.pumpAndSettle();
    expect(turns, [2]);
  });

  testWidgets('a drag during a currency fling finishes that page', (
    tester,
  ) async {
    final card = await pumpCard(tester);
    await tester.fling(card, const Offset(-80, 0), 3000);
    await tester.pump(const Duration(milliseconds: 16));
    expect(pages, isEmpty, reason: 'still sliding');
    await slowDrag(tester, card, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(pages, [1]);
  });
}
