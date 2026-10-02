import 'package:sqflite/sqflite.dart';

import '../../domain/models/category.dart';

/// Reads and writes the `categories` table (database.md §3.2).
///
/// Validation (name length, uniqueness, one emoji) is done by the form's
/// cubit, because uniqueness depends on the localized names of built-ins.
/// This class trusts its input.
class CategoryRepository {
  CategoryRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Database _db;
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
    return category.copyWith(updatedAt: _dateTime(now));
  }

  Future<void> delete(int id) =>
      _db.delete('categories', where: 'id = ?', whereArgs: [id]);

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
