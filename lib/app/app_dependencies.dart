import 'package:sqflite/sqflite.dart';

import '../data/repositories/backup_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/data_version.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/expense_draft_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/payment_method_repository.dart';
import '../data/repositories/recurring_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/database/app_database.dart';
import '../data/services/document_service.dart';
import '../data/services/photo_store.dart';
import '../data/services/photo_sweeper.dart';
import '../domain/periods.dart';
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
    required this.recurring,
    required this.drafts,
    required this.photos,
    required this.photoSweeper,
    required this.backups,
    required this.restoreTools,
    required this.dataVersion,
    required this.wallpaperSeed,
    required this.now,
  });

  /// Builds the repositories for an already open [database]. Tests use this
  /// with an in-memory database; [restoreTools] defaults to the real
  /// database file and dialogs, which such tests never reach.
  ///
  /// [photoRoot] is the app's external files folder (`databases/` and the
  /// photo folders). Without it the app has no photo folder: photos read
  /// as missing and nothing is swept, for tests that never touch photos.
  /// [sweepPhotos] false leaves out the startup sweep: widget tests, where
  /// its real file I/O never completes (phase-6.md F17).
  factory AppDependencies.forDatabase(
    Database database, {
    required String deviceCurrency,
    int? wallpaperSeed,
    DateTime Function()? now,
    RestoreTools? restoreTools,
    String? photoRoot,
    PhotoStore? photos,
    bool sweepPhotos = true,
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
    final drafts = ExpenseDraftRepository(database);
    final photoStore =
        photos ??
        PhotoStore(root: photoRoot, service: tools.photoService, now: now);
    final appDatabase = tools.appDatabase;
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
      recurring: RecurringRepository(
        database,
        dataVersion: dataVersion,
        now: now,
      ),
      drafts: drafts,
      photos: photoStore,
      photoSweeper: photoStore.isAvailable && sweepPhotos
          ? PhotoSweeper(
              db: database,
              drafts: drafts,
              store: photoStore,
              preRestoreCopies: () async => [
                for (final copy in await appDatabase.preRestoreCopies())
                  copy.path,
              ],
              openReadOnly: (path) => appDatabase.databaseFactory.openDatabase(
                path,
                options: OpenDatabaseOptions(
                  readOnly: true,
                  singleInstance: false,
                ),
              ),
              now: now,
            )
          : null,
      backups: BackupRepository(
        database,
        appDatabase: tools.appDatabase,
        settings: settings,
        photos: photoStore,
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
    photoRoot: await tools.appDatabase.filesFolder(),
  );

  /// Runs one small query per repository on [db], the way the app does on
  /// start: settings, a page of expenses, today's amounts (Home's totals,
  /// phase-5.md R10), the categories, events, payment
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
    final expenses = ExpenseRepository(db, dataVersion: dataVersion);
    await expenses.page(limit: 1);
    // `page` is `SELECT *`, which passes on an empty table that lacks a
    // column; this names the columns the totals read.
    final today = todayOn(DateTime.now());
    await expenses.amountsIn(from: today, to: today);
    await CategoryRepository(db, dataVersion: dataVersion).all();
    await EventRepository(db, dataVersion: dataVersion).all();
    await PaymentMethodRepository(
      db,
      settings: settings,
      dataVersion: dataVersion,
    ).all();
    await ExpenseDraftRepository.probe(db);
    // Both photo tables, as the form and Settings read them (R12).
    await expenses.photosOf(0);
    await expenses.photoStats();
    // The recurring columns and tables, named (phase-7a.md R4): `page`
    // above passes a database without them. A Phase 6 backup has
    // create_expenses applied but none of this schema, so it is refused
    // here instead of failing at the generator after the swap.
    await RecurringRepository.probe(db);
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

  /// Recurring items and the generator (phase-7a.md §6.1).
  final RecurringRepository recurring;

  /// The unsaved Add/Edit form (phase-4.md §6.4). Not part of
  /// [dataVersion]: a draft changes nothing Home counts.
  final ExpenseDraftRepository drafts;

  /// The photo files (phase-6.md §6.2).
  final PhotoStore photos;

  /// Deletes unused photo rows and files once per start (§6.5); null
  /// without a photo folder.
  final PhotoSweeper? photoSweeper;

  final BackupRepository backups;
  final RestoreTools restoreTools;

  /// Bumped by every write of the repositories above (not settings).
  final DataVersion dataVersion;

  /// The wallpaper's accent color (ARGB, Android 12+), or null when the
  /// device has none. Settings offers "Wallpaper colors" only with one.
  final int? wallpaperSeed;

  /// The clock the repositories use. Screens that show relative dates
  /// ("Today") read it too, so tests can move it across midnight.
  final DateTime Function() now;
}
