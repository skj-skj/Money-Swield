import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/data_version.dart';
import 'package:my_expense_tracker_app/data/repositories/event_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;
  late TestClock clock;
  late DataVersion version;
  late ExpenseRepository repository;

  setUp(() async {
    db = await openMigratedDatabase();
    clock = TestClock();
    version = DataVersion();
    repository = ExpenseRepository(db, dataVersion: version, now: clock.call);
  });

  /// A valid expense; seeded category 1 (food) and payment method 1 (cash).
  ExpenseInput input({
    String title = 'Lunch',
    String? description,
    Money amount = const Money(11050, 'INR'),
    DateTime? occurredAt,
    int utcOffsetMinutes = 330,
    int categoryId = 1,
    int paymentMethodId = 1,
    Set<int> eventIds = const {},
  }) => ExpenseInput(
    title: title,
    description: description,
    amount: amount,
    occurredAt: occurredAt ?? DateTime.utc(2026, 10, 1, 7),
    utcOffsetMinutes: utcOffsetMinutes,
    categoryId: categoryId,
    paymentMethodId: paymentMethodId,
    eventIds: eventIds,
  );

  /// Adds an expense and moves it to the bin.
  Future<Expense> addBinned([ExpenseInput? data]) async {
    final expense = await repository.add(data ?? input(title: 'Binned'));
    await repository.moveToBin(expense.id);
    return expense;
  }

  Future<int> count(String table) async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']!
          as int;

  group('add / byId / update', () {
    test('add returns exactly what byId reads back', () async {
      final added = await repository.add(
        input(description: 'With rice', eventIds: {1, 3}),
      );

      expect(added.title, 'Lunch');
      expect(added.description, 'With rice');
      expect(added.amount, const Money(11050, 'INR'));
      expect(added.amountExpression, isNull);
      expect(added.occurredAt, DateTime.utc(2026, 10, 1, 7));
      expect(added.occurredAt.isUtc, isTrue);
      expect(added.utcOffsetMinutes, 330);
      expect(added.occurredOn, '2026-10-01');
      expect(added.eventIds, {1, 3});
      expect(added.createdAt, clock.now);
      expect(added.updatedAt, clock.now);
      expect(added.deletedAt, isNull);
      expect(await repository.byId(added.id), added);
    });

    test('keeps a NULL description as NULL', () async {
      final added = await repository.add(input());
      final row = await db.query('expenses', where: 'id = ${added.id}');
      expect(row.single['description'], isNull);
    });

    test(
      'amounts are stored as exact integers, the largest included',
      () async {
        final added = await repository.add(
          input(amount: const Money(999999999999999, 'KWD')),
        );
        final row = await db.query('expenses', where: 'id = ${added.id}');
        expect(row.single['amount_minor'], 999999999999999);
        expect(
          (await repository.byId(added.id))!.amount.amountMinor,
          999999999999999,
        );
      },
    );

    test(
      'update saves every field, replaces the events and moves updated_at only',
      () async {
        final added = await repository.add(input(eventIds: {1, 2}));
        clock.advance(const Duration(minutes: 5));

        final saved = await repository.update(
          added.id,
          input(
            title: 'Dinner',
            description: 'Late',
            amount: const Money(500, 'JPY'),
            occurredAt: DateTime.utc(2026, 9, 30, 12),
            utcOffsetMinutes: 540,
            categoryId: 2,
            paymentMethodId: 3,
            eventIds: {2, 4},
          ),
        );

        expect(saved.title, 'Dinner');
        expect(saved.description, 'Late');
        expect(saved.amount, const Money(500, 'JPY'));
        expect(saved.occurredOn, '2026-09-30');
        expect(saved.categoryId, 2);
        expect(saved.paymentMethodId, 3);
        expect(saved.eventIds, {2, 4});
        expect(saved.createdAt, added.createdAt);
        expect(saved.updatedAt, clock.now);
        expect(await repository.byId(added.id), saved);
        expect(await count('expense_events'), 2);
      },
    );

    test('update can remove every event', () async {
      final added = await repository.add(input(eventIds: {1, 2}));
      final saved = await repository.update(added.id, input());
      expect(saved.eventIds, isEmpty);
      expect(await count('expense_events'), 0);
    });

    test(
      'update keeps an archived event that was already on the expense',
      () async {
        final events = EventRepository(db);
        final added = await repository.add(input(eventIds: {1}));
        await events.setArchived(1, true);

        final saved = await repository.update(
          added.id,
          input(title: 'Renamed', eventIds: added.eventIds),
        );
        expect(saved.eventIds, {1});
      },
    );

    test('update of a missing expense throws and changes nothing', () async {
      await expectLater(
        repository.update(999, input()),
        throwsA(isA<ExpenseNotFound>()),
      );
      expect(await count('expenses'), 0);
    });

    test('a failed write leaves nothing half-saved', () async {
      // Event 999 doesn't exist: the link fails on the foreign key, so the
      // expense row must not stay either.
      await expectLater(
        repository.add(input(eventIds: {1, 999})),
        throwsA(isA<DatabaseException>()),
      );
      expect(await count('expenses'), 0);
      expect(await count('expense_events'), 0);

      final added = await repository.add(input(eventIds: {1}));
      await expectLater(
        repository.update(added.id, input(title: 'New', eventIds: {999})),
        throwsA(isA<DatabaseException>()),
      );
      expect(await repository.byId(added.id), added);
    });

    test('byId of a missing expense is null', () async {
      expect(await repository.byId(999), isNull);
    });
  });

  group('occurred_on', () {
    test('is the local date, not the UTC date', () async {
      // 23:30 in India (UTC+5:30) is 18:00 UTC the same day…
      final india = await repository.add(
        input(occurredAt: DateTime.utc(2026, 10, 1, 18), utcOffsetMinutes: 330),
      );
      expect(india.occurredOn, '2026-10-01');
      expect(india.wallClock, DateTime.utc(2026, 10, 1, 23, 30));

      // …and 00:30 the next day in India is still 19:00 UTC on the 1st.
      final indiaAfterMidnight = await repository.add(
        input(occurredAt: DateTime.utc(2026, 10, 1, 19), utcOffsetMinutes: 330),
      );
      expect(indiaAfterMidnight.occurredOn, '2026-10-02');

      // 01:00 in UTC−5 is 06:00 UTC: same date. 23:00 in UTC−5 is 04:00
      // UTC the next day, but the local date is the day before.
      final newYork = await repository.add(
        input(occurredAt: DateTime.utc(2026, 10, 2, 4), utcOffsetMinutes: -300),
      );
      expect(newYork.occurredOn, '2026-10-01');
      final newYorkEarly = await repository.add(
        input(occurredAt: DateTime.utc(2026, 10, 2, 6), utcOffsetMinutes: -300),
      );
      expect(newYorkEarly.occurredOn, '2026-10-02');
      expect(newYorkEarly.wallClock, DateTime.utc(2026, 10, 2, 1));
    });

    test('each expense uses its own offset across a DST change', () async {
      // Spain moves from UTC+1 to UTC+2 at 01:00 UTC on 29 March 2026.
      final before = await repository.add(
        input(
          occurredAt: DateTime.utc(2026, 3, 28, 23, 30),
          utcOffsetMinutes: 60,
        ),
      );
      final after = await repository.add(
        input(
          occurredAt: DateTime.utc(2026, 3, 29, 22, 30),
          utcOffsetMinutes: 120,
        ),
      );
      expect(before.occurredOn, '2026-03-29');
      expect(before.wallClock, DateTime.utc(2026, 3, 29, 0, 30));
      expect(after.occurredOn, '2026-03-30');
      expect(after.wallClock, DateTime.utc(2026, 3, 30, 0, 30));
    });

    test('update recomputes it from the new date', () async {
      final added = await repository.add(input());
      final saved = await repository.update(
        added.id,
        input(occurredAt: DateTime.utc(2026, 1, 1, 12), utcOffsetMinutes: 0),
      );
      expect(saved.occurredOn, '2026-01-01');
    });
  });

  group('page', () {
    Future<List<Expense>> addAt(List<DateTime> times) async => [
      for (final (i, time) in times.indexed)
        await repository.add(input(title: 'E$i', occurredAt: time)),
    ];

    test('is newest first, by id when the time is the same', () async {
      final t = DateTime.utc(2026, 10, 1, 7);
      final added = await addAt([
        t,
        t.add(const Duration(hours: 1)),
        t,
        t.subtract(const Duration(days: 1)),
      ]);
      final page = await repository.page();
      expect([for (final e in page) e.title], ['E1', 'E2', 'E0', 'E3']);
      expect(page.first, added[1]);
    });

    test('continues after the cursor across equal times, without gaps or duplicates', () async {
      final t = DateTime.utc(2026, 10, 1, 7);
      await addAt([for (var i = 0; i < 7; i++) t]);

      final seen = <int>[];
      ExpenseCursor? cursor;
      while (true) {
        final page = await repository.page(after: cursor, limit: 3);
        seen.addAll(page.map((e) => e.id));
        if (page.length < 3) break;
        cursor = page.last.cursor;
      }
      expect(seen, hasLength(7));
      expect(seen.toSet(), hasLength(7));
      expect(seen, [...seen]..sort((a, b) => b.compareTo(a)));
    });

    test('a row inserted between pages causes no duplicates or gaps', () async {
      final t = DateTime.utc(2026, 10, 1, 7);
      final added = await addAt([
        for (var i = 0; i < 6; i++) t.subtract(Duration(hours: i)),
      ]);

      final first = await repository.page(limit: 3);
      // A new expense at the top, and one inside the part already loaded.
      await repository.add(
        input(title: 'Newest', occurredAt: t.add(const Duration(hours: 1))),
      );
      await repository.add(
        input(
          title: 'Middle',
          occurredAt: t.subtract(const Duration(minutes: 30)),
        ),
      );
      final second = await repository.page(after: first.last.cursor, limit: 3);

      expect([...first, ...second].map((e) => e.id), [
        for (final e in added) e.id,
      ]);
    });

    test('returns the events of every row', () async {
      await repository.add(input(eventIds: {1}));
      await repository.add(input(eventIds: {2, 3}));
      await repository.add(input());
      final page = await repository.page();
      expect(
        [for (final e in page) e.eventIds],
        [
          <int>{},
          {2, 3},
          {1},
        ],
      );
    });

    test('uses the (occurred_at, id) index with no sort step', () async {
      for (final cursor in [null, (occurredAtMs: 1, id: 1)]) {
        final plan = await db.rawQuery(
          'EXPLAIN QUERY PLAN SELECT * FROM expenses WHERE +deleted_at IS NULL'
          '${cursor == null ? '' : ' AND (occurred_at, id) < (?, ?)'} '
          'ORDER BY occurred_at DESC, id DESC LIMIT 30',
          cursor == null ? null : [cursor.occurredAtMs, cursor.id],
        );
        final details = [for (final row in plan) row['detail']! as String];
        expect(
          details.join('\n'),
          contains('index_expenses_on_occurred_at_and_id'),
          reason: '$details',
        );
        expect(
          details.any((d) => d.contains('TEMP B-TREE')),
          isFalse,
          reason: '$details',
        );
      }
    });

    test('the plan test above matches what page() runs', () async {
      // Guards the copy of the query in the test: if page() changed its
      // filter, this would no longer hold.
      final logged = <String>[];
      final spy = ExpenseRepository(
        _LoggingDatabase(db, logged),
        dataVersion: DataVersion(),
      );
      await spy.page(after: (occurredAtMs: 1, id: 1));
      expect(
        logged.first,
        allOf(
          contains('+deleted_at IS NULL'),
          contains('(occurred_at, id) < (?, ?)'),
        ),
      );
    });

    test('1200 rows in one call come back with all their events', () async {
      final t = DateTime.utc(2026, 10, 1, 7);
      await db.transaction((txn) async {
        for (var i = 0; i < 1200; i++) {
          final id = await txn.insert('expenses', {
            'title': 'E$i',
            'amount_minor': 100 + i,
            'currency_code': 'INR',
            'occurred_at': t.millisecondsSinceEpoch - i,
            'utc_offset_minutes': 0,
            'occurred_on': '2026-10-01',
            'category_id': 1,
            'payment_method_id': 1,
            'created_at': 0,
            'updated_at': 0,
          });
          await txn.insert('expense_events', {
            'expense_id': id,
            'event_id': 1 + i % 5,
          });
        }
      });

      final all = await repository.page(limit: 1200);
      expect(all, hasLength(1200));
      for (final (i, expense) in all.indexed) {
        expect(expense.eventIds, {1 + i % 5}, reason: expense.title);
      }
    });
  });

  group('the bin', () {
    test('every non-bin read ignores a binned row', () async {
      final binned = await addBinned(
        input(
          title: 'Binned',
          amount: const Money(1, 'JPY'),
          categoryId: 5,
          eventIds: {2},
        ),
      );
      final active = await repository.add(input());

      expect(await repository.byId(binned.id), isNull);
      expect(await repository.page(), [active]);
      expect((await repository.categoryUsage()).keys, [1]);
      expect(await repository.eventUsage(), isEmpty);
      expect(await repository.recentCurrencies(), ['INR']);
      await expectLater(
        repository.update(binned.id, input()),
        throwsA(isA<ExpenseNotFound>()),
        reason: 'binned expenses can not be edited',
      );
    });

    test('moveToBin sets deleted_at and leaves updated_at alone', () async {
      final added = await repository.add(input());
      clock.advance(const Duration(hours: 1));
      await repository.moveToBin(added.id);

      final binned = (await repository.binned()).single;
      expect(binned.deletedAt, clock.now);
      expect(binned.updatedAt, added.updatedAt);
    });

    test(
      'a binned expense keeps its events and gets them back on restore',
      () async {
        final added = await repository.add(input(eventIds: {1, 2}));
        await repository.moveToBin(added.id);
        expect((await repository.binned()).single.eventIds, {1, 2});

        await repository.restore(added.id);
        expect(await repository.byId(added.id), added);
      },
    );

    test(
      'moving an already binned expense keeps its first deletion time',
      () async {
        final added = await addBinned();
        final first = (await repository.binned()).single.deletedAt;
        clock.advance(const Duration(days: 1));
        await repository.moveToBin(added.id);
        expect((await repository.binned()).single.deletedAt, first);
      },
    );

    test('binned is ordered by deletion, newest first', () async {
      final a = await addBinned(input(title: 'A'));
      clock.advance(const Duration(minutes: 1));
      final b = await addBinned(input(title: 'B'));
      clock.advance(const Duration(minutes: 1));
      final c = await addBinned(input(title: 'C'));
      await repository.add(input(title: 'Active'));

      expect(
        [for (final e in await repository.binned()) e.id],
        [c.id, b.id, a.id],
      );
    });

    test('restoreAll brings every binned expense back', () async {
      await addBinned();
      await addBinned();
      await repository.restoreAll();
      expect(await repository.binned(), isEmpty);
      expect(await repository.page(), hasLength(2));
    });

    test('restore of an active or missing expense does nothing', () async {
      final active = await repository.add(input());
      await repository.restore(active.id);
      await repository.restore(999);
      expect(await repository.byId(active.id), active);
    });

    test(
      'deletePermanently and emptyBin never delete an active expense',
      () async {
        final active = await repository.add(input());
        await repository.deletePermanently(active.id);
        expect(await repository.byId(active.id), active);

        final binned = await addBinned(input(eventIds: {1}));
        await repository.emptyBin();
        expect(await repository.page(), [active]);
        expect(await repository.binned(), isEmpty);
        final links = await db.query(
          'expense_events',
          where: 'expense_id = ${binned.id}',
        );
        expect(links, isEmpty, reason: 'links cascade');
      },
    );

    test('deletePermanently removes only that binned expense', () async {
      final a = await addBinned();
      final b = await addBinned();
      await repository.deletePermanently(a.id);
      expect([for (final e in await repository.binned()) e.id], [b.id]);
    });

    test('purgeBin deletes what was binned more than 30 days ago', () async {
      final old = await addBinned(input(title: 'Old', eventIds: {1}));
      clock.advance(const Duration(milliseconds: 2));
      final recent = await addBinned(input(title: 'Recent'));
      final active = await repository.add(input(title: 'Active'));

      // 30 days − 1 ms after the recent one was binned: the old one is
      // 30 days + 1 ms old.
      clock.advance(
        ExpenseRepository.binRetention - const Duration(milliseconds: 1),
      );
      expect(await repository.purgeBin(), 1);
      expect([for (final e in await repository.binned()) e.id], [recent.id]);
      expect(await repository.byId(active.id), active);
      expect(
        await db.query('expense_events', where: 'expense_id = ${old.id}'),
        isEmpty,
      );

      // Exactly 30 days is kept; 1 ms more and it goes.
      clock.advance(const Duration(milliseconds: 1));
      expect(await repository.purgeBin(), 0);
      clock.advance(const Duration(milliseconds: 1));
      expect(await repository.purgeBin(), 1);
      expect(await repository.binned(), isEmpty);
      expect(await repository.byId(active.id), active);
    });
  });

  group('usage and popularity', () {
    /// Today on the device, as the repository sees it.
    DateTime today() {
      final local = clock.now.toLocal();
      return DateTime.utc(local.year, local.month, local.day);
    }

    /// An expense dated [daysAgo] days before today (negative = future),
    /// at noon with offset 0, so `occurred_on` is exactly that date.
    Future<Expense> addDaysAgo(
      int daysAgo, {
      int categoryId = 1,
      Set<int> eventIds = const {},
      int hour = 12,
    }) => repository.add(
      input(
        occurredAt: today()
            .subtract(Duration(days: daysAgo))
            .add(Duration(hours: hour)),
        utcOffsetMinutes: 0,
        categoryId: categoryId,
        eventIds: eventIds,
      ),
    );

    test('counts uses from today − 90 days to today', () async {
      await addDaysAgo(0, categoryId: 1);
      await addDaysAgo(90, categoryId: 1);
      await addDaysAgo(91, categoryId: 1);
      await addDaysAgo(91, categoryId: 2);

      final usage = await repository.categoryUsage();
      expect(usage[1]!.recentCount, 2);
      expect(usage[2]!.recentCount, 0, reason: 'too old to count');
      expect(
        usage[2]!.lastUsedAt,
        isNotNull,
        reason: 'but still known as used, for the tie-break',
      );
      expect(usage.containsKey(3), isFalse);
    });

    test('the most recent use is the latest occurred_at', () async {
      await addDaysAgo(3, categoryId: 1);
      final latest = await addDaysAgo(1, categoryId: 1, hour: 8);
      await addDaysAgo(2, categoryId: 1);
      expect(
        (await repository.categoryUsage())[1]!.lastUsedAt,
        latest.occurredAt,
      );
    });

    test('future-dated expenses are ignored', () async {
      await addDaysAgo(-1, categoryId: 1);
      await addDaysAgo(-30, categoryId: 2, eventIds: {1});
      final past = await addDaysAgo(5, categoryId: 2);

      final usage = await repository.categoryUsage();
      expect(usage.containsKey(1), isFalse);
      expect(usage[2], (recentCount: 1, lastUsedAt: past.occurredAt));
      expect(await repository.eventUsage(), isEmpty);
    });

    test('eventUsage counts per event', () async {
      final latest = await addDaysAgo(0, eventIds: {1, 2});
      await addDaysAgo(1, eventIds: {1}, hour: 20);
      await addDaysAgo(100, eventIds: {3});

      final usage = await repository.eventUsage();
      expect(usage[1]!.recentCount, 2);
      expect(usage[2]!.recentCount, 1);
      expect(usage[3]!.recentCount, 0);
      expect(usage[1]!.lastUsedAt, latest.occurredAt);
      expect(usage.containsKey(4), isFalse);
    });

    test('recentCurrencies is ordered by when expenses were entered', () async {
      await repository.add(input(amount: const Money(1, 'USD')));
      clock.advance(const Duration(minutes: 1));
      await repository.add(input(amount: const Money(1, 'INR')));
      clock.advance(const Duration(minutes: 1));
      // Back-dated a year, but entered last: it comes first.
      await repository.add(
        input(
          amount: const Money(1, 'EUR'),
          occurredAt: DateTime.utc(2025, 1, 1),
        ),
      );
      clock.advance(const Duration(minutes: 1));
      await repository.add(input(amount: const Money(2, 'USD')));

      expect(await repository.recentCurrencies(), ['USD', 'EUR', 'INR']);
      expect(await repository.recentCurrencies(limit: 2), ['USD', 'EUR']);
    });
  });

  group('DataVersion', () {
    test('every write bumps it; reads do not', () async {
      Future<void> expectBump(
        String name,
        Future<void> Function() action,
      ) async {
        final before = version.value;
        await action();
        expect(version.value, greaterThan(before), reason: name);
      }

      Future<void> expectNoBump(
        String name,
        Future<void> Function() action,
      ) async {
        final before = version.value;
        await action();
        expect(version.value, before, reason: name);
      }

      late Expense e;
      await expectBump('add', () async => e = await repository.add(input()));
      await expectBump('update', () => repository.update(e.id, input()));
      await expectBump('moveToBin', () => repository.moveToBin(e.id));
      await expectBump('restore', () => repository.restore(e.id));
      await expectBump('moveToBin', () => repository.moveToBin(e.id));
      await expectBump('restoreAll', repository.restoreAll);
      await expectBump('moveToBin', () => repository.moveToBin(e.id));
      await expectBump(
        'deletePermanently',
        () => repository.deletePermanently(e.id),
      );
      await expectBump('emptyBin', repository.emptyBin);
      await expectBump('purgeBin', repository.purgeBin);

      await expectNoBump('byId', () => repository.byId(1));
      await expectNoBump('page', repository.page);
      await expectNoBump('binned', repository.binned);
      await expectNoBump('categoryUsage', repository.categoryUsage);
      await expectNoBump('eventUsage', repository.eventUsage);
      await expectNoBump('recentCurrencies', repository.recentCurrencies);
    });

    test('a failed write does not bump it', () async {
      final before = version.value;
      await expectLater(
        repository.update(999, input()),
        throwsA(isA<ExpenseNotFound>()),
      );
      expect(version.value, before);
    });
  });
}

/// Records the SQL of every query, to check what a method really runs.
class _LoggingDatabase implements Database {
  _LoggingDatabase(this._db, this._log);

  final Database _db;
  final List<String> _log;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    _log.add('$table WHERE $where');
    return _db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
