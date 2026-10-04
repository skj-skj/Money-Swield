import 'package:sqflite/sqflite.dart';

import '../data/repositories/backup_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/data_version.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/expense_draft_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/payment_method_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/database/app_database.dart';
import '../data/services/document_service.dart';
import 'restore_tools.dart';

/// The open database and the repositories built on it. Created once by the
/// startup gate and passed down through constructors; screens hand the
/// repositories they need to the cubits they create. No service locator.
class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.settings,
    required this.categories,
    required this.events,
    required this.paymentMethods,
    required this.expenses,
    required this.drafts,
    required this.backups,
    required this.restoreTools,
    required this.dataVersion,
    required this.wallpaperSeed,
    required this.now,
  });

  /// Builds the repositories for an already open [database]. Tests use this
  /// with an in-memory database; [restoreTools] defaults to the real
  /// database file and dialogs, which such tests never reach.
  factory AppDependencies.forDatabase(
    Database database, {
    required String deviceCurrency,
    int? wallpaperSeed,
    DateTime Function()? now,
    RestoreTools? restoreTools,
  }) {
    final settings = SettingsRepository(
      database,
      deviceCurrency: deviceCurrency,
    );
    final tools =
        restoreTools ??
        RestoreTools(
          appDatabase: AppDatabase(),
          documents: const ChannelDocumentService(),
          deviceCurrency: deviceCurrency,
        );
    final dataVersion = DataVersion();
    return AppDependencies._(
      database: database,
      settings: settings,
      categories: CategoryRepository(
        database,
        dataVersion: dataVersion,
        now: now,
      ),
      events: EventRepository(database, dataVersion: dataVersion, now: now),
      paymentMethods: PaymentMethodRepository(
        database,
        settings: settings,
        dataVersion: dataVersion,
        now: now,
      ),
      expenses: ExpenseRepository(database, dataVersion: dataVersion, now: now),
      drafts: ExpenseDraftRepository(database),
      backups: BackupRepository(
        database,
        appDatabase: tools.appDatabase,
        settings: settings,
        now: now,
      ),
      restoreTools: tools,
      dataVersion: dataVersion,
      wallpaperSeed: wallpaperSeed,
      now: now ?? DateTime.now,
    );
  }

  /// Opens the app's database. Call only after migrations have finished.
  static Future<AppDependencies> open(
    RestoreTools tools, {
    int? wallpaperSeed,
  }) async => AppDependencies.forDatabase(
    await tools.appDatabase.open(),
    deviceCurrency: tools.deviceCurrency,
    wallpaperSeed: wallpaperSeed,
    restoreTools: tools,
  );

  /// Runs one small query per repository on [db], the way the app does on
  /// start: settings, a page of expenses, the categories, events, payment
  /// methods and the draft slot (read-only: an unreadable draft is fine
  /// and stays, R10). A restore runs it on the candidate before swapping it
  /// in, so a database that can't start the app is refused (§6.4 step 3).
  static Future<void> probe(
    Database db, {
    required String deviceCurrency,
  }) async {
    final dataVersion = DataVersion();
    final settings = SettingsRepository(db, deviceCurrency: deviceCurrency);
    await settings.load();
    await ExpenseRepository(db, dataVersion: dataVersion).page(limit: 1);
    await CategoryRepository(db, dataVersion: dataVersion).all();
    await EventRepository(db, dataVersion: dataVersion).all();
    await PaymentMethodRepository(
      db,
      settings: settings,
      dataVersion: dataVersion,
    ).all();
    await ExpenseDraftRepository.probe(db);
  }

  /// Closes the database for a restore's swap (phase-3.md §6.4): first
  /// writes the draft that is due and stops further draft writes, so
  /// nothing of this database is written after it closes, nor into the
  /// restored one (phase-4.md §6.4).
  Future<void> closeForRestore() async {
    await drafts.close();
    await database.close();
  }

  /// Stays open for the app's lifetime, like the cubits made in main().
  /// Only a restore closes it, right before swapping the file, and then
  /// restarts the app (phase-3.md §6.6).
  final Database database;
  final SettingsRepository settings;
  final CategoryRepository categories;
  final EventRepository events;
  final PaymentMethodRepository paymentMethods;
  final ExpenseRepository expenses;

  /// The unsaved Add/Edit form (phase-4.md §6.4). Not part of
  /// [dataVersion]: a draft changes nothing Home counts.
  final ExpenseDraftRepository drafts;

  final BackupRepository backups;
  final RestoreTools restoreTools;

  /// Bumped by every write of the four repositories above (not settings).
  final DataVersion dataVersion;

  /// The wallpaper's accent color (ARGB, Android 12+), or null when the
  /// device has none. Settings offers "Wallpaper colors" only with one.
  final int? wallpaperSeed;

  /// The clock the repositories use. Screens that show relative dates
  /// ("Today") read it too, so tests can move it across midnight.
  final DateTime Function() now;
}
