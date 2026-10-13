import 'package:path/path.dart' as p;

/// Where backup and restore keep their files.
///
/// - `cache/backup/`: the copy and the zip while a backup is made.
/// - `cache/restore/picked.zip`: the document picked in the open dialog.
/// - `databases/restore/candidate.db`: the database about to be swapped in.
///   In the same folder tree as the live database, so the final rename is
///   atomic (a rename across file systems isn't).
/// - `databases/backups/pre-restore-*.db`: copies of the replaced data.
class BackupPaths {
  const BackupPaths({required this.databaseFile, required this.cacheFolder});

  /// The live database, `.../databases/money_swield.db`.
  final String databaseFile;

  /// The app's cache folder. Leftovers there are deleted on start.
  final String cacheFolder;

  String get databaseFolder => p.dirname(databaseFile);

  String get backupWorkFolder => p.join(cacheFolder, 'backup');
  String get backupCopy => p.join(backupWorkFolder, p.basename(databaseFile));

  String get restoreWorkFolder => p.join(cacheFolder, 'restore');
  String get pickedZip => p.join(restoreWorkFolder, 'picked.zip');

  String get candidateFolder => p.join(databaseFolder, 'restore');
  String get candidate => p.join(candidateFolder, 'candidate.db');

  /// Shared with the migration runner's own backups (named
  /// `money_swield.db.*`); pre-restore copies are named so the runner
  /// never picks them up.
  String get preRestoreFolder => p.join(databaseFolder, 'backups');
}
