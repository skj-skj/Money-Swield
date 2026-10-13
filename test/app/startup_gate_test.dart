import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/app/shell.dart';
import 'package:money_swield/ui/features/onboarding/views/onboarding_screen.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

void main() {
  group('after migrations, startup shows', () {
    testWidgets('onboarding on a fresh database', (tester) async {
      await pumpApp(tester, dependencies: await openTestDependencies());
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(Shell), findsNothing);
    });

    testWidgets('the shell once onboarding was completed', (tester) async {
      final deps = await openTestDependencies();
      await deps.settings.setOnboardingCompleted();
      await pumpApp(tester, dependencies: deps);
      expect(find.byType(Shell), findsOneWidget);
      expect(find.text('No expenses yet'), findsOneWidget);
    });

    testWidgets('the saved language and theme right away', (tester) async {
      final deps = await openTestDependencies();
      await deps.settings.setOnboardingCompleted();
      await deps.settings.setLocale(hi);
      await pumpApp(tester, dependencies: deps);
      expect(find.text('अभी तक कोई खर्च नहीं'), findsOneWidget);
    });
  });

  group('when the database cannot be opened or read', () {
    testWidgets('shows the error view, never onboarding', (tester) async {
      // No migrations ran: reading the settings table throws.
      final broken = AppDependencies.forDatabase(
        await openEmptyDatabase(),
        deviceCurrency: 'INR',
      );
      await pumpApp(tester, dependencies: broken);

      expect(find.text("Your data couldn't be opened"), findsOneWidget);
      expect(
        find.textContaining('no such table: settings'),
        findsOneWidget,
        reason: 'the report names the error',
      );
      expect(
        find.textContaining('Step: Loading settings'),
        findsOneWidget,
        reason: 'the report names the step',
      );
      expect(find.text('Copy error report'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('an exception while opening also shows the error view', (
      tester,
    ) async {
      await pumpAppWith(
        tester,
        openDependencies: () async => throw StateError('disk unavailable'),
      );
      expect(find.textContaining('disk unavailable'), findsOneWidget);
      expect(find.textContaining('Step: Opening database'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('"Try again" retries, and can then succeed', (tester) async {
      final good = await openTestDependencies();
      var attempts = 0;
      await pumpAppWith(
        tester,
        openDependencies: () async {
          if (++attempts == 1) throw StateError('locked');
          return good;
        },
      );
      expect(find.textContaining('locked'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('the error report can be copied', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
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

      await pumpAppWith(
        tester,
        openDependencies: () async => throw StateError('disk unavailable'),
      );
      await tester.tap(find.text('Copy error report'));
      await tester.pump();
      expect(copied, contains('disk unavailable'));
      expect(find.text('Report copied'), findsOneWidget);
    });
  });
}
