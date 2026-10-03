import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;
import 'package:my_expense_tracker_app/data/services/backup/backup_paths.dart';
import 'package:my_expense_tracker_app/data/services/database/app_database.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration_runner.dart';
import 'package:my_expense_tracker_app/data/services/database/migrations/all_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/services/database/migration/test_helpers.dart';

/// Real database files in a temporary folder laid out like the app's
/// (`files/databases/`, `cache/`), deleted when the test ends.
///
/// Tests run on Windows, where an open file can't be deleted or renamed: a
/// connection left open fails the teardown or the swap. That is a useful
/// leak detector (phase-3.md §12): fix the leak, don't loosen the test.
class FileDatabases {
  FileDatabases._(this.root, this.factory);

  /// [androidLike] makes every database opened for writing get an
  /// `android_metadata` table, as on Android ([FileTestDatabaseFactory]). [noIsolate] runs SQLite on the test's
  /// own isolate, so its futures complete inside `testWidgets`' fake clock.
  static Future<FileDatabases> create({
    bool androidLike = false,
    bool noIsolate = false,
  }) async {
    final root = await Directory.systemTemp.createTemp('expense_tracker_test');
    addTearDown(() => root.delete(recursive: true));
    sqfliteFfiInit();
    final factory = noIsolate
        ? databaseFactoryFfiNoIsolate
        : testDatabaseFactory();
    return FileDatabases._(
      root,
      FileTestDatabaseFactory(factory, androidLike: androidLike),
    );
  }

  final Directory root;
  final FileTestDatabaseFactory factory;

  late final paths = BackupPaths(
    databaseFile: p.join(root.path, 'files', 'databases', AppDatabase.fileName),
    cacheFolder: p.join(root.path, 'cache'),
  );

  String get livePath => paths.databaseFile;

  /// An [AppDatabase] over [path] (the live file by default).
  AppDatabase appDatabase({String? path, List<Migration>? migrations}) =>
      AppDatabase(
        databaseFactory: factory,
        databasePath: () async => path ?? livePath,
        cacheFolder: () async => paths.cacheFolder,
        migrations: migrations ?? allMigrations,
      );

  /// A new file with every migration applied, per kind of factory (an
  /// Android-like one adds `android_metadata`). Running the migrations on a
  /// file takes seconds on Windows (each step opens, writes and closes
  /// files, and the virus scanner checks each), which pushed the first
  /// tests close to their timeout. So they run once per test file, and
  /// later new databases start as a copy of that one.
  static final _migratedTemplates = <bool, Uint8List>{};

  /// Runs [migrations] (all by default) on the file at [path].
  Future<void> migrate(String path, {List<Migration>? migrations}) async {
    await Directory(p.dirname(path)).create(recursive: true);
    final all = migrations == null || identical(migrations, allMigrations);
    final fromTemplate = all && !File(path).existsSync();
    final androidLike = factory.androidLike;
    final template = fromTemplate ? _migratedTemplates[androidLike] : null;
    if (template != null) {
      await File(path).writeAsBytes(template, flush: true);
      return;
    }
    await MigrationRunner(
      databaseFactory: factory,
      databasePath: path,
      migrations: migrations ?? allMigrations,
      locale: const Locale('en', 'IN'),
      prompter: FakePrompter(),
    ).migrate();
    if (fromTemplate) {
      _migratedTemplates[androidLike] = await File(path).readAsBytes();
    }
  }

  /// Opens [path] like the app does (foreign keys on). Closed when the
  /// test ends unless the test closes it first.
  Future<Database> open(String path) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    addTearDown(() async {
      if (db.isOpen) await db.close();
    });
    return db;
  }

  /// A migrated live database, open like the app's connection.
  Future<Database> openLive() async {
    await migrate(livePath);
    return open(livePath);
  }

  /// Runs [action] on its own short connection to [path].
  Future<T> withDatabase<T>(
    String path,
    Future<T> Function(Database db) action,
  ) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      return await action(db);
    } finally {
      await db.close();
    }
  }
}

/// Every row of every user table in [db], keyed by table name, in rowid
/// order: what "row-for-row equal" compares.
Future<Map<String, List<Map<String, Object?>>>> dumpTables(
  DatabaseExecutor db,
) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name <> 'android_metadata' ORDER BY name",
  );
  return {
    for (final row in tables)
      row['name']! as String: await db.rawQuery(
        'SELECT * FROM "${row['name']}" ORDER BY rowid',
      ),
  };
}

/// The schema SQL of [db] (tables and indexes), by name.
Future<Map<String, String?>> schemaOf(DatabaseExecutor db) async => {
  for (final row in await db.rawQuery(
    "SELECT name, sql FROM sqlite_master WHERE name <> 'android_metadata' "
    'ORDER BY name',
  ))
    row['name']! as String: row['sql'] as String?,
};

/// Opens the test's database files. Every connection is opened with
/// `PRAGMA synchronous = OFF`: SQLite then doesn't wait for each commit to
/// reach the disk, which costs ~0.9 s per commit on the Windows dev machine
/// and made these tests slow. Nothing here simulates a power cut, so it
/// changes no result: files, journals, renames and locks behave the same.
///
/// [androidLike] also opens databases like Android's `SQLiteDatabase`
/// does: every database opened for writing gets an `android_metadata`
/// table with one row, the locale (sqflite on Android opens without
/// `NO_LOCALIZED_COLLATORS`). The FFI factory doesn't, so tests that care
/// ask for it.
class FileTestDatabaseFactory implements DatabaseFactory {
  FileTestDatabaseFactory(this._inner, {required this.androidLike});

  final DatabaseFactory _inner;
  final bool androidLike;

  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async {
    final db = await _inner.openDatabase(path, options: options);
    try {
      await db.execute('PRAGMA synchronous = OFF');
    } catch (_) {
      // A file that isn't a database fails here, not on open: close it,
      // or the connection leaks and Windows keeps the file locked.
      await db.close();
      rethrow;
    }
    if (androidLike && options?.readOnly != true) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS android_metadata (locale TEXT)',
      );
      final rows = await db.rawQuery('SELECT 1 FROM android_metadata');
      if (rows.isEmpty) {
        await db.insert('android_metadata', {'locale': 'en_US'});
      }
    }
    return db;
  }

  @override
  Future<bool> databaseExists(String path) => _inner.databaseExists(path);

  @override
  Future<void> deleteDatabase(String path) => _inner.deleteDatabase(path);

  @override
  Future<String> getDatabasesPath() => _inner.getDatabasesPath();

  @override
  Future<void> setDatabasesPath(String path) => _inner.setDatabasesPath(path);

  @override
  Future<Uint8List> readDatabaseBytes(String path) =>
      _inner.readDatabaseBytes(path);

  @override
  Future<void> writeDatabaseBytes(String path, Uint8List bytes) =>
      _inner.writeDatabaseBytes(path, bytes);
}
