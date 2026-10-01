import 'dart:io';
import 'dart:ui' show Locale;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_backup.dart';
import 'migration.dart';
import 'migration_prompter.dart';

/// What the runner is doing right now.
enum MigrationStage { checking, backingUp, migrating, verifying, done }

class MigrationProgress {
  const MigrationProgress({required this.stage, required this.completed, required this.total, this.current});

  final MigrationStage stage;

  /// How many of the [total] pending migrations have finished.
  final int completed;
  final int total;

  /// The migration currently running, during [MigrationStage.migrating].
  final Migration? current;
}

/// Thrown when migrating fails. Holds everything a user needs to report it.
class MigrationFailure implements Exception {
  const MigrationFailure({
    required this.step,
    required this.error,
    required this.stackTrace,
    this.migration,
    this.backupPath,
  });

  /// What was happening, e.g. "Running 1759190400_add_currency_to_expenses".
  final String step;
  final Object error;
  final StackTrace stackTrace;

  /// The migration that failed, if the failure happened inside one.
  final Migration? migration;

  /// Where the pre-migration copy of the database was kept, if one was made.
  final String? backupPath;

  /// Plain-text report for the user to copy into a bug report.
  String get report => [
    'Step: $step',
    if (migration != null) 'Migration: $migration',
    'Error: $error',
    if (backupPath != null) 'Backup: $backupPath',
    '',
    stackTrace.toString(),
  ].join('\n');

  @override
  String toString() => 'MigrationFailure($step): $error';
}

/// Brings the database file up to date by running pending migrations.
///
/// For each run with pending migrations it:
/// 1. closes the database and copies it into `backups/`,
/// 2. runs each migration in its own transaction, checking foreign keys
///    before committing and recording it in `schema_migrations`,
/// 3. runs SQLite's integrity check,
/// 4. deletes the backup, which is only kept if something failed.
///
/// [rollback] goes through the same steps, running `down` instead.
class MigrationRunner {
  MigrationRunner({
    required DatabaseFactory databaseFactory,
    required this.databasePath,
    required List<Migration> migrations,
    required this.locale,
    required this.prompter,
    this._clock = DateTime.now,
  }) : _factory = databaseFactory,
       _migrations = _sortedAndChecked(migrations);

  static const historyTable = 'schema_migrations';

  final DatabaseFactory _factory;
  final String databasePath;
  final List<Migration> _migrations;
  final Locale locale;
  final MigrationPrompter prompter;
  final DateTime Function() _clock;

  /// Runs all migrations that have not run yet, oldest first.
  Future<void> migrate({void Function(MigrationProgress progress)? onProgress}) async {
    onProgress?.call(const MigrationProgress(stage: MigrationStage.checking, completed: 0, total: 0));
    final pending = await _guard('Checking database version', pendingMigrations);
    await _run(
      pending,
      up: true,
      report: (stage, completed, [current]) => onProgress?.call(
        MigrationProgress(stage: stage, completed: completed, total: pending.length, current: current),
      ),
    );
  }

  /// Undoes the last [steps] applied migrations, newest first, by running
  /// their `down`. Meant for development and tests.
  Future<void> rollback({int steps = 1}) async {
    if (steps < 0) throw ArgumentError.value(steps, 'steps', 'Must not be negative');
    final toUndo = await _guard('Checking database version', () async {
      final applied = await _withDatabase(_appliedVersions);
      return [
        for (final version in (applied.toList()..sort()).reversed.take(steps))
          _migrations.firstWhere((m) => m.version == version),
      ];
    });
    await _run(toUndo, up: false);
  }

  /// Migrations not yet applied to the database at [databasePath].
  Future<List<Migration>> pendingMigrations() async {
    // A new install has nothing applied. Checking without opening keeps the
    // file from being created here, so there is no empty file to back up.
    if (!await File(databasePath).exists()) return [..._migrations];
    final applied = await _withDatabase(_appliedVersions);
    return [for (final m in _migrations) if (!applied.contains(m.version)) m];
  }

  /// Runs each of [migrations] in its own transaction, `up` or (unless [up])
  /// `down`, with the backup and checks described on the class.
  Future<void> _run(
    List<Migration> migrations, {
    required bool up,
    void Function(MigrationStage stage, int completed, [Migration? current])? report,
  }) async {
    if (migrations.isEmpty) {
      report?.call(MigrationStage.done, 0);
      return;
    }

    report?.call(MigrationStage.backingUp, 0);
    final backup = await _guard('Backing up database', () => DatabaseBackup.create(databasePath, now: _clock()));

    final db = await _guard('Opening database', _open, backup: backup);
    try {
      for (final (index, migration) in migrations.indexed) {
        report?.call(MigrationStage.migrating, index, migration);
        final step = up ? 'Running $migration' : 'Rolling back $migration';
        await _guard(step, migration: migration, backup: backup, () async {
          await db.transaction((txn) async {
            final m = Migrator(txn, locale: locale, prompter: prompter);
            await (up ? migration.up(m) : migration.down(m));
            await _checkForeignKeys(txn);
            if (up) {
              await txn.insert(historyTable, {
                'version': migration.version,
                'name': migration.name,
                'applied_at': _clock().millisecondsSinceEpoch,
              });
            } else {
              await txn.delete(historyTable, where: 'version = ?', whereArgs: [migration.version]);
            }
          });
        });
      }
      report?.call(MigrationStage.verifying, migrations.length);
      await _guard('Checking database integrity', () => _checkIntegrity(db), backup: backup);
    } finally {
      await db.close();
    }

    if (backup != null) await DatabaseBackup.delete(backup);
    report?.call(MigrationStage.done, migrations.length);
  }

  /// Opens the database with the history table in place and foreign key
  /// enforcement off, as SQLite's table rebuild needs. The setting only
  /// lasts for this connection; the app's own connection turns it on.
  Future<Database> _open() async {
    await Directory(p.dirname(databasePath)).create(recursive: true);
    return _factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = OFF'),
        onOpen: (db) => db.execute(
          'CREATE TABLE IF NOT EXISTS $historyTable ('
          'version INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL, applied_at INTEGER NOT NULL)',
        ),
      ),
    );
  }

  Future<T> _withDatabase<T>(Future<T> Function(Database db) action) async {
    final db = await _open();
    try {
      return await action(db);
    } finally {
      await db.close();
    }
  }

  /// Versions recorded as applied. Throws if any is unknown to this app,
  /// i.e. a newer app changed the database.
  Future<Set<int>> _appliedVersions(Database db) async {
    final rows = await db.query(historyTable, columns: ['version']);
    final applied = {for (final row in rows) row['version']! as int};
    final unknown = applied.difference({for (final m in _migrations) m.version});
    if (unknown.isNotEmpty) {
      throw StateError(
        'This database was updated by a newer version of the app (unknown migrations: '
        '${(unknown.toList()..sort()).join(', ')}). Install the latest version of the app.',
      );
    }
    return applied;
  }

  static Future<void> _checkForeignKeys(DatabaseExecutor db) async {
    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    if (violations.isEmpty) return;
    final details = violations
        .take(5)
        .map((v) => '${v['table']} row ${v['rowid']} points to a missing row in ${v['parent']}')
        .join('; ');
    throw StateError('Foreign key check failed (${violations.length} violation(s)): $details');
  }

  static Future<void> _checkIntegrity(Database db) async {
    final rows = await db.rawQuery('PRAGMA integrity_check');
    final result = rows.map((r) => r.values.first).join('; ');
    if (result != 'ok') throw StateError('Integrity check failed: $result');
  }

  /// Runs [action], turning any error into a [MigrationFailure].
  Future<T> _guard<T>(String step, Future<T> Function() action, {Migration? migration, File? backup}) async {
    try {
      return await action();
    } on MigrationFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw MigrationFailure(
        step: step,
        error: error,
        stackTrace: stackTrace,
        migration: migration,
        backupPath: backup?.path,
      );
    }
  }

  static List<Migration> _sortedAndChecked(List<Migration> migrations) {
    final versions = <int>{};
    final names = <String>{};
    for (final m in migrations) {
      if (m.version <= 0) throw ArgumentError('Migration $m has an invalid version');
      if (!versions.add(m.version)) throw ArgumentError('Two migrations share version ${m.version}');
      if (!names.add(m.name)) throw ArgumentError('Two migrations share the name "${m.name}"');
    }
    return [...migrations]..sort((a, b) => a.version.compareTo(b.version));
  }
}
