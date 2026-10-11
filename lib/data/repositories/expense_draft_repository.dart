import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/expense_draft.dart';
import '../../domain/photos.dart';
import '../services/database/sql_helpers.dart';

/// Makes a timer; `Timer.new` in the app, a fake in tests.
typedef TimerFactory = Timer Function(Duration duration, void Function() run);

/// The one draft slot (D9, phase-4.md §6.4): in memory first, mirrored to
/// the `expense_draft` row ([debounce] after the last change) so it
/// survives the app being killed.
///
/// Created with the other repositories in `AppDependencies`, so the
/// restart after a restore drops the memory copy: an old database's draft
/// is never written into the new one.
///
/// Every write and delete goes through one `Future` chain, so they land in
/// call order, and a generation counter makes a write queued before
/// [clear] or [forget] a no-op. Without it, Save → clear → the timer fires
/// → the draft comes back.
///
/// Drafts don't bump `DataVersion`: a draft changes nothing Home counts.
class ExpenseDraftRepository {
  ExpenseDraftRepository(
    this._db, {
    TimerFactory? timer,
    this.debounce = const Duration(milliseconds: 500),
  }) : _timer = timer ?? Timer.new;

  final Database _db;
  final TimerFactory _timer;
  final Duration debounce;

  static const _table = 'expense_draft';

  /// The slot's only row (database.md §3.9).
  static const _slotId = 1;

  ExpenseDraft? _memory;

  /// Whether [_memory] is authoritative: after the first [read], or after
  /// any change. The row is never read again, so a queued or failed DELETE
  /// can't bring a cleared draft back.
  bool _loaded = false;

  /// [_memory] isn't in the row yet: a write is due, or failed.
  bool _pending = false;

  Timer? _debounceTimer;

  /// Bumped by [clear] and [forget]; a write from an older generation is
  /// dropped.
  int _generation = 0;

  Future<void> _chain = Future.value();

  /// Writes and deletes queued on [_chain] that haven't finished.
  int _queued = 0;

  bool _closed = false;

  /// [read] for a screen opening the form: a SQL error is logged and reads
  /// as no draft, so the form still opens.
  Future<ExpenseDraft?> readOrNull() async {
    try {
      return await read();
    } catch (error) {
      debugPrint('Reading the expense draft failed: $error');
      return null;
    }
  }

  /// The draft in the slot, or null. The first call reads the row; a row
  /// that can't be read as a draft is deleted then (logged). SQL errors
  /// throw: the caller logs them and goes on without a draft.
  Future<ExpenseDraft?> read() async {
    if (_loaded) return _memory;
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [_slotId]);
    // A change while the row was being read wins over the row.
    if (_loaded) return _memory;
    _loaded = true;
    final row = rows.firstOrNull;
    if (row == null) return null;
    final draft = _parse(row);
    if (draft == null) {
      debugPrint('Deleting an unreadable expense draft: ${row['form_json']}');
      unawaited(_enqueue(() => _db.delete(_table)));
    }
    return _memory = draft;
  }

  /// Puts [draft] in the slot, replacing whatever was there (P4-1), and
  /// writes it to the row [debounce] after the last call.
  void update(ExpenseDraft draft) {
    if (_closed) return;
    _memory = draft;
    _loaded = true;
    _pending = true;
    _debounceTimer?.cancel();
    _debounceTimer = _timer(debounce, _queueWrite);
  }

  /// Takes [photoIds] out of the slot's draft when it is an Edit draft of
  /// [expenseId] (phase-6.md §6.4a): the Photos screen deleted them from
  /// that expense, and without this the draft would bring them back on its
  /// next Update. Through [update], so memory and row agree. An Add draft
  /// or another expense's draft is left alone: its photos are its own
  /// until saved.
  Future<void> dropSavedPhotos(int expenseId, Set<int> photoIds) async {
    final draft = await read();
    if (draft == null || draft.editingExpenseId != expenseId) return;
    final kept = [
      for (final photo in draft.photos)
        if (photo is! SavedPhoto || !photoIds.contains(photo.id)) photo,
    ];
    if (kept.length == draft.photos.length) return;
    update(draft.withPhotos(kept));
  }

  /// Writes the draft now if a write is due (or failed), and waits for
  /// every write and delete already queued. Called when the form closes
  /// and when the app goes to the background.
  Future<void> flush() {
    _debounceTimer?.cancel();
    if (_pending) _queueWrite();
    return _queueDone;
  }

  /// Whether the slot holds changes the row doesn't have yet: after a
  /// [flush], only when that write failed.
  bool get writeDue => _pending;

  /// Waits for the writes already queued, and cancels the timer, without
  /// writing. The form calls it before a save that deletes the row in its
  /// own transaction (`clearDraft`), so a write still running can't put
  /// the row back after that commit. The draft stays due: if the save
  /// fails, the next [flush] writes it.
  Future<void> settle() {
    _debounceTimer?.cancel();
    return _queueDone;
  }

  /// Empties the slot and deletes the row.
  Future<void> clear() {
    _forgetMemory();
    if (_closed) return _queueDone;
    return _enqueue(() => _db.delete(_table));
  }

  /// Empties the slot without SQL: the row already went with a save
  /// (`ExpenseRepository.add` / `update` / `moveToBin` with `clearDraft`).
  void forget() => _forgetMemory();

  /// Writes what is due, then refuses every further change. A restore
  /// calls it before closing the database (phase-4.md §6.4).
  Future<void> close() async {
    await flush();
    _closed = true;
  }

  /// Read-only check that the slot can be read, for a restore's "opens as
  /// the app would" (R10). An unreadable draft is fine (the app would drop
  /// it) and is left alone.
  static Future<void> probe(DatabaseExecutor db) async {
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [_slotId]);
    if (rows.firstOrNull case final row?) _parse(row);
  }

  /// The draft in [db]'s slot, read-only, never deleted: for another
  /// database (a pre-restore copy, phase-6.md §6.5). Null when there is
  /// none, or no `expense_draft` table (a copy from before Phase 4), or it
  /// can't be read as a draft. SQL errors throw.
  static Future<ExpenseDraft?> readDraft(DatabaseExecutor db) async {
    final table = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = '$_table'",
    );
    if (table.isEmpty) return null;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [_slotId]);
    return switch (rows.firstOrNull) {
      final row? => _parse(row),
      null => null,
    };
  }

  void _forgetMemory() {
    _memory = null;
    _loaded = true;
    _pending = false;
    _generation++;
    _debounceTimer?.cancel();
  }

  void _queueWrite() {
    final generation = _generation;
    _enqueue(() => _write(generation));
  }

  Future<void> _write(int generation) async {
    final draft = _memory;
    if (generation != _generation || !_pending || draft == null) return;
    _pending = false;
    try {
      await _db.insert(
        _table,
        {
          'id': _slotId,
          'editing_expense_id': draft.editingExpenseId,
          'form_json': draft.toJson(),
          'updated_at': draft.updatedAt.millisecondsSinceEpoch,
        },
        // Deletes the old row first; safe because nothing references this
        // table (sqlite.md §5.2). UPSERT needs 3.24.
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (error, stackTrace) {
      // Stays due, so the next flush retries. Never shown to the user.
      if (generation == _generation) _pending = true;
      debugPrint('Writing the expense draft failed: $error\n$stackTrace');
    }
  }

  /// Completes once everything queued so far has run.
  ///
  /// With nothing queued it is a fresh future, made in the caller's zone:
  /// an already completed future from another zone resumes its awaiter
  /// only when the real event loop runs, which a widget test's fake-async
  /// zone never lets happen (found by the widget tests: Save hung).
  Future<void> get _queueDone => _queued == 0 ? Future.value() : _chain;

  /// Runs [action] after everything queued before it. A failure is logged
  /// and doesn't stop what comes after.
  Future<void> _enqueue(Future<Object?> Function() action) {
    final previous = _queueDone;
    _queued++;
    return _chain = previous.then((_) async {
      try {
        await action();
      } catch (error, stackTrace) {
        debugPrint('Expense draft SQL failed: $error\n$stackTrace');
      } finally {
        _queued--;
      }
    });
  }

  static ExpenseDraft? _parse(Map<String, Object?> row) {
    final json = row['form_json'];
    final updatedAt = row['updated_at'];
    if (json is! String || updatedAt is! int) return null;
    final editing = row['editing_expense_id'];
    if (editing != null && editing is! int) return null;
    return ExpenseDraft.fromJson(
      json,
      editingExpenseId: editing as int?,
      updatedAt: utcFromEpochMs(updatedAt),
    );
  }
}
