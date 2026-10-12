import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/data_version.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/home_list.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/domain/totals.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

/// Home's reads: the list order, the filters, the rows a total covers, the
/// text filter's entries and paging by ids. All on SQLite 3.22.
void main() {
  late Database db;
  late TestClock clock;
  late ExpenseRepository repository;

  setUp(() async {
    db = await openMigratedDatabase();
    clock = TestClock(DateTime.utc(2026, 10, 5, 6));
    repository = ExpenseRepository(
      db,
      dataVersion: DataVersion(),
      now: clock.call,
    );
  });

  Future<int> id(String table, String builtinKey) async =>
      (await db.query(
            table,
            where: 'builtin_key = ?',
            whereArgs: [builtinKey],
          )).single['id']!
          as int;

  /// Adds an expense at [at] (UTC) recorded with [offset] minutes.
  Future<Expense> add(
    String title, {
    DateTime? at,
    int offset = 330,
    int minor = 100,
    String code = 'INR',
    int categoryId = 1,
    Set<int> eventIds = const {},
    String? description,
  }) => repository.add(
    ExpenseInput(
      title: title,
      description: description,
      amount: Money(minor, code),
      occurredAt: at ?? DateTime.utc(2026, 10, 5, 6),
      utcOffsetMinutes: offset,
      categoryId: categoryId,
      paymentMethodId: 1,
      eventIds: eventIds,
    ),
  );

  Future<Expense> addBinned(String title, {DateTime? at}) async {
    final expense = await add(title, at: at);
    await repository.moveToBin(expense.id);
    return expense;
  }

  Future<List<String>> allPages({
    ExpenseFilter filter = ExpenseFilter.none,
    int limit = 2,
  }) async {
    final titles = <String>[];
    ExpenseCursor? cursor;
    while (true) {
      final page = await repository.page(
        filter: filter,
        after: cursor,
        limit: limit,
      );
      titles.addAll(page.map((e) => e.title));
      if (page.length < limit) return titles;
      cursor = page.last.cursor;
    }
  }

  group('list order', () {
    /// A traveller: 5 Oct noon in India, 6 Oct 1 am in India,
    /// then 5 Oct 8 pm in New York (= 6 Oct 00:00 UTC).
    Future<void> addTraveller() async {
      await add('india noon 5th', at: DateTime.utc(2026, 10, 5, 6, 30));
      await add('india 1am 6th', at: DateTime.utc(2026, 10, 5, 19, 30));
      await add('ny 8pm 5th', at: DateTime.utc(2026, 10, 6), offset: -240);
    }

    test('by local date first, then moment: each day together', () async {
      await addTraveller();
      final page = await repository.page();
      expect(
        [for (final e in page) '${e.occurredOn} ${e.title}'],
        [
          '2026-10-06 india 1am 6th',
          '2026-10-05 ny 8pm 5th',
          '2026-10-05 india noon 5th',
        ],
      );
      final groups = homeGroups(
        page,
        grouping: Period.day,
        weekStart: WeekStart.monday,
        hasMore: false,
      );
      expect(
        [for (final g in groups) g.range.from],
        ['2026-10-06', '2026-10-05'],
        reason: 'one header per date, not 6, 5, 6 or 5, 6, 5',
      );
    });

    test('the cursor continues across a day, in that order', () async {
      await addTraveller();
      expect(await allPages(limit: 1), [
        'india 1am 6th',
        'ny 8pm 5th',
        'india noon 5th',
      ]);
    });

    test('keyset across equal dates and equal moments, no gaps', () async {
      final t = DateTime.utc(2026, 10, 1, 7);
      for (var i = 0; i < 5; i++) {
        await add('same $i', at: t);
      }
      // Same moment, another local date (a later one, so listed first).
      await add('later day', at: t, offset: 1020);
      final titles = await allPages();
      expect(titles, hasLength(6));
      expect(titles.first, 'later day');
      expect(titles.skip(1), [
        'same 4',
        'same 3',
        'same 2',
        'same 1',
        'same 0',
      ]);
    });

    test('the index replaces (occurred_at, id) and (occurred_on)', () async {
      final indexes = [
        for (final row in await db.rawQuery('PRAGMA index_list(expenses)'))
          row['name']! as String,
      ];
      expect(
        indexes,
        contains('index_expenses_on_occurred_on_and_occurred_at_and_id'),
      );
      expect(indexes, isNot(contains('index_expenses_on_occurred_at_and_id')));
      expect(indexes, isNot(contains('index_expenses_on_occurred_on')));
    });
  });

  group('filtered page', () {
    late int food;
    late int transport;
    late int shopping;
    late int party;
    late int birthday;

    setUp(() async {
      food = await id('categories', 'food');
      transport = await id('categories', 'transport');
      shopping = await id('categories', 'shopping');
      party = await id('events', 'party');
      birthday = await id('events', 'birthday');
    });

    test('one category, two categories (either)', () async {
      await add('lunch', categoryId: food);
      await add('cab', categoryId: transport);
      await add('shirt', categoryId: shopping);
      expect(await allPages(filter: ExpenseFilter(categoryIds: {food})), [
        'lunch',
      ]);
      expect(
        (await allPages(filter: ExpenseFilter(categoryIds: {food, shopping})))
            .toSet(),
        {'lunch', 'shirt'},
      );
    });

    test('events: one, two (either), listed once with both', () async {
      await add('cake', eventIds: {birthday});
      await add('drinks', eventIds: {party});
      await add('both', eventIds: {party, birthday});
      await add('none');
      expect(
        (await allPages(filter: ExpenseFilter(eventIds: {party}))).toSet(),
        {'drinks', 'both'},
      );
      final either = await allPages(
        filter: ExpenseFilter(eventIds: {party, birthday}),
      );
      expect(either.toSet(), {'cake', 'drinks', 'both'});
      expect(either, hasLength(3), reason: 'two matching events, one row');
    });

    test("the owner's example: cab in Transport or Shopping, for Party or "
        'Birthday', () async {
      await add('cab home', categoryId: transport, eventIds: {party});
      await add('cab shop', categoryId: shopping, eventIds: {birthday});
      await add('cab food', categoryId: food, eventIds: {party});
      await add('cab untagged', categoryId: transport);
      await add('Metro', categoryId: transport, eventIds: {party});
      final filter = ExpenseFilter(
        text: 'cab',
        categoryIds: {transport, shopping},
        eventIds: {party, birthday},
      );
      final words = searchWords(filter.text);
      final matches = [
        for (final entry in await repository.searchEntries(
          filter: filter.withoutText,
        ))
          if (matchesText(entry, words)) entry.id,
      ];
      final rows = await repository.byIds(matches);
      expect({for (final e in rows) e.title}, {'cab home', 'cab shop'});
    });

    test('a binned match is left out', () async {
      await add('lunch', categoryId: food);
      await addBinned('binned lunch');
      expect(await allPages(filter: ExpenseFilter(categoryIds: {food})), [
        'lunch',
      ]);
    });

    test('1200 category ids in one filter: no variable limit', () async {
      await add('lunch', categoryId: food);
      final ids = {for (var i = 1000; i < 2199; i++) i, food};
      expect(ids, hasLength(1200));
      expect(await allPages(filter: ExpenseFilter(categoryIds: ids)), [
        'lunch',
      ]);
      expect(
        await repository.amountsIn(
          from: '2026-01-01',
          to: '2026-12-31',
          filter: ExpenseFilter(categoryIds: ids, eventIds: ids),
        ),
        isEmpty,
      );
    });

    test('byIds with 1200 ids: bound in chunks under 3.22 999 variables, '
        'events kept, binned and unknown ids left out, list order', () async {
      final party = await id('events', 'party');
      final added = <int>[];
      await db.transaction((txn) async {
        for (var i = 0; i < 1100; i++) {
          added.add(
            await insertExpenseRow(
              txn,
              categoryId: food,
              deletedAt: i == 7 ? 1 : null,
              eventIds: i.isEven ? {party} : const {},
            ),
          );
        }
      });
      final ids = [...added, for (var i = 0; i < 100; i++) 900000 + i];
      expect(ids, hasLength(1200));
      final rows = await repository.byIds(ids);
      expect(rows, hasLength(1099), reason: 'one binned, 100 unknown');
      expect(rows.map((e) => e.id), isNot(contains(added[7])));
      // Same day and moment: newest id first.
      expect(rows.first.id, added.last);
      expect(rows.last.id, added.first);
      final byId = {for (final e in rows) e.id: e};
      // Rows past the first chunk still get their events.
      expect(byId[added[1098]]!.eventIds, {party});
      expect(byId[added[1099]]!.eventIds, isEmpty);
      expect(byId[added[0]]!.eventIds, {party});
    });

    test('a filter id that does not exist matches nothing', () async {
      await add('lunch', categoryId: food);
      expect(
        await allPages(filter: const ExpenseFilter(categoryIds: {999})),
        isEmpty,
      );
    });
  });

  group('amountsIn', () {
    test('bounds are inclusive, the day after is not', () async {
      // occurred_on 2026-10-01, 2026-10-04, 2026-10-05 (India).
      await add('first', at: DateTime.utc(2026, 9, 30, 20), minor: 1);
      await add('last', at: DateTime.utc(2026, 10, 4, 6), minor: 10);
      await add('after', at: DateTime.utc(2026, 10, 4, 20), minor: 100);
      await add('before', at: DateTime.utc(2026, 9, 30, 6), minor: 1000);
      final rows = await repository.amountsIn(
        from: '2026-10-01',
        to: '2026-10-04',
      );
      expect(rows.toSet(), {
        ('2026-10-01', 'INR', 1),
        ('2026-10-04', 'INR', 10),
      });
    });

    test('binned excluded, future-dated included, draft never', () async {
      await add('today', minor: 100);
      await add('next week', at: DateTime.utc(2026, 10, 9, 6), minor: 200);
      await addBinned('binned');
      // The form's unsaved draft lives in its own table.
      await db.insert('expense_draft', {
        'id': 1,
        'editing_expense_id': null,
        'form_json': '{"title": "ZZDRAFT", "amountExpression": "99999"}',
        'updated_at': 0,
      });
      final rows = await repository.amountsIn(
        from: '2026-10-01',
        to: '2026-10-31',
      );
      expect(sumByCurrency([for (final (_, c, m) in rows) (c, m)]), {
        'INR': BigInt.from(300),
      });
    });

    test('per currency, JPY and KWD exact', () async {
      await add('a', minor: 500, code: 'JPY');
      await add('b', minor: 1234, code: 'KWD');
      await add('c', minor: 1, code: 'KWD');
      final rows = await repository.amountsIn(
        from: '2026-10-05',
        to: '2026-10-05',
      );
      expect(sumByCurrency([for (final (_, c, m) in rows) (c, m)]), {
        'JPY': BigInt.from(500),
        'KWD': BigInt.from(1235),
      });
    });

    test('three rows of max int64 add up exactly (no SQL SUM)', () async {
      for (var i = 0; i < 3; i++) {
        await add('big $i', minor: 9223372036854775807);
      }
      final rows = await repository.amountsIn(
        from: '2026-10-05',
        to: '2026-10-05',
      );
      expect(
        sumByCurrency([for (final (_, c, m) in rows) (c, m)])['INR'],
        BigInt.from(9223372036854775807) * BigInt.from(3),
      );
    });

    test('filtered like page', () async {
      final food = await id('categories', 'food');
      final party = await id('events', 'party');
      await add('food party', categoryId: food, eventIds: {party}, minor: 1);
      await add('food', categoryId: food, minor: 10);
      await add('other party', categoryId: 2, eventIds: {party}, minor: 100);
      Future<int> total(ExpenseFilter filter) async {
        final rows = await repository.amountsIn(
          from: '2026-10-05',
          to: '2026-10-05',
          filter: filter,
        );
        return rows.fold<int>(0, (sum, row) => sum + row.$3);
      }

      expect(await total(ExpenseFilter(categoryIds: {food})), 11);
      expect(await total(ExpenseFilter(eventIds: {party})), 101);
      expect(
        await total(ExpenseFilter(categoryIds: {food}, eventIds: {party})),
        1,
      );
    });
  });

  group('searchEntries', () {
    test('binned excluded, order equals page order, folded text', () async {
      await add('Lunch', at: DateTime.utc(2026, 10, 5, 6, 30));
      await add('india 1am 6th', at: DateTime.utc(2026, 10, 5, 19, 30));
      await add('NY', at: DateTime.utc(2026, 10, 6), offset: -240);
      await addBinned('Binned');
      final entries = await repository.searchEntries();
      final page = await repository.page();
      expect([for (final e in entries) e.id], [for (final e in page) e.id]);
      expect(entries.last.folded, 'lunch\n');
    });

    test('null description, a 1000-character one, category filter', () async {
      final food = await id('categories', 'food');
      final long = 'x' * 999 + 'Ç';
      await add('A', description: long, categoryId: food);
      await add('B', categoryId: 2);
      final entries = await repository.searchEntries(
        filter: ExpenseFilter(categoryIds: {food}),
      );
      expect(entries, hasLength(1));
      expect(entries.single.folded, 'a\n${'x' * 999}ç');
      expect(matchesText(entries.single, searchWords('XÇ')), isTrue);
    });
  });

  group('byIds', () {
    test('in list order; binned and deleted ids left out', () async {
      final a = await add('a', at: DateTime.utc(2026, 10, 1, 6));
      final b = await add('b', at: DateTime.utc(2026, 10, 3, 6));
      final c = await addBinned('c');
      final rows = await repository.byIds([a.id, c.id, 999999, b.id]);
      expect([for (final e in rows) e.title], ['b', 'a']);
    });

    test('1200 ids (chunks) come back with their events', () async {
      final ids = <int>[];
      await db.transaction((txn) async {
        for (var i = 0; i < 1200; i++) {
          final id = await txn.insert('expenses', {
            'title': 'E$i',
            'amount_minor': 100,
            'currency_code': 'INR',
            'occurred_at': i,
            'utc_offset_minutes': 0,
            'occurred_on': '2026-10-01',
            'category_id': 1,
            'payment_method_id': 1,
            'created_at': 0,
            'updated_at': 0,
          });
          await txn.insert('expense_events', {
            'expense_id': id,
            'event_id': 1 + i % 3,
          });
          ids.add(id);
        }
      });
      final rows = await repository.byIds(ids);
      expect(rows, hasLength(1200));
      expect(rows.first.title, 'E1199');
      for (final e in rows) {
        expect(e.eventIds, {1 + int.parse(e.title.substring(1)) % 3});
      }
    });
  });

  test('probe refuses an expenses table without currency_code', () async {
    final db = await openMigratedDatabase();
    // An empty table passes `SELECT *`; the totals read names columns.
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.execute('DROP TABLE expense_events');
    await db.execute('DROP TABLE expenses');
    await db.execute(
      'CREATE TABLE expenses (id INTEGER PRIMARY KEY, title TEXT, '
      'occurred_on TEXT, occurred_at INTEGER, amount_minor INTEGER, '
      'deleted_at INTEGER)',
    );
    await expectLater(
      AppDependencies.probe(db, deviceCurrency: 'INR'),
      throwsA(isA<DatabaseException>()),
    );
  });
}
