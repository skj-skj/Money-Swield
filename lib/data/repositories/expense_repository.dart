import 'package:sqflite/sqflite.dart';

import '../../domain/expense_filter.dart';
import '../../domain/models/expense.dart';
import '../../domain/models/money.dart';
import '../../domain/periods.dart';
import '../../domain/popularity.dart';
import '../../domain/title_suggestions.dart';
import '../../domain/totals.dart';
import '../services/database/sql_helpers.dart';
import 'data_version.dart';

/// Thrown by [ExpenseRepository.update] and [ExpenseRepository.moveToBin]
/// when the expense was deleted or moved to the bin meanwhile. An exception rather than a `StateError`, so
/// the form can catch exactly this case and nothing else.
class ExpenseNotFound implements Exception {
  const ExpenseNotFound(this.id);

  final int id;

  @override
  String toString() => 'ExpenseNotFound: expense $id is binned or gone';
}

/// Reads and writes the `expenses` and `expense_events` tables
/// (database.md §3.5, §3.6; phase-2.md §5).
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
  }) : _now = now ?? DateTime.now;

  final Database _db;
  final DataVersion _dataVersion;
  final DateTime Function() _now;

  /// How long an expense stays in the bin before the startup purge deletes
  /// it for good.
  static const binRetention = Duration(days: 30);

  /// The window popularity counts uses in (application-design.md A3).
  static const popularityWindowDays = 90;

  /// The window title suggestions count uses in (phase-4.md §6.1).
  static const titleWindowDays = 180;

  /// The window amount chips count uses in (phase-4.md §6.2).
  static const chipWindowDays = 90;

  /// The fewest uses an amount needs to be a chip.
  static const chipMinUses = 2;

  /// The bin filter, in one place: every method except the bin ones uses it.
  ///
  /// The unary `+` is deliberate: it stops SQLite from using
  /// `index_expenses_on_deleted_at` for this term. Without `ANALYZE` stats
  /// the planner treats `IS NULL` like a selective equality, picks that
  /// index, then reads every active row and sorts it, which defeats keyset
  /// pagination. A partial index would be the textbook fix, but the
  /// migration framework doesn't support them (phase-2.md §3, §5).
  static const _active = '+deleted_at IS NULL';

  /// For the bin queries, which do use the `deleted_at` index.
  static const _binned = 'deleted_at IS NOT NULL';

  /// Home's list order (phase-5.md §4.1, R1): by local date first, so a
  /// traveller's day stays together, then newest moment, then id. Served
  /// by `index_expenses_on_occurred_on_and_occurred_at_and_id`.
  static const _listOrder = 'occurred_on DESC, occurred_at DESC, id DESC';

  /// Inserts the expense and its events in one transaction.
  ///
  /// With [clearDraft], the form's draft row is deleted in the same
  /// transaction (phase-4.md §6.3): killed after the commit, there is no
  /// draft left to save the same expense twice; killed before, nothing was
  /// saved and the draft is still there.
  Future<Expense> add(ExpenseInput input, {bool clearDraft = false}) async {
    final now = _now().millisecondsSinceEpoch;
    final expense = await _db.transaction((txn) async {
      final id = await txn.insert('expenses', {
        ..._columns(input),
        'created_at': now,
        'updated_at': now,
      });
      await _insertEvents(txn, id, input.eventIds);
      if (clearDraft) await _deleteDraft(txn);
      return (await _read(txn, where: 'id = ?', whereArgs: [id])).single;
    });
    _dataVersion.bump();
    return expense;
  }

  /// Saves [input] over the active expense [id] and replaces its events, in
  /// one transaction. Throws [ExpenseNotFound] if the expense was deleted or
  /// moved to the bin meanwhile: binned expenses can't be edited
  /// (database.md §3.5). [clearDraft] as for [add].
  Future<Expense> update(
    int id,
    ExpenseInput input, {
    bool clearDraft = false,
  }) async {
    final now = _now().millisecondsSinceEpoch;
    final expense = await _db.transaction((txn) async {
      final changed = await txn.update(
        'expenses',
        {..._columns(input), 'updated_at': now},
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
      if (clearDraft) await _deleteDraft(txn);
      return (await _read(txn, where: 'id = ?', whereArgs: [id])).single;
    });
    _dataVersion.bump();
    return expense;
  }

  /// The active expense [id], or null if it is in the bin or gone.
  Future<Expense?> byId(int id) async => (await _read(
    _db,
    where: 'id = ? AND $_active',
    whereArgs: [id],
  )).firstOrNull;

  /// Active expenses that pass [filter]'s category and event part, in list
  /// order (local date, then moment, then id; phase-5.md §4.1),
  /// continuing after [after] (keyset pagination, database.md §4). Its
  /// text part is matched in Dart ([searchEntries]). Row values need
  /// SQLite 3.15; Android 10 (minSdk 29) ships 3.22.
  Future<List<Expense>> page({
    ExpenseFilter filter = ExpenseFilter.none,
    ExpenseCursor? after,
    int limit = 30,
  }) => _read(
    _db,
    where: [
      _active,
      ..._filterWhere(filter),
      if (after != null) '(occurred_on, occurred_at, id) < (?, ?, ?)',
    ].join(' AND '),
    whereArgs: after == null
        ? null
        : [after.occurredOn, after.occurredAtMs, after.id],
    orderBy: _listOrder,
    limit: limit,
  );

  /// The rows a total from [from] to [to] (inclusive) covers, for
  /// [filter]'s category and event part: date, currency and amount. The
  /// adding is Dart's (`sumByCurrency`, a `BigInt`; no SQL `SUM`, which
  /// throws at 2⁶³, phase-5.md R3). Future-dated rows are included
  /// (P5-13); drafts are another table.
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
        ..._filterWhere(filter),
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

  /// Every active expense that passes [filter]'s category and event part,
  /// in list order, as the text filter sees it (phase-5.md §6.3): read
  /// once when a text filter is applied, then matched in Dart.
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
      where: [_active, ..._filterWhere(filter)].join(' AND '),
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

  /// Moves the active expense [id] to the bin. `updated_at` is left alone:
  /// the expense itself didn't change. Throws [ExpenseNotFound] if it was
  /// already binned or is gone, so nobody offers Undo for nothing (R14).
  /// [clearDraft] as for [add].
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

  /// Deletes the binned expense [id] for good; its event links cascade.
  /// Only matches binned rows, so an active expense can never be
  /// hard-deleted by mistake.
  Future<void> deletePermanently(int id) async {
    // Phase 6 adds the orphan-photo cleanup here.
    await _db.delete('expenses', where: 'id = ? AND $_binned', whereArgs: [id]);
    _dataVersion.bump();
  }

  /// Deletes everything in the bin for good.
  Future<void> emptyBin() async {
    // Phase 6 adds the orphan-photo cleanup here.
    await _db.delete('expenses', where: _binned);
    _dataVersion.bump();
  }

  /// Deletes, in one transaction, the expenses binned more than
  /// [binRetention] ago. Returns how many. Runs at startup.
  Future<int> purgeBin() async {
    final cutoff = _now().subtract(binRetention).millisecondsSinceEpoch;
    final count = await _db.transaction(
      // Phase 6 adds the orphan-photo cleanup here.
      (txn) =>
          txn.delete('expenses', where: 'deleted_at < ?', whereArgs: [cutoff]),
    );
    _dataVersion.bump();
    return count;
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

  /// The currencies of the most recently **entered** active expenses
  /// (by `created_at`), distinct, newest first. Ordering by `occurred_at`
  /// would let a back- or future-dated expense jump the list (P2-15).
  Future<List<String>> recentCurrencies({int limit = 5}) async {
    final rows = await _db.rawQuery(
      'SELECT currency_code FROM expenses WHERE $_active '
      'GROUP BY currency_code '
      'ORDER BY MAX(created_at) DESC, MAX(id) DESC LIMIT ?',
      [limit],
    );
    return [for (final row in rows) row['currency_code']! as String];
  }

  /// Every distinct title of the active expenses up to today, exact
  /// spellings, with the newest row's amount and category and the uses in
  /// the last [titleWindowDays] (phase-4.md §6.1). Grouping spellings and
  /// matching happen in Dart (`title_suggestions.dart`).
  ///
  /// The amount and category are SQLite's bare columns next to the one
  /// `MAX()`: they come from the newest row, any one of them on a tie
  /// (sqlite.md §5.3). Display only; [prefillSource] is the exact query.
  /// The bin filter is in the `WHERE`, so a binned row is never that row.
  Future<List<TitleHistoryRow>> titleHistory() async {
    final (from, today) = _window(titleWindowDays);
    final rows = await _db.rawQuery(
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

  /// The newest active expense, up to today, titled exactly one of
  /// [spellings], with its events: what a picked suggestion prefills the
  /// form from (phase-4.md §6.1). Ties on `occurred_at` go to the highest
  /// id. Null if there is none (it was binned meanwhile).
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

  /// Amounts in [currencyCode] used at least [chipMinUses] times in the
  /// last [chipWindowDays] up to today, most used first, then most recent,
  /// then smallest; at most six (phase-4.md §6.2).
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
  /// [utcOffsetMinutes]. The only place `occurred_on` is computed.
  static String occurredOnFor(DateTime occurredAt, int utcOffsetMinutes) =>
      isoDay(occurredAt.toUtc().add(Duration(minutes: utcOffsetMinutes)));

  Map<String, Object?> _columns(ExpenseInput input) => {
    'title': input.title,
    'description': input.description,
    'amount_minor': input.amount.amountMinor,
    'amount_expression': input.amountExpression,
    'currency_code': input.amount.currencyCode,
    'occurred_at': input.occurredAt.millisecondsSinceEpoch,
    'utc_offset_minutes': input.utcOffsetMinutes,
    // Derived here, in the same write as its source (database.md §1).
    'occurred_on': occurredOnFor(input.occurredAt, input.utcOffsetMinutes),
    'category_id': input.categoryId,
    'payment_method_id': input.paymentMethodId,
  };

  /// The draft slot's row. The only place this class touches
  /// `expense_draft` (phase-4.md §6.3); `ExpenseDraftRepository` owns it.
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
    return [
      for (final row in rows) _fromRow(row, events[row['id']! as int] ?? {}),
    ];
  }

  static Expense _fromRow(Map<String, Object?> row, Set<int> eventIds) =>
      Expense(
        id: row['id']! as int,
        title: row['title']! as String,
        description: row['description'] as String?,
        amount: Money(
          row['amount_minor']! as int,
          row['currency_code']! as String,
        ),
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
      );

  /// Today's `occurred_on` on the device and the one [days] before it.
  (String from, String today) _window(int days) {
    final local = _now().toLocal();
    // Calendar arithmetic in UTC, so a DST change can't shift the date.
    final today = DateTime.utc(local.year, local.month, local.day);
    return (isoDay(today.subtract(Duration(days: days))), isoDay(today));
  }

  /// [filter]'s category and event part as SQL terms (phase-5.md §6.1).
  /// The ids are written into the SQL as literals, so a long selection
  /// never meets the 999-variable limit; they're `int`s from the app's
  /// own models, never text, so nothing can be injected.
  static List<String> _filterWhere(ExpenseFilter filter) => [
    if (filter.categoryIds.isNotEmpty)
      'category_id IN (${_idList(filter.categoryIds)})',
    if (filter.eventIds.isNotEmpty) _withAnyEvent(filter.eventIds),
  ];

  /// Any one of [eventIds]: an expense with two of them is still one row.
  static String _withAnyEvent(Set<int> eventIds) =>
      'id IN (SELECT expense_id FROM expense_events '
      'WHERE event_id IN (${_idList(eventIds)}))';

  static String _idList(Set<int> ids) => (ids.toList()..sort()).join(', ');

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
