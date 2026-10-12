// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// Expense categories, seeded with the built-in ones.
///
/// Built-in rows have a `builtin_key` and a NULL `name`, so the app shows
/// them in the user's language until they are renamed.
class CreateCategories extends Migration {
  const CreateCategories()
    : super(version: 1790942737, name: 'create_categories');

  // Written out here instead of shared with app code: a released migration
  // must never change, even if the app's list of built-ins does.
  static const _seeds = [
    ('food', '🍽️'),
    ('drinks', '🥤'),
    ('groceries', '🛒'),
    ('shopping', '🛍️'),
    ('clothes', '👕'),
    ('transport', '🚌'),
    ('fuel', '⛽'),
    ('rent', '🏠'),
    ('house', '🏡'),
    ('bills', '🧾'),
    ('health', '💊'),
    ('education', '📚'),
    ('entertainment', '🎬'),
    ('travel', '✈️'),
    ('gifts', '🎁'),
    ('personal_care', '💇'),
    ('subscription', '🔁'),
    ('loan', '🏦'),
    ('investment', '📈'),
    ('other', '📦'),
  ];

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('categories', (t) {
      t.text('builtin_key', unique: true);
      t.text('name');
      t.text('description');
      t.text('emoji', nullable: false);
      t.integer('created_at', nullable: false);
      t.integer('updated_at', nullable: false);
    });

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (key, emoji) in _seeds) {
      await m.insert('categories', {
        'builtin_key': key,
        'emoji': emoji,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('categories');
  }
}
