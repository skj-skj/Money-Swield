import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/test_database.dart';

/// The `expense_draft` table (phase-4.md §4). `all_migrations_test.dart`
/// already covers up/down/up.
void main() {
  late Database db;

  setUp(() async => db = await openMigratedDatabase());

  Future<void> writeSlot({int? editing, String json = '{}', int at = 1}) =>
      db.insert('expense_draft', {
        'id': 1,
        'editing_expense_id': editing,
        'form_json': json,
        'updated_at': at,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  test('INSERT OR REPLACE with id 1 keeps exactly one row', () async {
    await writeSlot(json: '{"title":"a"}');
    await writeSlot(editing: 7, json: '{"title":"b"}', at: 2);
    await writeSlot(json: '{"title":"c"}', at: 3);

    expect(await db.query('expense_draft'), [
      {
        'id': 1,
        'editing_expense_id': null,
        'form_json': '{"title":"c"}',
        'updated_at': 3,
      },
    ]);
  });

  test('editing_expense_id is not a reference: an id with no expense is '
      'accepted with foreign keys on', () async {
    await writeSlot(editing: 999);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(
      await db.rawQuery('PRAGMA foreign_key_list(expense_draft)'),
      isEmpty,
    );
  });

  test('nothing references expense_draft, so the replace can never cascade '
      '(sqlite.md §5.2)', () async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    for (final row in tables) {
      final name = row['name']! as String;
      final keys = await db.rawQuery("PRAGMA foreign_key_list('$name')");
      expect(
        keys.map((k) => k['table']),
        isNot(contains('expense_draft')),
        reason: name,
      );
    }
  });

  test('form_json and updated_at are required', () async {
    await expectLater(
      db.insert('expense_draft', {'id': 1, 'updated_at': 1}),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.insert('expense_draft', {'id': 1, 'form_json': '{}'}),
      throwsA(isA<DatabaseException>()),
    );
  });
}
