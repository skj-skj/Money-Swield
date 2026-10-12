// The <unix time>_<name>.dart file name is intentional.
// ignore_for_file: file_names

import '../migration/migration.dart';

/// Expenses suggested from bank SMS.
///
/// **No column holds the SMS text** (owner rev 3): the scan parses
/// it in memory and keeps only what it found, plus a SHA-256 of the text
/// to recognise the same SMS when it is read again. Pending and dismissed
/// rows are deleted after 30 days; added ones stay (they feed the payee
/// learning and the duplicate check).
///
/// A new migration rather than an edit of an existing one, though the app is
/// unreleased (owner rev 4): a new table reads best in its own file, with its
/// own up / down and tests.
class CreateSmsSuggestions extends Migration {
  const CreateSmsSuggestions()
    : super(version: 1791722683, name: 'create_sms_suggestions');

  @override
  Future<void> up(Migrator m) async {
    await m.createTable('sms_suggestions', (t) {
      // e.g. `VM-ABCBNK-S`, as the inbox has it.
      t.text('sender', nullable: false);
      // Epoch ms UTC: the inbox's `date`, when the phone received the SMS. The
      // expense's moment.
      t.integer('received_at', nullable: false);
      // The device's offset at `received_at`, when scanned.
      t.integer('utc_offset_minutes', nullable: false);
      // Local `YYYY-MM-DD` from the two above, written with them: the day
      // header and the page order (like `expenses.occurred_on`).
      t.text('received_on', nullable: false);
      // SHA-256 of the UTF-8 text, hex: the same SMS read again, and the form's
      // link. A hash, not the text.
      t.text('body_sha256', nullable: false);
      // > 0, at most 12 integer digits (checked in Dart).
      t.integer('amount_minor', nullable: false);
      // Always INR this phase.
      t.text('currency_code', nullable: false);
      // upi | credit_card | debit_card: a payment method's builtin_key, matched
      // when the form opens. Not a reference on purpose: deleting a payment
      // method never touches this table.
      t.text('payment_method_key', nullable: false);
      // As found, spaces collapsed, at most 100 characters.
      t.text('payee');
      // payeeKeyOf(payee), folded in Dart.
      t.text('payee_key');
      // Ref / RRN / UTR, upper-cased: the duplicate check.
      t.text('reference');
      // The suggested title and category, filled at scan.
      t.text('title');
      t.references(
        'category_id',
        toTable: 'categories',
        onDelete: ForeignKeyAction.setNull,
      );
      // pending | added | dismissed.
      t.text('status', nullable: false);
      // regex (9b adds ai). For debugging; never shown.
      t.text('parsed_by', nullable: false);
      // Set by Save. SET NULL: the row stays `added` when the expense is
      // deleted for good, so its card never comes back.
      t.references(
        'expense_id',
        toTable: 'expenses',
        onDelete: ForeignKeyAction.setNull,
      );
      t.integer('created_at', nullable: false);
      t.integer('updated_at', nullable: false);
      // The same SMS read twice is one row (INSERT OR IGNORE).
      t.index(['sender', 'received_at', 'body_sha256'], unique: true);
      // The page and the badge count, with no temp B-tree.
      t.index(['status', 'received_on', 'received_at']);
      t.index(['payee_key']);
      t.index(['reference']);
    });
  }

  @override
  Future<void> down(Migrator m) async {
    await m.dropTable('sms_suggestions');
  }
}
