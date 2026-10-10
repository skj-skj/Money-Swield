import 'package:sqflite/sqflite.dart';

import '../../domain/models/event.dart';
import '../services/database/sql_helpers.dart';
import 'data_version.dart';

/// Reads and writes the `events` table (database.md §3.4).
///
/// Validation (name length, uniqueness, one emoji) is done by the form's
/// cubit, because uniqueness depends on the localized names of built-ins.
/// This class trusts its input.
class EventRepository {
  EventRepository(
    this._db, {
    DataVersion? dataVersion,
    DateTime Function()? now,
  }) : _dataVersion = dataVersion ?? DataVersion(),
       _now = now ?? DateTime.now;

  final Database _db;

  /// Bumped after every write (phase-2.md §5).
  final DataVersion _dataVersion;

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
    _dataVersion.bump();
    return Event(
      id: id,
      builtinKey: null,
      name: name,
      description: description,
      emoji: emoji,
      archivedAt: null,
      createdAt: utcFromEpochMs(now),
      updatedAt: utcFromEpochMs(now),
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
    _dataVersion.bump();
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
    _dataVersion.bump();
  }

  /// Deletes the event. Its links cascade and the expenses stay, binned
  /// ones included (database.md §3.4).
  Future<void> delete(int id) async {
    await _db.delete('events', where: 'id = ?', whereArgs: [id]);
    _dataVersion.bump();
  }

  /// How many expenses (binned ones included) and recurring items
  /// (archived ones included) have the event: deleting it removes it from
  /// all of them (phase-7a.md R3). Shown in the delete confirmation.
  Future<({int expenses, int templates})> usage(int id) async {
    final expenses = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM expense_events WHERE event_id = ?',
      [id],
    );
    final templates = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM recurring_expense_events WHERE event_id = ?',
      [id],
    );
    return (
      expenses: expenses.single['n']! as int,
      templates: templates.single['n']! as int,
    );
  }

  static Event _fromRow(Map<String, Object?> row) => Event(
    id: row['id']! as int,
    builtinKey: row['builtin_key'] as String?,
    name: row['name'] as String?,
    description: row['description'] as String?,
    emoji: row['emoji']! as String,
    archivedAt: switch (row['archived_at']) {
      final int millis => utcFromEpochMs(millis),
      _ => null,
    },
    createdAt: utcFromEpochMs(row['created_at']! as int),
    updatedAt: utcFromEpochMs(row['updated_at']! as int),
  );
}
