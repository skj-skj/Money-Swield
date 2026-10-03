import 'package:sqflite/sqflite.dart';

import '../../domain/models/expense.dart';
import '../../domain/models/money.dart';
import '../../domain/popularity.dart';
import 'data_version.dart';

/// Thrown by [ExpenseRepository.update] when the expense was deleted or
/// moved to the bin meanwhile. An exception rather than a `StateError`, so
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

  /// Android 10–11 ship SQLite versions that allow at most 999 bound
  /// variables per statement, so `IN (…)` lists are sent in chunks.
  static const _maxIdsPerQuery = 500;

  /// Inserts the expense and its events in one transaction.
  Future<Expense> add(ExpenseInput input) async {
    final now = _now().millisecondsSinceEpoch;
    final expense = await _db.transaction((txn) async {
      final id = await txn.insert('expenses', {
        ..._columns(input),
        'created_at': now,
        'updated_at': now,
      });
      await _insertEvents(txn, id, input.eventIds);
      return (await _read(txn, where: 'id = ?', whereArgs: [id])).single;
    });
    _dataVersion.bump();
    return expense;
  }

  /// Saves [input] over the active expense [id] and replaces its events, in
  /// one transaction. Throws [ExpenseNotFound] if the expense was deleted or
  /// moved to the bin meanwhile: binned expenses can't be edited
  /// (database.md §3.5).
  Future<Expense> update(int id, ExpenseInput input) async {
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

  /// Active expenses, newest first, continuing after [after] (keyset
  /// pagination, database.md §4). Row values need SQLite 3.15; Android 10
  /// (minSdk 29) ships 3.22.
  Future<List<Expense>> page({ExpenseCursor? after, int limit = 30}) => _read(
    _db,
    where: after == null ? _active : '$_active AND (occurred_at, id) < (?, ?)',
    whereArgs: after == null ? null : [after.occurredAtMs, after.id],
    orderBy: 'occurred_at DESC, id DESC',
    limit: limit,
  );

  /// Moves the active expense [id] to the bin. `updated_at` is left alone:
  /// the expense itself didn't change.
  Future<void> moveToBin(int id) async {
    await _db.update(
      'expenses',
      {'deleted_at': _now().millisecondsSinceEpoch},
      where: 'id = ? AND $_active',
      whereArgs: [id],
    );
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
    final (from, today) = _popularityWindow();
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
    final (from, today) = _popularityWindow();
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

  /// The local date `YYYY-MM-DD` of an expense at [occurredAt] (UTC) with
  /// [utcOffsetMinutes]. The only place `occurred_on` is computed.
  static String occurredOnFor(DateTime occurredAt, int utcOffsetMinutes) =>
      _isoDate(occurredAt.toUtc().add(Duration(minutes: utcOffsetMinutes)));

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
    for (var start = 0; start < ids.length; start += _maxIdsPerQuery) {
      final chunk = ids.sublist(
        start,
        (start + _maxIdsPerQuery).clamp(0, ids.length),
      );
      final links = await db.query(
        'expense_events',
        columns: ['expense_id', 'event_id'],
        where: 'expense_id IN (${List.filled(chunk.length, '?').join(', ')})',
        whereArgs: chunk,
      );
      for (final link in links) {
        events
            .putIfAbsent(link['expense_id']! as int, () => {})
            .add(link['event_id']! as int);
      }
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
        occurredAt: _dateTime(row['occurred_at']! as int),
        utcOffsetMinutes: row['utc_offset_minutes']! as int,
        occurredOn: row['occurred_on']! as String,
        categoryId: row['category_id']! as int,
        paymentMethodId: row['payment_method_id']! as int,
        eventIds: eventIds,
        createdAt: _dateTime(row['created_at']! as int),
        updatedAt: _dateTime(row['updated_at']! as int),
        deletedAt: switch (row['deleted_at']) {
          final int millis => _dateTime(millis),
          _ => null,
        },
      );

  /// The first and last `occurred_on` popularity counts: today on the
  /// device and [popularityWindowDays] before it.
  (String from, String today) _popularityWindow() {
    final local = _now().toLocal();
    // Calendar arithmetic in UTC, so a DST change can't shift the date.
    final today = DateTime.utc(local.year, local.month, local.day);
    return (
      _isoDate(today.subtract(const Duration(days: popularityWindowDays))),
      _isoDate(today),
    );
  }

  static Map<int, ItemUsage> _usageMap(List<Map<String, Object?>> rows) => {
    for (final row in rows)
      row['id']! as int: (
        recentCount: row['recent']! as int,
        lastUsedAt: _dateTime(row['last']! as int),
      ),
  };

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Timestamps are stored as epoch milliseconds, UTC (database.md §1).
  static DateTime _dateTime(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
