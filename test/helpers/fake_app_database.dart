import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/data/services/database/app_database.dart';
import 'package:money_swield/data/services/database/migration/migration_prompter.dart';
import 'package:money_swield/data/services/database/migration/migration_runner.dart';
import 'package:money_swield/ui/features/migration/view_models/migration_cubit.dart';

/// Stands in for the database so migrations can be tested without SQLite.
class FakeAppDatabase implements AppDatabase {
  FakeAppDatabase(this.onMigrate, {this.outcome = MigrationOutcome.upToDate});

  /// What [migrate] reports once [onMigrate] finished.
  final MigrationOutcome outcome;

  final Future<void> Function(
    MigrationPrompter prompter,
    void Function(MigrationProgress) onProgress,
  )
  onMigrate;

  @override
  Future<MigrationOutcome> migrate({
    required Locale locale,
    required MigrationPrompter prompter,
    void Function(MigrationProgress progress)? onProgress,
  }) async {
    await onMigrate(prompter, onProgress ?? (_) {});
    return outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Builds a cubit for [database] and closes it when the test ends.
MigrationCubit cubitFor(FakeAppDatabase database) {
  final cubit = MigrationCubit(
    database: database,
    locale: const Locale('en', 'IN'),
  );
  addTearDown(cubit.close);
  return cubit;
}
