import 'package:sqflite/sqflite.dart';

import '../../domain/models/owner_usage.dart';

export '../../domain/models/owner_usage.dart';

/// What every expense and recurring item must have exactly one of: a
/// category and a payment method. Their usage count and their
/// move-then-delete are the same SQL on a different table and column. The
/// names come from this enum only, never from input, so they can be
/// written into the SQL.
enum ExpenseOwner {
  category('categories', 'category_id'),
  paymentMethod('payment_methods', 'payment_method_id');

  const ExpenseOwner(this.table, this.column);

  /// The owner's own table.
  final String table;

  /// Its column in `expenses` and `recurring_expenses`.
  final String column;

  /// How many expenses and recurring items use owner [id]. Binned expenses
  /// and archived items are counted on purpose: they block the delete too
  /// (RESTRICT) and must be moved (database.md §3.2, phase-7a.md R2).
  Future<OwnerUsage> usage(DatabaseExecutor db, int id) async {
    final row = (await db.rawQuery(
      'SELECT COALESCE(SUM(deleted_at IS NULL), 0) AS active, '
      'COALESCE(SUM(deleted_at IS NOT NULL), 0) AS binned '
      'FROM expenses WHERE $column = ?',
      [id],
    )).single;
    final templates = (await db.rawQuery(
      'SELECT count(*) AS n FROM recurring_expenses WHERE $column = ?',
      [id],
    )).single;
    return (
      active: row['active']! as int,
      binned: row['binned']! as int,
      templates: templates['n']! as int,
    );
  }

  /// Inside the caller's transaction: moves every expense of owner [id],
  /// binned ones included, and every recurring item of it, archived ones
  /// included (their later payments then use [toId]), to [toId] (stamping
  /// [updatedAtMs]) and deletes [id]. If [toId] no longer exists the move
  /// fails on the foreign key, and the caller's transaction rolls
  /// everything back (D7).
  Future<void> moveExpensesAndDelete(
    Transaction txn,
    int id, {
    required int toId,
    required int updatedAtMs,
  }) async {
    if (toId == id) {
      throw ArgumentError.value(toId, 'toId', 'must differ from id');
    }
    await txn.update(
      'expenses',
      {column: toId, 'updated_at': updatedAtMs},
      where: '$column = ?',
      whereArgs: [id],
    );
    await txn.update(
      'recurring_expenses',
      {column: toId, 'updated_at': updatedAtMs},
      where: '$column = ?',
      whereArgs: [id],
    );
    await txn.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
