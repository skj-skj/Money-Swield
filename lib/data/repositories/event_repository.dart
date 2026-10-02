import 'package:sqflite/sqflite.dart';

import '../../domain/models/event.dart';

/// Reads and writes the `events` table (database.md §3.4).
///
/// Validation (name length, uniqueness, one emoji) is done by the form's
/// cubit, because uniqueness depends on the localized names of built-ins.
/// This class trusts its input.
class EventRepository {
  EventRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  /// Every event, archived ones included, in no particular order. The list
  /// screen sorts by display name, which depends on the language.
  Future<List<Event>> all() async {
    final rows = await _db.query('events');
    return [for (final row in rows) _fromRow(row)];
  }

  Future<Event> add({
    required String name,
    String? description,
    required String emoji,
  }) async {
    final now = _now().millisecondsSinceEpoch;
    final id = await _db.insert('events', {
      'name': name,
      'description': description,
      'emoji': emoji,
      'created_at': now,
      'updated_at': now,
    });
    return Event(
      id: id,
      builtinKey: null,
      name: name,
      description: description,
      emoji: emoji,
      archivedAt: null,
      createdAt: _dateTime(now),
      updatedAt: _dateTime(now),
    );
  }

  /// Saves the name, description and emoji of [event] and sets
  /// `updated_at`. Returns the saved event. Throws [StateError] if it no
  /// longer exists.
  ///
  /// `archived_at` is deliberately not written: archiving goes through
  /// [setArchived], so saving a form opened before an archive can't undo it.
  Future<Event> update(Event event) async {
    final now = _now().millisecondsSinceEpoch;
    final changed = await _db.update(
      'events',
      {
        'name': event.name,
        'description': event.description,
        'emoji': event.emoji,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [event.id],
    );
    if (changed == 0) throw StateError('Event ${event.id} no longer exists');
    final rows = await _db.query(
      'events',
      where: 'id = ?',
      whereArgs: [event.id],
    );
    return _fromRow(rows.single);
  }

  /// Archives the event (hides it from the picker) or brings it back.
  /// Archiving an already archived event keeps its original date.
  Future<void> setArchived(int id, bool archived) async {
    final now = _now().millisecondsSinceEpoch;
    await _db.update(
      'events',
      {'archived_at': archived ? now : null, 'updated_at': now},
      where: archived
          ? 'id = ? AND archived_at IS NULL'
          : 'id = ? AND archived_at IS NOT NULL',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) =>
      _db.delete('events', where: 'id = ?', whereArgs: [id]);

  static Event _fromRow(Map<String, Object?> row) => Event(
    id: row['id']! as int,
    builtinKey: row['builtin_key'] as String?,
    name: row['name'] as String?,
    description: row['description'] as String?,
    emoji: row['emoji']! as String,
    archivedAt: switch (row['archived_at']) {
      final int millis => _dateTime(millis),
      _ => null,
    },
    createdAt: _dateTime(row['created_at']! as int),
    updatedAt: _dateTime(row['updated_at']! as int),
  );

  /// Timestamps are stored as epoch milliseconds, UTC (database.md §1).
  static DateTime _dateTime(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
