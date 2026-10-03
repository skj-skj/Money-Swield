import 'package:sqflite/sqflite.dart';

/// Checks shared by the migration runner, the backup copy and restore
/// validation, so the three can't drift apart.

/// Throws unless SQLite's `PRAGMA integrity_check` says `ok`.
Future<void> checkIntegrity(DatabaseExecutor db) async {
  final rows = await db.rawQuery('PRAGMA integrity_check');
  final result = rows.map((r) => r.values.first).join('; ');
  if (result != 'ok') throw StateError('Integrity check failed: $result');
}

/// Throws if any row points to a missing row. [schema] picks an attached
/// database (e.g. `backup`) instead of the main one.
Future<void> checkForeignKeys(DatabaseExecutor db, {String? schema}) async {
  final prefix = schema == null ? '' : '$schema.';
  final violations = await db.rawQuery('PRAGMA ${prefix}foreign_key_check');
  if (violations.isEmpty) return;
  final details = violations
      .take(5)
      .map(
        (v) =>
            '${v['table']} row ${v['rowid']} points to a missing row in ${v['parent']}',
      )
      .join('; ');
  throw StateError(
    'Foreign key check failed (${violations.length} violation(s)): $details',
  );
}

/// Thrown when a database has migrations this app doesn't know, i.e. a
/// newer version of the app changed it. An [Exception], not an error:
/// restore validation catches it to say "made by a newer version".
class UnknownMigrationsException implements Exception {
  UnknownMigrationsException(this.versions);

  final Set<int> versions;

  String get message =>
      'This database was updated by a newer version of the app (unknown migrations: '
      '${(versions.toList()..sort()).join(', ')}). Install the latest version of the app.';

  @override
  String toString() => message;
}

/// Throws [UnknownMigrationsException] if [applied] holds a version not in
/// [known].
void checkKnownVersions(Set<int> applied, Set<int> known) {
  final unknown = applied.difference(known);
  if (unknown.isNotEmpty) throw UnknownMigrationsException(unknown);
}
