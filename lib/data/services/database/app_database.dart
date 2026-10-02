import 'dart:io';
import 'dart:ui' show Locale;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'migration/migration.dart';
import 'migration/migration_prompter.dart';
import 'migration/migration_runner.dart';
import 'migrations/all_migrations.dart';

/// Owns the app's SQLite database file: where it lives, bringing it up to
/// date, and opening it.
///
/// The file is kept in the app-specific external storage folder,
/// `/sdcard/Android/data/<package>/files/databases/`. No permission is
/// needed to use it. Android deletes it when the app is uninstalled.
class AppDatabase {
  AppDatabase({
    sqflite.DatabaseFactory? databaseFactory,
    Future<String> Function()? databasePath,
    this._migrations = allMigrations,
  }) : _factory = databaseFactory ?? sqflite.databaseFactory,
       _databasePath = databasePath ?? _defaultDatabasePath;

  static const fileName = 'expense_tracker.db';

  final sqflite.DatabaseFactory _factory;
  final Future<String> Function() _databasePath;
  final List<Migration> _migrations;

  /// Runs pending migrations. Throws [MigrationFailure] if one fails.
  Future<void> migrate({
    required Locale locale,
    required MigrationPrompter prompter,
    void Function(MigrationProgress progress)? onProgress,
  }) async {
    final runner = MigrationRunner(
      databaseFactory: _factory,
      databasePath: await _databasePath(),
      migrations: _migrations,
      locale: locale,
      prompter: prompter,
    );
    await runner.migrate(onProgress: onProgress);
  }

  /// Opens the database for normal use, with foreign keys enforced. Call
  /// only after [migrate] has succeeded.
  Future<sqflite.Database> open() async {
    return _factory.openDatabase(
      await _databasePath(),
      options: sqflite.OpenDatabaseOptions(
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  }

  static Future<String> _defaultDatabasePath() async {
    final Directory? folder = await getExternalStorageDirectory();
    if (folder == null) {
      throw StateError('App storage folder is not available on this device');
    }
    return p.join(folder.path, 'databases', fileName);
  }
}
