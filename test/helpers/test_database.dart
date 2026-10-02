import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/services/database/migrations/all_migrations.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/services/database/migration/test_helpers.dart';

/// A fresh in-memory database with every migration applied (so with the
/// seed rows) and foreign keys on, like `AppDatabase.open`. Closed when the
/// test ends.
///
/// Uses the no-isolate FFI factory: its futures complete without real
/// I/O, so it also works inside `testWidgets`' fake-async zone.
Future<Database> openMigratedDatabase() async {
  final db = await openEmptyDatabase();
  final m = migratorFor(db);
  for (final migration in allMigrations) {
    await migration.up(m);
  }
  return db;
}

/// A fresh in-memory database with no tables at all. Closed when the test
/// ends.
Future<Database> openEmptyDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
  addTearDown(db.close);
  return db;
}

/// Repositories on a fresh migrated database.
Future<AppDependencies> openTestDependencies({
  String deviceCurrency = 'INR',
  TestClock? clock,
}) async => AppDependencies.forDatabase(
  await openMigratedDatabase(),
  deviceCurrency: deviceCurrency,
  now: clock?.call,
);

/// A clock the test moves by hand, for `created_at` / `updated_at`.
class TestClock {
  TestClock([DateTime? start])
    : now = start ?? DateTime.utc(2026, 10, 2, 9, 30);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

/// The app's strings in [languageCode], without a widget tree.
AppLocalizations l10nFor(String languageCode) =>
    lookupAppLocalizations(Locale(languageCode));

const en = Locale('en');
const es = Locale('es');
const hi = Locale('hi');
