import 'package:sqflite/sqflite.dart';

import '../../domain/models/payment_method.dart';
import '../services/database/sql_helpers.dart';
import 'data_version.dart';
import 'expense_owner.dart';
import 'settings_repository.dart';

/// Thrown by [PaymentMethodRepository.delete] for the default payment
/// method. Another method has to be made the default first.
class CannotDeleteDefault implements Exception {
  const CannotDeleteDefault(this.id);

  final int id;

  @override
  String toString() => 'CannotDeleteDefault: payment method $id is the default';
}

/// Reads and writes the `payment_methods` table.
///
/// Validation (name length, uniqueness, one emoji) is done by the form's
/// cubit, because uniqueness depends on the localized names of built-ins.
/// This class trusts its input.
class PaymentMethodRepository {
  PaymentMethodRepository(
    this._db, {
    required this._settings,
    DataVersion? dataVersion,
    DateTime Function()? now,
  }) : _dataVersion = dataVersion ?? DataVersion(),
       _now = now ?? DateTime.now;

  final Database _db;

  /// Knows which method is the default, so [delete] can refuse it.
  final SettingsRepository _settings;

  /// Bumped after every write.
  final DataVersion _dataVersion;

  final DateTime Function() _now;

  /// Every payment method, in no particular order. The list screen sorts by
  /// display name, which depends on the language.
  Future<List<PaymentMethod>> all() => allOn(_db);

  /// [all] on [db]: inside a transaction, the transaction's executor (a call to
  /// the database itself there waits for the transaction to end, and so never
  /// returns).
  static Future<List<PaymentMethod>> allOn(DatabaseExecutor db) async {
    final rows = await db.query('payment_methods');
    return [for (final row in rows) _fromRow(row)];
  }

  Future<PaymentMethod> add({
    required String name,
    required String emoji,
  }) async {
    final now = _now().millisecondsSinceEpoch;
    final id = await _db.insert('payment_methods', {
      'name': name,
      'emoji': emoji,
      'created_at': now,
      'updated_at': now,
    });
    _dataVersion.bump();
    return PaymentMethod(
      id: id,
      builtinKey: null,
      name: name,
      emoji: emoji,
      createdAt: utcFromEpochMs(now),
      updatedAt: utcFromEpochMs(now),
    );
  }

  /// Saves the name and emoji of [method] and sets `updated_at`. Returns the
  /// saved method. Throws [StateError] if it no longer exists.
  Future<PaymentMethod> update(PaymentMethod method) async {
    final now = _now().millisecondsSinceEpoch;
    final changed = await _db.update(
      'payment_methods',
      {'name': method.name, 'emoji': method.emoji, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [method.id],
    );
    if (changed == 0) {
      throw StateError('Payment method ${method.id} no longer exists');
    }
    _dataVersion.bump();
    return method.copyWith(updatedAt: utcFromEpochMs(now));
  }

  /// Deletes the method. Throws [CannotDeleteDefault] if it is the current
  /// default. The UI checks this too, but the check lives here as well so
  /// the setting and the table can never disagree. Fails on the foreign key
  /// (RESTRICT) if an expense still uses it; see [moveExpensesAndDelete].
  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      await _refuseDefault(txn, id);
      await txn.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
    });
    _dataVersion.bump();
  }

  /// How many expenses use the method. Binned ones are counted on purpose: they
  /// block the delete too and must be moved.
  Future<OwnerUsage> usage(int id) => ExpenseOwner.paymentMethod.usage(_db, id);

  /// Moves every expense of method [id], binned ones included, to [toId] and
  /// deletes [id], in one transaction. Throws [CannotDeleteDefault] for the
  /// default, and fails on the foreign key if [toId] no longer exists; either
  /// way nothing changes.
  Future<void> moveExpensesAndDelete(int id, {required int toId}) async {
    // ExpenseOwner checks this too, but only after the default check: here
    // a move onto itself is an ArgumentError even for the default.
    if (toId == id) {
      throw ArgumentError.value(toId, 'toId', 'must differ from id');
    }
    await _db.transaction((txn) async {
      await _refuseDefault(txn, id);
      await ExpenseOwner.paymentMethod.moveExpensesAndDelete(
        txn,
        id,
        toId: toId,
        updatedAtMs: _now().millisecondsSinceEpoch,
      );
    });
    _dataVersion.bump();
  }

  Future<void> _refuseDefault(Transaction txn, int id) async {
    if (await _settings.defaultPaymentMethodId(txn) == id) {
      throw CannotDeleteDefault(id);
    }
  }

  static PaymentMethod _fromRow(Map<String, Object?> row) => PaymentMethod(
    id: row['id']! as int,
    builtinKey: row['builtin_key'] as String?,
    name: row['name'] as String?,
    emoji: row['emoji']! as String,
    createdAt: utcFromEpochMs(row['created_at']! as int),
    updatedAt: utcFromEpochMs(row['updated_at']! as int),
  );
}
