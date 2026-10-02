import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/shell.dart';
import 'package:my_expense_tracker_app/ui/features/onboarding/views/onboarding_screen.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  testWidgets(
    'end to end in Hindi: picking हिन्दी translates the next steps, and Get started opens the shell',
    (tester) async {
      final deps = await openTestDependencies(deviceCurrency: 'INR');
      final settings = await pumpApp(tester, dependencies: deps);

      // Step 1, in the device language (English in tests).
      expect(find.text('Choose your language'), findsOneWidget);
      expect(find.text('System default (detected: English)'), findsOneWidget);
      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();
      expect(
        find.text('अपनी भाषा चुनें'),
        findsOneWidget,
        reason: 'the language applies at once',
      );
      await tester.tap(find.text('आगे'));
      await tester.pumpAndSettle();

      // Step 2: currency, preselected from the device.
      expect(find.text('आपकी मुद्रा'), findsOneWidget);
      expect(find.text('चरण 2 / 3'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Indian Rupee'))
            .selected,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'euro');
      await tester.pumpAndSettle();
      expect(
        find.text('Indian Rupee'),
        findsNothing,
        reason: 'search filters the list',
      );
      await tester.tap(find.text('Euro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('आगे'));
      await tester.pumpAndSettle();

      // Step 3: payment methods with Hindi built-in names, Cash preselected.
      expect(find.text('आप आमतौर पर कैसे भुगतान करते हैं?'), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'नकद')).selected,
        isTrue,
      );
      await tester.tap(find.text('UPI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('शुरू करें'));
      await tester.pumpAndSettle();

      expect(find.byType(Shell), findsOneWidget);
      expect(find.text('अभी तक कोई खर्च नहीं'), findsOneWidget);
      final stored = await deps.settings.load();
      expect(stored.locale, hi);
      expect(stored.defaultCurrency, 'EUR');
      expect(
        stored.defaultPaymentMethodId,
        (await deps.paymentMethods.all())[1].id,
      );
      expect(stored.onboardingCompleted, isTrue);
      expect(
        settings.value,
        stored,
        reason: 'what the app shows is what was saved',
      );

      // No way back to onboarding.
      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(popped, isFalse, reason: 'back on Home leaves the app');
    },
  );

  testWidgets('Back goes to the previous step; there is no Back on the first', (
    tester,
  ) async {
    await pumpApp(tester, dependencies: await openTestDependencies());
    expect(find.text('Back'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your currency'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your language'), findsOneWidget);
  });

  testWidgets('a currency search with no match says so', (tester) async {
    await pumpApp(tester, dependencies: await openTestDependencies());
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No currency matches "zzz"'), findsOneWidget);
  });

  testWidgets(
    'reopening after the app was killed resumes with the saved choices',
    (tester) async {
      final deps = await openTestDependencies();
      await deps.settings.setLocale(es);
      await deps.settings.setDefaultCurrency('USD');
      await deps.settings.setDefaultPaymentMethodId(
        (await deps.paymentMethods.all())[2].id,
      );

      await pumpApp(tester, dependencies: deps);
      expect(
        find.text('Elige tu idioma'),
        findsOneWidget,
        reason: 'restarts at step 1, in the saved language',
      );
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Español'))
            .selected,
        isTrue,
      );

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'US Dollar'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(
              find.widgetWithText(ListTile, 'Tarjeta de débito'),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'if saving fails, Get started tells the user and stays on onboarding',
    (tester) async {
      final deps = await openTestDependencies();
      await pumpApp(tester, dependencies: deps);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await deps.database.execute('DROP TABLE settings');
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    },
  );
}
