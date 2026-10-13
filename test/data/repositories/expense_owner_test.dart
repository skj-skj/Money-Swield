import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/data/repositories/expense_owner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

/// The SQL the category and payment method repositories share. Their own
/// tests cover each flow; these check what sharing it could break: one
/// owner's statement touching the other's column.
void main() {
  late Database db;

  setUp(() async {
    db = await openMigratedDatabase();
  });

  Future<List<(int, int, int)>> expenses() async => [
    for (final row in await db.query('expenses', orderBy: 'id'))
      (
        row['category_id']! as int,
        row['payment_method_id']! as int,
        row['updated_at']! as int,
      ),
  ];

  test('each owner names its own table and column', () {
    expect(ExpenseOwner.category.table, 'categories');
    expect(ExpenseOwner.category.column, 'category_id');
    expect(ExpenseOwner.paymentMethod.table, 'payment_methods');
    expect(ExpenseOwner.paymentMethod.column, 'payment_method_id');
  });

  test('usage counts by its own column only', () async {
    await insertExpenseRow(db, categoryId: 2, paymentMethodId: 1);
    await insertExpenseRow(db, categoryId: 1, paymentMethodId: 2);
    await insertExpenseRow(db, categoryId: 2, paymentMethodId: 3, deletedAt: 1);
    expect(await ExpenseOwner.category.usage(db, 2), (
      active: 1,
      binned: 1,
      templates: 0,
    ));
    expect(await ExpenseOwner.paymentMethod.usage(db, 2), (
      active: 1,
      binned: 0,
      templates: 0,
    ));
    expect(await ExpenseOwner.paymentMethod.usage(db, 99), (
      active: 0,
      binned: 0,
      templates: 0,
    ));
  });

  test('a category move changes only category_id; the payment method of '
      'every expense and other expenses stay', () async {
    await insertExpenseRow(db, categoryId: 1, paymentMethodId: 2);
    await insertExpenseRow(db, categoryId: 1, paymentMethodId: 3, deletedAt: 1);
    await insertExpenseRow(db, categoryId: 4, paymentMethodId: 1);
    await db.transaction(
      (txn) => ExpenseOwner.category.moveExpensesAndDelete(
        txn,
        1,
        toId: 5,
        updatedAtMs: 77,
      ),
    );
    expect(await expenses(), [(5, 2, 77), (5, 3, 77), (4, 1, 0)]);
    expect(await db.query('categories', where: 'id = 1'), isEmpty);
    expect(await db.query('payment_methods'), hasLength(4));
  });

  test('a payment method move changes only payment_method_id', () async {
    await insertExpenseRow(db, categoryId: 3, paymentMethodId: 2);
    await insertExpenseRow(db, categoryId: 6, paymentMethodId: 4);
    await db.transaction(
      (txn) => ExpenseOwner.paymentMethod.moveExpensesAndDelete(
        txn,
        2,
        toId: 3,
        updatedAtMs: 9,
      ),
    );
    expect(await expenses(), [(3, 3, 9), (6, 4, 0)]);
    expect(await db.query('payment_methods', where: 'id = 2'), isEmpty);
    expect(await db.query('categories'), hasLength(20));
  });

  test('onto itself: refused, nothing changes', () async {
    await insertExpenseRow(db, categoryId: 1);
    await expectLater(
      db.transaction(
        (txn) => ExpenseOwner.category.moveExpensesAndDelete(
          txn,
          1,
          toId: 1,
          updatedAtMs: 9,
        ),
      ),
      throwsArgumentError,
    );
    expect(await expenses(), [(1, 1, 0)]);
    expect(await db.query('categories', where: 'id = 1'), hasLength(1));
  });

  test('a target gone meanwhile: the foreign key fails and the whole '
      'transaction rolls back', () async {
    await insertExpenseRow(db, categoryId: 1);
    await db.delete('categories', where: 'id = 3');
    await expectLater(
      db.transaction(
        (txn) => ExpenseOwner.category.moveExpensesAndDelete(
          txn,
          1,
          toId: 3,
          updatedAtMs: 9,
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await expenses(), [(1, 1, 0)]);
    expect(await db.query('categories', where: 'id = 1'), hasLength(1));
  });

  group('recurring items', () {
    Future<List<(int, int, int)>> items() async => [
      for (final row in await db.query('recurring_expenses', orderBy: 'id'))
        (
          row['category_id']! as int,
          row['payment_method_id']! as int,
          row['updated_at']! as int,
        ),
    ];

    test(
      'usage counts items, running and archived, by its own column',
      () async {
        await insertRecurringRow(db, categoryId: 11, paymentMethodId: 3);
        await insertRecurringRow(
          db,
          categoryId: 11,
          paymentMethodId: 1,
          archivedAt: 7,
        );
        expect(await ExpenseOwner.category.usage(db, 11), (
          active: 0,
          binned: 0,
          templates: 2,
        ));
        expect(await ExpenseOwner.paymentMethod.usage(db, 3), (
          active: 0,
          binned: 0,
          templates: 1,
        ));
        expect(isUnused(await ExpenseOwner.category.usage(db, 11)), isFalse);
        expect(isUnused(await ExpenseOwner.category.usage(db, 12)), isTrue);
      },
    );

    test('a category used only by an item: the move moves the item and '
        'the delete succeeds', () async {
      await insertRecurringRow(db, categoryId: 11, paymentMethodId: 3);
      await db.transaction(
        (txn) => ExpenseOwner.category.moveExpensesAndDelete(
          txn,
          11,
          toId: 5,
          updatedAtMs: 77,
        ),
      );
      expect(await items(), [(5, 3, 77)]);
      expect(await db.query('categories', where: 'id = 11'), isEmpty);
    });

    test('used by both: expenses and items (archived too) move together; '
        'other items stay', () async {
      await insertExpenseRow(db, categoryId: 11, paymentMethodId: 2);
      await insertRecurringRow(db, categoryId: 11, paymentMethodId: 2);
      await insertRecurringRow(db, categoryId: 11, archivedAt: 9);
      await insertRecurringRow(db, categoryId: 4);
      await db.transaction(
        (txn) => ExpenseOwner.category.moveExpensesAndDelete(
          txn,
          11,
          toId: 5,
          updatedAtMs: 77,
        ),
      );
      expect(await expenses(), [(5, 2, 77)]);
      expect(await items(), [(5, 2, 77), (5, 1, 77), (4, 1, 0)]);
    });

    test("a payment method move changes only the items' method", () async {
      await insertRecurringRow(db, categoryId: 6, paymentMethodId: 2);
      await db.transaction(
        (txn) => ExpenseOwner.paymentMethod.moveExpensesAndDelete(
          txn,
          2,
          toId: 3,
          updatedAtMs: 9,
        ),
      );
      expect(await items(), [(6, 3, 9)]);
    });

    test('a target gone meanwhile rolls the items back too', () async {
      await insertRecurringRow(db, categoryId: 11);
      await db.delete('categories', where: 'id = 3');
      await expectLater(
        db.transaction(
          (txn) => ExpenseOwner.category.moveExpensesAndDelete(
            txn,
            11,
            toId: 3,
            updatedAtMs: 9,
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(await items(), [(11, 1, 0)]);
    });
  });
}
