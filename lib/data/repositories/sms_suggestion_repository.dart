import 'package:sqflite/sqflite.dart';

import '../../domain/amount_input.dart' show maxIntegerDigits;
import '../../domain/models/sms_suggestion.dart';
import '../../domain/periods.dart';
import '../../domain/photos.dart' show isValidSha256;
import '../../domain/sms/sms_learning.dart';
import '../../domain/sms/sms_title.dart';
import '../../domain/title_suggestions.dart';
import '../services/database/sql_helpers.dart';
import 'expense_repository.dart';
import 'settings_repository.dart';

/// Thrown by `ExpenseRepository.add` (with `fromSms`) when the suggestion was
/// added already: the whole Save rolls back, so one SMS never becomes two
/// expenses.
class SmsAlreadyAdded implements Exception {
  const SmsAlreadyAdded(this.id);

  final int id;

  @override
  String toString() => 'SmsAlreadyAdded: suggestion $id';
}

/// Reads and writes `sms_suggestions`. Never sees the SMS text: rows come in
/// parsed, with a hash.
class SmsSuggestionRepository {
  SmsSuggestionRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  static const _table = 'sms_suggestions';

  /// The page order, served by the `(status, received_on, received_at)` index
  /// with no temp B-tree.
  static const _pageOrder = 'received_on DESC, received_at DESC, id DESC';

  /// A page of pending suggestions, newest first, after [after] (keyset).
  Future<List<SmsSuggestion>> pendingPage({
    SmsPageKey? after,
    int limit = 60,
  }) async {
    final rows = await _db.query(
      _table,
      where: [
        "status = 'pending'",
        if (after != null) '(received_on, received_at, id) < (?, ?, ?)',
      ].join(' AND '),
      whereArgs: after == null
          ? null
          : [after.receivedOn, after.receivedAtMs, after.id],
      orderBy: _pageOrder,
      limit: limit,
    );
    return [for (final row in rows) _fromRow(row)];
  }

  /// How many wait: Home's badge.
  Future<int> pendingCount() async =>
      (await _db.rawQuery(
            "SELECT count(*) AS n FROM $_table WHERE status = 'pending'",
          )).single['n']!
          as int;

  /// The row [id], whatever its status, or null.
  Future<SmsSuggestion?> byId(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  /// Pending → dismissed. Whether it changed (an added or gone row
  /// doesn't).
  Future<bool> dismiss(int id) => _move(id, from: 'pending', to: 'dismissed');

  /// Undo of [dismiss]: dismissed → pending.
  Future<bool> undismiss(int id) => _move(id, from: 'dismissed', to: 'pending');

  Future<bool> _move(
    int id, {
    required String from,
    required String to,
  }) async =>
      await _db.update(
        _table,
        {'status': to, 'updated_at': _now().millisecondsSinceEpoch},
        where: 'id = ? AND status = ?',
        whereArgs: [id, from],
      ) ==
      1;

  /// The scan's cursor (`sms_last_scanned_at`), epoch ms, or null before
  /// the first scan. An unreadable value reads as null (a first scan).
  Future<int?> cursor() async => int.tryParse(
    await SettingsRepository.valueOf(_db, SettingsRepository.smsCursorKey) ??
        '',
  );

  /// The stored `(sender, received_at, body_sha256)` of SMS received from
  /// [fromMs] to [toMs], so the scan skips them before parsing: an SMS is
  /// parsed once.
  Future<Set<SmsKey>> existingKeys({
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await _db.query(
      _table,
      columns: ['sender', 'received_at', 'body_sha256'],
      where: 'received_at BETWEEN ? AND ?',
      whereArgs: [fromMs, toMs],
    );
    return {
      for (final row in rows)
        (
          sender: row['sender']! as String,
          receivedAtMs: row['received_at']! as int,
          bodySha256: row['body_sha256']! as String,
        ),
    };
  }

  /// Stores a scan's [rows] and moves the cursor to [cursorMs], in **one
  /// transaction**: a crash keeps both or neither, so the SMS after the cursor
  /// are read again and the ones before are stored.
  ///
  /// Every row is checked in Dart first and a bad one throws before anything is
  /// written: `INSERT OR IGNORE` would skip a NOT NULL break silently. A row
  /// whose reference **and amount** are stored already, or repeated earlier in
  /// [rows], is dropped (one payment in two SMS). The amount too, because two
  /// banks' short references (6 digits) do meet over the years, and added rows
  /// are never purged: the reference alone would drop a real payment. The title
  /// and category are filled here, through the transaction, so a Save that
  /// learned meanwhile is seen. Returns how many rows were added.
  Future<int> insertScanned(
    List<NewSmsSuggestion> rows, {
    required int cursorMs,
  }) async {
    rows.forEach(_check);
    final now = _now();
    final nowMs = now.millisecondsSinceEpoch;
    return _db.transaction((txn) async {
      final before = await _count(txn);
      final payments = await _existingPayments(txn, {
        for (final row in rows) ?row.reference,
      });
      final learned = <String, SmsLearned?>{};
      List<TitleHistoryRow>? history;
      // The model's pick was one of the categories when the scan began; a
      // category deleted since would break the foreign key and fail the whole
      // write, so it is dropped here instead.
      final categoryIds = rows.any((row) => row.aiCategoryId != null)
          ? await _categoryIds(txn)
          : const <int>{};
      final batch = txn.batch();
      for (final row in rows) {
        if (row.reference case final reference?) {
          if (!payments.add((reference, row.amountMinor))) continue;
        }
        final payeeKey = payeeKeyOf(row.payee);
        final learnt = payeeKey == null
            ? null
            : learned.containsKey(payeeKey)
            ? learned[payeeKey]
            : learned[payeeKey] = await _learnedFor(txn, payeeKey);
        final title = suggestedTitle(
          learned: learnt?.title,
          ai: row.aiTitle,
          payee: row.payee,
        );
        final ai = categoryIds.contains(row.aiCategoryId)
            ? row.aiCategoryId
            : null;
        final categoryId = learnt != null || title == null
            ? suggestedCategory(learned: learnt, title: title, ai: ai)
            : suggestedCategory(
                title: title,
                history: history ??= await ExpenseRepository.titleHistoryOn(
                  txn,
                  now: now,
                ),
                ai: ai,
              );
        batch.rawInsert(
          'INSERT OR IGNORE INTO $_table (sender, received_at, '
          'utc_offset_minutes, received_on, body_sha256, amount_minor, '
          'currency_code, payment_method_key, payee, payee_key, reference, '
          'title, category_id, status, parsed_by, expense_id, created_at, '
          'updated_at) VALUES '
          "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, "
          'NULL, ?, ?)',
          [
            row.sender,
            row.receivedAtMs,
            row.utcOffsetMinutes,
            localDayOf(utcFromEpochMs(row.receivedAtMs), row.utcOffsetMinutes),
            row.bodySha256,
            row.amountMinor,
            smsCurrencyCode,
            row.paymentMethodKey,
            row.payee,
            payeeKey,
            row.reference,
            title,
            categoryId,
            row.parsedBy.name,
            nowMs,
            nowMs,
          ],
        );
      }
      // The ignored rows' results are never read.
      await batch.commit(noResult: true);
      await txn.insert('settings', {
        'key': SettingsRepository.smsCursorKey,
        'value': '$cursorMs',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return await _count(txn) - before;
    });
  }

  /// Deletes pending and dismissed suggestions received more than [days] ago.
  /// Added ones stay: they hold no text and feed the learning and the duplicate
  /// check. Returns how many.
  Future<int> purgeOld({required int nowMs, required int days}) => _db.delete(
    _table,
    where: "status IN ('pending', 'dismissed') AND received_at < ?",
    whereArgs: [nowMs - days * Duration.millisecondsPerDay],
  );

  /// Marks the suggestion [link] added as [expenseId] inside Save's own
  /// transaction, guarded so a second Save changes nothing. Returns the row's
  /// payee key when it was marked (for [learnOn]), null when no row with this
  /// id **and** this hash exists (purged, or a restore put another SMS under
  /// the id): the expense is kept, nothing marked. Throws [SmsAlreadyAdded]
  /// when it was added before: the caller's transaction rolls back.
  static Future<({bool marked, String? payeeKey})> markAddedOn(
    Transaction txn,
    SmsLink link,
    int expenseId,
    int nowMs,
  ) async {
    final changed = await txn.update(
      _table,
      {'status': 'added', 'expense_id': expenseId, 'updated_at': nowMs},
      where: "id = ? AND body_sha256 = ? AND status <> 'added'",
      whereArgs: [link.id, link.bodySha256],
    );
    final rows = await txn.query(
      _table,
      columns: ['payee_key'],
      where: 'id = ? AND body_sha256 = ?',
      whereArgs: [link.id, link.bodySha256],
    );
    if (changed == 0) {
      if (rows.isNotEmpty) throw SmsAlreadyAdded(link.id);
      return (marked: false, payeeKey: null);
    }
    return (marked: true, payeeKey: rows.single['payee_key'] as String?);
  }

  /// Teaches the pending suggestions of [payeeKey] the [title] and [categoryId]
  /// a Save just used, in its transaction.
  static Future<void> learnOn(
    Transaction txn,
    String? payeeKey,
    String title,
    int categoryId,
    int nowMs,
  ) async {
    if (payeeKey == null) return;
    await txn.update(
      _table,
      {'title': title, 'category_id': categoryId, 'updated_at': nowMs},
      where: "payee_key = ? AND status = 'pending'",
      whereArgs: [payeeKey],
    );
  }

  /// Names every column, so a restored database without the table (or an older
  /// one) is refused before the swap. On an empty table too.
  static Future<void> probe(DatabaseExecutor db) => db.query(
    _table,
    columns: [
      'id',
      'sender',
      'received_at',
      'utc_offset_minutes',
      'received_on',
      'body_sha256',
      'amount_minor',
      'currency_code',
      'payment_method_key',
      'payee',
      'payee_key',
      'reference',
      'title',
      'category_id',
      'status',
      'parsed_by',
      'expense_id',
      'created_at',
      'updated_at',
    ],
    limit: 1,
  );

  static Future<int> _count(DatabaseExecutor db) async =>
      (await db.rawQuery('SELECT count(*) AS n FROM $_table')).single['n']!
          as int;

  /// The title and category of the newest still-active expense added from an
  /// SMS of [payeeKey] (`learnedFor`). Through [txn].
  static Future<SmsLearned?> _learnedFor(
    Transaction txn,
    String payeeKey,
  ) async {
    final rows = await txn.rawQuery(
      'SELECT e.title, e.category_id FROM $_table s '
      'JOIN expenses e ON e.id = s.expense_id '
      "WHERE s.payee_key = ? AND s.status = 'added' "
      'AND +e.deleted_at IS NULL '
      'ORDER BY s.received_at DESC, s.id DESC LIMIT 1',
      [payeeKey],
    );
    if (rows.isEmpty) return null;
    return (
      title: rows.single['title']! as String,
      categoryId: rows.single['category_id']! as int,
    );
  }

  /// The stored `(reference, amount)` pairs among [references], chunked.
  static Future<Set<(String, int)>> _existingPayments(
    Transaction txn,
    Set<String> references,
  ) async => {
    for (final row in await inChunks(
      references.toList(),
      (chunk) => txn.query(
        _table,
        columns: ['reference', 'amount_minor'],
        where: 'reference IN (${sqlPlaceholders(chunk.length)})',
        whereArgs: chunk,
      ),
    ))
      (row['reference']! as String, row['amount_minor']! as int),
  };

  /// The Dart check before any write.
  static Future<Set<int>> _categoryIds(Transaction txn) async => {
    for (final row in await txn.query('categories', columns: ['id']))
      row['id']! as int,
  };

  static void _check(NewSmsSuggestion row) {
    void fail(String why) => throw ArgumentError.value(row, 'row', why);
    if (row.sender.trim().isEmpty) fail('no sender');
    if (!isValidSha256(row.bodySha256)) fail('bad sha256');
    // At most maxIntegerDigits before the 2 minor digits (INR).
    if (row.amountMinor <= 0 ||
        '${row.amountMinor ~/ 100}'.length > maxIntegerDigits) {
      fail('bad amount');
    }
    if (!smsPaymentMethodKeys.contains(row.paymentMethodKey)) {
      fail('bad payment method key');
    }
  }

  static SmsSuggestion _fromRow(Map<String, Object?> row) => SmsSuggestion(
    id: row['id']! as int,
    sender: row['sender']! as String,
    receivedAt: utcFromEpochMs(row['received_at']! as int),
    utcOffsetMinutes: row['utc_offset_minutes']! as int,
    receivedOn: row['received_on']! as String,
    bodySha256: row['body_sha256']! as String,
    amountMinor: row['amount_minor']! as int,
    currencyCode: row['currency_code']! as String,
    paymentMethodKey: row['payment_method_key']! as String,
    payee: row['payee'] as String?,
    payeeKey: row['payee_key'] as String?,
    reference: row['reference'] as String?,
    title: row['title'] as String?,
    categoryId: row['category_id'] as int?,
    // An unknown status (a newer app's, after a downgrade) is never
    // offered as a card.
    status: SmsStatus.values.asNameMap()[row['status']] ?? SmsStatus.dismissed,
    expenseId: row['expense_id'] as int?,
  );
}

/// What makes an SMS the same SMS: its sender, when it came and its text's
/// hash (the table's unique key).
typedef SmsKey = ({String sender, int receivedAtMs, String bodySha256});
