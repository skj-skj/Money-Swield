import 'dart:io';

import 'package:path/path.dart' as p;

/// Copies the database file aside before migrations touch it.
///
/// The copy lives in a `backups` folder next to the database, e.g.
/// `.../databases/backups/expense_tracker.db.2026-09-30T10-15-00Z.bak`.
///
/// Only one backup is kept: the oldest. If a run fails, its backup stays,
/// and it holds the data from before any migration ran. Later runs reuse it
/// instead of adding copies of the partly migrated database.
class DatabaseBackup {
  const DatabaseBackup._();

  /// Journal files SQLite may keep next to the database.
  static const _sidecarSuffixes = ['-wal', '-journal'];

  /// Copies the (closed) database at [databasePath], or returns the backup a
  /// failed earlier run left. Returns null when there is no database yet,
  /// i.e. on first install there is nothing to lose.
  static Future<File?> create(
    String databasePath, {
    required DateTime now,
  }) async {
    final database = File(databasePath);
    if (!await database.exists()) return null;

    final folder = Directory(p.join(p.dirname(databasePath), 'backups'));
    await folder.create(recursive: true);
    final existing = await _backupsOf(databasePath, folder);
    if (existing.isNotEmpty) {
      for (final newer in existing.skip(1)) {
        await delete(newer);
      }
      return existing.first;
    }

    final stamp = now
        .toUtc()
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(':', '-');
    final backupPath = p.join(
      folder.path,
      '${p.basename(databasePath)}.${stamp}Z.bak',
    );
    for (final suffix in _sidecarSuffixes) {
      final sidecar = File('$databasePath$suffix');
      if (await sidecar.exists()) {
        await _copyVerified(sidecar, '$backupPath$suffix');
      }
    }
    // Copied under a temporary name and renamed last, so a backup cut short
    // (e.g. the app was killed) is never mistaken for a complete one.
    final partial = await _copyVerified(database, '$backupPath.partial');
    return partial.rename(backupPath);
  }

  static Future<void> delete(File backup) async {
    for (final file in [
      backup,
      for (final suffix in _sidecarSuffixes) File('${backup.path}$suffix'),
    ]) {
      if (await file.exists()) await file.delete();
    }
  }

  /// Complete backups of [databasePath], oldest first (the time stamp in the
  /// name sorts by age). Deletes partial copies on the way.
  static Future<List<File>> _backupsOf(
    String databasePath,
    Directory folder,
  ) async {
    final prefix = '${p.basename(databasePath)}.';
    final backups = <File>[];
    await for (final entity in folder.list()) {
      if (entity is! File || !p.basename(entity.path).startsWith(prefix)) {
        continue;
      }
      if (entity.path.endsWith('.bak')) backups.add(entity);
      if (entity.path.endsWith('.partial')) {
        await entity.delete(); // Left by a run that was cut short.
      }
    }
    return backups..sort((a, b) => a.path.compareTo(b.path));
  }

  static Future<File> _copyVerified(File source, String destination) async {
    final copy = await source.copy(destination);
    if (await copy.length() != await source.length()) {
      throw FileSystemException('Backup copy is incomplete', destination);
    }
    return copy;
  }
}
