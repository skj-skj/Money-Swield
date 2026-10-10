// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// Expenses (database.md §3.5, phase-2.md §3.1) and the recurring items
/// that add them (§3.8, phase-7a.md §4.1). Money is an integer in minor
/// units with its currency next to it; `deleted_at` set means the expense
/// is in the bin.
///
/// The recurring tables come first: `expenses.recurring_expense_id`
/// references them, and the framework refuses a reference to a table that
/// doesn't exist yet. They live in this migration, not a new one, because
/// the app is unreleased (owner: migrations are edited until release;
/// P7a-14), so a Phase 6 database needs a fresh install.
class CreateExpenses extends Migration {
  const CreateExpenses() : super(version: 1790960250, name: 'create_expenses');

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('recurring_expenses', (t) {
      t.text('title', nullable: false);
      t.text('description');
      // Prices are minor units of this currency, so it never changes
      // (P7a-10); `recurring_amounts` has no currency of its own.
      t.text('currency_code', nullable: false);
      t.references(
        'category_id',
        toTable: 'categories',
        nullable: false,
        onDelete: ForeignKeyAction.restrict,
      );
      t.references(
        'payment_method_id',
        toTable: 'payment_methods',
        nullable: false,
        onDelete: ForeignKeyAction.restrict,
      );
      // daily | weekly | monthly | yearly (domain/recurrence.dart).
      t.text('frequency', nullable: false);
      t.integer('interval_count', nullable: false, defaultValue: 1);
      // The first payment, and the anchor day (the 31st stays the 31st).
      t.text('start_on', nullable: false);
      // NULL = no end.
      t.text('end_on');
      // The time put on added payments, minutes past local midnight.
      t.integer('time_of_day_minutes', nullable: false);
      // The next payment not yet handled: every date before it was added,
      // deleted or skipped, and is never looked at again (phase-7a.md
      // §6.7). Never moves backwards; kept when archived. NULL when no
      // payment is left before the end.
      t.text('next_due_on');
      // Set = archived: stopped, or expired (its end date passed). Adds
      // nothing; listed only in the Archive.
      t.integer('archived_at');
      t.integer('created_at', nullable: false);
      t.integer('updated_at', nullable: false);
    });
    await m.createTable('recurring_amounts', (t) {
      t.references(
        'recurring_expense_id',
        toTable: 'recurring_expenses',
        nullable: false,
        onDelete: ForeignKeyAction.cascade,
        index: false, // First column of the unique index below.
      );
      t.integer('amount_minor', nullable: false);
      // A price change adds a row from a date and never edits history
      // (database.md §3.8).
      t.text('effective_from', nullable: false);
      t.integer('created_at', nullable: false);
      t.integer('updated_at', nullable: false);
      t.index(['recurring_expense_id', 'effective_from'], unique: true);
    });
    await m.createTable('recurring_expense_events', id: false, (t) {
      t.references(
        'recurring_expense_id',
        toTable: 'recurring_expenses',
        nullable: false,
        onDelete: ForeignKeyAction.cascade,
        index: false, // First column of the primary key.
      );
      t.references(
        'event_id',
        toTable: 'events',
        nullable: false,
        onDelete: ForeignKeyAction.cascade,
      );
      t.primaryKey(['recurring_expense_id', 'event_id']);
    });
    await m.createTable('expenses', (t) {
      t.text('title', nullable: false);
      t.text('description');
      t.integer('amount_minor', nullable: false);
      // What was typed, e.g. `50+60`; NULL for a plain number (Phase 4's
      // amount field).
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
      // Set by the recurring generator and by Save with Repeats only.
      // SET NULL: deleting a recurring item keeps the expenses it added.
      t.references(
        'recurring_expense_id',
        toTable: 'recurring_expenses',
        onDelete: ForeignKeyAction.setNull,
        index: false, // First column of the unique index below.
      );
      // Which payment of the item this is; never changed by an Edit, so a
      // re-dated payment is still that payment.
      t.text('recurring_due_on');
      t.integer('deleted_at');
      t.integer('created_at', nullable: false);
      t.integer('updated_at', nullable: false);
      // Home lists expenses by local date, then moment (phase-5.md R1):
      // ordering by the moment alone gives a traveller's day two headers.
      // The same index serves every occurred_on range (totals, chips,
      // usage).
      t.index(['occurred_on', 'occurred_at', 'id']);
      t.index(['category_id', 'occurred_on']);
      // Only for the bin and the purge (`IS NOT NULL`, `<`). Active-row
      // queries write `+deleted_at IS NULL` so the planner never picks it
      // (phase-2.md §5).
      t.index(['deleted_at']);
      // One row per payment: the generator running twice, or after a
      // crash, can't add a payment again. Binned rows count. SQLite allows
      // any number of NULL pairs (plain expenses).
      t.index(['recurring_expense_id', 'recurring_due_on'], unique: true);
    });
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('expenses');
    await m.dropTable('recurring_expense_events');
    await m.dropTable('recurring_amounts');
    await m.dropTable('recurring_expenses');
  }
}
