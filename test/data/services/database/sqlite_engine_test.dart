import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/test_database.dart';

/// Tests must run on the SQLite of the oldest supported phone (Android 10,
/// 3.22.0), built from Android's source (`pubspec.yaml` `hooks:`). Without this, a `sqlite3` package upgrade that
/// changes its hook options would silently put every test back on a newer
/// SQLite, where SQL a phone rejects passes.
void main() {
  test('tests run on Android 10 SQLite 3.22.0', () async {
    final db = await openEmptyDatabase();
    final row = (await db.rawQuery(
      'SELECT sqlite_version() AS version, sqlite_source_id() AS source',
    )).single;
    expect(row['version'], '3.22.0');
    // Android's copy: 3.22.0 with fixes backported in December 2018.
    expect(row['source'], startsWith('2018-12-19 01:30:22 c255889b'));
  });

  test('SQL newer than 3.22 fails, as on an Android 10 phone', () async {
    final db = await openEmptyDatabase();
    await db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v INTEGER)');
    for (final sql in [
      'SELECT TRUE', // 3.23
      'INSERT INTO t VALUES (1, 1) ON CONFLICT (id) DO UPDATE SET v = 2', // 3.24
      'SELECT row_number() OVER () FROM t', // 3.25
      'ALTER TABLE t RENAME COLUMN v TO w', // 3.25
      'SELECT v FROM t ORDER BY v NULLS LAST', // 3.30
      'SELECT count(*) FILTER (WHERE v > 0) FROM t', // 3.30
      'SELECT iif(1, 2, 3)', // 3.32
      'INSERT INTO t (v) VALUES (1) RETURNING id', // 3.35
      'ALTER TABLE t DROP COLUMN v', // 3.35
      "SELECT json('{}')", // not built into Android 10's SQLite
    ]) {
      await expectLater(
        db.execute(sql),
        throwsA(isA<DatabaseException>()),
        reason: sql,
      );
    }
  });
}
