import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../../domain/error_report.dart';
import '../backup/backup_paths.dart';
import '../backup/file_operations.dart';
import '../backup/pre_restore_copy.dart';
import 'database_files.dart';
import 'migration/migration.dart';
import 'migration/migration_prompter.dart';
import 'migration/migration_runner.dart';
import 'migrations/all_migrations.dart';

/// Thrown by [AppDatabase.replaceWith]. [needsRestart] says whether the app
/// has to restart to keep going: the app's connection is (or may be)
/// closed.
class SwapFailure implements Exception {
  const SwapFailure({
    required this.step,
    required this.error,
    required this.stackTrace,
    required this.needsRestart,
  });

  /// English on purpose: part of the report the user sends us.
  final String step;
  final Object error;
  final StackTrace stackTrace;
  final bool needsRestart;

  String get report => errorReport(step, error, stackTrace);

  @override
  String toString() => 'SwapFailure($step): $error';
}

/// Owns the app's SQLite database file: where it lives, bringing it up to
/// date, opening it, and replacing it with a restored one.
///
/// The file is kept in the app-specific external storage folder,
/// `/sdcard/Android/data/<package>/files/databases/`. No permission is
/// needed to use it. Android deletes it when the app is uninstalled.
class AppDatabase {
  AppDatabase({
    sqflite.DatabaseFactory? databaseFactory,
    Future<String> Function()? databasePath,
    Future<String> Function()? cacheFolder,
    FileOperations fileOperations = const IoFileOperations(),
    this._migrations = allMigrations,
  }) : _factory = databaseFactory,
       _databasePath = databasePath ?? _defaultDatabasePath,
       _cacheFolder = cacheFolder ?? _defaultCacheFolder,
       _files = fileOperations;

  static const fileName = 'money_swield.db';

  /// How many pre-restore copies are kept.
  static const keptPreRestoreCopies = 3;

  /// Opens this and every other database file of the app (restore
  /// candidates, backup copies). sqflite's default is looked up only when
  /// used: tests build an [AppDatabase] they never open, where it isn't set.
  sqflite.DatabaseFactory get databaseFactory =>
      _factory ?? sqflite.databaseFactory;
  final sqflite.DatabaseFactory? _factory;
  final Future<String> Function() _databasePath;
  final Future<String> Function() _cacheFolder;
  final FileOperations _files;
  final List<Migration> _migrations;

  /// Whether the first [migrate] of this app run found no database file.
  /// Kept across retries: a failed run already created the file, so on its
  /// own the runner would call the retry of a new install an update.
  bool? _startedWithoutFile;

  /// Versions of every migration this app has. A database with any other
  /// was changed by a newer app.
  Set<int> get knownMigrationVersions => {
    for (final m in _migrations) m.version,
  };

  /// An [AppDatabase] over the file at [path] (a restore candidate) with
  /// this one's factory and migrations, so the candidate is brought up to
  /// date exactly as the live file would be.
  AppDatabase forFile(String path) => AppDatabase(
    databaseFactory: _factory,
    databasePath: () async => path,
    cacheFolder: _cacheFolder,
    fileOperations: _files,
    migrations: _migrations,
  );

  /// Where the live database and the backup / restore files are.
  Future<BackupPaths> paths() async => BackupPaths(
    databaseFile: await _databasePath(),
    cacheFolder: await _cacheFolder(),
  );

  /// The app's external files folder, which holds `databases/` and the photo
  /// folders.
  Future<String> filesFolder() async =>
      p.dirname(p.dirname(await _databasePath()));

  /// Runs pending migrations and says whether that installed, updated or
  /// left alone the database. Throws [MigrationFailure] if one fails.
  Future<MigrationOutcome> migrate({
    required Locale locale,
    required MigrationPrompter prompter,
    void Function(MigrationProgress progress)? onProgress,
  }) async {
    final path = await _databasePath();
    _startedWithoutFile ??= !await File(path).exists();
    final runner = MigrationRunner(
      databaseFactory: databaseFactory,
      databasePath: path,
      migrations: _migrations,
      locale: locale,
      prompter: prompter,
    );
    final outcome = await runner.migrate(onProgress: onProgress);
    return outcome == MigrationOutcome.updated && _startedWithoutFile!
        ? MigrationOutcome.installed
        : outcome;
  }

  /// Forgets that this run started without a file. Called when the app restarts
  /// after a restore: otherwise a fresh install that restored a backup would
  /// say "Database initialized".
  void resetRunHistory() => _startedWithoutFile = null;

  /// Opens the database for normal use, with foreign keys enforced. Call
  /// only after [migrate] has succeeded.
  Future<sqflite.Database> open() async {
    return databaseFactory.openDatabase(
      await _databasePath(),
      options: sqflite.OpenDatabaseOptions(
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  }

  /// Complete pre-restore copies, newest (highest sequence) first.
  Future<List<PreRestoreCopy>> preRestoreCopies() async {
    final folder = Directory((await paths()).preRestoreFolder);
    if (!await folder.exists()) return [];
    return [
      await for (final entity in folder.list())
        if (entity is File) ?PreRestoreCopy.parse(entity.path),
    ]..sort((a, b) => b.sequence.compareTo(a.sequence));
  }

  /// Replaces the live database with the (migrated, checked) database at
  /// [candidatePath]. Until the rename in step 4 nothing the user has is
  /// changed; after it, the old data still exists as a pre-restore copy.
  ///
  /// 1. [closeConnection] closes the app's connection. If it throws, this
  ///    stops: nothing is copied, deleted or renamed. The app still
  ///    restarts: a close that failed half way may have
  ///    left the connection unusable. (sqflite's own `close()` marks the
  ///    database closed first and never throws, so this is a safety net.)
  /// 2. The live file and its journals are copied to a new pre-restore
  ///    copy, under `.partial` names, flushed, renamed last.
  /// 3. The live journals are deleted. Required: a leftover `-wal` would be
  ///    replayed onto the new file and corrupt it. They were copied in 2.
  /// 4. The candidate is renamed over the live file: the commit point. Same
  ///    folder tree, so the rename is atomic.
  /// 5. Old copies beyond [keptPreRestoreCopies] and the candidate's folder
  ///    are deleted, best effort: the restore has already succeeded.
  ///
  /// Throws [SwapFailure].
  Future<void> replaceWith(
    String candidatePath, {
    required Future<void> Function() closeConnection,
    DateTime? now,
  }) async {
    final paths = await this.paths();
    try {
      await closeConnection();
    } catch (error, stackTrace) {
      throw SwapFailure(
        step: 'Closing the database',
        error: error,
        stackTrace: stackTrace,
        needsRestart: true,
      );
    }
    await _swapStep(
      'Copying the current data',
      () => _copyLiveAside(paths, now ?? DateTime.now()),
    );
    await _swapStep(
      'Removing the journal files',
      () => _deleteFiles([
        for (final suffix in sidecarSuffixes) '${paths.databaseFile}$suffix',
      ]),
    );
    await _swapStep(
      'Swapping in the restored data',
      () => _files.rename(candidatePath, paths.databaseFile),
    );
    try {
      await _prunePreRestoreCopies();
      await deleteFolderIfExists(paths.candidateFolder);
    } catch (error, stackTrace) {
      // The next restore prunes again; the next start deletes the folder.
      debugPrint('Tidying up after a restore failed: $error\n$stackTrace');
    }
  }

  /// Deletes what a copy cut short left in the pre-restore folder: `.partial`
  /// files, and journals whose copy was never completed (they are renamed
  /// before the `.db`, so they can be left without it). Part of the startup
  /// cleanup.
  Future<void> cleanUpPreRestoreFolder() async {
    final folder = Directory((await paths()).preRestoreFolder);
    if (!await folder.exists()) return;
    await for (final entity in folder.list()) {
      final name = p.basename(entity.path);
      if (entity is! File || !name.startsWith(PreRestoreCopy.prefix)) continue;
      final orphanSidecar = sidecarSuffixes.any(
        (suffix) =>
            name.endsWith(suffix) &&
            !File(entity.path.substring(0, entity.path.length - suffix.length))
                .existsSync(),
      );
      if (name.endsWith('.partial') || orphanSidecar) await entity.delete();
    }
  }

  /// Runs one step after the connection is closed; a failure there needs a
  /// restart, since the old connection is gone either way.
  static Future<void> _swapStep(
    String step,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stackTrace) {
      throw SwapFailure(
        step: step,
        error: error,
        stackTrace: stackTrace,
        needsRestart: true,
      );
    }
  }

  /// Step 2 of [replaceWith]. Journals first, the `.db` last: a copy whose `.db`
  /// exists is complete. A missing live file has nothing to keep.
  Future<void> _copyLiveAside(BackupPaths paths, DateTime now) async {
    final live = paths.databaseFile;
    if (!await _files.exists(live)) return;
    await Directory(paths.preRestoreFolder).create(recursive: true);
    final copy = p.join(
      paths.preRestoreFolder,
      PreRestoreCopy.fileName(await _nextSequence(paths), now),
    );
    final suffixes = [
      for (final suffix in journalSuffixes)
        if (await _files.exists('$live$suffix')) suffix,
      '', // The database itself, last.
    ];
    for (final suffix in suffixes) {
      final partial = '$copy$suffix.partial';
      await _files.copyAndFlush('$live$suffix', partial);
      if (await _files.length(partial) != await _files.length('$live$suffix')) {
        throw FileSystemException('The copy is incomplete', partial);
      }
    }
    for (final suffix in suffixes) {
      await _files.rename('$copy$suffix.partial', '$copy$suffix');
    }
  }

  /// One more than the highest sequence of any file in the folder, complete
  /// or not, so a new copy never takes an old one's name.
  Future<int> _nextSequence(BackupPaths paths) async {
    var highest = 0;
    await for (final entity in Directory(paths.preRestoreFolder).list()) {
      final sequence = PreRestoreCopy.sequenceIn(entity.path);
      if (sequence != null && sequence > highest) highest = sequence;
    }
    return highest + 1;
  }

  Future<void> _prunePreRestoreCopies() async {
    final copies = await preRestoreCopies();
    for (final old in copies.skip(keptPreRestoreCopies)) {
      await _deleteFiles([
        for (final suffix in sidecarSuffixes) '${old.path}$suffix',
        old.path,
      ]);
    }
  }

  Future<void> _deleteFiles(List<String> paths) async {
    for (final path in paths) {
      if (await _files.exists(path)) await _files.delete(path);
    }
  }

  static Future<String> _defaultDatabasePath() async {
    final Directory? folder = await getExternalStorageDirectory();
    if (folder == null) {
      throw StateError('App storage folder is not available on this device');
    }
    return p.join(folder.path, 'databases', fileName);
  }

  static Future<String> _defaultCacheFolder() async =>
      (await getTemporaryDirectory()).path;
}
