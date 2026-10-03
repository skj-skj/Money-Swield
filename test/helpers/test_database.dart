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
  int? wallpaperSeed,
}) async => AppDependencies.forDatabase(
  await openMigratedDatabase(),
  deviceCurrency: deviceCurrency,
  wallpaperSeed: wallpaperSeed,
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

/// Inserts an expense row directly, for tests of other tables that only
/// need "something uses this". [deletedAt] set puts it in the bin.
Future<int> insertExpenseRow(
  DatabaseExecutor db, {
  int categoryId = 1,
  int paymentMethodId = 1,
  int? deletedAt,
  Set<int> eventIds = const {},
}) async {
  final id = await db.insert('expenses', {
    'title': 'Expense',
    'amount_minor': 100,
    'currency_code': 'INR',
    'occurred_at': 0,
    'utc_offset_minutes': 0,
    'occurred_on': '1970-01-01',
    'category_id': categoryId,
    'payment_method_id': paymentMethodId,
    'deleted_at': deletedAt,
    'created_at': 0,
    'updated_at': 0,
  });
  for (final eventId in eventIds) {
    await db.insert('expense_events', {'expense_id': id, 'event_id': eventId});
  }
  return id;
}
