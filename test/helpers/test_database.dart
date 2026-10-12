import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/services/database/migrations/all_migrations.dart';
import 'package:my_expense_tracker_app/data/services/on_device_ai_service.dart';
import 'package:my_expense_tracker_app/data/services/photo_store.dart';
import 'package:my_expense_tracker_app/data/services/report_export_service.dart';
import 'package:my_expense_tracker_app/data/services/sms_scanner.dart';
import 'package:my_expense_tracker_app/data/services/sms_service.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/services/database/migration/test_helpers.dart';
import 'fake_report_export_service.dart';

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

/// Repositories on a fresh migrated database. [photos] gives the app a photo
/// folder; without one, photos read as missing and nothing is swept.
Future<AppDependencies> openTestDependencies({
  String deviceCurrency = 'INR',
  TestClock? clock,
  int? wallpaperSeed,
  PhotoStore? photos,
  ReportExportService? reportExports,
  SmsService sms = const NoSmsService(),
  OnDeviceAiService ai = const NoOnDeviceAi(),
}) async => AppDependencies.forDatabase(
  await openMigratedDatabase(),
  deviceCurrency: deviceCurrency,
  wallpaperSeed: wallpaperSeed,
  now: clock?.call,
  photos: photos,
  // No real files or channels in widget tests.
  reportExports: reportExports ?? FakeReportExportService(),
  // The sweeper has its own tests; its file I/O would hang a widget test.
  sweepPhotos: false,
  sms: sms,
  ai: ai,
  // Parsing on this isolate: `Isolate.run` never completes inside a
  // widget test's fake async (the scanner's own tests cover it).
  smsScanner: (repository, settings) => SmsScanner(
    service: sms,
    repository: repository,
    settings: settings,
    now: clock?.call,
    parseAll: (messages) async => parseAllNow(messages),
    ai: ai,
    candidatesAll: (messages) async => candidatesNow(messages),
  ),
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

/// Inserts a recurring item row directly, for tests that only need "an item
/// uses this". [archivedAt] set archives it; [eventIds] are its events.
Future<int> insertRecurringRow(
  DatabaseExecutor db, {
  String title = 'Netflix',
  int categoryId = 1,
  int paymentMethodId = 1,
  String frequency = 'monthly',
  int interval = 1,
  String startOn = '2026-01-31',
  String? endOn,
  String? nextDueOn = '2026-02-28',
  int? archivedAt,
  Set<int> eventIds = const {},
  int? amountMinor = 64900,
  String currencyCode = 'INR',
  int updatedAt = 0,
}) async {
  final id = await db.insert('recurring_expenses', {
    'title': title,
    'currency_code': currencyCode,
    'category_id': categoryId,
    'payment_method_id': paymentMethodId,
    'frequency': frequency,
    'interval_count': interval,
    'start_on': startOn,
    'end_on': endOn,
    'time_of_day_minutes': 600,
    'next_due_on': nextDueOn,
    'archived_at': archivedAt,
    'created_at': 0,
    'updated_at': updatedAt,
  });
  if (amountMinor != null) {
    await db.insert('recurring_amounts', {
      'recurring_expense_id': id,
      'amount_minor': amountMinor,
      'effective_from': startOn,
      'created_at': 0,
      'updated_at': 0,
    });
  }
  for (final eventId in eventIds) {
    await db.insert('recurring_expense_events', {
      'recurring_expense_id': id,
      'event_id': eventId,
    });
  }
  return id;
}

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
