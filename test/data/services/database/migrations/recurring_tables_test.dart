import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/test_database.dart';

/// The recurring tables and the two columns on `expenses` (phase-7a.md
/// §4.1, database.md §3.8), as declared: columns, defaults, foreign-key
/// actions and unique indexes. That SQLite enforces them is SQLite's to
/// test; what the app relies on is tested where it relies on it (the
/// generator's duplicate guard, Delete for good, the owner moves).
/// `all_migrations_test.dart` covers up/down/up.
void main() {
  late Database db;

  setUp(() async => db = await openMigratedDatabase());

  Future<int> insertItem() =>
      db.insert('recurring_expenses', {
        'title': 'Netflix',
        'currency_code': 'INR',
        'category_id': 1,
        'payment_method_id': 1,
        'frequency': 'monthly',
        'start_on': '2026-01-31',
        'time_of_day_minutes': 600,
        'next_due_on': '2026-02-28',
        'created_at': 0,
        'updated_at': 0,
      });

  Future<List<Map<String, Object?>>> columns(String table) =>
      db.rawQuery('PRAGMA table_info($table)');

  Future<List<Map<String, Object?>>> foreignKeys(String table) =>
      db.rawQuery('PRAGMA foreign_key_list($table)');

  test('recurring_expenses has the columns of §4.1, NOT NULL where the '
      'spec says, and interval_count defaults to 1', () async {
    final byName = {
      for (final c in await columns('recurring_expenses')) c['name']: c,
    };
    expect(byName.keys, [
      'id',
      'title',
      'description',
      'currency_code',
      'category_id',
      'payment_method_id',
      'frequency',
      'interval_count',
      'start_on',
      'end_on',
      'time_of_day_minutes',
      'next_due_on',
      'archived_at',
      'created_at',
      'updated_at',
    ]);
    const notNull = {
      'title',
      'currency_code',
      'category_id',
      'payment_method_id',
      'frequency',
      'interval_count',
      'start_on',
      'time_of_day_minutes',
      'created_at',
      'updated_at',
    };
    for (final MapEntry(key: name, value: column) in byName.entries) {
      if (name == 'id') continue;
      expect(
        column['notnull'],
        notNull.contains(name) ? 1 : 0,
        reason: '$name',
      );
    }
    // A plain `1`, never `TRUE` (sqlite.md §5.1), and read back as 1.
    expect(byName['interval_count']!['dflt_value'], '1');
    final id = await insertItem();
    final row = (await db.query(
      'recurring_expenses',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    expect(row['interval_count'], 1);
  });

  test('expenses has recurring_expense_id and recurring_due_on, both '
      'nullable', () async {
    final byName = {for (final c in await columns('expenses')) c['name']: c};
    expect(byName['recurring_expense_id']!['notnull'], 0);
    expect(byName['recurring_due_on']!['notnull'], 0);
    expect(byName['recurring_due_on']!['type'], 'TEXT');
  });

  test('the foreign keys: RESTRICT to categories and payment methods, '
      'CASCADE from prices and events, SET NULL from expenses', () async {
    String action(List<Map<String, Object?>> fks, String column) =>
        fks.singleWhere((fk) => fk['from'] == column)['on_delete']! as String;
    final item = await foreignKeys('recurring_expenses');
    expect(action(item, 'category_id'), 'RESTRICT');
    expect(action(item, 'payment_method_id'), 'RESTRICT');
    expect(
      action(await foreignKeys('recurring_amounts'), 'recurring_expense_id'),
      'CASCADE',
    );
    final events = await foreignKeys('recurring_expense_events');
    expect(action(events, 'recurring_expense_id'), 'CASCADE');
    expect(action(events, 'event_id'), 'CASCADE');
    expect(
      action(await foreignKeys('expenses'), 'recurring_expense_id'),
      'SET NULL',
    );
  });

  test('the unique indexes: one price per item and date, one payment per '
      'item and due date', () async {
    Future<List<String>> uniqueIndexColumns(String table) async => [
      for (final index in await db.rawQuery('PRAGMA index_list($table)'))
        if (index['unique'] == 1 && index['origin'] == 'c')
          [
            for (final c in await db.rawQuery(
              'PRAGMA index_info(${index['name']})',
            ))
              c['name'],
          ].join(','),
    ];
    expect(await uniqueIndexColumns('recurring_amounts'), [
      'recurring_expense_id,effective_from',
    ]);
    expect(await uniqueIndexColumns('expenses'), [
      'recurring_expense_id,recurring_due_on',
    ]);
  });
}
