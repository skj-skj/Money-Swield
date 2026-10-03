import 'package:sqflite/sqflite.dart';

import '../data/repositories/category_repository.dart';
import '../data/repositories/data_version.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/payment_method_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/database/app_database.dart';

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
    required this.dataVersion,
    required this.wallpaperSeed,
    required this.now,
  });

  /// Builds the repositories for an already open [database]. Tests use this
  /// with an in-memory database.
  factory AppDependencies.forDatabase(
    Database database, {
    required String deviceCurrency,
    int? wallpaperSeed,
    DateTime Function()? now,
  }) {
    final settings = SettingsRepository(
      database,
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
      dataVersion: dataVersion,
      wallpaperSeed: wallpaperSeed,
      now: now ?? DateTime.now,
    );
  }

  /// Opens the app's database. Call only after migrations have finished.
  static Future<AppDependencies> open(
    AppDatabase appDatabase, {
    required String deviceCurrency,
    int? wallpaperSeed,
  }) async => AppDependencies.forDatabase(
    await appDatabase.open(),
    deviceCurrency: deviceCurrency,
    wallpaperSeed: wallpaperSeed,
  );

  // The database stays open for the app's lifetime, like the cubits made in
  // main(), so nothing closes it.
  final Database database;
  final SettingsRepository settings;
  final CategoryRepository categories;
  final EventRepository events;
  final PaymentMethodRepository paymentMethods;
  final ExpenseRepository expenses;

  /// Bumped by every write of the four repositories above (not settings).
  final DataVersion dataVersion;

  /// The wallpaper's accent color (ARGB, Android 12+), or null when the
  /// device has none. Settings offers "Wallpaper colors" only with one.
  final int? wallpaperSeed;

  /// The clock the repositories use. Screens that show relative dates
  /// ("Today") read it too, so tests can move it across midnight.
  final DateTime Function() now;
}
