import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/data/services/database/app_database.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration_prompter.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration_runner.dart';
import 'package:my_expense_tracker_app/ui/features/migration/view_models/migration_cubit.dart';

/// Stands in for the database so migrations can be tested without SQLite.
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

/// Builds a cubit for [database] and closes it when the test ends.
MigrationCubit cubitFor(FakeAppDatabase database) {
  final cubit = MigrationCubit(database: database, locale: const Locale('en', 'IN'));
  addTearDown(cubit.close);
  return cubit;
}
