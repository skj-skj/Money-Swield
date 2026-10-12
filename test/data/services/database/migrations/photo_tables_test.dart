import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/test_database.dart';

/// The `photos` and `expense_photos` tables on SQLite
/// 3.22, and the SQL facts the repository relies on.
/// `all_migrations_test.dart` already covers up/down/up.
void main() {
  late Database db;

  setUp(() async => db = await openMigratedDatabase());

  Future<int> insertPhoto(String sha) => db.insert('photos', {
    'relative_path': 'photos/$sha.jpg',
    'sha256': sha,
    'byte_size': 10,
    'created_at': 0,
    'updated_at': 0,
  });

  Future<int> count(String table) async =>
      (await db.rawQuery('SELECT count(*) AS n FROM $table')).single['n']!
          as int;

  final a = 'a' * 64;
  final b = 'b' * 64;

  test('the schema: columns, the unique path, both cascades and the '
      'photo_id index', () async {
    final columns = {
      for (final c in await db.rawQuery('PRAGMA table_info(photos)'))
        c['name']: c['notnull'],
    };
    expect(columns, {
      'id': 0, // INTEGER PRIMARY KEY
      'relative_path': 1,
      'sha256': 1,
      'byte_size': 1,
      'created_at': 1,
      'updated_at': 1,
    });
    final keys = await db.rawQuery('PRAGMA foreign_key_list(expense_photos)');
    expect(
      {for (final k in keys) k['from']: (k['table'], k['on_delete'])},
      {
        'expense_id': ('expenses', 'CASCADE'),
        'photo_id': ('photos', 'CASCADE'),
      },
    );
    final indexes = await db.rawQuery('PRAGMA index_list(expense_photos)');
    final names = [for (final i in indexes) i['name']];
    expect(names, contains('index_expense_photos_on_photo_id'));
    await insertPhoto(a);
    await expectLater(
      db.insert('photos', {
        'relative_path': 'photos/$a.jpg',
        'sha256': a,
        'byte_size': 1,
        'created_at': 0,
        'updated_at': 0,
      }),
      throwsA(isA<DatabaseException>()),
      reason: 'relative_path is unique',
    );
  });

  test('deleting an expense removes its links and keeps the photo row: '
      'the sweep deletes it later', () async {
    final expense = await insertExpenseRow(db);
    final photo = await insertPhoto(a);
    await db.insert('expense_photos', {
      'expense_id': expense,
      'photo_id': photo,
      'sort_order': 0,
    });
    await db.delete('expenses', where: 'id = ?', whereArgs: [expense]);
    expect(await count('expense_photos'), 0);
    expect(await count('photos'), 1);
  });

  test('the same photo twice on one expense breaks the primary key; a link '
      'to a missing photo breaks the foreign key', () async {
    final expense = await insertExpenseRow(db);
    final photo = await insertPhoto(a);
    await db.insert('expense_photos', {
      'expense_id': expense,
      'photo_id': photo,
      'sort_order': 0,
    });
    await expectLater(
      db.insert('expense_photos', {
        'expense_id': expense,
        'photo_id': photo,
        'sort_order': 1,
      }),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.insert('expense_photos', {
        'expense_id': expense,
        'photo_id': 999,
        'sort_order': 1,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('an ignored INSERT OR IGNORE returns 0 in tests, never the existing '
      'id (a phone returns -1): the repository never reads it', () async {
    final first = await insertPhoto(a);
    final ignored = await db.rawInsert(
      'INSERT OR IGNORE INTO photos '
      '(relative_path, sha256, byte_size, created_at, updated_at) '
      'VALUES (?, ?, 1, 0, 0)',
      ['photos/$a.jpg', a],
    );
    expect(ignored, isNot(first));
    expect(ignored, 0);
    expect(await count('photos'), 1);
  });

  test('INSERT … SELECT … WHERE id = ? inserts nothing for a vanished row; '
      'an empty NOT IN () is valid on 3.22', () async {
    final expense = await insertExpenseRow(db);
    await db.rawInsert(
      'INSERT INTO expense_photos (expense_id, photo_id, sort_order) '
      'SELECT ?, id, ? FROM photos WHERE id = ?',
      [expense, 0, 12345],
    );
    expect(await count('expense_photos'), 0);
    await insertPhoto(b);
    final deleted = await db.rawDelete(
      'DELETE FROM photos WHERE id NOT IN (SELECT photo_id FROM '
      'expense_photos) AND id NOT IN ()',
    );
    expect(deleted, 1);
  });

  test("the sweep's orphan delete searches expense_photos by photo_id "
      'through its index, not a full scan per photo', () async {
    final plan = await db.rawQuery(
      'EXPLAIN QUERY PLAN DELETE FROM photos WHERE id NOT IN '
      '(SELECT photo_id FROM expense_photos)',
    );
    final details = plan.map((r) => r['detail']).join(' | ');
    expect(details, contains('index_expense_photos_on_photo_id'));
  });
}
