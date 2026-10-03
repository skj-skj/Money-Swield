import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../services/backup/backup_archive.dart';
import '../services/backup/backup_manifest.dart';
import '../services/backup/backup_paths.dart';
import '../services/backup/file_operations.dart';
import '../services/database/app_database.dart';
import '../services/database/database_checks.dart';
import '../services/database/database_files.dart';
import '../services/database/migration/migration_runner.dart';
import 'settings_repository.dart';

/// A finished backup zip in `cache/backup/`, ready for the save dialog.
class BackupFile {
  const BackupFile({required this.path, required this.createdAt});

  final String path;
  final DateTime createdAt;

  /// The name suggested in the save dialog.
  String get name => p.basename(path);
}

/// Makes backups of the open database (phase-3.md §4, §5).
///
/// The copy is built table by table inside one transaction on the app's own
/// connection, not with `VACUUM INTO` (needs SQLite 3.27; Android 10 ships
/// 3.22) and not by copying the file (whether recent commits are in the
/// main file or a `-wal` depends on the journal mode Android picks, and the
/// connection stays open). Only SQL that SQLite 3.22 has is used here.
class BackupRepository {
  BackupRepository(
    this._db, {
    required this._appDatabase,
    required this._settings,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The app's open connection.
  final Database _db;

  /// Where the files go, and the factory that opens the copy on its own
  /// connection. Looked up only when a backup runs.
  final AppDatabase _appDatabase;
  final SettingsRepository _settings;
  final DateTime Function() _now;

  static const _attachedName = 'backup';

  Future<DateTime?> lastBackupAt() => _settings.lastBackupAt();

  Future<void> recordBackup(DateTime at) => _settings.setLastBackupAt(at);

  /// Active expenses on this phone: the confirm dialog's "All data on this
  /// phone (N expenses)". Same rule as the backup's count (§6.2).
  Future<int> activeExpenseCount() async => Sqflite.firstIntValue(
    await _db.rawQuery(
      'SELECT count(*) FROM expenses WHERE deleted_at IS NULL',
    ),
  )!;

  /// Builds a checked backup zip in `cache/backup/`. Throws on any problem,
  /// and then leaves nothing in that folder.
  Future<BackupFile> createBackup({required String appVersion}) async {
    final paths = await _appDatabase.paths();
    // A backup cut short leaves its copy here; its tables would make the
    // CREATE TABLEs below fail.
    await deleteFolderIfExists(paths.backupWorkFolder);
    await Directory(paths.backupWorkFolder).create(recursive: true);
    try {
      final schema = await _readSchema();
      await _createEmptyCopy(paths.backupCopy, schema);
      await _fillCopy(paths.backupCopy, schema.tables);
      final schemaVersion = await _checkCopy(paths.backupCopy);
      final createdAt = _now();
      final zip = p.join(paths.backupWorkFolder, backupFileName(createdAt));
      await BackupArchive.write(
        BackupManifest(
          format: BackupManifest.currentFormat,
          appVersion: appVersion,
          schemaVersion: schemaVersion,
          createdAt: createdAt,
        ),
        paths.backupCopy,
        zip,
      );
      await _checkZip(zip, paths);
      return BackupFile(path: zip, createdAt: createdAt);
    } catch (_) {
      await deleteFolderIfExists(paths.backupWorkFolder);
      rethrow;
    }
  }

  /// Deletes `cache/backup/`, at the end of every backup (§5.2 step 6).
  Future<void> deleteBackupFiles() async =>
      deleteFolderIfExists((await _appDatabase.paths()).backupWorkFolder);

  /// `expense-tracker-backup-YYYYMMDD-HHMMSS.zip` in device-local time.
  static String backupFileName(DateTime at) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'expense-tracker-backup-${t.year}${two(t.month)}${two(t.day)}'
        '-${two(t.hour)}${two(t.minute)}${two(t.second)}.zip';
  }

  /// §4.2 step 1. `substr`, not `NOT LIKE 'sqlite_%'`: in LIKE, `_` matches
  /// any character, which would skip a table named `sqliteXdata`.
  /// `android_metadata` is left out: Android creates it in every database
  /// it opens, so the copy already has it.
  Future<_Schema> _readSchema() async {
    final rows = await _db.rawQuery(
      'SELECT type, name, sql FROM sqlite_master '
      "WHERE sql IS NOT NULL AND substr(name, 1, 7) <> 'sqlite_' "
      "AND name <> 'android_metadata'",
    );
    final tables = <_SchemaItem>[];
    final indexes = <_SchemaItem>[];
    for (final row in rows) {
      final item = (name: row['name']! as String, sql: row['sql']! as String);
      switch (row['type']) {
        case 'table':
          tables.add(item);
        case 'index':
          indexes.add(item);
        // database.md §1 bans triggers and views; a trigger would also fire
        // while the copy is filled.
        case final type:
          throw StateError(
            'Backups support tables and indexes only, found $type "${item.name}"',
          );
      }
    }
    final userVersion =
        Sqflite.firstIntValue(await _db.rawQuery('PRAGMA user_version')) ?? 0;
    return _Schema(tables, indexes, userVersion);
  }

  /// §4.2 step 2: a new, separate database with the same schema. Running the
  /// original SQL on a fresh connection needs no rewriting of table names.
  Future<void> _createEmptyCopy(String path, _Schema schema) async {
    final copy = await _appDatabase.databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      // A rollback journal, not WAL: the zip holds the .db alone, and the
      // restore opens it read-only.
      await copy.rawQuery('PRAGMA journal_mode = DELETE');
      // One transaction, so one sync to disk rather than one per statement.
      await copy.transaction((txn) async {
        for (final item in [...schema.tables, ...schema.indexes]) {
          await txn.execute(item.sql);
        }
        await txn.execute('PRAGMA user_version = ${schema.userVersion}');
      });
    } finally {
      await copy.close();
    }
  }

  /// §4.2 step 3. ATTACH must run outside a transaction; everything that
  /// touches the attached copy runs inside **one** transaction, never as a
  /// separate call: Android may run a read outside a transaction on another
  /// pooled connection, which has nothing attached. sqflite runs one
  /// statement at a time per connection, so this is a snapshot.
  Future<void> _fillCopy(String path, List<_SchemaItem> tables) async {
    await _db.execute('ATTACH DATABASE ? AS $_attachedName', [path]);
    Object? failure;
    try {
      await _db.transaction((txn) async {
        // Tables can then be filled in any order.
        await txn.execute('PRAGMA defer_foreign_keys = ON');
        for (final table in tables) {
          final name = _quote(table.name);
          await txn.execute(
            'INSERT INTO $_attachedName.$name SELECT * FROM main.$name',
          );
        }
        await _copySequences(txn);
        // Checked here, not left to COMMIT: when COMMIT fails on a deferred
        // foreign key, sqflite doesn't roll back and the app's connection
        // becomes unusable (seen with sqflite_common_ffi 2.4). A throw in
        // the transaction rolls back cleanly. Live data with a dangling
        // reference therefore fails the backup with a clear message.
        await checkForeignKeys(txn, schema: _attachedName);
        for (final table in tables) {
          await _checkRowCount(txn, table.name);
        }
      });
    } catch (error) {
      failure = error;
      rethrow;
    } finally {
      await _detach(rethrowErrors: failure == null);
    }
  }

  /// The AUTOINCREMENT counters. Without them a restore would reuse the ids
  /// of permanently deleted rows (the migrator keeps them for the same
  /// reason). The inserts above already set the copy's counters to the
  /// highest id, so they are replaced, not added to.
  Future<void> _copySequences(Transaction txn) async {
    final hasSequence = await txn.rawQuery(
      "SELECT 1 FROM main.sqlite_master WHERE name = 'sqlite_sequence'",
    );
    if (hasSequence.isEmpty) return;
    await txn.execute('DELETE FROM $_attachedName.sqlite_sequence');
    await txn.execute(
      'INSERT INTO $_attachedName.sqlite_sequence '
      'SELECT * FROM main.sqlite_sequence',
    );
  }

  Future<void> _checkRowCount(Transaction txn, String table) async {
    Future<int> count(String schema) async => Sqflite.firstIntValue(
      await txn.rawQuery('SELECT count(*) FROM $schema.${_quote(table)}'),
    )!;
    final source = await count('main');
    final copied = await count(_attachedName);
    if (source != copied) {
      throw StateError('Copied $copied of $source rows of "$table"');
    }
  }

  /// A failed DETACH after a failed copy mustn't hide the copy's error.
  Future<void> _detach({required bool rethrowErrors}) async {
    try {
      await _db.execute('DETACH DATABASE $_attachedName');
    } catch (_) {
      if (rethrowErrors) rethrow;
    }
  }

  /// §4.2 step 4: the copy on its own, read-only. Returns the newest applied
  /// migration for the manifest.
  Future<int?> _checkCopy(String path) async {
    final copy = await _appDatabase.databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    final int? schemaVersion;
    try {
      await checkIntegrity(copy);
      await checkForeignKeys(copy);
      final applied = await MigrationRunner.appliedVersions(copy);
      schemaVersion = applied.isEmpty
          ? null
          : applied.reduce((a, b) => a > b ? a : b);
    } finally {
      await copy.close();
    }
    // The zip holds the .db only; anything still in a journal would be lost.
    await checkJournalsEmpty(path, what: 'The backup copy');
    return schemaVersion;
  }

  /// Reads the new zip back the way a restore would and compares the
  /// database it holds with the copy, so a backup that couldn't be
  /// restored is never saved.
  Future<void> _checkZip(String zip, BackupPaths paths) async {
    final readBack = p.join(paths.backupWorkFolder, 'read-back.db');
    try {
      await BackupArchive.read(zip, extractDatabaseTo: readBack);
      if (!await filesEqual(readBack, paths.backupCopy)) {
        throw StateError('The backup zip does not hold the copied database');
      }
    } finally {
      await deleteFileIfExists(readBack);
    }
  }

  static String _quote(String name) => '"${name.replaceAll('"', '""')}"';
}

typedef _SchemaItem = ({String name, String sql});

class _Schema {
  const _Schema(this.tables, this.indexes, this.userVersion);

  final List<_SchemaItem> tables;
  final List<_SchemaItem> indexes;
  final int userVersion;
}
