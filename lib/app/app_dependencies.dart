import 'package:sqflite/sqflite.dart';

import '../data/repositories/category_repository.dart';
import '../data/repositories/event_repository.dart';
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
  });

  /// Builds the repositories for an already open [database]. Tests use this
  /// with an in-memory database.
  factory AppDependencies.forDatabase(
    Database database, {
    required String deviceCurrency,
    DateTime Function()? now,
  }) {
    final settings = SettingsRepository(
      database,
      deviceCurrency: deviceCurrency,
    );
    return AppDependencies._(
      database: database,
      settings: settings,
      categories: CategoryRepository(database, now: now),
      events: EventRepository(database, now: now),
      paymentMethods: PaymentMethodRepository(
        database,
        settings: settings,
        now: now,
      ),
    );
  }

  /// Opens the app's database. Call only after migrations have finished.
  static Future<AppDependencies> open(
    AppDatabase appDatabase, {
    required String deviceCurrency,
  }) async => AppDependencies.forDatabase(
    await appDatabase.open(),
    deviceCurrency: deviceCurrency,
  );

  // The database stays open for the app's lifetime, like the cubits made in
  // main(), so nothing closes it.
  final Database database;
  final SettingsRepository settings;
  final CategoryRepository categories;
  final EventRepository events;
  final PaymentMethodRepository paymentMethods;
}
