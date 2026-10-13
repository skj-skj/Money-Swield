import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/data/repositories/report_repository.dart';
import 'package:money_swield/domain/expense_filter.dart';
import 'package:money_swield/domain/models/money.dart';
import 'package:money_swield/domain/repeat_input.dart';
import 'package:money_swield/domain/report_filter.dart';
import 'package:money_swield/domain/report_range.dart';

import '../../helpers/recurring_fixture.dart';

void main() {
  late RecurringFixture f;
  late ReportRepository reports;

  setUp(() async {
    f = await RecurringFixture.open();
    reports = ReportRepository(f.db);
  });

  const oct = ReportRange(ReportPeriod.month, '2026-10-01', '2026-10-31');
  const all = ReportRange.allTime();

  /// Lunch (cat 1, cash 1, no events), Dinner (cat 2, upi 2, events 2 + 5),
  /// Taxi (cat 1, card 3, event 5) in October; Old in 2019; a binned row;
  /// a Netflix payment (recurring). Returns ids by title.
  Future<Map<String, int>> seed() async {
    Future<int> add(
      String title,
      String day, {
      int category = 1,
      int method = 1,
      Set<int> events = const {},
      int amount = 100,
      String currency = 'INR',
    }) async => (await f.expenses.add(
      f.input(
        title: title,
        day: day,
        categoryId: category,
        paymentMethodId: method,
        eventIds: events,
        amount: Money(amount, currency),
      ),
    )).id;
    final ids = {
      'lunch': await add('Lunch', '2026-10-02'),
      'dinner': await add(
        'Dinner',
        '2026-10-03',
        category: 2,
        method: 2,
        events: {2, 5},
      ),
      'taxi': await add('Taxi', '2026-10-31', method: 3, events: {5}),
      'old': await add('Old', '2019-03-12', currency: 'USD'),
      'binned': await add('Binned', '2026-10-04'),
    };
    await f.expenses.moveToBin(ids['binned']!);
    final (expense: netflix, pastAdded: _) = await f.addRepeating(
      input: f.input(
        title: 'Netflix',
        day: '2026-10-09',
        categoryId: 3,
        paymentMethodId: 1,
        eventIds: {},
      ),
      choice: const RepeatChoice(frequency: Frequency.yearly),
    );
    ids['netflix'] = netflix.id;
    return ids;
  }

  Future<List<String>> titles(ReportRange range, ReportFilter filter) async => [
    for (final row in (await reports.read(range, filter)).rows) row.title,
  ];

  test('range and All time; binned never; report order', () async {
    await seed();
    expect(await titles(oct, ReportFilter.none), [
      'Lunch',
      'Dinner',
      'Netflix',
      'Taxi',
    ]);
    expect(await titles(all, ReportFilter.none), [
      'Old',
      'Lunch',
      'Dinner',
      'Netflix',
      'Taxi',
    ]);
  });

  test('category, event, payment method, all three, Only recurring', () async {
    await seed();
    ReportFilter only({
      Set<int> categories = const {},
      Set<int> events = const {},
      Set<int> methods = const {},
      bool recurring = false,
    }) => ReportFilter(
      base: ExpenseFilter(
        categoryIds: categories,
        eventIds: events,
        onlyRecurring: recurring,
      ),
      paymentMethodIds: methods,
    );
    expect(await titles(all, only(categories: {1})), ['Old', 'Lunch', 'Taxi']);
    expect(await titles(all, only(events: {5})), ['Dinner', 'Taxi']);
    expect(await titles(all, only(methods: {1})), ['Old', 'Lunch', 'Netflix']);
    expect(await titles(all, only(methods: {2, 3})), ['Dinner', 'Taxi']);
    expect(
      await titles(all, only(categories: {1}, events: {5}, methods: {3})),
      ['Taxi'],
    );
    expect(await titles(all, only(recurring: true)), ['Netflix']);
  });

  test('the text part is never applied in SQL', () async {
    await seed();
    final read = await reports.read(
      oct,
      const ReportFilter(base: ExpenseFilter(text: 'zzz')),
    );
    expect(read.rows, hasLength(4));
  });

  test('event ids as a set; no events → empty; fields read', () async {
    final ids = await seed();
    final rows = {
      for (final row in (await reports.read(
        all,
        ReportFilter.none,
        withDescriptions: true,
      )).rows)
        row.id: row,
    };
    expect(rows[ids['dinner']]!.eventIds, {2, 5});
    expect(rows[ids['lunch']]!.eventIds, isEmpty);
    final dinner = rows[ids['dinner']]!;
    expect(dinner.categoryId, 2);
    expect(dinner.paymentMethodId, 2);
    expect(dinner.day, '2026-10-03');
    expect(dinner.description, 'Family plan');
    expect(dinner.recurring, isFalse);
    expect(rows[ids['netflix']]!.recurring, isTrue);
    expect(rows[ids['old']]!.currencyCode, 'USD');
    expect(ReportRepository.parseIdSet('3,1,3'), {1, 3});
    expect(ReportRepository.parseIdSet(null), isEmpty);
  });

  test('descriptions only when asked (a text filter needs them)', () async {
    await seed();
    final without = await reports.read(oct, ReportFilter.none);
    expect(without.rows.every((r) => r.description == null), isTrue);
    final withThem = await reports.read(
      oct,
      ReportFilter.none,
      withDescriptions: true,
    );
    expect(withThem.rows.first.description, 'Family plan');
  });

  test('maps: archived events too; every category and method', () async {
    await f.db.update('events', {'archived_at': 1}, where: 'id = 2');
    final read = await reports.read(oct, ReportFilter.none);
    expect(read.events[2]!.isArchived, isTrue);
    expect(read.categories.length, await _count(f, 'categories'));
    expect(read.paymentMethods.length, await _count(f, 'payment_methods'));
    expect(read.events.length, await _count(f, 'events'));
  });

  test('a 1,000-id filter (literals, not variables)', () async {
    await seed();
    final many = {for (var i = 1; i <= 1000; i++) i};
    final read = await reports.read(
      all,
      ReportFilter(
        base: ExpenseFilter(categoryIds: many, eventIds: many),
        paymentMethodIds: many,
      ),
    );
    expect([for (final r in read.rows) r.title], ['Dinner', 'Taxi']);
    final sql = ReportRepository.reportSql(
      oct,
      ReportFilter(base: ExpenseFilter(categoryIds: many)),
    );
    expect('?'.allMatches(sql).length, 2);
  });

  test('a Save started during the read completes after it, not in it '
      '(the reads run on the transaction: one on the database would never '
      'return)', () async {
    await seed();
    final reading = reports.read(oct, ReportFilter.none);
    final saving = f.expenses.add(f.input(title: 'Late', day: '2026-10-05'));
    final read = await reading.timeout(const Duration(seconds: 10));
    final saved = await saving.timeout(const Duration(seconds: 10));
    expect(read.rows.map((r) => r.id), isNot(contains(saved.id)));
    expect(
      (await reports.read(oct, ReportFilter.none)).rows.map((r) => r.id),
      contains(saved.id),
    );
  });

  group('plans on 3.22: the date index, no temp B-tree', () {
    Future<List<String>> plan(ReportRange range, ReportFilter filter) async {
      final sql = ReportRepository.reportSql(range, filter);
      final args = range.isAllTime
          ? const <Object>[]
          : const <Object>['2026-10-01', '2026-10-31'];
      return [
        for (final row in await f.db.rawQuery('EXPLAIN QUERY PLAN $sql', args))
          row['detail']! as String,
      ];
    }

    const methods = ReportFilter(paymentMethodIds: {1, 2});
    for (final (name, range) in [('range', oct), ('All time', all)]) {
      for (final (label, filter) in [
        ('no filter', ReportFilter.none),
        ('payment methods', methods),
        (
          'Only recurring',
          const ReportFilter(
            base: ExpenseFilter(onlyRecurring: true),
            paymentMethodIds: {1},
          ),
        ),
      ]) {
        test('$name, $label', () async {
          final details = await plan(range, filter);
          final text = details.join('\n');
          expect(
            text,
            contains('index_expenses_on_occurred_on_and_occurred_at_and_id'),
            reason: text,
          );
          expect(text, isNot(contains('TEMP B-TREE')), reason: text);
          // The events subquery searches expense_events' key.
          expect(text, contains('expense_events'), reason: text);
          expect(text, isNot(contains('SCAN TABLE expense_events')));
        });
      }
    }
  });
}

Future<int> _count(RecurringFixture f, String table) async =>
    (await f.db.rawQuery('SELECT count(*) AS n FROM $table')).single['n']!
        as int;
