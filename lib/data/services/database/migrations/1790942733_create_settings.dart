// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// Key/value store for app preferences (database.md §3.1).
///
/// No seed rows: SettingsRepository has a default for every key, and a
/// missing row means "use the default".
class CreateSettings extends Migration {
  const CreateSettings() : super(version: 1790942733, name: 'create_settings');

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('settings', id: false, (t) {
      t.text('key', nullable: false);
      t.text('value');
      t.primaryKey(['key']);
    });
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('settings');
  }
}
