// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// Which events an expense belongs to. Both sides cascade: deleting an event
/// unlinks it and the expenses stay; deleting an expense for good removes its
/// links.
class CreateExpenseEvents extends Migration {
  const CreateExpenseEvents()
    : super(version: 1790960267, name: 'create_expense_events');

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('expense_events', id: false, (t) {
      t.references(
        'expense_id',
        toTable: 'expenses',
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
      t.primaryKey(['expense_id', 'event_id']);
    });
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('expense_events');
  }
}
