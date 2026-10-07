import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/domain/totals.dart';
import 'package:my_expense_tracker_app/ui/features/home/view_models/expense_list_cubit.dart';

import '../../../../helpers/test_database.dart';

/// Records every `amountsIn` and `page` call; with [hold] set, each waits
/// for the test to complete its gate.
class _SpyExpenses extends ExpenseRepository {
  _SpyExpenses(super.db, {required super.dataVersion});

  bool hold = false;
  final reads = <String>[];
  final gates = <Completer<void>>[];
  Exception? failWith;

  final pageGates = <Completer<void>>[];
  bool holdPages = false;

  /// Holds first pages (no cursor) on [pageGates] too.
  bool holdFirstPages = false;

  /// Every `page` call throws this.
  Exception? failPagesWith;

  @override
  Future<List<AmountRow>> amountsIn({
    required String from,
    required String to,
    ExpenseFilter filter = ExpenseFilter.none,
  }) async {
    reads.add('$from…$to');
    if (hold) {
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
    }
    if (failWith case final error?) throw error;
    return super.amountsIn(from: from, to: to, filter: filter);
  }

  @override
  Future<List<Expense>> page({
    ExpenseFilter filter = ExpenseFilter.none,
    ExpenseCursor? after,
    int limit = 30,
  }) async {
    if (after == null ? holdFirstPages : holdPages) {
      final gate = Completer<void>();
      pageGates.add(gate);
      await gate.future;
    }
    if (failPagesWith case final error?) throw error;
    return super.page(filter: filter, after: after, limit: limit);
  }
}

void main() {
  late AppDependencies deps;
  late _SpyExpenses spy;

  setUp(() async {
    deps = await openTestDependencies();
    spy = _SpyExpenses(deps.database, dataVersion: deps.dataVersion);
  });

  ExpenseListCubit cubitFor({int pageSize = 30}) {
    final cubit = ExpenseListCubit(
      expenses: spy,
      categories: deps.categories,
      paymentMethods: deps.paymentMethods,
      events: deps.events,
      drafts: deps.drafts,
      dataVersion: deps.dataVersion,
      defaultCurrency: 'INR',
      pageSize: pageSize,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// Adds an expense at noon UTC on [day] (offset 0, so occurred_on = day).
  Future<Expense> add(
    String day, {
    String title = 'E',
    int minor = 100,
    String code = 'INR',
    int categoryId = 1,
  }) => deps.expenses.add(
    ExpenseInput(
      title: title,
      description: null,
      amount: Money(minor, code),
      occurredAt: DateTime.parse('${day}T12:00:00Z'),
      utcOffsetMinutes: 0,
      categoryId: categoryId,
      paymentMethodId: 1,
      eventIds: const {},
    ),
  );

  ExpenseListLoaded loaded(ExpenseListCubit cubit) =>
      cubit.value as ExpenseListLoaded;

  SubtotalState? subtotal(ExpenseListCubit cubit, PeriodRange key) =>
      loaded(cubit).subtotals[key];

  CurrencyTotals? totals(ExpenseListCubit cubit, PeriodRange key) =>
      switch (subtotal(cubit, key)) {
        SubtotalReady(:final totals) => totals,
        _ => null,
      };

  final week = periodOf('2026-10-05', Period.week, WeekStart.monday);
  final lastWeek = periodOf('2026-09-28', Period.week, WeekStart.monday);

  /// Lets queued reads run.
  Future<void> settle() => pumpEventQueue();

  group('lazy subtotals', () {
    test('read once per key, one at a time, in request order', () async {
      await add('2026-10-05', minor: 100);
      await add('2026-10-06', minor: 50, code: 'USD');
      await add('2026-09-29', minor: 7);
      final cubit = cubitFor();
      await cubit.load();
      expect(loaded(cubit).groups.map((g) => g.range.from), [
        '2026-10-05',
        '2026-09-28',
      ]);

      spy.hold = true;
      cubit
        ..requestSubtotal(week)
        ..requestSubtotal(lastWeek)
        ..requestSubtotal(week); // a second request is a no-op
      await settle();
      expect(spy.reads, ['2026-10-05…2026-10-11'], reason: 'one at a time');
      spy.gates.single.complete();
      await settle();
      expect(spy.reads, ['2026-10-05…2026-10-11', '2026-09-28…2026-10-04']);
      spy.gates.last.complete();
      await settle();

      expect(totals(cubit, week), {
        'INR': BigInt.from(100),
        'USD': BigInt.from(50),
      });
      expect(totals(cubit, lastWeek), {'INR': BigInt.from(7)});
      cubit.requestSubtotal(week);
      await settle();
      expect(spy.reads, hasLength(2), reason: 'cached');
    });

    test('a failure is failed; retry reads again', () async {
      await add('2026-10-05');
      final cubit = cubitFor();
      await cubit.load();
      spy.failWith = Exception('disk');
      cubit.requestSubtotal(week);
      await settle();
      expect(subtotal(cubit, week), isA<SubtotalFailed>());

      spy.failWith = null;
      cubit.retrySubtotal(week);
      await settle();
      expect(totals(cubit, week), {'INR': BigInt.from(100)});
      expect(spy.reads, hasLength(2));
    });

    for (final change in ['filter', 'grouping', 'week start']) {
      test(
        'changing the $change with a read held drops the late result',
        () async {
          final food = await add('2026-10-05', minor: 100, categoryId: 1);
          await add('2026-10-05', minor: 1000, categoryId: 2);
          final cubit = cubitFor();
          await cubit.load();
          spy.hold = true;
          cubit.requestSubtotal(week);
          await settle();

          switch (change) {
            case 'filter':
              await cubit.setFilter(
                ExpenseFilter(categoryIds: {food.categoryId}),
              );
            case 'grouping':
              cubit.setGrouping(Period.month);
            case _:
              cubit.setWeekStart(WeekStart.sunday);
          }
          expect(loaded(cubit).subtotals, isEmpty, reason: 'shows loading');
          spy.gates.single.complete(); // the old read finishes now
          await settle();
          expect(
            loaded(cubit).subtotals,
            isEmpty,
            reason: 'late result dropped',
          );

          spy.hold = false;
          final key = loaded(cubit).groups.first.range;
          cubit.requestSubtotal(key);
          await settle();
          expect(totals(cubit, key), {
            'INR': BigInt.from(change == 'filter' ? 100 : 1100),
          });
        },
      );
    }

    test(
      'a reload after a write drops them; visible ones read again',
      () async {
        await add('2026-10-05', minor: 100);
        final cubit = cubitFor();
        await cubit.load();
        cubit.requestSubtotal(week);
        await settle();
        expect(totals(cubit, week), {'INR': BigInt.from(100)});

        await add('2026-10-06', minor: 1);
        await cubit.reloadIfChanged();
        expect(loaded(cubit).subtotals, isEmpty);
        cubit.requestSubtotal(week);
        await settle();
        expect(totals(cubit, week), {'INR': BigInt.from(101)});
      },
    );

    test('a group cut by the page end still gets its whole subtotal', () async {
      for (var i = 0; i < 40; i++) {
        await add('2026-10-0${5 + i % 5}', minor: 1);
      }
      final cubit = cubitFor(pageSize: 30);
      await cubit.load();
      expect(loaded(cubit).expenses, hasLength(30));
      expect(loaded(cubit).groups.single.open, isTrue);
      cubit.requestSubtotal(week);
      await settle();
      expect(totals(cubit, week), {'INR': BigInt.from(40)});
    });
  });

  group('text filter', () {
    test(
      'rows page through the matches; subtotals cover unloaded ones',
      () async {
        for (var i = 0; i < 40; i++) {
          await add('2026-10-0${5 + i % 5}', title: 'Cab $i', minor: 2);
        }
        await add('2026-10-05', title: 'Lunch', minor: 1000);
        final cubit = cubitFor(pageSize: 30);
        await cubit.setFilter(const ExpenseFilter(text: 'cab'));
        expect(loaded(cubit).expenses, hasLength(30));
        expect(loaded(cubit).hasMore, isTrue);

        cubit.requestSubtotal(week);
        expect(totals(cubit, week), {'INR': BigInt.from(80)}, reason: 'sync');
        expect(spy.reads, isEmpty, reason: 'from the matches in memory');

        await cubit.loadMore();
        expect(loaded(cubit).expenses, hasLength(40));
        expect(loaded(cubit).hasMore, isFalse);
        expect(
          loaded(cubit).expenses.every((e) => e.title.startsWith('Cab')),
          isTrue,
        );
      },
    );

    test('a match binned since is skipped, not shown', () async {
      final a = await add('2026-10-05', title: 'cab a');
      await add('2026-10-04', title: 'cab b');
      final cubit = cubitFor();
      await cubit.setFilter(const ExpenseFilter(text: 'cab'));
      await deps.expenses.moveToBin(a.id);
      await cubit.reload();
      expect([for (final e in loaded(cubit).expenses) e.title], ['cab b']);
    });
  });

  test('setFilter during loadMore drops the page; rows start over', () async {
    for (var i = 0; i < 5; i++) {
      await add(
        '2026-10-0${1 + i}',
        title: 'E$i',
        categoryId: i.isEven ? 1 : 2,
      );
    }
    final cubit = cubitFor(pageSize: 2);
    await cubit.load();
    spy.holdPages = true;
    final more = cubit.loadMore();
    await settle();
    await cubit.setFilter(const ExpenseFilter(categoryIds: {2}));
    spy.pageGates.single.complete();
    await more;
    expect([for (final e in loaded(cubit).expenses) e.title], ['E3', 'E1']);
    expect(loaded(cubit).expenses.toSet(), hasLength(2), reason: 'no dupes');
  });

  test('a category deleted in Manage leaves the filter on reload', () async {
    final mine = await deps.categories.add(name: 'Mine', emoji: '🧪');
    await add('2026-10-05', title: 'mine', categoryId: mine.id);
    await add('2026-10-04', title: 'food');
    final cubit = cubitFor();
    await cubit.setFilter(ExpenseFilter(categoryIds: {mine.id}));
    expect([for (final e in loaded(cubit).expenses) e.title], ['mine']);

    await deps.categories.moveExpensesAndDelete(mine.id, toId: 1);
    await cubit.reloadIfChanged();
    expect(loaded(cubit).filter.categoryIds, isEmpty);
    expect(
      [for (final e in loaded(cubit).expenses) e.title],
      ['mine', 'food'],
      reason: 'everything, not nothing',
    );
  });

  test('regrouping keeps the rows and rebuilds the groups', () async {
    await add('2026-10-05');
    await add('2026-09-29');
    final cubit = cubitFor();
    await cubit.load();
    final rows = loaded(cubit).expenses;
    cubit.setGrouping(Period.month);
    expect(identical(loaded(cubit).expenses, rows), isTrue);
    expect(loaded(cubit).groups.map((g) => g.range.from), [
      '2026-10-01',
      '2026-09-01',
    ]);
    cubit.setGrouping(Period.year);
    expect(loaded(cubit).groups.single.range.from, '2026-01-01');
  });

  test('a subtotal alone keeps the same list (no list rebuild)', () async {
    await add('2026-10-05');
    final cubit = cubitFor();
    await cubit.load();
    final before = loaded(cubit);
    cubit.requestSubtotal(week);
    await settle();
    expect(loaded(cubit).sameListAs(before), isTrue);
    expect(identical(loaded(cubit), before), isFalse);
  });

  // Regressions found in the Phase 5 review (2026-10-06).
  group('a regroup or a failed filter during a load', () {
    test('setWeekStart during the first load still shows the list', () async {
      await add('2026-10-05');
      final cubit = cubitFor();
      spy.holdFirstPages = true;
      final loading = cubit.load();
      await settle();
      cubit.setWeekStart(WeekStart.sunday);
      spy.pageGates.single.complete();
      await loading;
      expect(cubit.value, isA<ExpenseListLoaded>());
      expect(loaded(cubit).weekStart, WeekStart.sunday);
      expect(
        loaded(cubit).groups.single.range,
        periodOf('2026-10-05', Period.week, WeekStart.sunday),
      );
    });

    test('setGrouping during setFilter keeps the new filter', () async {
      await add('2026-10-05', categoryId: 1);
      await add('2026-10-04', categoryId: 2);
      final cubit = cubitFor();
      await cubit.load();
      spy.holdFirstPages = true;
      final filtering = cubit.setFilter(const ExpenseFilter(categoryIds: {1}));
      await settle();
      cubit.setGrouping(Period.month);
      spy.pageGates.single.complete();
      expect(await filtering, isTrue);
      final state = loaded(cubit);
      expect(state.filter, const ExpenseFilter(categoryIds: {1}));
      expect(state.expenses.map((e) => e.categoryId), [1]);
      expect(state.grouping, Period.month);
    });

    test('a page in flight survives a regroup, grouped the new way', () async {
      for (var d = 1; d <= 3; d++) {
        await add('2026-10-0$d');
      }
      final cubit = cubitFor(pageSize: 2);
      await cubit.load();
      spy.holdPages = true;
      final more = cubit.loadMore();
      await settle();
      cubit.setGrouping(Period.month);
      expect(loaded(cubit).loadingMore, isTrue, reason: 'one page at a time');
      await cubit.loadMore(); // ignored: a page is in flight
      spy.pageGates.single.complete();
      await more;
      final state = loaded(cubit);
      expect(state.expenses.map((e) => e.occurredOn), [
        '2026-10-03',
        '2026-10-02',
        '2026-10-01',
      ]);
      expect(state.groups.single.range.period, Period.month);
    });

    test(
      'a failed setFilter keeps the old filter for pages and subtotals',
      () async {
        // Page size 2: three rows of category 1, three of category 2.
        for (var d = 1; d <= 3; d++) {
          await add('2026-10-0$d', minor: 10, categoryId: 1);
          await add('2026-09-2$d', minor: 1000, categoryId: 2);
        }
        final cubit = cubitFor(pageSize: 2);
        await cubit.load();
        spy.failPagesWith = Exception('disk');
        expect(
          await cubit.setFilter(const ExpenseFilter(categoryIds: {2})),
          isFalse,
        );
        spy.failPagesWith = null;
        expect(loaded(cubit).filter, ExpenseFilter.none);

        await cubit.loadMore();
        expect(
          loaded(cubit).expenses.map((e) => (e.occurredOn, e.categoryId)),
          [
            ('2026-10-03', 1),
            ('2026-10-02', 1),
            ('2026-10-01', 1),
            ('2026-09-23', 2),
          ],
          reason: 'the next page continues the unfiltered list',
        );
        // 28 Sep – 4 Oct: the three category 1 rows of 1–3 Oct.
        cubit.requestSubtotal(lastWeek);
        await settle();
        expect(totals(cubit, lastWeek), {
          'INR': BigInt.from(30),
        }, reason: 'no category filter, like the rows on screen');
      },
    );

    test('a reload overtaking setFilter shows the new filter', () async {
      await add('2026-10-05', categoryId: 1);
      await add('2026-10-04', categoryId: 2);
      final cubit = cubitFor();
      await cubit.load();
      spy.holdFirstPages = true;
      final filtering = cubit.setFilter(const ExpenseFilter(categoryIds: {2}));
      await settle();
      spy.holdFirstPages = false;
      await cubit.reload();
      expect(loaded(cubit).filter, const ExpenseFilter(categoryIds: {2}));
      expect(loaded(cubit).expenses.map((e) => e.categoryId), [2]);
      spy.pageGates.single.complete();
      expect(await filtering, isTrue, reason: 'overtaken, not failed');
      expect(loaded(cubit).filter, const ExpenseFilter(categoryIds: {2}));
    });
  });
}
