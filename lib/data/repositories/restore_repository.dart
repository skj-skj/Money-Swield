import 'dart:io';
import 'dart:ui' show Locale;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/restore_candidate.dart';
import '../services/backup/backup_archive.dart';
import '../services/backup/backup_paths.dart';
import '../services/backup/file_operations.dart';
import '../services/backup/pre_restore_copy.dart';
import '../services/database/app_database.dart';
import '../services/database/database_checks.dart';
import '../services/database/database_files.dart';
import '../services/database/migration/migration_prompter.dart';
import '../services/database/migration/migration_runner.dart';
import '../services/database/migration/migrator.dart';
import '../services/database/migrations/1790942733_create_settings.dart';
import 'settings_repository.dart';

/// Runs one small read per repository on an open candidate, the way the app
/// would on start (§6.4 step 3). Passed in so this class doesn't depend on
/// the app layer that builds the repositories.
typedef CandidateProbe = Future<void> Function(Database db);

/// Prepares a database to replace the live one (phase-3.md §6). Every step
/// here works on `databases/restore/candidate.db`; nothing touches the live
/// database, which [AppDatabase.replaceWith] alone replaces.
class RestoreRepository {
  RestoreRepository({required this._appDatabase, required this._probe});

  final AppDatabase _appDatabase;
  final CandidateProbe _probe;

  DatabaseFactory get _factory => _appDatabase.databaseFactory;

  Future<String> candidatePath() async =>
      (await _appDatabase.paths()).candidate;

  /// Validates the zip the open dialog copied to `cache/restore/picked.zip`
  /// and extracts its database as the candidate. Throws [RestoreRejected].
  Future<RestoreCandidate> prepareFromZip() async {
    final paths = await _freshCandidateFolder();
    try {
      final manifest = await BackupArchive.read(
        paths.pickedZip,
        extractDatabaseTo: paths.candidate,
      );
      return await _validate(
        paths.candidate,
        source: RestoreSource.zip,
        createdAt: manifest.createdAt,
      );
    } catch (_) {
      await deleteCandidate();
      rethrow;
    } finally {
      // The picked zip isn't needed past this point.
      await deleteFolderIfExists(paths.restoreWorkFolder);
    }
  }

  /// Copies [copy] (with its journals: its `-wal` may hold data) to the
  /// candidate and validates it. Copied, not moved, so the copy survives a
  /// failed attempt.
  Future<RestoreCandidate> prepareFromCopy(PreRestoreCopy copy) async {
    final paths = await _freshCandidateFolder();
    try {
      for (final suffix in ['', ...journalSuffixes]) {
        final source = File('${copy.path}$suffix');
        if (await source.exists()) {
          await source.copy('${paths.candidate}$suffix');
        }
      }
      return await _validate(
        paths.candidate,
        source: RestoreSource.preRestoreCopy,
        createdAt: copy.createdAt,
      );
    } catch (_) {
      await deleteCandidate();
      rethrow;
    }
  }

  /// Writes the backup's own time into the candidate's `last_backup_at`
  /// (P3-9): the restored data *is* that backup.
  Future<void> stamp(RestoreCandidate candidate) async {
    final createdAt = candidate.createdAt;
    if (!candidate.stampsLastBackup || createdAt == null) return;
    await _withCandidate(
      (db) => SettingsRepository(
        db,
        deviceCurrency: '', // Only read by load(); not used to write.
      ).setLastBackupAt(createdAt),
    );
  }

  /// §6.4 step 3: opens the candidate as the app would and runs a small
  /// query per repository, so a database that validates but can't start
  /// the app is refused before the swap. Then checks that nothing is left
  /// in a journal: the rename moves the `.db` only.
  Future<void> checkOpensAsApp() async {
    final path = await candidatePath();
    try {
      await _withCandidate(_probe, foreignKeys: true);
    } catch (error) {
      throw RestoreRejected(
        RestoreRejection.damaged,
        'The restored data can\'t be opened: $error',
      );
    }
    await checkJournalsEmpty(path, what: 'The restored data');
  }

  /// §6.4 step 2, before [stamp]: makes sure the candidate's `settings` can
  /// be read. Settings that are missing or unreadable (the table dropped, a
  /// column renamed by hand, a value that isn't text) don't make the
  /// expenses damaged, so the backup is restored with default settings
  /// rather than refused: the table is rebuilt empty and onboarding is
  /// marked done, so the user lands on Home and is told the settings are
  /// back to defaults. A value that is only unknown (a newer app's theme)
  /// already falls back to its default when read, so it doesn't count.
  ///
  /// Returns whether the settings were reset.
  ///
  /// Rebuilt with [CreateSettings], the only migration that shapes the
  /// table. Until the first release, a change to `settings` goes into that
  /// migration itself, so this stays right. After release a new migration
  /// that changes `settings` must be applied here too.
  Future<bool> repairSettings() => _withCandidate((db) async {
    if (await _settingsReadable(db)) return false;
    await db.transaction((txn) async {
      await txn.execute('DROP TABLE IF EXISTS settings');
      await const CreateSettings().up(
        Migrator(txn, locale: const Locale('en'), prompter: _NoQuestions()),
      );
    });
    await SettingsRepository(
      db,
      deviceCurrency: '', // Only read by load(); not used to write.
    ).setOnboardingCompleted();
    return true;
  });

  /// Whether `settings` exists and every row is what [SettingsRepository]
  /// reads: a text key and a text (or null) value.
  static Future<bool> _settingsReadable(Database db) async {
    try {
      final rows = await db.rawQuery('SELECT key, value FROM settings');
      return rows.every(
        (row) =>
            row['key'] is String &&
            (row['value'] == null || row['value'] is String),
      );
    } on DatabaseException {
      return false;
    }
  }

  /// Deletes the candidate and its folder (with any migration backup the
  /// runner left there).
  Future<void> deleteCandidate() async =>
      deleteFolderIfExists((await _appDatabase.paths()).candidateFolder);

  /// Deletes what a backup or restore cut short left behind (§6.6). Run on
  /// every start, before anything can start a new restore.
  Future<void> cleanUpLeftovers() async {
    final paths = await _appDatabase.paths();
    await deleteFolderIfExists(paths.backupWorkFolder);
    await deleteFolderIfExists(paths.restoreWorkFolder);
    await deleteFolderIfExists(paths.candidateFolder);
    await _appDatabase.cleanUpPreRestoreFolder();
  }

  Future<BackupPaths> _freshCandidateFolder() async {
    final paths = await _appDatabase.paths();
    await deleteFolderIfExists(paths.candidateFolder);
    await Directory(paths.candidateFolder).create(recursive: true);
    return paths;
  }

  /// §6.2, in order, stopping at the first problem. The candidate is opened
  /// read-only and not through [MigrationRunner] (whose open creates
  /// `schema_migrations` when it's missing, hiding "not one of ours").
  Future<RestoreCandidate> _validate(
    String path, {
    required RestoreSource source,
    required DateTime? createdAt,
  }) async {
    final Database db;
    try {
      db = await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
    } catch (error) {
      throw RestoreRejected(RestoreRejection.damaged, 'Can\'t open: $error');
    }
    try {
      await _checkHealthy(db);
      await _checkMigrations(db);
      return await _summarize(db, source: source, createdAt: createdAt);
    } finally {
      await db.close();
    }
  }

  static Future<void> _checkHealthy(Database db) async {
    try {
      await checkIntegrity(db);
      await checkForeignKeys(db);
    } catch (error) {
      throw RestoreRejected(RestoreRejection.damaged, '$error');
    }
  }

  /// `schema_migrations` must exist **and have rows**: an empty one would
  /// make every migration run, building an empty database that then
  /// replaces the user's data.
  Future<void> _checkMigrations(Database db) async {
    final Set<int> applied;
    try {
      applied = await MigrationRunner.appliedVersions(db);
    } catch (error) {
      throw RestoreRejected(
        RestoreRejection.damaged,
        'No migration history: $error',
      );
    }
    if (applied.isEmpty) {
      throw const RestoreRejected(
        RestoreRejection.damaged,
        'The migration history is empty',
      );
    }
    try {
      checkKnownVersions(applied, _appDatabase.knownMigrationVersions);
    } on UnknownMigrationsException catch (error) {
      throw RestoreRejected(RestoreRejection.tooNew, error.message);
    }
  }

  /// What the confirm dialog shows. Counting is skipped for a backup from a
  /// schema without `expenses` (Phase 1), so it still validates.
  static Future<RestoreCandidate> _summarize(
    Database db, {
    required RestoreSource source,
    required DateTime? createdAt,
  }) async {
    final hasExpenses = (await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'expenses'",
    )).isNotEmpty;
    if (!hasExpenses) {
      return RestoreCandidate(
        source: source,
        createdAt: createdAt,
        activeExpenses: null,
        binnedExpenses: null,
        latestExpenseOn: null,
      );
    }
    // One counting rule everywhere (P3-20): "N expenses" is active only.
    // count(CASE …) rather than `FILTER (WHERE …)`, which needs SQLite 3.30
    // (Android 10 has 3.22). count() of no rows is 0, unlike sum().
    final row = (await db.rawQuery(
      'SELECT count(CASE WHEN deleted_at IS NULL THEN 1 END) AS active, '
      'count(CASE WHEN deleted_at IS NOT NULL THEN 1 END) AS binned, '
      'max(CASE WHEN deleted_at IS NULL THEN occurred_on END) AS latest '
      'FROM expenses',
    )).single;
    return RestoreCandidate(
      source: source,
      createdAt: createdAt,
      activeExpenses: row['active']! as int,
      binnedExpenses: row['binned']! as int,
      latestExpenseOn: DateTime.tryParse(row['latest'] as String? ?? ''),
    );
  }

  Future<T> _withCandidate<T>(
    Future<T> Function(Database db) action, {
    bool foreignKeys = false,
  }) async {
    final db = await _factory.openDatabase(
      await candidatePath(),
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: foreignKeys
            ? (db) => db.execute('PRAGMA foreign_keys = ON')
            : null,
      ),
    );
    try {
      return await action(db);
    } finally {
      await db.close();
    }
  }
}

/// Creating the settings table asks nothing; a question would be a bug.
class _NoQuestions implements MigrationPrompter {
  @override
  Future<String> askText(String question, {String initialValue = ''}) =>
      throw StateError('Unexpected question: $question');

  @override
  Future<String> askChoice(
    String question,
    List<String> options, {
    String? initialValue,
  }) => throw StateError('Unexpected question: $question');
}
