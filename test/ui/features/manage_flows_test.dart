import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/ui/core/widgets/emoji_picker_field.dart';
import 'package:money_swield/ui/core/widgets/item_card.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// The Manage tab's lists and forms, driven through the real app.
void main() {
  late AppDependencies deps;

  setUp(() async {
    deps = await openTestDependencies();
    await deps.settings.setOnboardingCompleted();
  });

  Future<void> openList(WidgetTester tester, String title) async {
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> pickEmoji(WidgetTester tester, String emoji) async {
    await tester.tap(find.byType(EmojiPickerField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(emoji).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
  }

  Finder nameField() => find.byKey(const ValueKey('name'));

  group('categories', () {
    testWidgets('add: the new category appears in the list, sorted by name', (
      tester,
    ) async {
      await openList(tester, 'Categories');
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();

      await pickEmoji(tester, '🐶');
      await tester.enterText(nameField(), 'Pets');
      await tester.enterText(
        find.byKey(const ValueKey('description')),
        'Food and vet',
      );
      await tapSave(tester);

      // Sorted between "Investment" and "Personal care", below the fold.
      await tester.scrollUntilVisible(find.text('Pets'), 200);
      expect(find.text('Pets'), findsOneWidget);
      expect(find.text('Food and vet'), findsOneWidget);
      // The grid alternates columns, so its reading order is item 0 left,
      // 1 right, 2 left …; the widget tree lists the left column first.
      final cards = tester.widgetList<ItemCard>(find.byType(ItemCard)).toList();
      final left = cards.take((cards.length + 1) ~/ 2).toList();
      final right = cards.skip(left.length).toList();
      final names = [
        for (var i = 0; i < cards.length; i++)
          (i.isEven ? left[i ~/ 2] : right[i ~/ 2]).title,
      ];
      expect(
        names,
        [...names]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      );
    });

    testWidgets('errors show under the fields and nothing is saved', (
      tester,
    ) async {
      await openList(tester, 'Categories');
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Pick an emoji'), findsOneWidget);
      await tester.enterText(nameField(), 'FOOD');
      await tester.pump();
      expect(find.text('"FOOD" already exists'), findsOneWidget);
      expect(await deps.categories.all(), hasLength(20));
    });

    testWidgets('an emoji can be typed instead of picked', (tester) async {
      await openList(tester, 'Categories');
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EmojiPickerField));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Type any emoji'),
        '🦄',
      );
      await tester.tap(find.text('Use'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Magic');
      await tapSave(tester);

      expect(
        (await deps.categories.all()).any(
          (c) => c.name == 'Magic' && c.emoji == '🦄',
        ),
        isTrue,
      );
    });

    testWidgets(
      'renaming a built-in to the same text keeps it following the language',
      (tester) async {
        await openList(tester, 'Categories');
        await tester.tap(find.text('Food'));
        await tester.pumpAndSettle();
        expect(find.text('Edit category'), findsOneWidget);
        expect(find.text('Reset to default name'), findsNothing);

        await tester.enterText(nameField(), 'Food');
        await tapSave(tester);
        final food = (await deps.categories.all()).firstWhere(
          (c) => c.builtinKey == 'food',
        );
        expect(food.name, isNull);

        // Switch to Spanish: the unrenamed built-in is translated.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Español'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gestionar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Categorías'));
        await tester.pumpAndSettle();
        expect(find.text('Comida'), findsOneWidget);
      },
    );

    testWidgets(
      'a renamed built-in keeps its name, and "Reset to default name" undoes it',
      (tester) async {
        await openList(tester, 'Categories');
        await tester.tap(find.text('Food'));
        await tester.pumpAndSettle();
        await tester.enterText(nameField(), 'Khana');
        await tester.pump();
        expect(find.text('Reset to default name'), findsOneWidget);
        await tapSave(tester);
        expect(find.text('Food'), findsNothing);
        await tester.scrollUntilVisible(find.text('Khana'), 200);

        await tester.tap(find.text('Khana'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset to default name'));
        await tester.pump();
        expect(tester.widget<TextField>(nameField()).controller!.text, 'Food');
        await tapSave(tester);
        await tester.scrollUntilVisible(find.text('Food'), -200);
        expect(find.text('Food'), findsOneWidget);
        expect(
          (await deps.categories.all())
              .firstWhere((c) => c.builtinKey == 'food')
              .name,
          isNull,
        );
      },
    );

    testWidgets('delete asks first; cancel keeps it, confirm removes it', (
      tester,
    ) async {
      await openList(tester, 'Categories');
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Food"?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await deps.categories.all(), hasLength(20));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Categories'),
        findsOneWidget,
        reason: 'back on the list',
      );
      expect(find.text('Food'), findsNothing);
      expect(await deps.categories.all(), hasLength(19));
    });

    testWidgets('the Manage count updates after returning', (tester) async {
      await openList(tester, 'Categories');
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('19'), findsOneWidget);
    });
  });

  group('events', () {
    testWidgets(
      'archive moves an event to the collapsed Archived section, unarchive brings it back',
      (tester) async {
        await openList(tester, 'Events');
        expect(find.textContaining('Archived'), findsNothing);

        await tester.tap(find.text('Trip'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Archive'));
        await tester.pumpAndSettle();

        expect(find.text('Archived (1)'), findsOneWidget);
        expect(
          find.text('Trip'),
          findsNothing,
          reason: 'the section starts collapsed',
        );
        await tester.tap(find.text('Archived (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trip'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unarchive'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Archived'), findsNothing);
        expect(find.text('Trip'), findsOneWidget);
      },
    );
  });

  group('payment methods', () {
    testWidgets(
      'the default shows a badge, and its Delete is disabled with a hint',
      (tester) async {
        await openList(tester, 'Payment methods');
        expect(
          find.descendant(
            of: find.widgetWithText(ItemCard, 'Cash'),
            matching: find.text('Default'),
          ),
          findsOne,
        );

        await tester.tap(find.text('Cash'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Delete'),
              )
              .onPressed,
          isNull,
        );
        expect(
          find.text('Set another method as default first'),
          findsOneWidget,
        );
        expect(find.text('Set as default'), findsNothing);
      },
    );

    testWidgets(
      '"Set as default" moves the badge; the old default can then be deleted',
      (tester) async {
        await openList(tester, 'Payment methods');
        await tester.tap(find.text('UPI'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set as default'));
        await tester.pumpAndSettle();
        expect(
          find.text('Set another method as default first'),
          findsOneWidget,
          reason: 'UPI is now the default',
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.widgetWithText(ItemCard, 'UPI'),
            matching: find.text('Default'),
          ),
          findsOne,
        );

        await tester.tap(find.text('Cash'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Cash'), findsNothing);
      },
    );

    testWidgets('the payment method form has no description field', (
      tester,
    ) async {
      await openList(tester, 'Payment methods');
      await tester.tap(find.text('Add payment method'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('description')), findsNothing);
    });
  });
}
