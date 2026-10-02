import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

void main() {
  Future<AppDependencies> onboarded() async {
    final deps = await openTestDependencies();
    await deps.settings.setOnboardingCompleted();
    return deps;
  }

  testWidgets('shows Home first, with the empty state', (tester) async {
    await pumpApp(tester, dependencies: await onboarded());
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(
      find.text('Adding expenses is coming in the next update.'),
      findsOneWidget,
    );
  });

  testWidgets('Manage shows each list with its count', (tester) async {
    await pumpApp(tester, dependencies: await onboarded());
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Categories'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Categories'),
        matching: find.text('20'),
      ),
      findsOne,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Events'),
        matching: find.text('5'),
      ),
      findsOne,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Payment methods'),
        matching: find.text('4'),
      ),
      findsOne,
    );
  });

  testWidgets('back on another tab goes to Home; back on Home leaves the app', (
    tester,
  ) async {
    await pumpApp(tester, dependencies: await onboarded());
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Default currency'), findsOneWidget);

    expect(
      await tester.binding.handlePopRoute(),
      isTrue,
      reason: 'handled by the shell',
    );
    await tester.pumpAndSettle();
    expect(find.text('No expenses yet'), findsOneWidget);

    expect(
      await tester.binding.handlePopRoute(),
      isFalse,
      reason: 'the app may close',
    );
  });

  testWidgets('a tab keeps its state when switching away and back', (
    tester,
  ) async {
    await pumpApp(tester, dependencies: await onboarded());
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Add category'), findsOneWidget);

    // The list is pushed over the shell; popping returns to Manage.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('20'), findsOneWidget);
  });
}
