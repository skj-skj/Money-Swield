import 'package:sqflite/sqflite.dart';

import '../../domain/models/category.dart';
import 'data_version.dart';

/// Reads and writes the `categories` table (database.md §3.2).
///
/// Validation (name length, uniqueness, one emoji) is done by the form's
/// cubit, because uniqueness depends on the localized names of built-ins.
/// This class trusts its input.
class CategoryRepository {
  CategoryRepository(
    this._db, {
    DataVersion? dataVersion,
    DateTime Function()? now,
  }) : _dataVersion = dataVersion ?? DataVersion(),
       _now = now ?? DateTime.now;

  final Database _db;

  /// Bumped after every write (phase-2.md §5).
  final DataVersion _dataVersion;

  final DateTime Function() _now;

  /// Every category, in no particular order. The list screen sorts by
  /// display name, which depends on the language.
  Future<List<Category>> all() async {
    final rows = await _db.query('categories');
    return [for (final row in rows) _fromRow(row)];
  }

  Future<Category> add({
    required String name,
    String? description,
    required String emoji,
  }) async {
    final now = _now().millisecondsSinceEpoch;
    final id = await _db.insert('categories', {
      'name': name,
      'description': description,
      'emoji': emoji,
      'created_at': now,
      'updated_at': now,
    });
    _dataVersion.bump();
    return Category(
      id: id,
      builtinKey: null,
      name: name,
      description: description,
      emoji: emoji,
      createdAt: _dateTime(now),
      updatedAt: _dateTime(now),
    );
  }

  /// Saves the name, description and emoji of [category] and sets
  /// `updated_at`. Returns the saved category. Throws [StateError] if it no
  /// longer exists.
  Future<Category> update(Category category) async {
    final now = _now().millisecondsSinceEpoch;
    final changed = await _db.update(
      'categories',
      {
        'name': category.name,
        'description': category.description,
        'emoji': category.emoji,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
    if (changed == 0) {
      throw StateError('Category ${category.id} no longer exists');
    }
    _dataVersion.bump();
    return category.copyWith(updatedAt: _dateTime(now));
  }

  /// Deletes the category. Fails on the foreign key (RESTRICT) if an
  /// expense still uses it; see [moveExpensesAndDelete].
  Future<void> delete(int id) async {
    await _db.delete('categories', where: 'id = ?', whereArgs: [id]);
    _dataVersion.bump();
  }

  /// How many expenses use the category. Binned ones are counted on
  /// purpose: they block the delete too and must be moved (database.md
  /// §3.2).
  Future<({int active, int binned})> usage(int id) async {
    final row = (await _db.rawQuery(
      'SELECT COALESCE(SUM(deleted_at IS NULL), 0) AS active, '
      'COALESCE(SUM(deleted_at IS NOT NULL), 0) AS binned '
      'FROM expenses WHERE category_id = ?',
      [id],
    )).single;
    return (active: row['active']! as int, binned: row['binned']! as int);
  }

  /// Moves every expense of category [id], binned ones included, to [toId]
  /// and deletes [id], in one transaction (D7). If [toId] no longer exists
  /// the move fails on the foreign key and nothing changes.
  Future<void> moveExpensesAndDelete(int id, {required int toId}) async {
    if (toId == id) {
      throw ArgumentError.value(toId, 'toId', 'must differ from id');
    }
    await _db.transaction((txn) async {
      await txn.update(
        'expenses',
        {'category_id': toId, 'updated_at': _now().millisecondsSinceEpoch},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
    _dataVersion.bump();
  }

  static Category _fromRow(Map<String, Object?> row) => Category(
    id: row['id']! as int,
    builtinKey: row['builtin_key'] as String?,
    name: row['name'] as String?,
    description: row['description'] as String?,
    emoji: row['emoji']! as String,
    createdAt: _dateTime(row['created_at']! as int),
    updatedAt: _dateTime(row['updated_at']! as int),
  );

  /// Timestamps are stored as epoch milliseconds, UTC (database.md §1).
  static DateTime _dateTime(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
