import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/test_database.dart';

/// The first migrations create the tables and seed the built-in rows.
/// `all_migrations_test.dart` already covers up/down/up.
void main() {
  late Database db;

  setUp(() async => db = await openMigratedDatabase());

  Future<List<(String?, String?, String)>> seeds(String table) async {
    final rows = await db.query(table, orderBy: 'id');
    return [
      for (final row in rows)
        (
          row['builtin_key'] as String?,
          row['name'] as String?,
          row['emoji']! as String,
        ),
    ];
  }

  group('categories', () {
    test(
      'are seeded in order, with a NULL name and the expected emoji',
      () async {
        expect(await seeds('categories'), [
          ('food', null, '🍽️'),
          ('drinks', null, '🥤'),
          ('groceries', null, '🛒'),
          ('shopping', null, '🛍️'),
          ('clothes', null, '👕'),
          ('transport', null, '🚌'),
          ('fuel', null, '⛽'),
          ('rent', null, '🏠'),
          ('house', null, '🏡'),
          ('bills', null, '🧾'),
          ('health', null, '💊'),
          ('education', null, '📚'),
          ('entertainment', null, '🎬'),
          ('travel', null, '✈️'),
          ('gifts', null, '🎁'),
          ('personal_care', null, '💇'),
          ('subscription', null, '🔁'),
          ('loan', null, '🏦'),
          ('investment', null, '📈'),
          ('other', null, '📦'),
        ]);
      },
    );

    test('have no description and equal created/updated timestamps', () async {
      final rows = await db.query('categories');
      for (final row in rows) {
        expect(row['description'], isNull, reason: '${row['builtin_key']}');
        expect(row['created_at'], isA<int>());
        expect(
          row['created_at'],
          row['updated_at'],
          reason: '${row['builtin_key']}',
        );
      }
    });
  });

  test(
    'payment methods are seeded in order: cash, upi, debit card, credit card',
    () async {
      expect(await seeds('payment_methods'), [
        ('cash', null, '💵'),
        ('upi', null, '📱'),
        ('debit_card', null, '🏧'),
        ('credit_card', null, '💳'),
      ]);
    },
  );

  test('events are seeded in order and not archived', () async {
    expect(await seeds('events'), [
      ('birthday', null, '🎂'),
      ('anniversary', null, '💍'),
      ('party', null, '🎉'),
      ('festival', null, '🪔'),
      ('trip', null, '🧳'),
      ('wedding', null, '💒'),
      // Not 🍽️: that is the food category's.
      ('dining_out', null, '🍴'),
    ]);
    final archived = await db.query('events', where: 'archived_at IS NOT NULL');
    expect(archived, isEmpty);
  });

  test('settings start empty: every key falls back to its default', () async {
    expect(await db.query('settings'), isEmpty);
  });

  group('constraints', () {
    for (final table in ['categories', 'payment_methods', 'events']) {
      test('$table.builtin_key is unique', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final first = (await db.query(table, limit: 1)).single['builtin_key'];
        expect(
          () => db.insert(table, {
            'builtin_key': first,
            'emoji': '🧪',
            'created_at': now,
            'updated_at': now,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });

      test('$table allows many user rows without a builtin_key', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.insert(table, {
          'name': 'A',
          'emoji': '🧪',
          'created_at': now,
          'updated_at': now,
        });
        await db.insert(table, {
          'name': 'B',
          'emoji': '🧪',
          'created_at': now,
          'updated_at': now,
        });
        expect(
          await db.query(table, where: 'builtin_key IS NULL'),
          hasLength(2),
        );
      });

      test('$table.emoji is required', () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        expect(
          () => db.insert(table, {
            'name': 'No emoji',
            'created_at': now,
            'updated_at': now,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });
    }

    test('settings.key is the primary key', () async {
      await db.insert('settings', {'key': 'theme', 'value': 'dark'});
      expect(
        () => db.insert('settings', {'key': 'theme', 'value': 'light'}),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
