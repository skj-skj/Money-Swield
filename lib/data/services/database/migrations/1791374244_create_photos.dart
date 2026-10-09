// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// Photos of expenses (database.md §3.7, phase-6.md §4.1). A file is named
/// by its SHA-256 and shared by every expense with the same picture, so a
/// photo is one row however many expenses link it.
///
/// Deleting a link never deletes a row or a file: the startup sweep does,
/// once nothing references them (phase-6.md §6.5). Pictures the user saves
/// to Pictures/ are copies and are not in this table.
class CreatePhotos extends Migration {
  const CreatePhotos() : super(version: 1791374244, name: 'create_photos');

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('photos', (t) {
      // `photos/<sha256>.<ext>`, relative to the app's external files
      // folder (the one holding `databases/`). Never absolute: that folder
      // differs between phones.
      t.text('relative_path', nullable: false, unique: true);
      t.text('sha256', nullable: false);
      t.integer('byte_size', nullable: false);
      t.integer('created_at', nullable: false);
      t.integer('updated_at', nullable: false);
    });
    await m.createTable('expense_photos', id: false, (t) {
      t.references(
        'expense_id',
        toTable: 'expenses',
        nullable: false,
        onDelete: ForeignKeyAction.cascade,
        index: false, // First column of the primary key.
      );
      // Cascades too, but nothing deletes a photo row while it is linked:
      // the sweep deletes unlinked rows only.
      t.references(
        'photo_id',
        toTable: 'photos',
        nullable: false,
        onDelete: ForeignKeyAction.cascade,
      );
      // The order the photos were added in; the grid shows them so.
      t.integer('sort_order', nullable: false);
      t.primaryKey(['expense_id', 'photo_id']);
    });
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('expense_photos');
    await m.dropTable('photos');
  }
}
