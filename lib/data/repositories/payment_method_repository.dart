import 'package:sqflite/sqflite.dart';

import '../../domain/models/payment_method.dart';
import 'settings_repository.dart';

/// Thrown by [PaymentMethodRepository.delete] for the default payment
/// method. Another method has to be made the default first.
class CannotDeleteDefault implements Exception {
  const CannotDeleteDefault(this.id);

  final int id;

  @override
  String toString() => 'CannotDeleteDefault: payment method $id is the default';
}

/// Reads and writes the `payment_methods` table (database.md §3.3).
///
/// Validation (name length, uniqueness, one emoji) is done by the form's
/// cubit, because uniqueness depends on the localized names of built-ins.
/// This class trusts its input.
class PaymentMethodRepository {
  PaymentMethodRepository(
    this._db, {
    required this._settings,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Database _db;

  /// Knows which method is the default, so [delete] can refuse it.
  final SettingsRepository _settings;

  final DateTime Function() _now;

  /// Every payment method, in no particular order. The list screen sorts by
  /// display name, which depends on the language.
  Future<List<PaymentMethod>> all() async {
    final rows = await _db.query('payment_methods');
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
    return PaymentMethod(
      id: id,
      builtinKey: null,
      name: name,
      emoji: emoji,
      createdAt: _dateTime(now),
      updatedAt: _dateTime(now),
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
    return method.copyWith(updatedAt: _dateTime(now));
  }

  /// Deletes the method. Throws [CannotDeleteDefault] if it is the current
  /// default. The UI checks this too, but the check lives here as well so
  /// the setting and the table can never disagree.
  Future<void> delete(int id) => _db.transaction((txn) async {
    if (await _settings.defaultPaymentMethodId(txn) == id) {
      throw CannotDeleteDefault(id);
    }
    await txn.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
  });

  static PaymentMethod _fromRow(Map<String, Object?> row) => PaymentMethod(
    id: row['id']! as int,
    builtinKey: row['builtin_key'] as String?,
    name: row['name'] as String?,
    emoji: row['emoji']! as String,
    createdAt: _dateTime(row['created_at']! as int),
    updatedAt: _dateTime(row['updated_at']! as int),
  );

  /// Timestamps are stored as epoch milliseconds, UTC (database.md §1).
  static DateTime _dateTime(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
