import 'package:sqflite/sqflite.dart';

import '../../domain/expense_filter.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/money.dart';
import '../../domain/models/sms_suggestion.dart';
import '../../domain/periods.dart';
import '../../domain/photo_groups.dart';
import '../../domain/photos.dart';
import '../../domain/popularity.dart';
import '../../domain/recurring_moment.dart';
import '../../domain/repeat_input.dart';
import '../../domain/title_suggestions.dart';
import '../../domain/totals.dart';
import '../services/database/sql_helpers.dart';
import 'data_version.dart';
import 'expense_filter_sql.dart';
import 'recurring_repository.dart';
import 'sms_suggestion_repository.dart';

/// Thrown by [ExpenseRepository.update] and [ExpenseRepository.moveToBin]
/// when the expense was deleted or moved to the bin meanwhile. An exception rather than a `StateError`, so
/// the form can catch exactly this case and nothing else.
class ExpenseNotFound implements Exception {
  const ExpenseNotFound(this.id);

  final int id;

  @override
  String toString() => 'ExpenseNotFound: expense $id is binned or gone';
}

/// Thrown by [ExpenseRepository.addRepeating] when the Repeats settings
/// don't hold any more (checked again inside the save): nothing was
/// written.
class RepeatRefused implements Exception {
  const RepeatRefused(this.error);

  final RepeatError error;

  @override
  String toString() => 'RepeatRefused: ${error.name}';
}

/// Reads and writes the `expenses` and `expense_events` tables.
///
/// Validation (title length, amount > 0, …) is done by the form's cubit;
/// this class trusts its input, except for the bin rules, which it enforces
/// itself so a mistake elsewhere can't edit a binned expense or hard-delete
/// an active one.
class ExpenseRepository {
  ExpenseRepository(
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

  /// The device's zone, for the moments of earlier payments a Save with Repeats
  /// adds; a fake one in tests.
  final ZonedMoment Function(int, int, int, int, int) _localMoment;

  /// How long an expense stays in the bin before the startup purge deletes
  /// it for good.
  static const binRetention = Duration(days: 30);

  /// The window popularity counts uses in.
  static const popularityWindowDays = 90;

  /// The window title suggestions count uses in.
  static const titleWindowDays = 180;

  /// The window amount chips count uses in.
  static const chipWindowDays = 90;

  /// The fewest uses an amount needs to be a chip.
  static const chipMinUses = 2;

  /// The bin filter, in one place: every method except the bin ones uses it.
  ///
  /// The unary `+` is deliberate: it stops SQLite from using
  /// `index_expenses_on_deleted_at` for this term. Without `ANALYZE` stats the
  /// planner treats `IS NULL` like a selective equality, picks that index, then
  /// reads every active row and sorts it, which defeats keyset pagination. A
  /// partial index would be the textbook fix, but the migration framework
  /// doesn't support them.
  static const _active = '+deleted_at IS NULL';

  /// For the bin queries, which do use the `deleted_at` index.
  static const _binned = 'deleted_at IS NOT NULL';

  /// Home's list order: by local date first, so a traveller's day stays
  /// together, then newest moment, then id. Served by
  /// `index_expenses_on_occurred_on_and_occurred_at_and_id`.
  static const _listOrder = 'occurred_on DESC, occurred_at DESC, id DESC';

  /// Inserts the expense and its events in one transaction.
  ///
  /// With [clearDraft], the form's draft row is deleted in the same
  /// transaction: killed after the commit, there is no draft left to save the
  /// same expense twice; killed before, nothing was saved and the draft is
  /// still there.
  ///
  /// With [fromSms], the SMS suggestion is marked added in the same
  /// transaction: a crash leaves both or neither, and a second Save of the same
  /// suggestion throws [SmsAlreadyAdded] with nothing written.
  Future<Expense> add(
    ExpenseInput input, {
    bool clearDraft = false,
    SmsLink? fromSms,
  }) async {
    final now = _now().millisecondsSinceEpoch;
    final expense = await _db.transaction((txn) async {
      final id = await txn.insert('expenses', {
        ..._columns(input),
        'created_at': now,
        'updated_at': now,
      });
      await _insertEvents(txn, id, input.eventIds);
      await _linkPhotos(txn, id, input.photos, now);
      await _markSms(txn, fromSms, id, input, now);
      if (clearDraft) await _deleteDraft(txn);
      return (await _read(txn, where: 'id = ?', whereArgs: [id])).single;
    });
    _dataVersion.bump();
    return expense;
  }

  /// **Save with Repeats**: [input] is saved as the
  /// first payment of a new recurring item that repeats as [choice], in one
  /// transaction with the item, its first price and events, and the
  /// earlier payments up to today. The schedule starts on the saved row's
  /// `occurred_on`, so the form and the stored rule can't disagree.
  ///
  /// [choice] is checked again against today: a [RepeatRefused] means nothing
  /// was written (a Save across midnight can tip "1,000 earlier payments" over
  /// the cap). Killed before the commit, nothing is saved and the draft stays;
  /// after it, everything is, and there's no draft to save it twice
  /// ([clearDraft] as for [add]). The form's photos go to this expense only.
  /// Returns the expense and how many earlier payments were added. [fromSms] as
  /// for [add].
  Future<({Expense expense, int pastAdded})> addRepeating(
    ExpenseInput input,
    RepeatChoice choice, {
    bool clearDraft = false,
    SmsLink? fromSms,
  }) => _saveRepeating(
    null,
    input,
    choice,
    clearDraft: clearDraft,
    fromSms: fromSms,
  );

  /// **Make an existing expense repeat**: [input] is
  /// saved over the active expense [id], which becomes the first payment
  /// of a new item, as [addRepeating] does for a new one, in one
  /// transaction. Throws [ExpenseNotFound] for a binned or gone expense and
  /// [ArgumentError] for one that is a payment already (the form hides
  /// Repeats there, so only a bug gets here): nothing is written.
  Future<({Expense expense, int pastAdded})> updateRepeating(
    int id,
    ExpenseInput input,
    RepeatChoice choice, {
    bool clearDraft = false,
  }) => _saveRepeating(id, input, choice, clearDraft: clearDraft);

  /// [addRepeating] ([id] null) and [updateRepeating].
  Future<({Expense expense, int pastAdded})> _saveRepeating(
    int? id,
    ExpenseInput input,
    RepeatChoice choice, {
    required bool clearDraft,
    SmsLink? fromSms,
  }) async {
    final now = _now();
    final nowMs = now.millisecondsSinceEpoch;
    final today = todayOn(now);
    final startOn = occurredOnFor(input.occurredAt, input.utcOffsetMinutes);
    final error = validateRepeat(choice, startOn: startOn, today: today);
    if (error != null) throw RepeatRefused(error);
    final schedule = scheduleFor(choice, startOn);
    final (:past, :next) = repeatPreview(
      choice,
      startOn: startOn,
      today: today,
    );
    final wallClock = input.occurredAt.toUtc().add(
      Duration(minutes: input.utcOffsetMinutes),
    );
    final timeOfDay = wallClock.hour * 60 + wallClock.minute;
    final expense = await _db.transaction((txn) async {
      // Checked before anything is written, though a throw rolls it all
      // back anyway.
      if (id != null) await _plainActiveRow(txn, id);
      final itemId = await RecurringRepository.insertTemplate(
        txn,
        NewRecurringItem(
          title: input.title,
          description: input.description,
          amount: input.amount,
          categoryId: input.categoryId,
          paymentMethodId: input.paymentMethodId,
          eventIds: input.eventIds,
          schedule: schedule,
          timeOfDayMinutes: timeOfDay,
          nextDueOn: next,
        ),
        nowMs,
      );
      final link = {
        'recurring_expense_id': itemId,
        'recurring_due_on': startOn,
      };
      final int expenseId;
      if (id == null) {
        expenseId = await txn.insert('expenses', {
          ..._columns(input),
          ...link,
          'created_at': nowMs,
          'updated_at': nowMs,
        });
        await _insertEvents(txn, expenseId, input.eventIds);
        await _linkPhotos(txn, expenseId, input.photos, nowMs);
        await _markSms(txn, fromSms, expenseId, input, nowMs);
      } else {
        expenseId = id;
        await _overwrite(txn, id, input, nowMs, extra: link);
      }
      await insertPayments(txn, itemId, [
        for (final day in past)
          if (paymentMoment(day, timeOfDay, localMoment: _localMoment)
              case final moment)
            PaymentInput(
              recurringExpenseId: itemId,
              dueOn: day,
              title: input.title,
              description: input.description,
              // One price so far: the first, from the start.
              amount: input.amount,
              occurredAt: moment.occurredAt,
              utcOffsetMinutes: moment.offsetMinutes,
              categoryId: input.categoryId,
              paymentMethodId: input.paymentMethodId,
            ),
      ], nowMs: nowMs);
      if (clearDraft) await _deleteDraft(txn);
      return (await _read(txn, where: 'id = ?', whereArgs: [expenseId])).single;
    });
    _dataVersion.bump();
    return (expense: expense, pastAdded: past.length);
  }

  /// Saves [input] over the active expense [id] and replaces its events, in one
  /// transaction. Throws [ExpenseNotFound] if the expense was deleted or moved
  /// to the bin meanwhile: binned expenses can't be edited. [clearDraft] as for
  /// [add].
  Future<Expense> update(
    int id,
    ExpenseInput input, {
    bool clearDraft = false,
  }) async {
    final now = _now().millisecondsSinceEpoch;
    final expense = await _db.transaction((txn) async {
      await _overwrite(txn, id, input, now);
      if (clearDraft) await _deleteDraft(txn);
      return (await _read(txn, where: 'id = ?', whereArgs: [id])).single;
    });
    _dataVersion.bump();
    return expense;
  }

  /// [input] over the active expense [id] (with [extra] columns), its
  /// events and photos replaced, inside [txn]: [update]'s and
  /// [updateRepeating]'s. [ExpenseNotFound] when it is binned or gone.
  static Future<void> _overwrite(
    Transaction txn,
    int id,
    ExpenseInput input,
    int nowMs, {
    Map<String, Object?> extra = const {},
  }) async {
    final changed = await txn.update(
      'expenses',
      {..._columns(input), ...extra, 'updated_at': nowMs},
      where: 'id = ? AND $_active',
      whereArgs: [id],
    );
    if (changed == 0) throw ExpenseNotFound(id);
    await txn.delete(
      'expense_events',
      where: 'expense_id = ?',
      whereArgs: [id],
    );
    await _insertEvents(txn, id, input.eventIds);
    // Replaced like the events: the rows of photos no longer linked stay until
    // the startup sweep.
    await txn.delete(
      'expense_photos',
      where: 'expense_id = ?',
      whereArgs: [id],
    );
    await _linkPhotos(txn, id, input.photos, nowMs);
  }

  /// Checks that [id] is active ([ExpenseNotFound]) and not a payment yet
  /// ([ArgumentError]): only a plain expense is made to repeat.
  static Future<void> _plainActiveRow(Transaction txn, int id) async {
    final rows = await txn.query(
      'expenses',
      columns: ['recurring_expense_id'],
      where: 'id = ? AND $_active',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw ExpenseNotFound(id);
    final itemId = rows.single['recurring_expense_id'];
    if (itemId != null) {
      throw ArgumentError.value(id, 'id', 'a payment of item $itemId already');
    }
  }

  /// The active expense [id], or null if it is in the bin or gone.
  Future<Expense?> byId(int id) async => (await _read(
    _db,
    where: 'id = ? AND $_active',
    whereArgs: [id],
  )).firstOrNull;

  /// Active expenses that pass [filter]'s category and event part, in list
  /// order (local date, then moment, then id), continuing after [after] (keyset
  /// pagination). Its text part is matched in Dart ([searchEntries]). Row
  /// values need SQLite 3.15; Android 10 (minSdk 29) ships 3.22.
  Future<List<Expense>> page({
    ExpenseFilter filter = ExpenseFilter.none,
    ExpenseCursor? after,
    int limit = 30,
  }) => _read(
    _db,
    where: [
      _active,
      ...expenseFilterSql(filter),
      if (after != null) '(occurred_on, occurred_at, id) < (?, ?, ?)',
    ].join(' AND '),
    whereArgs: after == null
        ? null
        : [after.occurredOn, after.occurredAtMs, after.id],
    orderBy: _listOrder,
    limit: limit,
  );

  /// The rows a total from [from] to [to] (inclusive) covers, for [filter]'s
  /// category and event part: date, currency and amount. The adding is Dart's
  /// (`sumByCurrency`, a `BigInt`; no SQL `SUM`, which throws at 2⁶³).
  /// Future-dated rows are included; drafts are another table.
  Future<List<AmountRow>> amountsIn({
    required String from,
    required String to,
    ExpenseFilter filter = ExpenseFilter.none,
  }) async {
    final rows = await _db.query(
      'expenses',
      columns: ['occurred_on', 'currency_code', 'amount_minor'],
      where: [
        _active,
        ...expenseFilterSql(filter),
        'occurred_on BETWEEN ? AND ?',
      ].join(' AND '),
      whereArgs: [from, to],
    );
    return [
      for (final row in rows)
        (
          row['occurred_on']! as String,
          row['currency_code']! as String,
          row['amount_minor']! as int,
        ),
    ];
  }

  /// Every active expense that passes [filter]'s category and event part, in
  /// list order, as the text filter sees it: read once when a text filter is
  /// applied, then matched in Dart.
  Future<List<SearchEntry>> searchEntries({
    ExpenseFilter filter = ExpenseFilter.none,
  }) async {
    final rows = await _db.query(
      'expenses',
      columns: [
        'id',
        'occurred_on',
        'occurred_at',
        'amount_minor',
        'currency_code',
        'title',
        'description',
      ],
      where: [_active, ...expenseFilterSql(filter)].join(' AND '),
      orderBy: _listOrder,
    );
    return [
      for (final row in rows)
        (
          id: row['id']! as int,
          day: row['occurred_on']! as String,
          occurredAtMs: row['occurred_at']! as int,
          amountMinor: row['amount_minor']! as int,
          currencyCode: row['currency_code']! as String,
          folded: foldForSearch(
            row['title']! as String,
            row['description'] as String?,
          ),
        ),
    ];
  }

  /// The active expenses among [ids], with their events, in list order.
  /// Ids not found (binned or deleted meanwhile) are left out. Sent in
  /// chunks, for SQLite 3.22's 999-variable limit.
  Future<List<Expense>> byIds(List<int> ids) async {
    final found = await inChunks(
      ids,
      (chunk) => _read(
        _db,
        where: 'id IN (${sqlPlaceholders(chunk.length)}) AND $_active',
        whereArgs: chunk,
      ),
    );
    return found..sort(_compareListOrder);
  }

  /// Moves the active expense [id] to the bin. `updated_at` is left alone: the
  /// expense itself didn't change. Throws [ExpenseNotFound] if it was already
  /// binned or is gone, so nobody offers Undo for nothing. [clearDraft] as for
  /// [add].
  Future<void> moveToBin(int id, {bool clearDraft = false}) async {
    await _db.transaction((txn) async {
      final changed = await txn.update(
        'expenses',
        {'deleted_at': _now().millisecondsSinceEpoch},
        where: 'id = ? AND $_active',
        whereArgs: [id],
      );
      if (changed == 0) throw ExpenseNotFound(id);
      if (clearDraft) await _deleteDraft(txn);
    });
    _dataVersion.bump();
  }

  /// Takes [id] out of the bin. Does nothing if it isn't there (e.g. the
  /// bin was emptied before Undo was tapped).
  Future<void> restore(int id) async {
    await _db.update(
      'expenses',
      {'deleted_at': null},
      where: 'id = ? AND $_binned',
      whereArgs: [id],
    );
    _dataVersion.bump();
  }

  Future<void> restoreAll() async {
    await _db.update('expenses', {'deleted_at': null}, where: _binned);
    _dataVersion.bump();
  }

  /// Everything in the bin, most recently deleted first. No limit: the bin
  /// holds at most 30 days of deletions.
  Future<List<Expense>> binned() =>
      _read(_db, where: _binned, orderBy: 'deleted_at DESC, id DESC');

  /// Deletes the binned expense [id] for good; its event and photo links
  /// cascade. Only matches binned rows, so an active expense can never be
  /// hard-deleted by mistake. Its photo rows and files stay until the startup
  /// sweep, which deletes only what nothing references.
  Future<void> deletePermanently(int id) async {
    await _db.delete('expenses', where: 'id = ? AND $_binned', whereArgs: [id]);
    _dataVersion.bump();
  }

  /// Deletes everything in the bin for good. Photos as for
  /// [deletePermanently].
  Future<void> emptyBin() async {
    await _db.delete('expenses', where: _binned);
    _dataVersion.bump();
  }

  /// Deletes, in one transaction, the expenses binned more than [binRetention]
  /// ago. Returns how many. Runs at startup, before the photo sweep, which then
  /// frees their photos.
  Future<int> purgeBin() async {
    final cutoff = _now().subtract(binRetention).millisecondsSinceEpoch;
    final count = await _db.transaction(
      (txn) =>
          txn.delete('expenses', where: 'deleted_at < ?', whereArgs: [cutoff]),
    );
    _dataVersion.bump();
    return count;
  }

  // Photos.

  /// The photos of expense [id] (active or binned), in order.
  Future<List<SavedPhoto>> photosOf(int id) async =>
      (await _photosOfMany(_db, [id]))[id] ?? const [];

  /// Which of [photoIds] still have a row: a draft's saved photos are checked
  /// with it when the form opens.
  Future<Set<int>> existingPhotoIds(Iterable<int> photoIds) async {
    final rows = await inChunks(
      photoIds.toSet().toList(),
      (chunk) => _db.query(
        'photos',
        columns: ['id'],
        where: 'id IN (${sqlPlaceholders(chunk.length)})',
        whereArgs: chunk,
      ),
    );
    return {for (final row in rows) row['id']! as int};
  }

  /// How many photos the expenses have, active and binned, and their bytes
  /// (Settings → Photos, the backup screen). Rows no expense links any more
  /// are left out: the next start's sweep deletes them. The bytes are
  /// added in Dart from the rows (no SQL `SUM`).
  Future<({int count, int bytes})> photoStats() async {
    final rows = await _db.rawQuery(
      'SELECT byte_size FROM photos '
      'WHERE id IN (SELECT photo_id FROM expense_photos)',
    );
    return (
      count: rows.length,
      bytes: rows.fold(0, (sum, row) => sum + (row['byte_size']! as int)),
    );
  }

  /// Whether any active expense has a photo: Home's photos icon shows only
  /// then.
  Future<bool> hasPhotos() async => (await _db.rawQuery(
    'SELECT 1 FROM expenses WHERE $_active '
    'AND id IN (SELECT expense_id FROM expense_photos) LIMIT 1',
  )).isNotEmpty;

  /// Whether [filter] lets through any active expense with a photo: the icon is
  /// greyed out when it doesn't. The category and event part is SQL; a text
  /// part is matched in Dart, like Home's list.
  Future<bool> hasMatchingPhotos(ExpenseFilter filter) async {
    if (!filter.hasText) {
      return (await _db.rawQuery(
        'SELECT 1 FROM expenses WHERE '
        '${[_active, ...expenseFilterSql(filter), _withPhotos].join(' AND ')} '
        'LIMIT 1',
      )).isNotEmpty;
    }
    return (await textMatchesWithPhotos(filter)).isNotEmpty;
  }

  /// The ids of [filter]'s text matches (among its category and event part)
  /// that have photos, in list order: the Photos screen's text path and
  /// [hasMatchingPhotos]'.
  Future<List<int>> textMatchesWithPhotos(ExpenseFilter filter) async {
    final words = searchWords(filter.text);
    return withPhotos([
      for (final entry in await searchEntries(filter: filter.withoutText))
        if (matchesText(entry, words)) entry,
    ]);
  }

  /// The ids of [entries] that have photos, in their order. Home passes
  /// the text matches it already read, for its photos icon.
  Future<List<int>> withPhotos(Iterable<SearchEntry> entries) async {
    final ids = await expenseIdsWithPhotos();
    return [
      for (final entry in entries)
        if (ids.contains(entry.id)) entry.id,
    ];
  }

  /// Every expense id that has a photo, binned ones too: text matches are
  /// intersected with it ([withPhotos]).
  Future<Set<int>> expenseIdsWithPhotos() async => {
    for (final row in await _db.rawQuery(
      'SELECT DISTINCT expense_id FROM expense_photos',
    ))
      row['expense_id']! as int,
  };

  /// A page of the Photos screen: active expenses **with photos** that pass
  /// [filter]'s category and event part, in Home's order, after [after], each
  /// with its photos in order. Keyset by expense, so an expense's photos are
  /// never split across pages.
  Future<List<PhotoExpense>> photoExpensesPage({
    ExpenseFilter filter = ExpenseFilter.none,
    ExpenseCursor? after,
    int limit = 30,
  }) async {
    final expenses = await _read(
      _db,
      where: [
        _active,
        ...expenseFilterSql(filter),
        _withPhotos,
        if (after != null) '(occurred_on, occurred_at, id) < (?, ?, ?)',
      ].join(' AND '),
      whereArgs: after == null
          ? null
          : [after.occurredOn, after.occurredAtMs, after.id],
      orderBy: _listOrder,
      limit: limit,
    );
    return _withTheirPhotos(expenses);
  }

  /// The active expenses among [ids] that have photos, each with its
  /// photos, in Home's order: the Photos screen's text path, 30 ids at a
  /// time.
  Future<List<PhotoExpense>> photoExpensesByIds(List<int> ids) async =>
      _withTheirPhotos([
        for (final e in await byIds(ids))
          if (e.photoCount > 0) e,
      ]);

  Future<List<PhotoExpense>> _withTheirPhotos(List<Expense> expenses) async {
    final photos = await _photosOfMany(_db, [for (final e in expenses) e.id]);
    return [
      for (final e in expenses) (expense: e, photos: photos[e.id] ?? const []),
    ];
  }

  /// Deletes the [links] (expense, photo) from their expenses at once, in one
  /// transaction: the Photos screen's Delete (owner rev 6). Only **active**
  /// expenses are changed (one binned or deleted since the screen loaded is
  /// skipped); each changed expense's remaining photos are numbered 0.. again
  /// in their order, and its `updated_at` moves. Returns how many links went
  /// and the expenses that lost some: only their Edit drafts may drop the
  /// photos (a skipped expense keeps them). The rows and files stay for the
  /// sweep.
  Future<({int count, Set<int> expenseIds})> removePhotoLinks(
    List<({int expenseId, int photoId})> links,
  ) async {
    final byExpense = <int, Set<int>>{};
    for (final link in links) {
      byExpense.putIfAbsent(link.expenseId, () => {}).add(link.photoId);
    }
    if (byExpense.isEmpty) return (count: 0, expenseIds: <int>{});
    final now = _now().millisecondsSinceEpoch;
    final changed = <int>{};
    final removed = await _db.transaction((txn) async {
      var removed = 0;
      for (final MapEntry(key: expenseId, value: photoIds)
          in byExpense.entries) {
        final active = await txn.query(
          'expenses',
          columns: ['id'],
          where: 'id = ? AND $_active',
          whereArgs: [expenseId],
        );
        if (active.isEmpty) continue;
        // Ints from the app's own rows, as literals (like the filter's).
        final count = await txn.delete(
          'expense_photos',
          where: 'expense_id = ? AND photo_id IN (${sqlIdList(photoIds)})',
          whereArgs: [expenseId],
        );
        if (count == 0) continue;
        removed += count;
        changed.add(expenseId);
        final rest = await txn.query(
          'expense_photos',
          columns: ['photo_id'],
          where: 'expense_id = ?',
          whereArgs: [expenseId],
          orderBy: 'sort_order, photo_id',
        );
        for (final (i, row) in rest.indexed) {
          await txn.update(
            'expense_photos',
            {'sort_order': i},
            where: 'expense_id = ? AND photo_id = ?',
            whereArgs: [expenseId, row['photo_id']],
          );
        }
        await txn.update(
          'expenses',
          {'updated_at': now},
          where: 'id = ?',
          whereArgs: [expenseId],
        );
      }
      return removed;
    });
    if (removed > 0) _dataVersion.bump();
    return (count: removed, expenseIds: changed);
  }

  /// Per category id: active uses in the last 90 days and the most recent
  /// use. Expenses dated after today are left out, so a booking for next
  /// month doesn't count as "most recent". Categories without uses are
  /// missing from the map.
  Future<Map<int, ItemUsage>> categoryUsage() async {
    final (from, today) = _window(popularityWindowDays);
    final rows = await _db.rawQuery(
      'SELECT category_id AS id, '
      'SUM(occurred_on >= ?) AS recent, MAX(occurred_at) AS last '
      'FROM expenses WHERE $_active AND occurred_on <= ? '
      'GROUP BY category_id',
      [from, today],
    );
    return _usageMap(rows);
  }

  /// Like [categoryUsage], per event id.
  Future<Map<int, ItemUsage>> eventUsage() async {
    final (from, today) = _window(popularityWindowDays);
    final rows = await _db.rawQuery(
      'SELECT ee.event_id AS id, '
      'SUM(e.occurred_on >= ?) AS recent, MAX(e.occurred_at) AS last '
      'FROM expense_events ee JOIN expenses e ON e.id = ee.expense_id '
      'WHERE +e.deleted_at IS NULL AND e.occurred_on <= ? '
      'GROUP BY ee.event_id',
      [from, today],
    );
    return _usageMap(rows);
  }

  /// The currencies of the most recently **entered** active expenses (by
  /// `created_at`), distinct, newest first. Ordering by `occurred_at` would let
  /// a back- or future-dated expense jump the list.
  Future<List<String>> recentCurrencies({int limit = 5}) async {
    final rows = await _db.rawQuery(
      'SELECT currency_code FROM expenses WHERE $_active '
      'GROUP BY currency_code '
      'ORDER BY MAX(created_at) DESC, MAX(id) DESC LIMIT ?',
      [limit],
    );
    return [for (final row in rows) row['currency_code']! as String];
  }

  /// Every distinct title of the active expenses up to today, exact spellings,
  /// with the newest row's amount and category and the uses in the last
  /// [titleWindowDays]. Grouping spellings and matching happen in Dart
  /// (`title_suggestions.dart`).
  ///
  /// The amount and category are SQLite's bare columns next to the one `MAX()`:
  /// they come from the newest row, any one of them on a tie. Display only;
  /// [prefillSource] is the exact query. The bin filter is in the `WHERE`, so a
  /// binned row is never that row.
  Future<List<TitleHistoryRow>> titleHistory() =>
      titleHistoryOn(_db, now: _now());

  /// [titleHistory] through [db], with "today" taken from [now]: the SMS scan
  /// reads it inside its own transaction, where a read through the database
  /// itself would never return (sqflite's `transaction()` holds the lock).
  static Future<List<TitleHistoryRow>> titleHistoryOn(
    DatabaseExecutor db, {
    required DateTime now,
  }) async {
    final (from, today) = _windowAt(now, titleWindowDays);
    final rows = await db.rawQuery(
      'SELECT title, amount_minor, currency_code, category_id, '
      'MAX(occurred_at) AS last_at, SUM(occurred_on >= ?) AS recent '
      'FROM expenses WHERE $_active AND occurred_on <= ? '
      'GROUP BY title',
      [from, today],
    );
    return [
      for (final row in rows)
        TitleHistoryRow(
          title: row['title']! as String,
          amountMinor: row['amount_minor']! as int,
          currencyCode: row['currency_code']! as String,
          categoryId: row['category_id']! as int,
          lastAt: utcFromEpochMs(row['last_at']! as int),
          recent: row['recent']! as int,
        ),
    ];
  }

  /// The newest active expense, up to today, titled exactly one of [spellings],
  /// with its events: what a picked suggestion prefills the form from. Ties on
  /// `occurred_at` go to the highest id. Null if there is none (it was binned
  /// meanwhile).
  Future<Expense?> prefillSource(List<String> spellings) async {
    if (spellings.isEmpty) return null;
    // A title has a handful of spellings; the cap only keeps the statement
    // under SQLite 3.22's 999 variables.
    final some = spellings.take(maxBoundValues).toList();
    final (_, today) = _window(0);
    return (await _read(
      _db,
      where:
          'title IN (${sqlPlaceholders(some.length)}) '
          'AND $_active AND occurred_on <= ?',
      whereArgs: [...some, today],
      orderBy: 'occurred_at DESC, id DESC',
      limit: 1,
    )).firstOrNull;
  }

  /// Amounts in [currencyCode] used at least [chipMinUses] times in the last
  /// [chipWindowDays] up to today, most used first, then most recent, then
  /// smallest; at most six.
  Future<List<int>> amountChipStats(String currencyCode) async {
    final (from, today) = _window(chipWindowDays);
    final rows = await _db.rawQuery(
      'SELECT amount_minor, COUNT(*) AS uses, MAX(occurred_at) AS last_at '
      'FROM expenses WHERE $_active AND currency_code = ? '
      'AND occurred_on BETWEEN ? AND ? '
      'GROUP BY amount_minor HAVING COUNT(*) >= ? '
      'ORDER BY uses DESC, last_at DESC, amount_minor ASC LIMIT 6',
      [currencyCode, from, today, chipMinUses],
    );
    return [for (final row in rows) row['amount_minor']! as int];
  }

  /// The local date `YYYY-MM-DD` of an expense at [occurredAt] (UTC) with
  /// [utcOffsetMinutes]. The only place `occurred_on` is computed; the rule
  /// itself is [localDayOf], which recurring payments check against.
  static String occurredOnFor(DateTime occurredAt, int utcOffsetMinutes) =>
      localDayOf(occurredAt, utcOffsetMinutes);

  /// Inserts [payments] of recurring item [itemId] and copies the item's events
  /// onto each, inside the caller's transaction ([txn]): the generator's and
  /// Save with Repeats'. Their `occurred_on` is derived like any expense's. A
  /// payment of a due date that has a row already fails on the unique index and
  /// rolls the caller back: callers leave those out.
  ///
  /// In one batch, then one event copy per 500 due dates (found through the
  /// unique index): one statement and channel call per payment made "Add the
  /// first 1,000" take seconds on the Oppo.
  static Future<void> insertPayments(
    Transaction txn,
    int itemId,
    List<PaymentInput> payments, {
    required int nowMs,
  }) async {
    if (payments.isEmpty) return;
    final batch = txn.batch();
    for (final p in payments) {
      if (p.recurringExpenseId != itemId) {
        throw ArgumentError.value(
          p.recurringExpenseId,
          'payment',
          'other item',
        );
      }
      batch.insert('expenses', {
        ..._columns(
          ExpenseInput(
            title: p.title,
            description: p.description,
            amount: p.amount,
            occurredAt: p.occurredAt,
            utcOffsetMinutes: p.utcOffsetMinutes,
            categoryId: p.categoryId,
            paymentMethodId: p.paymentMethodId,
            eventIds: const {},
          ),
        ),
        'recurring_expense_id': itemId,
        'recurring_due_on': p.dueOn,
        'created_at': nowMs,
        'updated_at': nowMs,
      });
    }
    await batch.commit(noResult: true);
    await inChunks([for (final p in payments) p.dueOn], (days) async {
      await txn.rawInsert(
        'INSERT INTO expense_events (expense_id, event_id) '
        'SELECT e.id, r.event_id FROM expenses e '
        'JOIN recurring_expense_events r '
        'ON r.recurring_expense_id = e.recurring_expense_id '
        'WHERE e.recurring_expense_id = ? '
        'AND e.recurring_due_on IN (${sqlPlaceholders(days.length)})',
        [itemId, ...days],
      );
      return const <void>[];
    });
  }

  /// Recurring item [itemId]'s active payments, newest due date first, [limit]
  /// at a time, continuing before the due date [before] (the unique index
  /// serves it).
  static Future<List<Expense>> paymentsOf(
    DatabaseExecutor db,
    int itemId, {
    String? before,
    int limit = 30,
  }) => _read(
    db,
    where: [
      'recurring_expense_id = ?',
      _active,
      if (before != null) 'recurring_due_on < ?',
    ].join(' AND '),
    whereArgs: [itemId, ?before],
    orderBy: 'recurring_due_on DESC',
    limit: limit,
  );

  static Map<String, Object?> _columns(ExpenseInput input) => {
    'title': input.title,
    'description': input.description,
    'amount_minor': input.amount.amountMinor,
    'amount_expression': input.amountExpression,
    'currency_code': input.amount.currencyCode,
    'occurred_at': input.occurredAt.millisecondsSinceEpoch,
    'utc_offset_minutes': input.utcOffsetMinutes,
    // Derived here, in the same write as its source.
    'occurred_on': occurredOnFor(input.occurredAt, input.utcOffsetMinutes),
    'category_id': input.categoryId,
    'payment_method_id': input.paymentMethodId,
  };

  /// Marks the SMS suggestion [link] added as [expenseId] and teaches its
  /// payee's pending suggestions the saved title and category, inside the
  /// save's transaction. Nothing without a link.
  static Future<void> _markSms(
    Transaction txn,
    SmsLink? link,
    int expenseId,
    ExpenseInput input,
    int nowMs,
  ) async {
    if (link == null) return;
    final (:marked, :payeeKey) = await SmsSuggestionRepository.markAddedOn(
      txn,
      link,
      expenseId,
      nowMs,
    );
    if (!marked) return;
    await SmsSuggestionRepository.learnOn(
      txn,
      payeeKey,
      input.title,
      input.categoryId,
      nowMs,
    );
  }

  /// The draft slot's row. The only place this class touches `expense_draft`;
  /// `ExpenseDraftRepository` owns it.
  static Future<void> _deleteDraft(Transaction txn) =>
      txn.delete('expense_draft');

  static Future<void> _insertEvents(
    Transaction txn,
    int expenseId,
    Set<int> eventIds,
  ) async {
    for (final eventId in eventIds) {
      await txn.insert('expense_events', {
        'expense_id': expenseId,
        'event_id': eventId,
      });
    }
  }

  /// Links [photos] to the expense [expenseId] in order, inside the save's own
  /// transaction. A new photo's row is made if its path isn't there yet
  /// (`INSERT OR IGNORE`), then its id read back: the insert's return value is
  /// never used, since an ignored insert returns 0 in tests and -1 on a phone.
  /// A saved photo is linked only if its row still exists, checked in this same
  /// transaction: a row the sweep took meanwhile links nothing, and the form
  /// says so. A photo already linked in this save is skipped, so a duplicate
  /// can't fail the save.
  static Future<void> _linkPhotos(
    Transaction txn,
    int expenseId,
    List<PhotoLinkInput> photos,
    int now,
  ) async {
    final linked = <int>{};
    for (final photo in photos) {
      final photoId = await _photoIdFor(txn, photo, now);
      if (photoId == null || !linked.add(photoId)) continue;
      await txn.insert('expense_photos', {
        'expense_id': expenseId,
        'photo_id': photoId,
        'sort_order': linked.length - 1,
      });
    }
  }

  /// [photo]'s row id: a new photo's row is made first if its path isn't
  /// there; a saved photo's is null when its row is gone.
  static Future<int?> _photoIdFor(
    Transaction txn,
    PhotoLinkInput photo,
    int now,
  ) async {
    switch (photo) {
      case LinkNewPhoto(:final relativePath, :final sha256, :final byteSize):
        if (!isValidPhotoPath(relativePath)) {
          throw ArgumentError.value(relativePath, 'photo', 'not a photo path');
        }
        await txn.rawInsert(
          'INSERT OR IGNORE INTO photos '
          '(relative_path, sha256, byte_size, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?)',
          [relativePath, sha256, byteSize, now, now],
        );
        final rows = await txn.query(
          'photos',
          columns: ['id'],
          where: 'relative_path = ?',
          whereArgs: [relativePath],
        );
        return rows.single['id']! as int;
      case LinkSavedPhoto(:final photoId):
        final rows = await txn.query(
          'photos',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [photoId],
        );
        return rows.isEmpty ? null : photoId;
    }
  }

  /// The photos of [ids], in order, by expense id. In chunks for SQLite
  /// 3.22's 999 variables.
  static Future<Map<int, List<SavedPhoto>>> _photosOfMany(
    DatabaseExecutor db,
    List<int> ids,
  ) async {
    final rows = await inChunks(
      ids,
      (chunk) => db.rawQuery(
        'SELECT ep.expense_id, p.id, p.relative_path, p.sha256, p.byte_size '
        'FROM expense_photos ep JOIN photos p ON p.id = ep.photo_id '
        'WHERE ep.expense_id IN (${sqlPlaceholders(chunk.length)}) '
        'ORDER BY ep.expense_id, ep.sort_order, p.id',
        chunk,
      ),
    );
    final photos = <int, List<SavedPhoto>>{};
    for (final row in rows) {
      photos
          .putIfAbsent(row['expense_id']! as int, () => [])
          .add(
            SavedPhoto(
              id: row['id']! as int,
              relativePath: row['relative_path']! as String,
              sha256: row['sha256']! as String,
              byteSize: row['byte_size']! as int,
            ),
          );
    }
    return photos;
  }

  /// Reads expenses with their events. Every method that returns expenses
  /// goes through here, so events are always loaded in full.
  static Future<List<Expense>> _read(
    DatabaseExecutor db, {
    required String where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final rows = await db.query(
      'expenses',
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
    final events = <int, Set<int>>{};
    final ids = [for (final row in rows) row['id']! as int];
    final links = await inChunks(
      ids,
      (chunk) => db.query(
        'expense_events',
        columns: ['expense_id', 'event_id'],
        where: 'expense_id IN (${sqlPlaceholders(chunk.length)})',
        whereArgs: chunk,
      ),
    );
    for (final link in links) {
      events
          .putIfAbsent(link['expense_id']! as int, () => {})
          .add(link['event_id']! as int);
    }
    final photoCounts = {
      for (final row in await inChunks(
        ids,
        (chunk) => db.rawQuery(
          'SELECT expense_id, count(*) AS n FROM expense_photos '
          'WHERE expense_id IN (${sqlPlaceholders(chunk.length)}) '
          'GROUP BY expense_id',
          chunk,
        ),
      ))
        row['expense_id']! as int: row['n']! as int,
    };
    return [
      for (final row in rows)
        _fromRow(
          row,
          events[row['id']! as int] ?? {},
          photoCounts[row['id']! as int] ?? 0,
        ),
    ];
  }

  static Expense _fromRow(
    Map<String, Object?> row,
    Set<int> eventIds,
    int photoCount,
  ) => Expense(
    id: row['id']! as int,
    title: row['title']! as String,
    description: row['description'] as String?,
    amount: Money(row['amount_minor']! as int, row['currency_code']! as String),
    amountExpression: row['amount_expression'] as String?,
    occurredAt: utcFromEpochMs(row['occurred_at']! as int),
    utcOffsetMinutes: row['utc_offset_minutes']! as int,
    occurredOn: row['occurred_on']! as String,
    categoryId: row['category_id']! as int,
    paymentMethodId: row['payment_method_id']! as int,
    eventIds: eventIds,
    createdAt: utcFromEpochMs(row['created_at']! as int),
    updatedAt: utcFromEpochMs(row['updated_at']! as int),
    deletedAt: switch (row['deleted_at']) {
      final int millis => utcFromEpochMs(millis),
      _ => null,
    },
    photoCount: photoCount,
    recurringExpenseId: row['recurring_expense_id'] as int?,
    recurringDueOn: row['recurring_due_on'] as String?,
  );

  /// Today's `occurred_on` on the device and the one [days] before it.
  (String from, String today) _window(int days) => _windowAt(_now(), days);

  static (String from, String today) _windowAt(DateTime now, int days) {
    final local = now.toLocal();
    // Calendar arithmetic in UTC, so a DST change can't shift the date.
    final today = DateTime.utc(local.year, local.month, local.day);
    return (isoDay(today.subtract(Duration(days: days))), isoDay(today));
  }

  /// Has at least one photo.
  static const _withPhotos = 'id IN (SELECT expense_id FROM expense_photos)';

  /// [_listOrder] in Dart, for rows read in chunks.
  static int _compareListOrder(Expense a, Expense b) {
    final byDay = b.occurredOn.compareTo(a.occurredOn);
    if (byDay != 0) return byDay;
    final byMoment = b.occurredAt.compareTo(a.occurredAt);
    return byMoment != 0 ? byMoment : b.id.compareTo(a.id);
  }

  static Map<int, ItemUsage> _usageMap(List<Map<String, Object?>> rows) => {
    for (final row in rows)
      row['id']! as int: (
        recentCount: row['recent']! as int,
        lastUsedAt: utcFromEpochMs(row['last']! as int),
      ),
  };
}
