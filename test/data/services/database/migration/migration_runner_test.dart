import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration_runner.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers.dart';

final createExpenses = TestMigration(
  1000,
  'create_expenses',
  (m) => m.createTable('expenses', (t) {
    t.text('title', nullable: false);
    t.real('amount', nullable: false);
    t.integer('spent_at', nullable: false); // Epoch milliseconds.
  }),
  (m) => m.dropTable('expenses'),
);

/// Backfill from device locale and user input: add the column as nullable,
/// fill it, then make it NOT NULL.
final addCurrencyToExpenses = TestMigration(
  2000,
  'add_currency_to_expenses',
  (m) async {
    await m.addColumn('expenses', 'currency', SqliteType.text);

    final suggested = m.locale.countryCode == 'IN' ? 'INR' : 'USD';
    final currency = await m.askChoice('Which currency are your existing expenses in?', [suggested, 'EUR']);
    await m.update('expenses', {'currency': currency});

    await m.changeColumn('expenses', 'currency', SqliteType.text, nullable: false);
  },
  (m) => m.removeColumn('expenses', 'currency'),
);

/// Backfill a new table computed from an existing one.
final createMonthlySpend = TestMigration(
  3000,
  'create_monthly_spend',
  (m) async {
    await m.createTable('monthly_spend', (t) {
      t.text('month', nullable: false, unique: true); // e.g. "2026-09"
      t.real('total', nullable: false);
    });

    final totals = <String, double>{};
    for (final expense in await m.select('expenses', columns: ['amount', 'spent_at'])) {
      final date = DateTime.fromMillisecondsSinceEpoch(expense['spent_at']! as int, isUtc: true);
      final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      totals[month] = (totals[month] ?? 0) + (expense['amount']! as num).toDouble();
    }
    for (final MapEntry(key: month, value: total) in totals.entries) {
      await m.insert('monthly_spend', {'month': month, 'total': total});
    }
  },
  (m) => m.dropTable('monthly_spend'),
);

void main() {
  late Directory folder;
  late String databasePath;
  final factory = testDatabaseFactory();

  MigrationRunner runner(List<Migration> migrations, {FakePrompter? prompter}) => MigrationRunner(
    databaseFactory: factory,
    databasePath: databasePath,
    migrations: migrations,
    locale: const Locale('en', 'IN'),
    prompter: prompter ?? FakePrompter(),
  );

  Future<T> withDatabase<T>(Future<T> Function(Database db) action) async {
    final db = await factory.openDatabase(databasePath, options: OpenDatabaseOptions(singleInstance: false));
    try {
      return await action(db);
    } finally {
      await db.close();
    }
  }

  List<String> backups() {
    final backupFolder = Directory(p.join(folder.path, 'backups'));
    if (!backupFolder.existsSync()) return [];
    return backupFolder.listSync().map((f) => p.basename(f.path)).toList();
  }

  Future<void> insertExpense(String title, double amount, DateTime spentAt) => withDatabase(
    (db) => db.insert('expenses', {'title': title, 'amount': amount, 'spent_at': spentAt.millisecondsSinceEpoch}),
  );

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('migration_runner_test');
    databasePath = p.join(folder.path, 'app.db');
  });

  tearDown(() => folder.delete(recursive: true));

  test('runs pending migrations in version order and records them', () async {
    final progress = <MigrationProgress>[];
    await runner([createMonthlySpend, createExpenses]).migrate(onProgress: progress.add);

    final history = await withDatabase((db) => db.query('schema_migrations', orderBy: 'version'));
    expect(history.map((r) => r['name']), ['create_expenses', 'create_monthly_spend']);
    expect(
      progress.where((e) => e.stage == MigrationStage.migrating).map((e) => '${e.completed}/${e.total}'),
      ['0/2', '1/2'],
    );
    expect(progress.last.stage, MigrationStage.done);
    expect(await runner([createExpenses, createMonthlySpend]).pendingMigrations(), isEmpty);
  });

  test('backfills from locale and user input, then computes a new table', () async {
    await runner([createExpenses]).migrate();
    await insertExpense('Lunch', 10, DateTime.utc(2026, 8, 3));
    await insertExpense('Dinner', 15, DateTime.utc(2026, 8, 20));
    await insertExpense('Rent', 500, DateTime.utc(2026, 9, 1));

    final prompter = FakePrompter(['INR']);
    await runner([createExpenses, addCurrencyToExpenses, createMonthlySpend], prompter: prompter).migrate();

    expect(prompter.questions, ['Which currency are your existing expenses in?']);
    await withDatabase((db) async {
      final currencies = await db.query('expenses', columns: ['currency'], distinct: true);
      expect(currencies, [
        {'currency': 'INR'},
      ]);
      final monthly = await db.query('monthly_spend', columns: ['month', 'total'], orderBy: 'month');
      expect(monthly, [
        {'month': '2026-08', 'total': 25.0},
        {'month': '2026-09', 'total': 500.0},
      ]);
    });
  });

  test('backs up before migrating and deletes the backup after success', () async {
    await runner([createExpenses]).migrate();
    expect(backups(), isEmpty, reason: 'first install has nothing to back up');

    await runner([createExpenses, createMonthlySpend]).migrate();
    expect(backups(), isEmpty);
  });

  test('a failing migration is rolled back, earlier ones are kept, and the backup stays', () async {
    await runner([createExpenses]).migrate();
    await insertExpense('Lunch', 10, DateTime.utc(2026, 8, 3));

    final broken = TestMigration(2500, 'broken', (m) async {
      await m.addColumn('expenses', 'half_done', SqliteType.integer);
      throw StateError('boom');
    });

    await expectLater(
      runner([createExpenses, addCurrencyToExpenses, broken, createMonthlySpend], prompter: FakePrompter(['INR'])).migrate(),
      throwsA(
        isA<MigrationFailure>()
            .having((f) => f.migration?.name, 'migration', 'broken')
            .having((f) => f.report, 'report', contains('boom'))
            .having((f) => f.backupPath, 'backupPath', isNotNull),
      ),
    );

    await withDatabase((db) async {
      final versions = (await db.query('schema_migrations')).map((r) => r['version']);
      expect(versions, [1000, 2000]);
      final columns = (await db.rawQuery('PRAGMA table_info(expenses)')).map((r) => r['name']);
      expect(columns, isNot(contains('half_done')));
      expect(await db.query('expenses'), hasLength(1));
    });
    expect(backups(), hasLength(1));
  });

  test('a migration that leaves broken foreign keys is rejected', () async {
    final orphan = TestMigration(2000, 'orphan', (m) async {
      await m.createTable('categories', (t) => t.text('name'));
      await m.addReference('expenses', 'category_id', toTable: 'categories');
      await m.insert('expenses', {'title': 'x', 'amount': 1, 'spent_at': 0, 'category_id': 99});
    });
    await runner([createExpenses]).migrate();

    await expectLater(
      runner([createExpenses, orphan]).migrate(),
      throwsA(isA<MigrationFailure>().having((f) => '${f.error}', 'error', contains('Foreign key check failed'))),
    );
    expect(await runner([createExpenses, orphan]).pendingMigrations(), hasLength(1));
  });

  test('refuses a database written by a newer app version', () async {
    await runner([createExpenses, createMonthlySpend]).migrate();

    await expectLater(
      runner([createExpenses]).migrate(),
      throwsA(isA<MigrationFailure>().having((f) => '${f.error}', 'error', contains('newer version'))),
    );
  });

  test('rollback runs down in reverse order', () async {
    await runner([createExpenses, addCurrencyToExpenses], prompter: FakePrompter(['INR'])).migrate();
    final all = runner([createExpenses, addCurrencyToExpenses]);

    await all.rollback();
    expect((await all.pendingMigrations()).map((m) => m.name), ['add_currency_to_expenses']);
    await all.rollback();
    expect(await withDatabase((db) => db.query('sqlite_master', where: "name = 'expenses'")), isEmpty);
  });

  test('rejects duplicate versions', () {
    expect(() => runner([createExpenses, TestMigration(1000, 'other', (_) async {})]), throwsArgumentError);
  });
}
