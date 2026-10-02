// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// Payment methods, seeded with the built-in ones (database.md §3.3).
///
/// `cash` is the default payment method until the user picks another one
/// (SettingsRepository falls back to it when the setting is missing).
class CreatePaymentMethods extends Migration {
  const CreatePaymentMethods()
    : super(version: 1790942740, name: 'create_payment_methods');

  // Written out here instead of shared with app code: a released migration
  // must never change, even if the app's list of built-ins does.
  static const _seeds = [
    ('cash', '💵'),
    ('upi', '📱'),
    ('debit_card', '🏧'),
    ('credit_card', '💳'),
  ];

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('payment_methods', (t) {
      t.text('builtin_key', unique: true);
      t.text('name');
      t.text('emoji', nullable: false);
      t.integer('created_at', nullable: false);
      t.integer('updated_at', nullable: false);
    });

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (key, emoji) in _seeds) {
      await m.insert('payment_methods', {
        'builtin_key': key,
        'emoji': emoji,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('payment_methods');
  }
}
