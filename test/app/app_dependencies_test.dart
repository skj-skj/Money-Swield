import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/domain/models/expense_draft.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

ExpenseDraft _draft(String title) => ExpenseDraft(
  editingExpenseId: null,
  title: title,
  amountExpression: '',
  description: '',
  categoryId: null,
  eventIds: const {},
  paymentMethodId: 1,
  currencyCode: 'INR',
  pickedWallClock: null,
  touched: const {DraftField.title},
  itemizeLine: null,
  itemizeLabels: const [],
  itemizeTerms: const [],
  updatedAt: DateTime.utc(2026),
);

/// The draft parts of AppDependencies.
void main() {
  test('probe reads the draft slot and leaves a malformed row alone', () async {
    final db = await openMigratedDatabase();
    await db.insert('expense_draft', {
      'id': 1,
      'form_json': 'not json',
      'updated_at': 1,
    });
    await AppDependencies.probe(db, deviceCurrency: 'INR');
    expect(await db.query('expense_draft'), hasLength(1));
  });

  test('probe refuses a database without the draft table', () async {
    final db = await openMigratedDatabase();
    await db.execute('DROP TABLE expense_draft');
    await expectLater(
      AppDependencies.probe(db, deviceCurrency: 'INR'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('probe refuses a database without either photo table', () async {
    for (final table in ['expense_photos', 'photos']) {
      final db = await openMigratedDatabase();
      await db.execute('DROP TABLE expense_photos');
      if (table == 'photos') {
        // Back without photos: only `photos` is missing now.
        await db.execute(
          'CREATE TABLE expense_photos (expense_id INTEGER, '
          'photo_id INTEGER, sort_order INTEGER)',
        );
        await db.execute('PRAGMA foreign_keys = OFF');
        await db.execute('DROP TABLE photos');
      }
      await expectLater(
        AppDependencies.probe(db, deviceCurrency: 'INR'),
        throwsA(isA<DatabaseException>()),
        reason: table,
      );
    }
  });

  group('probe and the recurring schema', () {
    /// `expenses` without the two recurring columns, rows kept: an older
    /// build's table, which `SELECT *` reads without complaint.
    Future<void> dropRecurringColumns(Database db) async {
      await db.execute('PRAGMA foreign_keys = OFF');
      await db.execute(
        'CREATE TABLE old_expenses AS SELECT id, title, description, '
        'amount_minor, amount_expression, currency_code, occurred_at, '
        'utc_offset_minutes, occurred_on, category_id, payment_method_id, '
        'deleted_at, created_at, updated_at FROM expenses',
      );
      await db.execute('DROP TABLE expenses');
      await db.execute('ALTER TABLE old_expenses RENAME TO expenses');
    }

    test('an older database (no columns, no tables) is refused', () async {
      final db = await openMigratedDatabase();
      await insertExpenseRow(db);
      await dropRecurringColumns(db);
      for (final table in [
        'recurring_skips',
        'recurring_expense_events',
        'recurring_amounts',
        'recurring_expenses',
      ]) {
        await db.execute('DROP TABLE $table');
      }
      await expectLater(
        AppDependencies.probe(db, deviceCurrency: 'INR'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('the tables without the expense columns: refused', () async {
      final db = await openMigratedDatabase();
      await insertExpenseRow(db);
      await dropRecurringColumns(db);
      await expectLater(
        AppDependencies.probe(db, deviceCurrency: 'INR'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('any one recurring table missing: refused', () async {
      for (final table in [
        'recurring_skips',
        'recurring_expense_events',
        'recurring_amounts',
        'recurring_expenses',
      ]) {
        final db = await openMigratedDatabase();
        await db.execute('PRAGMA foreign_keys = OFF');
        await db.execute('DROP TABLE $table');
        await expectLater(
          AppDependencies.probe(db, deviceCurrency: 'INR'),
          throwsA(isA<DatabaseException>()),
          reason: table,
        );
      }
    });

    test('a database without replaces_id or recurring_skips is '
        'refused', () async {
      // Either part missing alone is refused, so an older backup is too.
      final noSkips = await openMigratedDatabase();
      await noSkips.execute('DROP TABLE recurring_skips');
      await expectLater(
        AppDependencies.probe(noSkips, deviceCurrency: 'INR'),
        throwsA(isA<DatabaseException>()),
      );
      final noReplaces = await openMigratedDatabase();
      await insertRecurringRow(noReplaces);
      await noReplaces.execute('PRAGMA foreign_keys = OFF');
      await noReplaces.execute(
        'CREATE TABLE old_items AS SELECT id, title, description, '
        'currency_code, category_id, payment_method_id, frequency, '
        'interval_count, start_on, end_on, time_of_day_minutes, next_due_on, '
        'archived_at, created_at, updated_at FROM recurring_expenses',
      );
      await noReplaces.execute('DROP TABLE recurring_expenses');
      await noReplaces.execute(
        'ALTER TABLE old_items RENAME TO recurring_expenses',
      );
      await expectLater(
        AppDependencies.probe(noReplaces, deviceCurrency: 'INR'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('a broken item passes: the app opens it (as broken)', () async {
      final db = await openMigratedDatabase();
      final id = await insertRecurringRow(db, amountMinor: null);
      await db.update('recurring_expenses', {
        'frequency': 'fortnightly',
      }, where: 'id = $id');
      await AppDependencies.probe(db, deviceCurrency: 'INR');
    });
  });

  // That close() writes what is due first is in
  // expense_draft_repository_test ("close writes what is due").
  test('closeForRestore closes the drafts, then the database; a change '
      'after is refused without an error', () async {
    final deps = await openTestDependencies();
    deps.drafts.update(_draft('typed'));
    await deps.closeForRestore();
    expect(deps.database.isOpen, isFalse);
    // A change after the close is refused, never written anywhere.
    deps.drafts.update(_draft('after'));
    await deps.drafts.flush();
  });

  test('a restart builds a new draft repository: the old memory copy is '
      'not carried over', () async {
    final deps = await openTestDependencies();
    deps.drafts.update(_draft('old database'));
    final restarted = AppDependencies.forDatabase(
      deps.database,
      deviceCurrency: 'INR',
    );
    expect(identical(restarted.drafts, deps.drafts), isFalse);
    expect(await restarted.drafts.read(), isNull, reason: 'never flushed');
  });
}
