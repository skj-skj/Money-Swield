import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/test_database.dart';

/// The foreign keys of the Phase 2 tables (phase-2.md §3, database.md §1).
/// `all_migrations_test.dart` already covers up/down/up.
void main() {
  late Database db;

  setUp(() async => db = await openMigratedDatabase());

  Future<int> insertExpense({int categoryId = 1, int paymentMethodId = 1}) =>
      db.insert('expenses', {
        'title': 'Lunch',
        'amount_minor': 11050,
        'currency_code': 'INR',
        'occurred_at': 0,
        'utc_offset_minutes': 330,
        'occurred_on': '1970-01-01',
        'category_id': categoryId,
        'payment_method_id': paymentMethodId,
        'created_at': 0,
        'updated_at': 0,
      });

  Future<int> count(String table) async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']!
          as int;

  test('a category in use can not be deleted directly (RESTRICT)', () async {
    await insertExpense(categoryId: 1);
    await expectLater(
      db.delete('categories', where: 'id = 1'),
      throwsA(isA<DatabaseException>()),
    );
    expect(await count('expenses'), 1);
  });

  test(
    'a payment method in use can not be deleted directly (RESTRICT)',
    () async {
      await insertExpense(paymentMethodId: 2);
      await expectLater(
        db.delete('payment_methods', where: 'id = 2'),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test('an expense must point at an existing category', () async {
    await expectLater(
      insertExpense(categoryId: 9999),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('deleting an expense removes its event links', () async {
    final id = await insertExpense();
    await db.insert('expense_events', {'expense_id': id, 'event_id': 1});
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    expect(await count('expense_events'), 0);
    expect(await count('events'), 7, reason: 'the event itself stays');
  });

  test('deleting an event unlinks it and keeps the expense', () async {
    final id = await insertExpense();
    await db.insert('expense_events', {'expense_id': id, 'event_id': 1});
    await db.insert('expense_events', {'expense_id': id, 'event_id': 2});
    await db.delete('events', where: 'id = 1');
    expect(await count('expenses'), 1);
    expect(await db.query('expense_events'), [
      {'expense_id': id, 'event_id': 2},
    ]);
  });

  test('an expense can not have the same event twice', () async {
    final id = await insertExpense();
    await db.insert('expense_events', {'expense_id': id, 'event_id': 1});
    await expectLater(
      db.insert('expense_events', {'expense_id': id, 'event_id': 1}),
      throwsA(isA<DatabaseException>()),
    );
  });
}
