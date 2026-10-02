// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// Events (trips, birthdays …), seeded with the built-in ones
/// (database.md §3.4). `archived_at` hides an event from the picker.
class CreateEvents extends Migration {
  const CreateEvents() : super(version: 1790942747, name: 'create_events');

  // Written out here instead of shared with app code: a released migration
  // must never change, even if the app's list of built-ins does.
  static const _seeds = [
    ('birthday', '🎂'),
    ('anniversary', '💍'),
    ('party', '🎉'),
    ('festival', '🪔'),
    ('trip', '🧳'),
  ];

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('events', (t) {
      t.text('builtin_key', unique: true);
      t.text('name');
      t.text('description');
      t.text('emoji', nullable: false);
      t.integer('archived_at');
      t.integer('created_at', nullable: false);
      t.integer('updated_at', nullable: false);
    });

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (key, emoji) in _seeds) {
      await m.insert('events', {
        'builtin_key': key,
        'emoji': emoji,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('events');
  }
}
