import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/ui/features/home/views/add_expense_fab.dart';

/// Home's Add button folding into a round "+" (owner, 2026-10-07): it
/// animates, and folded it is a 56 dp circle with the "+" centred
/// (Material's collapsed extended FAB is a 60 dp pill, "+" 2 dp off).
void main() {
  late int taps;

  Future<void> pumpFab(
    WidgetTester tester, {
    required bool extended,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            floatingActionButton: AddExpenseFab(
              extended: extended,
              label: 'Add expense',
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
  }

  setUp(() => taps = 0);

  Rect fabRect(WidgetTester tester) =>
      tester.getRect(find.byType(FloatingActionButton));

  testWidgets('folded: a 56 dp circle with the "+" in its centre', (
    tester,
  ) async {
    await pumpFab(tester, extended: false);
    final fab = fabRect(tester);
    expect(fab.size, const Size(56, 56));
    final plus = tester.getRect(find.byIcon(Icons.add));
    expect(plus.center.dx, closeTo(fab.center.dx, 0.01));
    expect(plus.center.dy, closeTo(fab.center.dy, 0.01));
    await tester.tap(find.byType(FloatingActionButton));
    expect(taps, 1);
    expect(find.byTooltip('Add expense'), findsOneWidget);
  });

  testWidgets('unfolded: the label shows, Material\'s padding', (tester) async {
    await pumpFab(tester, extended: true);
    final fab = fabRect(tester);
    final plus = tester.getRect(find.byIcon(Icons.add));
    final label = tester.getRect(find.text('Add expense'));
    expect(fab.height, 56);
    expect(plus.left - fab.left, 16);
    expect(fab.right - label.right, 20);
    expect(label.left - plus.right, 8);
    await tester.tap(find.text('Add expense'));
    expect(taps, 1);
  });

  testWidgets('folding animates the width, quickly', (tester) async {
    await pumpFab(tester, extended: true);
    final open = fabRect(tester).width;
    await pumpFab(tester, extended: false);
    await tester.pump(); // starts the animation
    await tester.pump(AddExpenseFab.duration ~/ 2);
    final half = fabRect(tester).width;
    expect(half, lessThan(open));
    expect(half, greaterThan(56), reason: 'mid-way, not swapped at once');
    await tester.pump(AddExpenseFab.reverseDuration);
    expect(fabRect(tester).width, 56);

    await pumpFab(tester, extended: true);
    await tester.pump();
    await tester.pump(AddExpenseFab.duration ~/ 2);
    expect(fabRect(tester).width, inExclusiveRange(56, open));
    await tester.pumpAndSettle();
    expect(fabRect(tester).width, open);
  });

  // Owner, 2026-10-07: folding was "snappy": it sped up to the end and
  // stopped dead on the circle. It must ease in and out both ways.
  for (final fold in [true, false]) {
    testWidgets('${fold ? 'folding' : 'unfolding'} eases in and out, no '
        'snap at the end', (tester) async {
      await pumpFab(tester, extended: fold);
      await pumpFab(tester, extended: !fold);
      await tester.pump(); // starts the animation
      final total = fold
          ? AddExpenseFab.reverseDuration
          : AddExpenseFab.duration;
      const frame = Duration(milliseconds: 16);
      final widths = [fabRect(tester).width];
      for (var elapsed = Duration.zero; elapsed < total; elapsed += frame) {
        await tester.pump(frame);
        widths.add(fabRect(tester).width);
      }
      final steps = [
        for (var i = 1; i < widths.length; i++)
          (widths[i] - widths[i - 1]).abs(),
      ];
      final fastest = steps.reduce((a, b) => a > b ? a : b);
      final peak = steps.indexOf(fastest);
      expect(
        peak,
        inExclusiveRange(1, steps.length - 3),
        reason: 'fastest in the middle: $steps',
      );
      for (final end in steps.sublist(steps.length - 3)) {
        expect(end, lessThan(fastest / 3), reason: 'eases into place: $steps');
      }
      expect(steps.first, lessThan(fastest / 2), reason: 'starts gently');
      // No jump: no frame moves more than an eighth of the whole change.
      final change = (widths.last - widths.first).abs();
      expect(fastest, lessThan(change / 8), reason: 'no jump: $steps');
      expect(widths.last, fold ? 56 : greaterThan(56));
    });
  }

  testWidgets('with animations off it switches at once', (tester) async {
    await pumpFab(tester, extended: true, disableAnimations: true);
    await pumpFab(tester, extended: false, disableAnimations: true);
    await tester.pump();
    expect(fabRect(tester).width, 56);
  });
}
