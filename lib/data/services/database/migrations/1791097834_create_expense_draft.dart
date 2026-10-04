// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// The one unsaved Add/Edit form (database.md §3.9, phase-4.md §4). Always
/// the row `id = 1`, written with `INSERT OR REPLACE`; that deletes the old
/// row first, which is safe only because nothing references this table
/// (sqlite.md §5.2). Keep it that way.
class CreateExpenseDraft extends Migration {
  const CreateExpenseDraft()
    : super(version: 1791097834, name: 'create_expense_draft');

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('expense_draft', (t) {
      // Not a reference: the expense may be deleted meanwhile; the draft
      // then just stops matching any row (database.md §3.9).
      t.integer('editing_expense_id');
      // Read and written only by Dart: Android 10's SQLite has no JSON
      // functions (sqlite.md §3).
      t.text('form_json', nullable: false);
      t.integer('updated_at', nullable: false);
    });
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('expense_draft');
  }
}
