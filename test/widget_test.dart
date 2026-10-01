import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/data/services/database/app_database.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration_prompter.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration_runner.dart';
import 'package:my_expense_tracker_app/main.dart';
import 'package:my_expense_tracker_app/ui/features/migration/view_models/migration_view_model.dart';

/// Stands in for the database so the screen can be tested without SQLite.
class FakeAppDatabase implements AppDatabase {
  FakeAppDatabase(this.onMigrate);

  final Future<void> Function(MigrationPrompter prompter, void Function(MigrationProgress) onProgress) onMigrate;

  @override
  Future<void> migrate({
    required Locale locale,
    required MigrationPrompter prompter,
    void Function(MigrationProgress progress)? onProgress,
  }) => onMigrate(prompter, onProgress ?? (_) {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MigrationViewModel viewModelFor(FakeAppDatabase database) =>
    MigrationViewModel(database: database, locale: const Locale('en', 'IN'));

void main() {
  testWidgets('shows progress, asks a question, then opens the app', (tester) async {
    final release = Completer<void>();
    String? answer;
    final viewModel = viewModelFor(
      FakeAppDatabase((prompter, onProgress) async {
        onProgress(const MigrationProgress(stage: MigrationStage.migrating, completed: 1, total: 3));
        await release.future;
        answer = await prompter.askChoice('Which currency?', ['INR', 'USD']);
      }),
    );

    await tester.pumpWidget(MyApp(migrationViewModel: viewModel));
    unawaited(viewModel.run());
    await tester.pump();
    expect(find.text('Updating your data (2 of 3)'), findsOneWidget);

    release.complete();
    await tester.pump();
    expect(find.text('Which currency?'), findsOneWidget);

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull, reason: 'nothing picked yet');
    await tester.tap(find.text('USD'));
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(answer, 'USD');
    expect(find.text('You have pushed the button this many times:'), findsOneWidget);
  });

  testWidgets('a choice with an initial value starts selected', (tester) async {
    String? answer;
    final viewModel = viewModelFor(
      FakeAppDatabase((prompter, onProgress) async {
        answer = await prompter.askChoice('Which currency?', ['INR', 'USD'], initialValue: 'USD');
      }),
    );

    await tester.pumpWidget(MyApp(migrationViewModel: viewModel));
    unawaited(viewModel.run());
    await tester.pump();
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'USD')).selected, isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(answer, 'USD');
  });

  testWidgets('shows which migration failed and lets the user retry', (tester) async {
    var attempts = 0;
    final viewModel = viewModelFor(
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

    await tester.pumpWidget(MyApp(migrationViewModel: viewModel));
    await viewModel.run();
    await tester.pump();

    expect(find.text('Updating your data failed'), findsOneWidget);
    expect(find.text('Running 1790000000_add_currency_to_expenses'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.textContaining('/backups/expense_tracker.db.bak'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(attempts, 2);
  });
}
