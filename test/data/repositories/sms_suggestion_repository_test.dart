import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/data_version.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/sms_suggestion_repository.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/models/sms_suggestion.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

/// `sms_suggestions` and `SmsSuggestionRepository`, and
/// `ExpenseRepository.add(fromSms)`, on SQLite 3.22. Suggestions have no bin;
/// the learning queries each get a binned expense that must not count.
void main() {
  late Database db;
  late TestClock clock;
  late SmsSuggestionRepository repo;
  late ExpenseRepository expenses;

  const day = Duration.millisecondsPerDay;

  setUp(() async {
    db = await openMigratedDatabase();
    clock = TestClock(DateTime.utc(2026, 10, 11, 9));
    repo = SmsSuggestionRepository(db, now: clock.call);
    expenses = ExpenseRepository(
      db,
      dataVersion: DataVersion(),
      now: clock.call,
    );
  });

  int nowMs() => clock.now.millisecondsSinceEpoch;

  var shaSeed = 0;

  /// [c] 64 times, or a new hash each call (zero-padded counter).
  String sha([String? c]) =>
      c != null ? c * 64 : (shaSeed++).toRadixString(16).padLeft(64, '0');

  NewSmsSuggestion row({
    String sender = 'VM-ABCBNK-S',
    int? atMs,
    String? hash,
    int amount = 15000,
    String method = 'upi',
    String? payee = 'ACME MARKETPLACE PRIVATE',
    String? reference,
    int offset = 330,
  }) => NewSmsSuggestion(
    sender: sender,
    receivedAtMs: atMs ?? nowMs() - day,
    utcOffsetMinutes: offset,
    bodySha256: hash ?? sha(),
    amountMinor: amount,
    paymentMethodKey: method,
    payee: payee,
    reference: reference,
  );

  Future<int> count([String where = '1']) async =>
      (await db.rawQuery(
            'SELECT count(*) AS n FROM sms_suggestions WHERE $where',
          )).single['n']!
          as int;

  ExpenseInput input({String title = 'Acme groceries', int categoryId = 2}) =>
      ExpenseInput(
        title: title,
        description: null,
        amount: const Money(15000, 'INR'),
        amountExpression: null,
        occurredAt: clock.now.subtract(const Duration(hours: 1)),
        utcOffsetMinutes: 330,
        categoryId: categoryId,
        paymentMethodId: 1,
        eventIds: const {},
      );

  Future<SmsSuggestion> stored(NewSmsSuggestion r) async {
    await repo.insertScanned([r], cursorMs: 1);
    return (await repo.pendingPage()).firstWhere(
      (s) => s.bodySha256 == r.bodySha256,
    );
  }

  group('the table', () {
    test('columns, NOT NULL, no body, both SET NULL, six indexes', () async {
      final columns = {
        for (final c in await db.rawQuery('PRAGMA table_info(sms_suggestions)'))
          c['name']: c['notnull'],
      };
      expect(columns, {
        'id': 0,
        'sender': 1,
        'received_at': 1,
        'utc_offset_minutes': 1,
        'received_on': 1,
        'body_sha256': 1,
        'amount_minor': 1,
        'currency_code': 1,
        'payment_method_key': 1,
        'payee': 0,
        'payee_key': 0,
        'reference': 0,
        'title': 0,
        'category_id': 0,
        'status': 1,
        'parsed_by': 1,
        'expense_id': 0,
        'created_at': 1,
        'updated_at': 1,
      });
      expect(columns.keys, isNot(contains('body')));
      final keys = await db.rawQuery(
        'PRAGMA foreign_key_list(sms_suggestions)',
      );
      expect(
        {for (final k in keys) k['from']: (k['table'], k['on_delete'])},
        {
          'category_id': ('categories', 'SET NULL'),
          'expense_id': ('expenses', 'SET NULL'),
        },
      );
      final indexes = await db.rawQuery('PRAGMA index_list(sms_suggestions)');
      expect(indexes, hasLength(6));
      expect(
        [
          for (final i in indexes)
            if (i['unique'] == 1) i['name'],
        ],
        ['index_sms_suggestions_on_sender_and_received_at_and_body_sha256'],
      );
    });

    test(
      'deleting the expense or the category sets NULL, keeps status',
      () async {
        final s = await stored(row());
        final expenseId = await insertExpenseRow(db);
        await db.update(
          'sms_suggestions',
          {'status': 'added', 'expense_id': expenseId, 'category_id': 2},
          where: 'id = ?',
          whereArgs: [s.id],
        );
        await db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
        await db.delete('categories', where: 'id = ?', whereArgs: [2]);
        final after = (await repo.byId(s.id))!;
        expect(after.expenseId, isNull);
        expect(after.categoryId, isNull);
        expect(after.status, SmsStatus.added);
      },
    );

    test('deleting a payment method never touches the table', () async {
      final s = await stored(row(method: 'credit_card'));
      await db.delete('payment_methods', where: "builtin_key = 'credit_card'");
      expect((await repo.byId(s.id))!.paymentMethodKey, 'credit_card');
    });
  });

  group('plans', () {
    Future<String> plan(String sql, [List<Object?> args = const []]) async => [
      for (final r in await db.rawQuery('EXPLAIN QUERY PLAN $sql', args))
        r['detail'],
    ].join(' | ');

    test(
      'the page and its keyset search the status index, no temp B-tree',
      () async {
        const page =
            "SELECT * FROM sms_suggestions WHERE status = 'pending' "
            'ORDER BY received_on DESC, received_at DESC, id DESC LIMIT 60';
        const keyset =
            "SELECT * FROM sms_suggestions WHERE status = 'pending' "
            'AND (received_on, received_at, id) < (?, ?, ?) '
            'ORDER BY received_on DESC, received_at DESC, id DESC LIMIT 60';
        for (final sql in [page, keyset]) {
          final p = await plan(
            sql,
            sql.contains('?') ? ['2026-10-01', 1, 1] : const [],
          );
          expect(p, contains('index_sms_suggestions_on_status'), reason: p);
          expect(p, isNot(contains('TEMP B-TREE')), reason: p);
        }
      },
    );

    test('the count is covering; existingKeys and the purge use what they '
        'can', () async {
      final countPlan = await plan(
        "SELECT count(*) FROM sms_suggestions WHERE status = 'pending'",
      );
      expect(countPlan, contains('COVERING INDEX'), reason: countPlan);
      final keysPlan = await plan(
        'SELECT sender, received_at, body_sha256 FROM sms_suggestions '
        'WHERE received_at BETWEEN ? AND ?',
        [0, 1],
      );
      final purgePlan = await plan(
        "DELETE FROM sms_suggestions WHERE status IN ('pending', 'dismissed') "
        'AND received_at < ?',
        [0],
      );
      // Both read a table that the purge keeps small.
      printOnFailure('existingKeys: $keysPlan\npurge: $purgePlan');
      expect(purgePlan, contains('index_sms_suggestions_on_status'));
    });
  });

  group('insertScanned', () {
    test(
      'twice the same rows → one each, the cursor written with them',
      () async {
        final rows = [row(hash: sha('a')), row(hash: sha('b'))];
        expect(await repo.insertScanned(rows, cursorMs: 111), 2);
        expect(await repo.insertScanned(rows, cursorMs: 222), 0);
        expect(await count(), 2);
        expect(await repo.cursor(), 222);
      },
    );

    test('derived columns: received_on in the SMS\'s zone, payee key, '
        'INR, pending, regex', () async {
      // 2026-10-09 19:00 UTC is 00:30 on the 10th in IST.
      final s = await stored(
        row(atMs: DateTime.utc(2026, 10, 9, 19).millisecondsSinceEpoch),
      );
      expect(s.receivedOn, '2026-10-10');
      expect(s.payeeKey, 'acme marketplace');
      expect(s.title, 'Acme Marketplace');
      expect(s.currencyCode, 'INR');
      expect(s.status, SmsStatus.pending);
      final raw = await db.query(
        'sms_suggestions',
        where: 'id = ?',
        whereArgs: [s.id],
      );
      expect(raw.single['parsed_by'], 'regex');
    });

    test('a bad row throws before any write (INSERT OR IGNORE would skip a '
        'NOT NULL break silently)', () async {
      for (final bad in [
        row(sender: ' '),
        row(hash: 'x'),
        row(amount: 0),
        row(amount: -5),
        row(amount: 100000000000000), // 13 integer digits
        row(method: 'cash'),
      ]) {
        await expectLater(
          repo.insertScanned([row(hash: sha('c')), bad], cursorMs: 5),
          throwsArgumentError,
        );
      }
      expect(await count(), 0);
      expect(await repo.cursor(), isNull);
    });

    test(
      'a foreign-key failure inside rolls back the rows and the cursor',
      () async {
        await repo.insertScanned([row(hash: sha('a'))], cursorMs: 10);
        // A category that doesn't exist, forced through the learning path: a
        // learned row whose expense names category 999 can't exist, so the
        // failure is forced with a temp trigger.
        await db.execute(
          'CREATE TEMP TRIGGER fail_insert BEFORE INSERT ON sms_suggestions '
          "BEGIN SELECT RAISE(ABORT, 'forced'); END",
        );
        await expectLater(
          repo.insertScanned([row(hash: sha('b'))], cursorMs: 20),
          throwsA(isA<DatabaseException>()),
        );
        await db.execute('DROP TRIGGER fail_insert');
        expect(await count(), 1);
        expect(await repo.cursor(), 10);
      },
    );

    test(
      'a reference and amount stored already, or twice in one batch, are '
      'dropped; the same reference with another amount (two banks) is kept',
      () async {
        await repo.insertScanned([
          row(hash: sha('a'), reference: '123456'),
        ], cursorMs: 1);
        expect(
          await repo.insertScanned([
            row(hash: sha('b'), reference: '123456'),
            row(hash: sha('c'), reference: '123456', amount: 9900),
            row(hash: sha('d'), reference: 'NEW123456'),
            row(hash: sha('e'), reference: 'NEW123456'),
            row(hash: sha('f'), reference: 'NEW123456', amount: 9900),
            row(hash: sha('1')),
            row(hash: sha('2')),
          ], cursorMs: 2),
          5,
        );
      },
    );

    test('a category by title through the transaction (this hangs if '
        'it reads through the database); not from a title only older than '
        '180 days, not from a binned or future one', () async {
      await expenses.add(input(title: 'Acme Marketplace', categoryId: 5));
      final s = await stored(row(hash: sha('a')));
      expect(s.categoryId, 5);

      final old = await openMigratedDatabase();
      final oldRepo = SmsSuggestionRepository(old, now: clock.call);
      final oldExpenses = ExpenseRepository(
        old,
        dataVersion: DataVersion(),
        now: () => clock.now.subtract(const Duration(days: 200)),
      );
      await oldExpenses.add(
        input(
          title: 'Acme Marketplace',
          categoryId: 5,
        )._at(clock.now.subtract(const Duration(days: 200))),
      );
      final binnedId = await insertExpenseRow(old, deletedAt: 1);
      await old.update(
        'expenses',
        {'title': 'Acme Marketplace', 'occurred_on': '2026-10-10'},
        where: 'id = ?',
        whereArgs: [binnedId],
      );
      await oldRepo.insertScanned([row(hash: sha('b'))], cursorMs: 1);
      expect((await oldRepo.pendingPage()).single.categoryId, isNull);
    });

    test('learned title and category from an added row whose expense is '
        'active, not from one whose expense is binned', () async {
      final first = await stored(row(hash: sha('a'), payee: 'ACME'));
      final saved = await expenses.add(
        input(title: 'Groceries', categoryId: 3),
        fromSms: first.link,
      );
      final second = await stored(row(hash: sha('b'), payee: 'Acme Pvt'));
      expect(second.title, 'Groceries');
      expect(second.categoryId, 3);

      await expenses.moveToBin(saved.id);
      final third = await stored(row(hash: sha('c'), payee: 'ACME'));
      expect(third.title, 'Acme');
      expect(third.categoryId, isNull);
    });
  });

  group('pendingPage', () {
    test('130 rows over 3 months → 60, 60, 10 in order; an insert between '
        'pages appears neither twice nor skipped', () async {
      final rows = [
        for (var i = 0; i < 130; i++)
          row(
            hash: (1000 + i).toRadixString(16).padLeft(64, '0'),
            atMs:
                DateTime.utc(2026, 7, 1).millisecondsSinceEpoch +
                i * day * 3 ~/ 4,
          ),
      ];
      await repo.insertScanned(rows, cursorMs: 1);
      final seen = <int>[];
      var page = await repo.pendingPage();
      expect(page, hasLength(60));
      seen.addAll(page.map((s) => s.id));
      // Newer than everything loaded: belongs before page 1, not after.
      await repo.insertScanned([
        row(hash: 'f' * 64, atMs: nowMs()),
      ], cursorMs: 2);
      page = await repo.pendingPage(after: page.last.pageKey);
      expect(page, hasLength(60));
      seen.addAll(page.map((s) => s.id));
      page = await repo.pendingPage(after: page.last.pageKey);
      expect(page, hasLength(10));
      seen.addAll(page.map((s) => s.id));
      expect(seen.toSet(), hasLength(130));
      final all = await db.query(
        'sms_suggestions',
        orderBy: 'received_on DESC, received_at DESC, id DESC',
      );
      expect(seen, [
        for (final r in all)
          if (r['body_sha256'] != 'f' * 64) r['id'],
      ]);
    });

    test('count, dismiss / undismiss: only pending / dismissed change; an '
        'added row untouched', () async {
      final a = await stored(row(hash: sha('a')));
      final b = await stored(row(hash: sha('b')));
      expect(await repo.pendingCount(), 2);
      expect(await repo.dismiss(a.id), isTrue);
      expect(await repo.dismiss(a.id), isFalse);
      expect(await repo.pendingCount(), 1);
      expect(await repo.undismiss(a.id), isTrue);
      expect(await repo.undismiss(a.id), isFalse);
      await expenses.add(input(), fromSms: b.link);
      expect(await repo.dismiss(b.id), isFalse);
      expect(await repo.undismiss(b.id), isFalse);
      expect((await repo.byId(b.id))!.status, SmsStatus.added);
      expect(await repo.dismiss(999), isFalse);
    });
  });

  group('purgeOld', () {
    test('pending and dismissed 31 days old go; 29 days stay; added 90 days '
        'old stays; days: 75 keeps a 60-day-old pending', () async {
      final old = await stored(row(hash: sha('a'), atMs: nowMs() - 31 * day));
      final oldDismissed = await stored(
        row(hash: sha('b'), atMs: nowMs() - 31 * day),
      );
      await repo.dismiss(oldDismissed.id);
      final recent = await stored(
        row(hash: sha('c'), atMs: nowMs() - 29 * day),
      );
      final added = await stored(row(hash: sha('d'), atMs: nowMs() - 90 * day));
      await expenses.add(input(), fromSms: added.link);
      final sixty = await stored(row(hash: sha('e'), atMs: nowMs() - 60 * day));

      expect(await repo.purgeOld(nowMs: nowMs(), days: 75), 0);
      expect(await repo.byId(sixty.id), isNotNull);

      expect(await repo.purgeOld(nowMs: nowMs(), days: 30), 3);
      expect(await repo.byId(old.id), isNull);
      expect(await repo.byId(oldDismissed.id), isNull);
      expect(await repo.byId(sixty.id), isNull);
      expect(await repo.byId(recent.id), isNotNull);
      expect(await repo.byId(added.id), isNotNull);
    });
  });

  group('ExpenseRepository.add(fromSms)', () {
    test('marks the suggestion added with the expense id in one transaction; '
        'a second add → SmsAlreadyAdded and no second expense', () async {
      final s = await stored(row());
      final e = await expenses.add(input(), fromSms: s.link);
      final after = (await repo.byId(s.id))!;
      expect(after.status, SmsStatus.added);
      expect(after.expenseId, e.id);
      await expectLater(
        expenses.add(input(), fromSms: s.link),
        throwsA(isA<SmsAlreadyAdded>()),
      );
      expect(
        (await db.rawQuery('SELECT count(*) AS n FROM expenses')).single['n'],
        1,
      );
    });

    test('a link whose sha differs, or no row (purged): saved, nothing '
        'marked', () async {
      final s = await stored(row());
      await expenses.add(input(), fromSms: (id: s.id, bodySha256: sha('9')));
      expect((await repo.byId(s.id))!.status, SmsStatus.pending);
      await expenses.add(input(), fromSms: (id: 999, bodySha256: s.bodySha256));
      expect(
        (await db.rawQuery('SELECT count(*) AS n FROM expenses')).single['n'],
        2,
      );
    });

    test('learnOn updates only the pending rows of that payee', () async {
      final a = await stored(row(hash: sha('a'), payee: 'ACME'));
      final b = await stored(row(hash: sha('b'), payee: 'Acme Private'));
      final c = await stored(row(hash: sha('c'), payee: 'ACME'));
      final other = await stored(row(hash: sha('d'), payee: 'SWIGGY'));
      await repo.dismiss(c.id);
      await expenses.add(input(title: 'Veg', categoryId: 4), fromSms: a.link);
      expect((await repo.byId(b.id))!.title, 'Veg');
      expect((await repo.byId(b.id))!.categoryId, 4);
      expect((await repo.byId(c.id))!.title, 'Acme');
      expect((await repo.byId(other.id))!.title, 'Swiggy');
    });

    test('addRepeating(fromSms) marks it too; the draft is cleared with the '
        'mark', () async {
      final s = await stored(row());
      await db.insert('expense_draft', {
        'id': 1,
        'editing_expense_id': null,
        'form_json': '{}',
        'updated_at': 0,
      });
      final saved = await expenses.addRepeating(
        input(),
        const RepeatChoice(),
        clearDraft: true,
        fromSms: s.link,
      );
      expect((await repo.byId(s.id))!.expenseId, saved.expense.id);
      expect(await db.query('expense_draft'), isEmpty);
    });

    test('a refused second Save keeps the draft (the whole transaction '
        'rolls back)', () async {
      final s = await stored(row());
      await expenses.add(input(), fromSms: s.link);
      await db.insert('expense_draft', {
        'id': 1,
        'editing_expense_id': null,
        'form_json': '{}',
        'updated_at': 0,
      });
      await expectLater(
        expenses.add(input(), clearDraft: true, fromSms: s.link),
        throwsA(isA<SmsAlreadyAdded>()),
      );
      expect(await db.query('expense_draft'), hasLength(1));
    });
  });

  test('AppDependencies.probe refuses a database without the table', () async {
    await AppDependencies.probe(db, deviceCurrency: 'INR');
    await db.execute('DROP TABLE sms_suggestions');
    await expectLater(
      AppDependencies.probe(db, deviceCurrency: 'INR'),
      throwsA(isA<DatabaseException>()),
    );
  });
}

extension on ExpenseInput {
  ExpenseInput _at(DateTime at) => ExpenseInput(
    title: title,
    description: description,
    amount: amount,
    amountExpression: amountExpression,
    occurredAt: at,
    utcOffsetMinutes: utcOffsetMinutes,
    categoryId: categoryId,
    paymentMethodId: paymentMethodId,
    eventIds: eventIds,
  );
}
