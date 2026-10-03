// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// Expenses (database.md §3.5, phase-2.md §3.1). Money is an integer in
/// minor units with its currency next to it; `deleted_at` set means the
/// expense is in the bin.
///
/// `recurring_expense_id` / `recurring_due_on` are not here on purpose:
/// Phase 7 adds them together with the table they point to.
class CreateExpenses extends Migration {
  const CreateExpenses() : super(version: 1790960250, name: 'create_expenses');

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('expenses', (t) {
      t.text('title', nullable: false);
      t.text('description');
      t.integer('amount_minor', nullable: false);
      // What was typed, e.g. `50+60`. Always NULL until Phase 4's keypad;
      // created now so Phase 4 needs no migration for it.
      t.text('amount_expression');
      t.text('currency_code', nullable: false);
      t.integer('occurred_at', nullable: false);
      t.integer('utc_offset_minutes', nullable: false);
      t.text('occurred_on', nullable: false);
      // The (category_id, occurred_on) index below also covers the FK.
      t.references(
        'category_id',
        toTable: 'categories',
        nullable: false,
        onDelete: ForeignKeyAction.restrict,
        index: false,
      );
      t.references(
        'payment_method_id',
        toTable: 'payment_methods',
        nullable: false,
        onDelete: ForeignKeyAction.restrict,
      );
      t.integer('deleted_at');
      t.integer('created_at', nullable: false);
      t.integer('updated_at', nullable: false);
      t.index(['occurred_at', 'id']);
      t.index(['occurred_on']);
      t.index(['category_id', 'occurred_on']);
      // Only for the bin and the purge (`IS NOT NULL`, `<`). Active-row
      // queries write `+deleted_at IS NULL` so the planner never picks it
      // (phase-2.md §5).
      t.index(['deleted_at']);
    });
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('expenses');
  }
}
