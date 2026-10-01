import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/schema_reader.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/table_definition.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

void main() {
  late Database db;
  late Migrator m;

  Future<TableDefinition> read(String table) => SchemaReader(db).readTable(table);

  Future<void> createCategoriesAndExpenses() async {
    await m.createTable('categories', (t) {
      t.text('name', nullable: false, unique: true);
    });
    await m.createTable('expenses', (t) {
      t.text('title', nullable: false);
      t.real('amount', nullable: false, defaultValue: 0);
      t.text('note');
      t.references('category_id', toTable: 'categories', onDelete: ForeignKeyAction.cascade);
    });
    await m.insert('categories', {'name': 'Food'});
    await m.insert('expenses', {'title': 'Lunch', 'amount': 12.5, 'note': 'office', 'category_id': 1});
    await m.insert('expenses', {'title': 'Tea', 'amount': 2, 'category_id': 1});
  }

  setUp(() async {
    db = await openMemoryDatabase();
    m = migratorFor(db);
  });

  tearDown(() => db.close());

  group('createTable', () {
    test('creates columns, constraints, foreign keys and indexes', () async {
      await createCategoriesAndExpenses();

      final expenses = await read('expenses');
      expect(expenses.columns.map((c) => c.name), ['id', 'title', 'amount', 'note', 'category_id']);
      expect(expenses.primaryKey, ['id']);
      expect(expenses.autoIncrement, isTrue);
      expect(expenses.column('title').nullable, isFalse);
      expect(expenses.column('amount').defaultSql, '0');
      expect(expenses.column('note').nullable, isTrue);
      expect(expenses.foreignKeys.single.parentTable, 'categories');
      expect(expenses.foreignKeys.single.onDelete, ForeignKeyAction.cascade);
      expect(expenses.indexes.single.name, 'index_expenses_on_category_id');
      expect((await read('categories')).isKey(['name']), isTrue);
    });

    test('supports a composite primary key when id is false', () async {
      await m.createTable('monthly_spend', id: false, (t) {
        t.integer('year', nullable: false);
        t.integer('month', nullable: false);
        t.real('total', nullable: false);
        t.primaryKey(['year', 'month']);
      });
      final table = await read('monthly_spend');
      expect(table.primaryKey, ['year', 'month']);
      expect(table.autoIncrement, isFalse);
    });

    test('rejects an existing table, in any letter case, and bad names', () async {
      await m.createTable('a', (t) => t.text('x'));
      await expectLater(m.createTable('a', (t) => t.text('x')), throwsArgumentError);
      await expectLater(m.createTable('A', (t) => t.text('x')), throwsArgumentError);
      await expectLater(m.createTable('bad name', (t) => t.text('x')), throwsArgumentError);
      await expectLater(m.createTable('b', (t) => t.text('x; DROP TABLE a')), throwsArgumentError);
    });
  });

  group('changing columns keeps data', () {
    setUp(createCategoriesAndExpenses);

    test('addColumn with a default fills existing rows', () async {
      await m.addColumn('expenses', 'currency', SqliteType.text, nullable: false, defaultValue: 'INR');
      final rows = await m.select('expenses', columns: ['title', 'currency']);
      expect(rows, [
        {'title': 'Lunch', 'currency': 'INR'},
        {'title': 'Tea', 'currency': 'INR'},
      ]);
    });

    test('addColumn NOT NULL without default on existing rows explains the fix', () async {
      await expectLater(
        m.addColumn('expenses', 'currency', SqliteType.text, nullable: false),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('backfill'))),
      );
      expect(await m.columnExists('expenses', 'currency'), isFalse);
    });

    test('removeColumn drops the column and its indexes', () async {
      await m.addIndex('expenses', ['note']);
      await m.removeColumn('expenses', 'note');
      final table = await read('expenses');
      expect(table.hasColumn('note'), isFalse);
      expect(table.indexes.map((i) => i.name), ['index_expenses_on_category_id']);
      expect(await m.count('expenses'), 2);
    });

    test('renameColumn keeps values, indexes and foreign keys', () async {
      await m.renameColumn('expenses', 'category_id', 'group_id');
      final table = await read('expenses');
      expect(table.foreignKeys.single.columns, ['group_id']);
      expect(table.indexes.single.columns, ['group_id']);
      expect((await m.select('expenses', where: {'group_id': 1})).length, 2);
    });

    test('renameColumn renames default-named indexes, keeps custom names', () async {
      await m.addIndex('expenses', ['note']);
      await m.addIndex('expenses', ['title'], name: 'by_title');
      await m.renameColumn('expenses', 'note', 'description');
      await m.renameColumn('expenses', 'title', 'name');
      expect((await read('expenses')).indexes.map((i) => i.name), [
        'index_expenses_on_category_id',
        'index_expenses_on_description',
        'by_title',
      ]);
    });

    test('refuses to rename a column another table references', () async {
      await expectLater(m.renameColumn('categories', 'id', 'category_id'), throwsArgumentError);
    });

    test('changeColumn changes type and nullability', () async {
      await m.changeColumn('expenses', 'amount', SqliteType.text, nullable: false);
      final table = await read('expenses');
      expect(table.column('amount').type, SqliteType.text);
      expect(table.column('amount').defaultSql, isNull);
      expect((await m.select('expenses', columns: ['amount'])).first['amount'], '12.5');
    });

    test('changeColumn to NOT NULL fails clearly while NULLs exist', () async {
      await expectLater(
        m.changeColumn('expenses', 'note', SqliteType.text, nullable: false),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('1 existing row'))),
      );
    });

    test('changeColumn to NOT NULL with a default fills existing NULLs', () async {
      await m.changeColumn('expenses', 'note', SqliteType.text, nullable: false, defaultValue: '');
      expect(await m.select('expenses', columns: ['note']), [
        {'note': 'office'},
        {'note': ''},
      ]);
    });

    test('changeTable applies several changes in one rebuild', () async {
      await m.changeTable('expenses', (t) {
        t.renameColumn('note', 'description');
        t.integer('paid', nullable: false, defaultValue: true);
        t.index(['title', 'amount'], unique: true);
      });
      final table = await read('expenses');
      expect(table.columns.map((c) => c.name), ['id', 'title', 'amount', 'description', 'category_id', 'paid']);
      expect(table.indexes.map((i) => i.name), contains('index_expenses_on_title_and_amount'));
      expect((await m.select('expenses', where: {'title': 'Lunch'})).single['description'], 'office');
    });
  });

  group('in-place changes and rebuilds', () {
    setUp(createCategoriesAndExpenses);

    test('plain columns, references and indexes are changed in place', () async {
      // A hand-made CHECK would be lost by a rebuild, so only in-place
      // changes can succeed on this table.
      await db.execute(
        "CREATE TABLE legacy (id INTEGER PRIMARY KEY, kind TEXT DEFAULT 'check' CHECK (kind != ''))",
      );
      await m.addColumn('legacy', 'note', SqliteType.text);
      await m.addColumn('legacy', 'count', SqliteType.integer, nullable: false, defaultValue: 0);
      await m.addReference('legacy', 'category_id', toTable: 'categories');
      await m.removeIndex('legacy', columns: ['category_id']);
      expect((await read('legacy')).columns.map((c) => c.name), ['id', 'kind', 'note', 'count', 'category_id']);

      await expectLater(m.removeColumn('legacy', 'note'), throwsA(isA<UnsupportedError>()));
      await expectLater(m.addColumn('legacy', 'code', SqliteType.text, unique: true), throwsA(isA<UnsupportedError>()));
    });

    test('a table used by a view is not rebuilt', () async {
      await db.execute('CREATE VIEW lunches AS SELECT * FROM expenses');
      await expectLater(
        m.removeColumn('expenses', 'note'),
        throwsA(isA<UnsupportedError>().having((e) => e.message, 'message', contains('view "lunches"'))),
      );
      await m.addColumn('expenses', 'currency', SqliteType.text); // In place still works.
    });

    test('a rebuilt table has the same schema as the original, foreign keys in order', () async {
      await m.createTable('accounts', (t) => t.text('name'));
      await m.addReference('expenses', 'account_id', toTable: 'accounts');
      final before = (await read('expenses')).createTableSql();

      for (var i = 0; i < 2; i++) {
        await m.addColumn('expenses', 'tmp', SqliteType.text); // In place.
        await m.removeColumn('expenses', 'tmp'); // Rebuilds.
        expect((await read('expenses')).createTableSql(), before);
      }
    });

    test('rebuild does not reuse ids of deleted rows', () async {
      await m.delete('expenses', where: {'title': 'Tea'}); // Highest id is now 1, but 2 was used.
      await m.removeColumn('expenses', 'note'); // Rebuilds.
      final id = await m.insert('expenses', {'title': 'Bus', 'amount': 1});
      expect(id, 3);
    });

    test('rebuilding the parent keeps foreign keys valid', () async {
      await m.addColumn('categories', 'color', SqliteType.text, unique: true); // Unique needs a rebuild.
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });
  });

  group('references', () {
    setUp(createCategoriesAndExpenses);

    test('addReference and removeReference', () async {
      await m.createTable('accounts', (t) => t.text('name'));
      await m.addReference('expenses', 'account_id', toTable: 'accounts', onDelete: ForeignKeyAction.setNull);
      var table = await read('expenses');
      expect(table.foreignKeys.map((f) => f.parentTable), containsAll(['categories', 'accounts']));
      expect(table.indexes.map((i) => i.name), contains('index_expenses_on_account_id'));

      await m.removeReference('expenses', 'account_id');
      table = await read('expenses');
      expect(table.hasColumn('account_id'), isFalse);
      expect(table.foreignKeys.map((f) => f.parentTable), ['categories']);
    });

    test('must point at an existing table', () async {
      await expectLater(
        m.createTable('a', (t) => t.references('x_id', toTable: 'missing')),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('does not exist'))),
      );
    });

    test('must point at a primary key or unique column, which must stay unique', () async {
      await expectLater(
        m.addReference('expenses', 'title_ref', toTable: 'expenses', toColumn: 'title'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('not its primary key'))),
      );
      await m.createTable('b', (t) => t.references('category_name', toTable: 'categories', toColumn: 'name'));
      await expectLater(
        m.changeColumn('categories', 'name', SqliteType.text, nullable: false), // Drops UNIQUE.
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('must stay'))),
      );
    });

    test('dropTable refuses while other tables reference it', () async {
      await expectLater(m.dropTable('categories'), throwsArgumentError);
      await m.dropTable('expenses');
      await m.dropTable('categories');
      expect(await m.tableExists('categories'), isFalse);
    });
  });

  group('indexes', () {
    setUp(createCategoriesAndExpenses);

    test('addIndex and removeIndex by columns or name', () async {
      await m.addIndex('expenses', ['title'], unique: true);
      expect((await read('expenses')).indexes.last.unique, isTrue);
      await m.removeIndex('expenses', columns: ['title']);
      await m.removeIndex('expenses', name: 'index_expenses_on_category_id');
      expect((await read('expenses')).indexes, isEmpty);
    });

    test('names must be unique across tables', () async {
      await m.addIndex('categories', ['name'], name: 'by_name');
      await expectLater(
        m.addIndex('expenses', ['title'], name: 'by_name'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('index "by_name" on "categories"'))),
      );
    });
  });

  group('data helpers', () {
    setUp(createCategoriesAndExpenses);

    test('where matches NULL with IS NULL', () async {
      expect(await m.count('expenses', where: {'note': null}), 1);
      expect(await m.update('expenses', {'note': 'none'}, where: {'note': null}), 1);
      expect(await m.count('expenses', where: {'note': null}), 0);
    });

    test('bool values are stored as 1 / 0', () async {
      await m.addColumn('expenses', 'paid', SqliteType.integer);
      await m.update('expenses', {'paid': true}, where: {'title': 'Lunch'});
      expect(await m.count('expenses', where: {'paid': true}), 1);
      expect((await m.select('expenses', where: {'title': 'Lunch'})).single['paid'], 1);
    });
  });

  group('asking the user', () {
    test('askChoice checks that the initial value is an option', () async {
      expect(() => m.askChoice('Currency?', ['INR', 'USD'], initialValue: 'EUR'), throwsArgumentError);
      expect(await m.askChoice('Currency?', ['INR', 'USD'], initialValue: 'USD'), 'USD');
    });
  });
}
