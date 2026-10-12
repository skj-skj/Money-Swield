import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/expense.dart';
import '../../domain/models/money.dart';
import '../../domain/models/recurring_item.dart';
import '../../domain/periods.dart';
import '../../domain/recurrence.dart';
import '../../domain/recurring_moment.dart';
import '../../domain/recurring_plan.dart';
import '../../domain/recurring_price.dart';
import '../../domain/repeat_input.dart' show isValidDay, maxRepeatInterval;
import '../../domain/upcoming.dart' show SkipKey;
import '../services/database/sql_helpers.dart';
import 'data_version.dart';
import 'expense_repository.dart';

/// A new recurring item, as Save with Repeats stores it.
class NewRecurringItem {
  const NewRecurringItem({
    required this.title,
    required this.description,
    required this.amount,
    required this.categoryId,
    required this.paymentMethodId,
    required this.eventIds,
    required this.schedule,
    required this.timeOfDayMinutes,
    required this.nextDueOn,
    this.replacesId,
  });

  final String title;
  final String? description;

  /// The first price, from the start; its currency is the item's for good.
  final Money amount;
  final int categoryId;
  final int paymentMethodId;
  final Set<int> eventIds;
  final Schedule schedule;
  final int timeOfDayMinutes;

  /// The first payment not yet added.
  final String? nextDueOn;

  /// The item it was made from when how often changed.
  final int? replacesId;
}

/// The item is gone, archived (for a write only a running item takes), running
/// (for Restore or Delete for good), or broken. Exceptions, not `StateError`,
/// so a screen can catch exactly these (avoid_catching_errors).
class RecurringItemUnavailable implements Exception {
  const RecurringItemUnavailable(this.detail);

  /// English, for logs and tests.
  final String detail;

  @override
  String toString() => 'RecurringItemUnavailable: $detail';
}

/// A change the rules refuse: an end too early or too late, a price before the
/// start or on a date in force, removing a price that stays. Nothing was
/// written.
class RecurringChangeRefused implements Exception {
  const RecurringChangeRefused(this.detail);

  final String detail;

  @override
  String toString() => 'RecurringChangeRefused: $detail';
}

/// What Restore did.
typedef RestoreOutcome = ({String? next, bool endCleared, int added});

/// What Skip them did.
typedef SkipOutcome = ({int skipped, int added, String? next});

/// What Add selected did: payments added, listed dates not added (unticked, or
/// with a row already: skipped for good), and the cursor after.
/// `added + skipped` is how many the sheet listed.
typedef SelectedOutcome = ({int added, int skipped, String? next});

/// What the Add selected sheet lists ([RecurringRepository.heldDates]):
/// the held `days`, and the `cursor` and day (`through`) they were read
/// with, which [RecurringRepository.addSelected] holds to.
typedef HeldDates = ({List<String> days, String cursor, String through});

/// Reads and writes the recurring tables and runs the generator. Bumps
/// [DataVersion] after every commit that changed something.
///
/// **One owner for expense rows**: payments are inserted and read through
/// [ExpenseRepository] (which derives `occurred_on` and loads events); the
/// only write here to `expenses` is clearing `recurring_due_on` before a
/// delete for good.
///
/// Validation of what the user typed is the cubits'; this class enforces
/// the rules that protect data: the cursor never moves backwards, a price
/// before the start is refused, and an archived item is written only by
/// [restore], [undoArchive] and [delete].
class RecurringRepository {
  RecurringRepository(
    this._db, {
    required this._dataVersion,
    DateTime Function()? now,
    ZonedMoment Function(int year, int month, int day, int hour, int minute)?
    localMoment,
  }) : _now = now ?? DateTime.now,
       _localMoment = localMoment ?? deviceMoment;

  final Database _db;
  final DataVersion _dataVersion;
  final DateTime Function() _now;

  /// The device's zone; a fake one in tests.
  final ZonedMoment Function(int, int, int, int, int) _localMoment;

  /// The items the last [generateDue] couldn't run: their page says so.
  Set<int> get lastFailed => _lastFailed;
  Set<int> _lastFailed = const {};

  String get _today => todayOn(_now());

  // Reads.

  /// Every running item (not archived), with its price today, events,
  /// cursor, active payment count and hold. A malformed item comes back
  /// broken ([RecurringItem.isBroken]), never thrown.
  Future<List<RecurringItem>> all() => _readItems(_db, 'archived_at IS NULL');

  /// The archived items, newest archived first.
  Future<List<RecurringItem>> archived() async =>
      (await _readItems(_db, 'archived_at IS NOT NULL'))..sort((a, b) {
        final byTime = b.archivedAt!.compareTo(a.archivedAt!);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });

  /// How many items are running and archived: Manage and the list's
  /// Archive row.
  Future<({int running, int archived})> counts() async {
    final row = (await _db.rawQuery(
      'SELECT count(CASE WHEN archived_at IS NULL THEN 1 END) AS running, '
      'count(CASE WHEN archived_at IS NOT NULL THEN 1 END) AS archived '
      'FROM recurring_expenses',
    )).single;
    return (running: row['running']! as int, archived: row['archived']! as int);
  }

  /// Item [id], running or archived, or null when it is gone.
  Future<RecurringItem?> byId(int id) async =>
      (await _readItems(_db, 'id = ?', [id])).firstOrNull;

  /// The items among [ids] that still exist, by id: one read for many (the
  /// Bin's payments).
  Future<Map<int, RecurringItem>> byIds(Set<int> ids) async => {
    for (final item in await inChunks(
      ids.toList(),
      (chunk) =>
          _readItems(_db, 'id IN (${sqlPlaceholders(chunk.length)})', chunk),
    ))
      item.id: item,
  };

  /// Item [id]'s prices, oldest first.
  Future<List<PricePoint>> prices(int id) => _prices(_db, id);

  /// Item [id]'s active payments, newest due first, [limit] at a time,
  /// continuing before the due date [before].
  Future<List<Expense>> payments(int id, {String? before, int limit = 30}) =>
      ExpenseRepository.paymentsOf(_db, id, before: before, limit: limit);

  /// The newest due date of item [id]'s payments, binned ones included: an Edit
  /// can't end the item before it.
  Future<String?> newestPaymentOn(int id) => _newestPaymentOn(_db, id);

  // Writes.

  /// Inserts [item] with its first price (from its start) and events, inside
  /// [txn] (Save with Repeats). Returns its id.
  static Future<int> insertTemplate(
    Transaction txn,
    NewRecurringItem item,
    int nowMs,
  ) async {
    final s = item.schedule;
    final id = await txn.insert('recurring_expenses', {
      'title': item.title,
      'description': item.description,
      'currency_code': item.amount.currencyCode,
      'category_id': item.categoryId,
      'payment_method_id': item.paymentMethodId,
      'frequency': s.frequency.name,
      'interval_count': s.interval,
      'start_on': s.startOn,
      'end_on': s.endOn,
      'time_of_day_minutes': item.timeOfDayMinutes,
      'next_due_on': item.nextDueOn,
      'replaces_id': item.replacesId,
      'created_at': nowMs,
      'updated_at': nowMs,
    });
    await txn.insert('recurring_amounts', {
      'recurring_expense_id': id,
      'amount_minor': item.amount.amountMinor,
      'effective_from': s.startOn,
      'created_at': nowMs,
      'updated_at': nowMs,
    });
    await _insertEvents(txn, id, item.eventIds);
    return id;
  }

  /// Saves the editable fields of the running item [id]: title, description,
  /// category, payment method, events, time of day and end, in one transaction.
  /// Throws [RecurringItemUnavailable] for an archived or missing item,
  /// [RecurringChangeRefused] for an end before [earliestEndFor] or after
  /// [lastEndOn]. The cursor follows the end ([cursorAfterEndChange]).
  Future<void> update(int id, RecurringEdit edit) async {
    final nowMs = _now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      final row = await _runningRow(txn, id);
      final schedule = _scheduleOf(row);
      if (schedule == null) {
        throw RecurringItemUnavailable('Item $id is broken');
      }
      final endOn = edit.endOn;
      if (endOn != null) {
        final earliest = earliestEndFor(
          startOn: schedule.startOn,
          newestPayment: await _newestPaymentOn(txn, id),
          today: _today,
        );
        if (!_dayWithin(endOn, earliest)) {
          throw RecurringChangeRefused('End $endOn: before $earliest');
        }
      }
      final changed = Schedule(
        frequency: schedule.frequency,
        interval: schedule.interval,
        startOn: schedule.startOn,
        endOn: endOn,
      );
      await txn.update(
        'recurring_expenses',
        {
          'title': edit.title,
          'description': edit.description,
          'category_id': edit.categoryId,
          'payment_method_id': edit.paymentMethodId,
          'time_of_day_minutes': edit.timeOfDayMinutes,
          'end_on': endOn,
          'next_due_on': cursorAfterEndChange(
            changed,
            cursor: row['next_due_on'] as String?,
            oldEnd: schedule.endOn,
          ),
          'updated_at': nowMs,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'recurring_expense_events',
        where: 'recurring_expense_id = ?',
        whereArgs: [id],
      );
      await _insertEvents(txn, id, edit.eventIds);
    });
    _dataVersion.bump();
  }

  /// **Changing how often**: one transaction
  /// makes a new item with [edit]'s fields and [schedule] (its end is
  /// [edit]'s), `replaces_id` = [id], the old item's price on the new start and
  /// its scheduled prices after it and [edit]'s events; then archives the old
  /// one (its cursor kept, so restoring it never pays a date twice). A start of
  /// today adds today's payment in the same transaction. Returns the new id.
  ///
  /// Refused ([RecurringChangeRefused]), nothing written: a start before
  /// [earliestFirstPayment] (on or before the old item's last handled
  /// date, or before today) or after [lastEndOn]; an end before the start
  /// or after [lastEndOn]; payments waiting ([paymentsWaiting]: they would
  /// be dropped). [RecurringItemUnavailable] for an archived, gone or
  /// broken item.
  Future<int> replaceSchedule(
    int id,
    RecurringEdit edit,
    Schedule schedule,
  ) async {
    final nowMs = _now().millisecondsSinceEpoch;
    final today = _today;
    final newId = await _db.transaction((txn) async {
      final row = await _runningRow(txn, id);
      final old = _scheduleOf(row);
      if (old == null) throw RecurringItemUnavailable('Item $id is broken');
      final cursor = row['next_due_on'] as String?;
      if (paymentsWaiting(cursor: cursor, today: today)) {
        throw RecurringChangeRefused('Item $id has payments waiting');
      }
      final startOn = schedule.startOn;
      final earliest = earliestFirstPayment(old, cursor: cursor, today: today);
      final endOn = edit.endOn;
      if (!_dayWithin(startOn, earliest)) {
        throw RecurringChangeRefused('Start $startOn: before $earliest');
      }
      if (endOn != null && !_dayWithin(endOn, startOn)) {
        throw RecurringChangeRefused('End $endOn: before $startOn');
      }
      if (schedule.interval < 1 || schedule.interval > maxRepeatInterval) {
        throw RecurringChangeRefused('Interval ${schedule.interval}');
      }
      final points = await _prices(txn, id);
      // Before the item's first price only when it hasn't started yet (made
      // with a later start, nothing handled, so the First payment may be
      // any day from today): its first price is what it would charge.
      final price = priceOn(points, startOn) ?? _firstPrice(points);
      if (price == null) {
        throw RecurringItemUnavailable('Item $id has no price');
      }
      final newSchedule = Schedule(
        frequency: schedule.frequency,
        interval: schedule.interval,
        startOn: startOn,
        endOn: endOn,
      );
      final created = await insertTemplate(
        txn,
        NewRecurringItem(
          title: edit.title,
          description: edit.description,
          amount: Money(price, row['currency_code']! as String),
          categoryId: edit.categoryId,
          paymentMethodId: edit.paymentMethodId,
          eventIds: edit.eventIds,
          schedule: newSchedule,
          timeOfDayMinutes: edit.timeOfDayMinutes,
          nextDueOn: startOn,
          replacesId: id,
        ),
        nowMs,
      );
      for (final p in points) {
        if (p.from.compareTo(startOn) <= 0) continue;
        await txn.insert('recurring_amounts', {
          'recurring_expense_id': created,
          'amount_minor': p.amountMinor,
          'effective_from': p.from,
          'created_at': nowMs,
          'updated_at': nowMs,
        });
      }
      // The same moment as the new item's created_at: that is how the
      // Archive tells "replaced" from a later Stop.
      await txn.update(
        'recurring_expenses',
        _archivedAt(nowMs),
        where: 'id = ?',
        whereArgs: [id],
      );
      // A start today: its first payment now, not at the next start.
      await _runItem(txn, created, today: today, confirmed: true);
      return created;
    });
    _dataVersion.bump();
    return newId;
  }

  /// The running item of [id]'s family ([runningRelatives]): what Restoring
  /// [id] swaps out; null when none runs. The newest when (only by a bug)
  /// several do.
  Future<RecurringItem?> runningRelative(int id) async {
    final relatives = await _runningRelatives(_db, id);
    return relatives.isEmpty ? null : byId(relatives.first);
  }

  static Future<List<int>> _runningRelatives(
    DatabaseExecutor db,
    int id,
  ) async => runningRelatives(id, {
    // A handful of rows: read whole, walked in Dart (no recursive SQL).
    for (final row in await db.query(
      'recurring_expenses',
      columns: ['id', 'replaces_id', 'archived_at'],
    ))
      row['id']! as int: (
        replacesId: row['replaces_id'] as int?,
        running: row['archived_at'] == null,
      ),
  });

  /// A new price for the running item [id] from [from]: a new row, or the
  /// scheduled price on that date replaced. Payments already added keep theirs.
  /// Throws [RecurringChangeRefused] when refused (before the start, a price in
  /// force, an amount not above 0).
  Future<void> changePrice(
    int id, {
    required int amountMinor,
    required String from,
  }) async {
    if (amountMinor <= 0) {
      throw RecurringChangeRefused('Price $amountMinor: must be > 0');
    }
    if (!isValidDay(from)) {
      throw RecurringChangeRefused('Price from $from: not a date');
    }
    final nowMs = _now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      final row = await _runningRow(txn, id);
      final change = priceChangeFor(
        await _prices(txn, id),
        startOn: row['start_on']! as String,
        from: from,
        today: _today,
      );
      switch (change) {
        case PriceChange.beforeStart || PriceChange.inForce:
          throw RecurringChangeRefused('Price from $from: ${change.name}');
        case PriceChange.replace:
          await txn.update(
            'recurring_amounts',
            {'amount_minor': amountMinor, 'updated_at': nowMs},
            where: 'recurring_expense_id = ? AND effective_from = ?',
            whereArgs: [id, from],
          );
        case PriceChange.add:
          await txn.insert('recurring_amounts', {
            'recurring_expense_id': id,
            'amount_minor': amountMinor,
            'effective_from': from,
            'created_at': nowMs,
            'updated_at': nowMs,
          });
      }
      await _touch(txn, id, nowMs);
    });
    _dataVersion.bump();
  }

  /// Removes the scheduled price of the running item [id] from [from].
  /// Throws [RecurringChangeRefused] for the first price or one in force.
  Future<void> removePrice(int id, String from) async {
    final nowMs = _now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await _runningRow(txn, id);
      if (!canRemovePrice(await _prices(txn, id), from: from, today: _today)) {
        throw RecurringChangeRefused('The price from $from of item $id stays');
      }
      await txn.delete(
        'recurring_amounts',
        where: 'recurring_expense_id = ? AND effective_from = ?',
        whereArgs: [id, from],
      );
      await _touch(txn, id, nowMs);
    });
    _dataVersion.bump();
  }

  /// **Stop**: archives the running item [id]; its cursor and end are
  /// kept, so Undo or Restore never adds a payment twice. Throws
  /// [RecurringItemUnavailable] when it is archived already or gone.
  Future<ArchiveUndo> archive(int id) async {
    final nowMs = _now().millisecondsSinceEpoch;
    final changed = await _db.update(
      'recurring_expenses',
      _archivedAt(nowMs),
      where: 'id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
    if (changed == 0) {
      throw RecurringItemUnavailable('Item $id is archived or gone');
    }
    _dataVersion.bump();
    return (id: id, updatedAtMs: nowMs);
  }

  /// Undo of Stop: back to running, only if nothing changed since (Restore
  /// or Delete in the meantime). Returns whether it did.
  ///
  /// Nor when another item of its family runs now: Stop B, restore A (nothing
  /// to swap), then Undo of B's Stop would have run both for one bill.
  Future<bool> undoArchive(ArchiveUndo undo) async {
    final changed = await _db.transaction((txn) async {
      if ((await _runningRelatives(txn, undo.id)).isNotEmpty) return 0;
      return txn.update(
        'recurring_expenses',
        {'archived_at': null, 'updated_at': _now().millisecondsSinceEpoch},
        where: 'id = ? AND archived_at IS NOT NULL AND updated_at = ?',
        whereArgs: [undo.id, undo.updatedAtMs],
      );
    });
    if (changed > 0) _dataVersion.bump();
    return changed > 0;
  }

  /// **Restore** from the Archive: running again from today. An end
  /// before today is cleared; the cursor is [cursorAfterRestore]. Then
  /// today's payment, if one is due, is added. Throws
  /// [RecurringItemUnavailable] for an
  /// item that isn't archived, or is broken.
  ///
  /// **The swap**: [swapOut] is the running item
  /// of its family the dialog named ([runningRelative]); it is archived in
  /// the same transaction (its payments stay). A family member running
  /// that isn't [swapOut] (none was named, or another one runs now) is
  /// refused ([RecurringChangeRefused]), nothing written: two items must
  /// never run for one bill. A [swapOut] stopped meanwhile is fine.
  Future<RestoreOutcome> restore(int id, {int? swapOut}) async {
    final nowMs = _now().millisecondsSinceEpoch;
    final today = _today;
    final endCleared = await _db.transaction((txn) async {
      final row = await _row(txn, id);
      if (row == null || row['archived_at'] == null) {
        throw RecurringItemUnavailable('Item $id is not archived');
      }
      final schedule = _scheduleOf(row);
      if (schedule == null) {
        throw RecurringItemUnavailable('Item $id is broken');
      }
      final running = await _runningRelatives(txn, id);
      if (running.any((other) => other != swapOut)) {
        throw RecurringChangeRefused('Item $id: $running run in its family');
      }
      if (running.isNotEmpty) {
        await txn.update(
          'recurring_expenses',
          _archivedAt(nowMs),
          where: 'id = ?',
          whereArgs: [swapOut],
        );
      }
      final plan = planRestore(
        schedule,
        cursor: row['next_due_on'] as String?,
        today: today,
      );
      await txn.update(
        'recurring_expenses',
        {
          'archived_at': null,
          'end_on': plan.schedule.endOn,
          'next_due_on': plan.next,
          'updated_at': nowMs,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return plan.endPassed != null;
    });
    _dataVersion.bump();
    final report = await generateDue(onlyId: id, confirmed: true);
    return (
      next: (await byId(id))?.nextDueOn,
      endCleared: endCleared,
      added: report.added,
    );
  }

  /// **Delete for good** an archived item: its payments, active and
  /// binned, stay as plain expenses (their due date is cleared, then the
  /// foreign key clears the item); prices and events go. Throws
  /// [RecurringItemUnavailable] for a running item.
  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      final row = await _row(txn, id);
      if (row == null || row['archived_at'] == null) {
        throw RecurringItemUnavailable('Only an archived item is deleted');
      }
      await txn.update(
        'expenses',
        {'recurring_due_on': null},
        where: 'recurring_expense_id = ?',
        whereArgs: [id],
      );
      await txn.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
    });
    _dataVersion.bump();
  }

  /// **Skip them**: every payment due before today is skipped (the
  /// cursor moves to the first payment from today, never backwards), then
  /// today's is added if it is due.
  Future<SkipOutcome> skipBacklog(int id) async {
    final today = _today;
    final nowMs = _now().millisecondsSinceEpoch;
    final skipped = await _db.transaction((txn) async {
      final row = await _runningRow(txn, id);
      final schedule = _scheduleOf(row);
      final cursor = row['next_due_on'] as String?;
      if (schedule == null || cursor == null || cursor.compareTo(today) >= 0) {
        return 0;
      }
      final skips = await _skipsOf(txn, id);
      final next = occurrenceOnOrAfter(schedule, today);
      await txn.update(
        'recurring_expenses',
        {'next_due_on': next, 'updated_at': nowMs},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _dropPassedSkips(txn, id, next);
      // Dates skipped once from Upcoming were never going to be added: they
      // aren't counted as skipped now. Counted, not walked: a daily item from
      // 1900 has 46,000 dates.
      final yesterday = addDays(today, -1);
      return dueCount(schedule, cursor: cursor, today: yesterday) -
          skippedBetween(schedule, skips, cursor, yesterday);
    });
    if (skipped > 0) _dataVersion.bump();
    final report = await generateDue(onlyId: id, confirmed: true);
    return (
      skipped: skipped,
      added: report.added,
      next: (await byId(id))?.nextDueOn,
    );
  }

  // Add selected and skips.

  /// The held dates of item [id] that the Add selected sheet lists: due
  /// from its cursor through today, skipped ones left out, at most 1,000
  /// ([dueDatesSkipping]); with the cursor and the day they were read on,
  /// which [addSelected] holds to.
  Future<HeldDates?> heldDates(int id) async {
    final row = await _row(_db, id);
    final schedule = row == null ? null : _scheduleOf(row);
    final cursor = row?['next_due_on'] as String?;
    if (row == null || schedule == null || cursor == null) return null;
    final today = _today;
    final (:due, next: _) = dueDatesSkipping(
      schedule,
      from: cursor,
      through: today,
      skipped: await _skipsOf(_db, id),
    );
    return (days: due, cursor: cursor, through: today);
  }

  /// **Add selected**: in one transaction, the [ticked]
  /// dates that are really due ([selectedPlan]) are added (one with a row
  /// already is passed over) and the cursor moves past every listed date,
  /// so the unticked ones are skipped for good. [held] is what the sheet
  /// listed ([heldDates]): its cursor moved since (a run, another tap),
  /// nothing is written and [RecurringChangeRefused] is thrown; the page
  /// reloads. Its day holds past midnight: the new day's payment wasn't
  /// listed, so it is left for the generator, never skipped unseen.
  Future<SelectedOutcome> addSelected(
    int id,
    Set<String> ticked, {
    required HeldDates held,
  }) async {
    final today = _today;
    // Never after today (a clock set back): no future payment is added.
    final through = held.through.compareTo(today) < 0 ? held.through : today;
    final outcome = await _db.transaction((txn) async {
      final row = await _runningRow(txn, id);
      final schedule = _scheduleOf(row);
      if (schedule == null) {
        throw RecurringItemUnavailable('Item $id is broken');
      }
      if (row['next_due_on'] != held.cursor) {
        throw RecurringChangeRefused('Item $id: the cursor moved');
      }
      final (:add, :listed, :next) = selectedPlan(
        schedule,
        cursor: held.cursor,
        today: through,
        ticked: ticked,
        skipped: await _skipsOf(txn, id),
      );
      final added = await _addDue(txn, row, add, next);
      return (added: added, skipped: listed - added, next: next);
    });
    _dataVersion.bump();
    return outcome;
  }

  /// The skips stored for days after [after] (Upcoming's).
  Future<Set<SkipKey>> skips({required String after}) async => {
    for (final row in await _db.rawQuery(
      'SELECT recurring_expense_id, due_on FROM recurring_skips '
      'WHERE due_on > ?',
      [after],
    ))
      (
        itemId: row['recurring_expense_id']! as int,
        day: row['due_on']! as String,
      ),
  };

  /// **Skip once**: payment [day] of item [id] won't be
  /// added. Only a day Upcoming lists: a payment of a running item, after
  /// today, on or after its cursor, before its end; anything else is
  /// [RecurringChangeRefused] (the day passed while the screen was open).
  /// A second skip of the same day does nothing (checked first; the
  /// unique index backs it).
  Future<void> skipOnce(int id, String day) async {
    final nowMs = _now().millisecondsSinceEpoch;
    final today = _today;
    final added = await _db.transaction((txn) async {
      final row = await _runningRow(txn, id);
      final schedule = _scheduleOf(row);
      final cursor = row['next_due_on'] as String?;
      if (schedule == null ||
          cursor == null ||
          !isValidDay(day) ||
          day.compareTo(today) <= 0 ||
          day.compareTo(cursor) < 0 ||
          occurrenceOnOrAfter(schedule, day) != day) {
        throw RecurringChangeRefused('Item $id: $day is not upcoming');
      }
      if ((await _skipsOf(txn, id)).contains(day)) return false;
      await txn.insert('recurring_skips', {
        'recurring_expense_id': id,
        'due_on': day,
        'created_at': nowMs,
        'updated_at': nowMs,
      });
      return true;
    });
    if (added) _dataVersion.bump();
  }

  /// **Bring back** a skipped payment; Undo of Skip once. Does
  /// nothing when it isn't skipped.
  Future<void> unskip(int id, String day) async {
    final count = await _db.delete(
      'recurring_skips',
      where: 'recurring_expense_id = ? AND due_on = ?',
      whereArgs: [id, day],
    );
    if (count > 0) _dataVersion.bump();
  }

  // The generator.

  /// Adds every payment that has come due, item by item, each in its own
  /// transaction; archives items whose end passed. [confirmed]: the user
  /// already said yes (Add all), so no hold. [onlyId] narrows it to one
  /// item. A failing item is logged and left as it was; the others go on.
  ///
  /// Idempotent three ways: the cursor and the inserts commit together;
  /// an existing payment (active or binned) is passed over; the unique
  /// index refuses a duplicate even if that check were wrong. Two runs at
  /// once serialize on sqflite's transactions, and the second re-reads the
  /// moved cursor.
  Future<GenerateReport> generateDue({
    bool confirmed = false,
    int? onlyId,
  }) async {
    final today = _today;
    final nowMs = _now().millisecondsSinceEpoch;
    final watch = Stopwatch()..start();
    final due = await _db.query(
      'recurring_expenses',
      columns: ['id'],
      where: [
        'archived_at IS NULL AND next_due_on IS NOT NULL AND next_due_on <= ?',
        if (onlyId != null) 'id = ?',
      ].join(' AND '),
      whereArgs: [today, ?onlyId],
      orderBy: 'next_due_on, id',
    );
    var added = 0;
    // A cursor moved without a payment added (they had rows already) is a
    // change too: screens that reload "if changed" kept showing a backlog that
    // was gone.
    var moved = false;
    final held = <HeldItem>[];
    final failed = <int>{};
    for (final row in due) {
      final id = row['id']! as int;
      try {
        final outcome = await _db.transaction(
          (txn) => _runItem(txn, id, today: today, confirmed: confirmed),
        );
        switch (outcome) {
          case (added: final int count, moved: final bool cursorMoved):
            added += count;
            moved = moved || cursorMoved;
          case final HeldItem hold:
            held.add(hold);
        }
      } catch (error, stackTrace) {
        failed.add(id);
        debugPrint(
          'Recurring item $id: adding payments failed: $error\n'
          '$stackTrace',
        );
      }
    }
    // After the items, not before: an item whose last payment was added
    // in this run after its end passed (the app wasn't opened between
    // them) expires now, not at the next run. Until then it showed as
    // running with a past end, and its Edit refused every save.
    final expired = await _db.update(
      'recurring_expenses',
      _archivedAt(nowMs),
      where:
          'archived_at IS NULL AND next_due_on IS NULL AND end_on IS NOT NULL '
          'AND end_on < ?',
      whereArgs: [today],
    );
    // Skips no cursor can reach any more: an archived item's from before
    // today (Restore starts from today), and any its cursor passed (a
    // Restore or an Edit moved it). A handful of rows.
    await _db.rawDelete(
      'DELETE FROM recurring_skips WHERE EXISTS (SELECT 1 FROM '
      'recurring_expenses r WHERE r.id = recurring_skips.recurring_expense_id '
      'AND (recurring_skips.due_on < r.next_due_on OR (r.archived_at IS NOT '
      'NULL AND recurring_skips.due_on < ?)))',
      [today],
    );
    _lastFailed = onlyId == null
        ? failed
        : {..._lastFailed.where((id) => id != onlyId), ...failed};
    if (added > 0 || expired > 0 || moved) _dataVersion.bump();
    if (added > 0) {
      debugPrint(
        'Recurring run: added $added in ${watch.elapsedMilliseconds} ms',
      );
    }
    return GenerateReport(
      added: added,
      held: held,
      failed: failed,
      expired: expired,
    );
  }

  /// One item, inside its transaction: how many payments it added and
  /// whether its cursor moved, or its hold. Throws (rolling the item back)
  /// when it can't be run.
  Future<Object> _runItem(
    Transaction txn,
    int id, {
    required String today,
    required bool confirmed,
  }) async {
    final row = await _row(txn, id);
    // Archived, deleted or run by another start meanwhile.
    if (row == null || row['archived_at'] != null) {
      return (added: 0, moved: false);
    }
    final schedule = _scheduleOf(row);
    if (schedule == null) throw RecurringItemUnavailable('Item $id is broken');
    final plan = planTemplate(
      schedule,
      cursor: row['next_due_on'] as String?,
      today: today,
      confirmed: confirmed,
      // Read in this transaction: a skip is never added.
      skipped: await _skipsOf(txn, id),
    );
    switch (plan) {
      case NothingDue():
        return (added: 0, moved: false);
      case HoldPayments(:final count, :final from, :final to):
        return (
          id: id,
          title: row['title']! as String,
          count: count,
          from: from,
          to: to,
        );
      case AddPayments(:final due, :final next):
        final added = await _addDue(txn, row, due, next);
        return (added: added, moved: next != row['next_due_on']);
    }
  }

  /// Adds the payments of [days] for the item in [row] at their prices,
  /// passing over any with a row already (active or binned), then moves
  /// its cursor to [next] and drops the skips it passed: the generator's
  /// and Add selected's write, inside [txn]. Returns how many it added.
  /// Throws (rolling it all back) when a day has no price.
  Future<int> _addDue(
    Transaction txn,
    Map<String, Object?> row,
    List<String> days,
    String? next,
  ) async {
    final id = row['id']! as int;
    final points = await _prices(txn, id);
    final existing = await _paymentsOnOrBetween(txn, id, days);
    final payments = <PaymentInput>[];
    for (final day in days) {
      if (existing.contains(day)) continue;
      final amount = priceOn(points, day);
      if (amount == null) {
        throw RecurringItemUnavailable('Item $id has no price on $day');
      }
      payments.add(_paymentOf(row, day, amount));
    }
    await ExpenseRepository.insertPayments(
      txn,
      id,
      payments,
      nowMs: _now().millisecondsSinceEpoch,
    );
    // updated_at is left alone: the item itself didn't change (and Undo of
    // a Stop compares it).
    await txn.update(
      'recurring_expenses',
      {'next_due_on': next},
      where: 'id = ?',
      whereArgs: [id],
    );
    // With the cursor, in the same transaction: a crash before the commit
    // leaves the skip and adds nothing.
    await _dropPassedSkips(txn, id, next);
    return payments.length;
  }

  /// What Stop, an expiry, a swap and a new schedule write.
  static Map<String, Object?> _archivedAt(int nowMs) => {
    'archived_at': nowMs,
    'updated_at': nowMs,
  };

  /// Whether [day] is a real date from [from] through [lastEndOn].
  static bool _dayWithin(String day, String from) =>
      isValidDay(day) &&
      day.compareTo(from) >= 0 &&
      day.compareTo(lastEndOn) <= 0;

  /// The oldest of [points]' prices; null when there are none.
  static int? _firstPrice(List<PricePoint> points) => points.isEmpty
      ? null
      : points
            .reduce((a, b) => a.from.compareTo(b.from) <= 0 ? a : b)
            .amountMinor;

  /// The payment due on [day] of the item in [row], at [amountMinor], in the
  /// device's zone now.
  PaymentInput _paymentOf(
    Map<String, Object?> row,
    String day,
    int amountMinor,
  ) {
    final moment = paymentMoment(
      day,
      row['time_of_day_minutes']! as int,
      localMoment: _localMoment,
      onSkippedDay: (day) =>
          debugPrint('Recurring payment due $day: the zone skips that day'),
    );
    return PaymentInput(
      recurringExpenseId: row['id']! as int,
      dueOn: day,
      title: row['title']! as String,
      description: row['description'] as String?,
      amount: Money(amountMinor, row['currency_code']! as String),
      occurredAt: moment.occurredAt,
      utcOffsetMinutes: moment.offsetMinutes,
      categoryId: row['category_id']! as int,
      paymentMethodId: row['payment_method_id']! as int,
    );
  }

  // The restore probe.

  /// Reads every recurring column once, the way the app does, so a
  /// database without them (an older backup) is refused before it
  /// replaces the user's data. Plain SELECTs naming the columns, not
  /// [all]: one malformed row must not refuse a backup the app can open.
  static Future<void> probe(DatabaseExecutor db) async {
    await db.rawQuery(
      'SELECT recurring_expense_id, recurring_due_on FROM expenses LIMIT 1',
    );
    await db.rawQuery(
      'SELECT id, title, description, currency_code, category_id, '
      'payment_method_id, frequency, interval_count, start_on, end_on, '
      'time_of_day_minutes, next_due_on, archived_at, created_at, updated_at, '
      'replaces_id FROM recurring_expenses LIMIT 1',
    );
    // Skips and replacements: an older database lacks both.
    await db.rawQuery(
      'SELECT recurring_expense_id, due_on, created_at, updated_at '
      'FROM recurring_skips LIMIT 1',
    );
    await db.rawQuery(
      'SELECT id, recurring_expense_id, amount_minor, effective_from, '
      'created_at, updated_at FROM recurring_amounts LIMIT 1',
    );
    await db.rawQuery(
      'SELECT recurring_expense_id, event_id FROM recurring_expense_events '
      'LIMIT 1',
    );
  }

  // Helpers.

  Future<List<RecurringItem>> _readItems(
    DatabaseExecutor db,
    String where, [
    List<Object?>? whereArgs,
  ]) async {
    final rows = await db.query(
      'recurring_expenses',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id',
    );
    // Growable: archived() sorts what it gets.
    if (rows.isEmpty) return [];
    final ids = [for (final row in rows) row['id']! as int];
    final points = <int, List<PricePoint>>{};
    final events = <int, Set<int>>{};
    final counts = <int, int>{};
    // When each item's replacements were made: "replaced" is one made in the
    // same write that archived it.
    final replacedAt = <int, Set<int>>{};
    // Skipped dates: the hold leaves them out.
    final skips = <int, Set<String>>{};
    await inChunks(ids, (chunk) async {
      final list = sqlPlaceholders(chunk.length);
      for (final p in await db.rawQuery(
        'SELECT recurring_expense_id AS id, amount_minor, effective_from '
        'FROM recurring_amounts WHERE recurring_expense_id IN ($list)',
        chunk,
      )) {
        points.putIfAbsent(p['id']! as int, () => []).add((
          from: p['effective_from']! as String,
          amountMinor: p['amount_minor']! as int,
        ));
      }
      for (final e in await db.rawQuery(
        'SELECT recurring_expense_id AS id, event_id '
        'FROM recurring_expense_events WHERE recurring_expense_id IN ($list)',
        chunk,
      )) {
        events
            .putIfAbsent(e['id']! as int, () => {})
            .add(e['event_id']! as int);
      }
      for (final c in await db.rawQuery(
        'SELECT recurring_expense_id AS id, count(*) AS n FROM expenses '
        'WHERE recurring_expense_id IN ($list) AND +deleted_at IS NULL '
        'GROUP BY recurring_expense_id',
        chunk,
      )) {
        counts[c['id']! as int] = c['n']! as int;
      }
      for (final r in await db.rawQuery(
        'SELECT replaces_id AS id, created_at FROM recurring_expenses '
        'WHERE replaces_id IN ($list)',
        chunk,
      )) {
        replacedAt
            .putIfAbsent(r['id']! as int, () => {})
            .add(r['created_at']! as int);
      }
      for (final k in await db.rawQuery(
        'SELECT recurring_expense_id AS id, due_on FROM recurring_skips '
        'WHERE recurring_expense_id IN ($list)',
        chunk,
      )) {
        skips
            .putIfAbsent(k['id']! as int, () => {})
            .add(k['due_on']! as String);
      }
      return const <void>[];
    });
    final today = _today;
    return [
      for (final row in rows)
        _itemOf(
          row,
          points: points[row['id']] ?? const [],
          eventIds: events[row['id']] ?? const {},
          paymentCount: counts[row['id']] ?? 0,
          replacedAt: replacedAt[row['id']] ?? const {},
          skipped: skips[row['id']] ?? const {},
          today: today,
        ),
    ];
  }

  RecurringItem _itemOf(
    Map<String, Object?> row, {
    required List<PricePoint> points,
    required Set<int> eventIds,
    required int paymentCount,
    required Set<int> replacedAt,
    required Set<String> skipped,
    required String today,
  }) {
    final schedule = _scheduleOf(row);
    final cursor = row['next_due_on'] as String?;
    final archivedAt = switch (row['archived_at']) {
      final int ms => utcFromEpochMs(ms),
      _ => null,
    };
    final startOn = schedule?.startOn ?? today;
    final plan = schedule == null || archivedAt != null
        ? null
        : planTemplate(
            schedule,
            cursor: cursor,
            today: today,
            confirmed: false,
            skipped: skipped,
          );
    return RecurringItem(
      id: row['id']! as int,
      title: row['title']! as String,
      description: row['description'] as String?,
      currencyCode: row['currency_code']! as String,
      categoryId: row['category_id']! as int,
      paymentMethodId: row['payment_method_id']! as int,
      eventIds: eventIds,
      schedule: schedule,
      timeOfDayMinutes: row['time_of_day_minutes']! as int,
      nextDueOn: cursor,
      archivedAt: archivedAt,
      archivedOn: archivedAt == null ? null : todayOn(archivedAt),
      createdAt: utcFromEpochMs(row['created_at']! as int),
      updatedAt: utcFromEpochMs(row['updated_at']! as int),
      // An item that hasn't started shows its first price.
      priceMinor: priceOn(
        points,
        startOn.compareTo(today) > 0 ? startOn : today,
      ),
      paymentCount: paymentCount,
      hold: plan is HoldPayments ? plan : null,
      replacesId: row['replaces_id'] as int?,
      replaced: replacedAt.contains(row['archived_at']),
      prices: points,
    );
  }

  /// The stored rule, or null when any part of it can't be read: the item
  /// is then broken, never guessed at.
  static Schedule? _scheduleOf(Map<String, Object?> row) {
    final frequency = switch (row['frequency']) {
      final String name => Frequency.values.asNameMap()[name],
      _ => null,
    };
    final interval = row['interval_count'];
    final startOn = row['start_on'];
    final endOn = row['end_on'];
    final cursor = row['next_due_on'];
    if (frequency == null ||
        interval is! int ||
        interval < 1 ||
        interval > maxRepeatInterval ||
        startOn is! String ||
        !isValidDay(startOn) ||
        (endOn != null && (endOn is! String || !isValidDay(endOn))) ||
        (cursor != null && (cursor is! String || !isValidDay(cursor)))) {
      return null;
    }
    return Schedule(
      frequency: frequency,
      interval: interval,
      startOn: startOn,
      endOn: endOn as String?,
    );
  }

  static Future<Map<String, Object?>?> _row(
    DatabaseExecutor db,
    int id,
  ) async => (await db.query(
    'recurring_expenses',
    where: 'id = ?',
    whereArgs: [id],
  )).firstOrNull;

  /// Item [id]'s row; [RecurringItemUnavailable] when it is gone or
  /// archived (archived
  /// items open read-only).
  static Future<Map<String, Object?>> _runningRow(
    DatabaseExecutor db,
    int id,
  ) async {
    final row = await _row(db, id);
    if (row == null) throw RecurringItemUnavailable('Item $id is gone');
    if (row['archived_at'] != null) {
      throw RecurringItemUnavailable('Item $id is archived');
    }
    return row;
  }

  static Future<List<PricePoint>> _prices(DatabaseExecutor db, int id) async =>
      [
        for (final p in await db.query(
          'recurring_amounts',
          columns: ['amount_minor', 'effective_from'],
          where: 'recurring_expense_id = ?',
          whereArgs: [id],
          orderBy: 'effective_from',
        ))
          (
            from: p['effective_from']! as String,
            amountMinor: p['amount_minor']! as int,
          ),
      ];

  /// The due dates among [days] (in order) of item [id] that have a row, active
  /// or binned: one covering-index range search rather than a query per date.
  static Future<Set<String>> _paymentsOnOrBetween(
    DatabaseExecutor db,
    int id,
    List<String> days,
  ) async {
    if (days.isEmpty) return const {};
    final rows = await db.rawQuery(
      'SELECT recurring_due_on FROM expenses WHERE recurring_expense_id = ? '
      'AND recurring_due_on BETWEEN ? AND ?',
      [id, days.first, days.last],
    );
    return {for (final r in rows) r['recurring_due_on']! as String};
  }

  static Future<Set<String>> _skipsOf(DatabaseExecutor db, int id) async => {
    for (final row in await db.query(
      'recurring_skips',
      columns: ['due_on'],
      where: 'recurring_expense_id = ?',
      whereArgs: [id],
    ))
      row['due_on']! as String,
  };

  /// Deletes item [id]'s skips before [next], its new cursor: they were passed
  /// over and are never looked at again. With no cursor (no payment left) they
  /// stay: an Edit that extends the end makes them payments again.
  static Future<void> _dropPassedSkips(
    Transaction txn,
    int id,
    String? next,
  ) async {
    if (next == null) return;
    await txn.delete(
      'recurring_skips',
      where: 'recurring_expense_id = ? AND due_on < ?',
      whereArgs: [id, next],
    );
  }

  static Future<String?> _newestPaymentOn(DatabaseExecutor db, int id) async =>
      (await db.rawQuery(
            'SELECT max(recurring_due_on) AS newest FROM expenses '
            'WHERE recurring_expense_id = ?',
            [id],
          )).single['newest']
          as String?;

  static Future<void> _insertEvents(
    Transaction txn,
    int id,
    Set<int> eventIds,
  ) async {
    for (final eventId in eventIds) {
      await txn.insert('recurring_expense_events', {
        'recurring_expense_id': id,
        'event_id': eventId,
      });
    }
  }

  static Future<void> _touch(Transaction txn, int id, int nowMs) => txn.update(
    'recurring_expenses',
    {'updated_at': nowMs},
    where: 'id = ?',
    whereArgs: [id],
  );
}
