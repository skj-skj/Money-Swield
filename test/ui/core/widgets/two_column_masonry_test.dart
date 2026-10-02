import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/item_card.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/two_column_masonry.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    ),
  );

  Widget box(String label, double height) =>
      SizedBox(key: ValueKey(label), height: height, child: Text(label));

  group('TwoColumnMasonry', () {
    testWidgets('alternates items left, right, left … in their order', (
      tester,
    ) async {
      await pump(
        tester,
        TwoColumnMasonry(
          children: [
            for (final l in ['a', 'b', 'c', 'd', 'e']) box(l, 50),
          ],
        ),
      );
      double x(String l) => tester.getTopLeft(find.byKey(ValueKey(l))).dx;
      expect(
        {x('a'), x('c'), x('e')},
        hasLength(1),
        reason: 'a, c, e share the left column',
      );
      expect(x('b'), greaterThan(x('a')));
      expect(x('d'), x('b'));
    });

    testWidgets(
      'each column stacks at its own heights, with no gaps from the other column',
      (tester) async {
        await pump(
          tester,
          TwoColumnMasonry(
            spacing: 10,
            children: [box('tall', 200), box('short', 40), box('next', 40)],
          ),
        );
        double top(String l) => tester.getTopLeft(find.byKey(ValueKey(l))).dy;
        double bottom(String l) =>
            tester.getBottomLeft(find.byKey(ValueKey(l))).dy;
        expect(
          top('next'),
          bottom('tall') + 10,
          reason: 'below its own column, not below the row',
        );
        expect(top('short'), top('tall'));
      },
    );

    testWidgets('both columns get the same width', (tester) async {
      await pump(
        tester,
        TwoColumnMasonry(children: [box('a', 50), box('b', 50)]),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('a'))).width,
        tester.getSize(find.byKey(const ValueKey('b'))).width,
      );
    });

    testWidgets('handles zero and one item', (tester) async {
      await pump(tester, const TwoColumnMasonry(children: []));
      await pump(tester, TwoColumnMasonry(children: [box('only', 50)]));
      expect(find.text('only'), findsOneWidget);
    });
  });

  group('ItemCard', () {
    testWidgets(
      'cuts a long title at 2 lines and a long description at 3, without overflowing',
      (tester) async {
        await pump(
          tester,
          TwoColumnMasonry(
            children: [
              ItemCard(
                emoji: '📦',
                title: 'Long ' * 40,
                description: 'Very long description ' * 40,
                onTap: () {},
              ),
              ItemCard(emoji: '🍕', title: 'Short', onTap: () {}),
            ],
          ),
        );
        expect(tester.takeException(), isNull, reason: 'no overflow');
        final title = tester.widget<Text>(find.textContaining('Long Long'));
        expect(title.maxLines, 2);
        expect(title.overflow, TextOverflow.ellipsis);
        final description = tester.widget<Text>(
          find.textContaining('Very long'),
        );
        expect(description.maxLines, 3);
        expect(description.overflow, TextOverflow.ellipsis);
        expect(
          tester.getSize(find.widgetWithText(ItemCard, 'Short')).height,
          lessThan(tester.getSize(find.byType(ItemCard).first).height),
          reason: 'cards take their own height',
        );
      },
    );

    testWidgets('shows the badge and reports taps', (tester) async {
      var taps = 0;
      await pump(
        tester,
        ItemCard(
          emoji: '💵',
          title: 'Cash',
          badge: 'Default',
          onTap: () => taps++,
        ),
      );
      expect(find.text('Default'), findsOneWidget);
      await tester.tap(find.text('Cash'));
      expect(taps, 1);
    });

    testWidgets('a title in Hindi with long words still fits', (tester) async {
      await pump(
        tester,
        TwoColumnMasonry(
          children: [
            ItemCard(
              emoji: '💇',
              title: 'व्यक्तिगत देखभाल और सौंदर्य प्रसाधन',
              onTap: () {},
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
