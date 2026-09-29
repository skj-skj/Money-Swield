import 'dart:io';

import 'package:path/path.dart' as p;

/// Copies the database file aside before migrations touch it.
///
/// The copy lives in a `backups` folder next to the database, e.g.
/// `.../databases/backups/expense_tracker.db.2026-09-30T10-15-00Z.bak`.
class DatabaseBackup {
  const DatabaseBackup._();

  /// Journal files SQLite may keep next to the database.
  static const _sidecarSuffixes = ['-wal', '-journal'];

  /// Copies the (closed) database at [databasePath]. Returns null when there
  /// is no database yet, i.e. on first install there is nothing to lose.
  static Future<File?> create(String databasePath, {required DateTime now}) async {
    final database = File(databasePath);
    if (!await database.exists()) return null;

    final folder = Directory(p.join(p.dirname(databasePath), 'backups'));
    await folder.create(recursive: true);
    final stamp = now.toUtc().toIso8601String().split('.').first.replaceAll(':', '-');
    final backupPath = p.join(folder.path, '${p.basename(databasePath)}.${stamp}Z.bak');

    final backup = await _copyVerified(database, backupPath);
    for (final suffix in _sidecarSuffixes) {
      final sidecar = File('$databasePath$suffix');
      if (await sidecar.exists()) await _copyVerified(sidecar, '$backupPath$suffix');
    }
    return backup;
  }

  static Future<void> delete(File backup) async {
    for (final file in [backup, for (final suffix in _sidecarSuffixes) File('${backup.path}$suffix')]) {
      if (await file.exists()) await file.delete();
    }
  }

  static Future<File> _copyVerified(File source, String destination) async {
    final copy = await source.copy(destination);
    if (await copy.length() != await source.length()) {
      throw FileSystemException('Backup copy is incomplete', destination);
    }
    return copy;
  }
}
