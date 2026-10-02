import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration_runner.dart';

import 'helpers/fake_app_database.dart';
import 'helpers/pump_app.dart';
import 'helpers/test_database.dart';

/// The migration screen inside the real app, before startup takes over.
void main() {
  testWidgets('shows progress, asks a question, then opens the app', (
    tester,
  ) async {
    final release = Completer<void>();
    String? answer;
    final cubit = cubitFor(
      FakeAppDatabase((prompter, onProgress) async {
        onProgress(
          const MigrationProgress(
            stage: MigrationStage.migrating,
            completed: 1,
            total: 3,
          ),
        );
        await release.future;
        answer = await prompter.askChoice('Which currency?', ['INR', 'USD']);
      }),
    );
    final deps = await openTestDependencies();

    await pumpApp(tester, dependencies: deps, migrationCubit: cubit);
    unawaited(cubit.run());
    await tester.pump();
    expect(find.text('Updating your data (2 of 3)'), findsOneWidget);

    release.complete();
    await tester.pump();
    expect(find.text('Which currency?'), findsOneWidget);

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(
      tester.widget<FilledButton>(continueButton).onPressed,
      isNull,
      reason: 'nothing picked yet',
    );
    await tester.tap(find.text('USD'));
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(answer, 'USD');
    expect(
      find.text('Choose your language'),
      findsOneWidget,
      reason: 'a fresh install goes on to onboarding',
    );
  });

  testWidgets('a choice with an initial value starts selected', (tester) async {
    String? answer;
    final cubit = cubitFor(
      FakeAppDatabase((prompter, onProgress) async {
        answer = await prompter.askChoice('Which currency?', [
          'INR',
          'USD',
        ], initialValue: 'USD');
      }),
    );

    await pumpApp(
      tester,
      dependencies: await openTestDependencies(),
      migrationCubit: cubit,
    );
    unawaited(cubit.run());
    await tester.pump();
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'USD')).selected,
      isTrue,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(answer, 'USD');
  });

  testWidgets('shows which migration failed and lets the user retry', (
    tester,
  ) async {
    var attempts = 0;
    final cubit = cubitFor(
      FakeAppDatabase((prompter, onProgress) async {
        attempts++;
        throw MigrationFailure(
          step: 'Running 1790000000_add_currency_to_expenses',
          error: StateError('boom'),
          stackTrace: StackTrace.current,
          backupPath: '/backups/expense_tracker.db.bak',
        );
      }),
    );

    await pumpApp(
      tester,
      dependencies: await openTestDependencies(),
      migrationCubit: cubit,
    );
    await cubit.run();
    await tester.pump();

    expect(find.text('Updating your data failed'), findsOneWidget);
    expect(
      find.text('Running 1790000000_add_currency_to_expenses'),
      findsOneWidget,
    );
    expect(find.textContaining('boom'), findsOneWidget);
    expect(
      find.textContaining('/backups/expense_tracker.db.bak'),
      findsOneWidget,
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(attempts, 2);
  });

  testWidgets('the migration screen is shown in the device language', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('hi', 'IN');
    tester.platformDispatcher.localesTestValue = [const Locale('hi', 'IN')];
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final cubit = cubitFor(
      FakeAppDatabase((prompter, onProgress) async {
        onProgress(
          const MigrationProgress(
            stage: MigrationStage.migrating,
            completed: 0,
            total: 2,
          ),
        );
        await Completer<void>().future; // Never finishes.
      }),
    );

    await pumpApp(
      tester,
      dependencies: await openTestDependencies(),
      migrationCubit: cubit,
    );
    unawaited(cubit.run());
    await tester.pump();

    expect(find.text('आपका डेटा अपडेट हो रहा है (2 में से 1)'), findsOneWidget);
    expect(find.text('कृपया ऐप खुला रखें।'), findsOneWidget);
  });
}
