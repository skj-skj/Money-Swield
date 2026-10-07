import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/app/shell.dart';
import 'package:my_expense_tracker_app/domain/models/app_theme_mode.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDependencies deps;

  setUp(() async {
    deps = await openTestDependencies(deviceCurrency: 'INR');
    await deps.settings.setOnboardingCompleted();
  });

  Future<void> openSettings(WidgetTester tester) async {
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
  }

  /// A tile of the Settings grid (phase-5.md §8.5).
  Future<void> openTile(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Shell, skipOffstage: false)))
          .brightness;

  group('theme', () {
    testWidgets('switching theme changes the brightness and is saved', (
      tester,
    ) async {
      await openSettings(tester);
      await openTile(tester, 'settingsLook');
      expect(
        brightness(tester),
        Brightness.light,
        reason: 'system theme, and the test device is light',
      );

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.dark);
      expect((await deps.settings.load()).theme, AppThemeMode.dark);

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light').last);
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.light);
    });
  });

  group('language', () {
    testWidgets(
      'switching re-renders the app at once, built-in names included',
      (tester) async {
        await openSettings(tester);
        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('हिन्दी'));
        await tester.pumpAndSettle();

        expect(find.text('सेटिंग').first, findsOneWidget);
        expect(
          find.text('INR · 💵 नकद'),
          findsOneWidget,
          reason: 'the default payment method follows the language',
        );
        expect((await deps.settings.load()).locale, hi);

        await tester.tap(find.text('भाषा'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('सिस्टम डिफ़ॉल्ट'));
        await tester.pumpAndSettle();
        expect(
          find.text('Language'),
          findsOneWidget,
          reason: 'back to the device language',
        );
        expect((await deps.settings.load()).locale, isNull);
      },
    );

    testWidgets('dismissing the dialog changes nothing', (tester) async {
      await openSettings(tester);
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // Outside the dialog.
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(
        await deps.database.query('settings', where: "key = 'locale'"),
        isEmpty,
      );
    });
  });

  testWidgets('default currency opens the picker sheet and saves the choice', (
    tester,
  ) async {
    await openSettings(tester);
    await openTile(tester, 'settingsDefaults');
    expect(find.text('₹ INR · Indian Rupee'), findsOneWidget);

    await tester.tap(find.text('Default currency'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'jpy');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japanese Yen'));
    await tester.pumpAndSettle();

    expect(find.text('¥ JPY · Japanese Yen'), findsOneWidget);
    expect((await deps.settings.load()).defaultCurrency, 'JPY');
  });

  testWidgets('default currency shows the recently used currencies first', (
    tester,
  ) async {
    await deps.expenses.add(
      ExpenseInput(
        title: 'Taxi',
        description: null,
        amount: const Money(500, 'USD'),
        occurredAt: DateTime.utc(2026, 10, 1),
        utcOffsetMinutes: 0,
        categoryId: 1,
        paymentMethodId: 1,
        eventIds: const {},
      ),
    );
    await openSettings(tester);
    await openTile(tester, 'settingsDefaults');
    await tester.tap(find.text('Default currency'));
    await tester.pumpAndSettle();

    // phase-2.md §8: the same Recent section as Home's currency chip.
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('All currencies'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('US Dollar').first).dy,
      lessThan(tester.getTopLeft(find.text('All currencies')).dy),
    );
  });

  testWidgets(
    'default payment method lists the current methods, including ones added meanwhile',
    (tester) async {
      await openSettings(tester);
      await openTile(tester, 'settingsDefaults');
      expect(find.text('💵 Cash'), findsOneWidget);

      // Added on the Manage tab while Settings stayed alive.
      final wallet = await deps.paymentMethods.add(name: 'Wallet', emoji: '👛');
      await tester.tap(find.text('Default payment method'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('👛 Wallet'));
      await tester.pumpAndSettle();

      expect(find.text('👛 Wallet'), findsOneWidget);
      expect((await deps.settings.load()).defaultPaymentMethodId, wallet.id);
    },
  );

  testWidgets(
    'a renamed default shows its new name when returning to the tab',
    (tester) async {
      await openSettings(tester);
      final cash = (await deps.paymentMethods.all()).first;
      await deps.paymentMethods.update(cash.copyWith(name: 'Nakad'));

      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();
      expect(find.text('INR · 💵 Nakad'), findsOneWidget);
    },
  );

  testWidgets('a failed save shows a message and keeps the old value', (
    tester,
  ) async {
    await openSettings(tester);
    await openTile(tester, 'settingsLook');
    await deps.database.execute('DROP TABLE settings');
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save. Please try again."), findsOneWidget);
    expect(brightness(tester), Brightness.light);
  });
}
