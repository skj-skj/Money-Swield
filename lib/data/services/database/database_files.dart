import 'dart:io';

/// Files SQLite may keep next to a database. `-shm` holds nothing that
/// isn't in the `-wal` and is rebuilt, so copies leave it out.
const journalSuffixes = ['-wal', '-journal'];
const sidecarSuffixes = ['-wal', '-shm', '-journal'];

/// Throws unless every journal next to the database at [path] is missing or
/// empty. Used before a step that moves or zips the `.db` alone, where
/// anything still in a journal would be lost. Checks the size, not the
/// file: Android's TRUNCATE mode keeps a 0-byte `-journal` (phase-3.md
/// §12a). [what] names the database in the error.
Future<void> checkJournalsEmpty(String path, {required String what}) async {
  for (final suffix in journalSuffixes) {
    final journal = File('$path$suffix');
    if (await journal.exists() && await journal.length() > 0) {
      throw StateError('$what left a non-empty $suffix file');
    }
  }
}

/// `2026-10-03T08:35:12`: [at] in UTC, whole seconds, without the `Z`.
String utcSeconds(DateTime at) => at.toUtc().toIso8601String().split('.').first;

/// `2026-10-03T08-35-12Z`: [at] for a file name (no `:`, which Windows and
/// some file providers refuse).
String fileStamp(DateTime at) => '${utcSeconds(at).replaceAll(':', '-')}Z';
