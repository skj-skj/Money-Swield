import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/data/repositories/expense_repository.dart';
import 'package:money_swield/domain/expense_filter.dart';
import 'package:money_swield/domain/models/expense.dart';
import 'package:money_swield/domain/models/money.dart';
import 'package:money_swield/domain/periods.dart';
import 'package:money_swield/domain/totals.dart';
import 'package:money_swield/ui/features/home/view_models/trend_cubit.dart';

import '../../../../helpers/test_database.dart';

class _CountingExpenses extends ExpenseRepository {
  _CountingExpenses(super.db, {required super.dataVersion});

  int reads = 0;
  final gates = <Completer<void>>[];
  bool hold = false;
  Exception? failWith;

  @override
  Future<List<AmountRow>> amountsIn({
    required String from,
    required String to,
    ExpenseFilter filter = ExpenseFilter.none,
  }) async {
    reads++;
    if (hold) {
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
    }
    if (failWith case final error?) throw error;
    return super.amountsIn(from: from, to: to, filter: filter);
  }
}

/// Clock times are local
/// `DateTime(…)`s, so the tests hold in any zone.
void main() {
  late AppDependencies deps;
  late _CountingExpenses expenses;
  late DateTime now;

  setUp(() async {
    deps = await openTestDependencies();
    expenses = _CountingExpenses(deps.database, dataVersion: deps.dataVersion);
    now = DateTime(2026, 10, 5, 9); // Monday 5 Oct, local.
  });

  TrendCubit cubitFor({Period period = Period.month}) {
    final cubit = TrendCubit(
      expenses: expenses,
      now: () => now,
      defaultCurrency: 'INR',
      period: period,
      weekStart: WeekStart.monday,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// An expense at noon local time on [day].
  Future<Expense> add(
    String day, {
    int minor = 100,
    String code = 'INR',
    int categoryId = 1,
    String title = 'E',
  }) {
    final at = DateTime.parse('$day 12:00:00');
    return deps.expenses.add(
      ExpenseInput(
        title: title,
        description: null,
        amount: Money(minor, code),
        occurredAt: at.toUtc(),
        utcOffsetMinutes: at.timeZoneOffset.inMinutes,
        categoryId: categoryId,
        paymentMethodId: 1,
        eventIds: const {},
      ),
    );
  }

  TrendLoaded loaded(TrendCubit cubit) => cubit.value as TrendLoaded;

  BigInt? headline(TrendCubit cubit) {
    final state = loaded(cubit);
    return state.face.totals[state.currency];
  }

  test('week, month and year from one read; a turn reads nothing', () async {
    await add('2026-10-05', minor: 1); // this week
    await add('2026-10-02', minor: 10); // this month, last week
    await add('2026-03-01', minor: 100); // this year
    await add('2025-12-31', minor: 1000); // last year
    final cubit = cubitFor();
    await cubit.load();
    expect(expenses.reads, 1);
    expect(loaded(cubit).period, Period.month);
    expect(headline(cubit), BigInt.from(11));

    expect(cubit.turn(1), Period.year);
    expect(headline(cubit), BigInt.from(111));
    expect(loaded(cubit).face.pointsFor('INR'), hasLength(12));
    cubit.turn(1);
    expect(loaded(cubit).period, Period.week);
    expect(headline(cubit), BigInt.one);
    expect(expenses.reads, 1, reason: 'turns read nothing');
  });

  test('three quick turns: the last one shows', () async {
    await add('2026-10-05');
    final cubit = cubitFor(period: Period.week);
    await cubit.load();
    cubit
      ..turn(1)
      ..turn(1)
      ..turn(-1);
    expect(loaded(cubit).period, Period.month);
  });

  test('a spin turns several periods at once', () async {
    await add('2026-10-05');
    final cubit = cubitFor(period: Period.week);
    await cubit.load();
    cubit.select(0);
    expect(cubit.turn(4), Period.month); // 4 = one round and one
    expect(loaded(cubit).period, Period.month);
    expect(loaded(cubit).selected, isNull);
    expect(cubit.turn(-3), Period.month, reason: 'a full round back');
    expect(cubit.turn(-5), Period.year);
    expect(expenses.reads, 1, reason: 'turns read nothing');
  });

  test('past midnight on a Sunday, the next week after load', () async {
    now = DateTime(2026, 10, 4, 23, 59); // Sunday
    await add('2026-10-04', minor: 5);
    await add('2026-10-05', minor: 7);
    final cubit = cubitFor(period: Period.week);
    await cubit.load();
    expect(loaded(cubit).face.range.from, '2026-09-28');
    expect(headline(cubit), BigInt.from(5));

    now = DateTime(2026, 10, 5, 0, 1);
    await cubit.load();
    expect(loaded(cubit).face.range.from, '2026-10-05');
    expect(headline(cubit), BigInt.from(7));
  });

  test('a week crossing into last year keeps its 7 days', () async {
    now = DateTime(2027, 1, 1, 9); // Friday; the week starts 28 Dec 2026
    await add('2026-12-28', minor: 3);
    await add('2027-01-01', minor: 4);
    final cubit = cubitFor(period: Period.week);
    await cubit.load();
    final points = loaded(cubit).face.pointsFor('INR');
    expect(points, hasLength(7));
    expect(points.first.amountMinor, BigInt.from(3));
    expect(headline(cubit), BigInt.from(7));
    cubit.turn(-1); // the year: 2027 only
    expect(headline(cubit), BigInt.from(4));
  });

  test('future-dated days of the period count', () async {
    await add('2026-10-30', minor: 9);
    final cubit = cubitFor();
    await cubit.load();
    expect(headline(cubit), BigInt.from(9));
  });

  group('currency carousel', () {
    test('default first, then by code; wraps both ways', () async {
      await add('2026-10-05', minor: 100);
      await add('2026-10-05', minor: 5, code: 'USD');
      await add('2026-10-05', minor: 6, code: 'EUR');
      final cubit = cubitFor();
      await cubit.load();
      expect(loaded(cubit).currenciesOf(Period.month), ['INR', 'EUR', 'USD']);
      expect(loaded(cubit).currency, 'INR');
      cubit.moveCurrency(1);
      expect(loaded(cubit).currency, 'EUR');
      cubit
        ..moveCurrency(1)
        ..moveCurrency(1);
      expect(loaded(cubit).currency, 'INR', reason: 'endless loop');
      cubit.moveCurrency(-1);
      expect(loaded(cubit).currency, 'USD');
    });

    test('the default absent: starts on the first', () async {
      await add('2026-10-05', minor: 5, code: 'USD');
      final cubit = cubitFor();
      await cubit.load();
      expect(loaded(cubit).currency, 'USD');
    });

    test('kept across a reload and a turn while it has rows, else the '
        'default', () async {
      await add('2026-10-05', minor: 100);
      await add('2026-10-05', minor: 5, code: 'USD');
      await add('2026-03-05', minor: 6, code: 'EUR');
      final cubit = cubitFor();
      await cubit.load();
      cubit.moveCurrency(1); // USD
      await cubit.load();
      expect(loaded(cubit).currency, 'USD');
      cubit.turn(1); // the year has USD too
      expect(loaded(cubit).currency, 'USD');
      cubit.moveCurrency(-1); // EUR, only in the year
      cubit.turn(1); // the week: no EUR
      expect(loaded(cubit).currency, 'INR');
    });

    test('one currency: moving does nothing', () async {
      await add('2026-10-05');
      final cubit = cubitFor();
      await cubit.load();
      cubit.moveCurrency(1);
      expect(loaded(cubit).currency, 'INR');
    });

    test('an empty period has one page, the current currency', () async {
      await add('2026-03-05', minor: 6, code: 'EUR');
      final cubit = cubitFor();
      await cubit.load();
      expect(loaded(cubit).face.isEmpty, isTrue);
      expect(loaded(cubit).currenciesOf(Period.month), [
        loaded(cubit).currency,
      ]);
    });
  });

  test('selection toggles; a reload or a turn clears it', () async {
    await add('2026-10-05');
    final cubit = cubitFor();
    await cubit.load();
    cubit.select(4);
    expect(loaded(cubit).selected, 4);
    cubit.select(4);
    expect(loaded(cubit).selected, isNull);
    cubit.select(2);
    await cubit.load();
    expect(loaded(cubit).selected, isNull);
    cubit
      ..select(2)
      ..turn(1);
    expect(loaded(cubit).selected, isNull);
  });

  test('a failure shows failed; trying again loads', () async {
    await add('2026-10-05');
    expenses.failWith = Exception('disk');
    final cubit = cubitFor();
    await cubit.load();
    expect(cubit.value, isA<TrendFailed>());
    expenses.failWith = null;
    await cubit.load();
    expect(headline(cubit), BigInt.from(100));
  });

  group('follows the filter', () {
    test('a Food filter: this month\'s Food rows, marked filtered', () async {
      await add('2026-10-05', minor: 100, categoryId: 1);
      await add('2026-10-06', minor: 1000, categoryId: 2);
      final cubit = cubitFor();
      await cubit.load();
      expect(loaded(cubit).filtered, isFalse);
      await cubit.setFilter(const ExpenseFilter(categoryIds: {1}));
      expect(headline(cubit), BigInt.from(100));
      expect(loaded(cubit).filtered, isTrue);
      await cubit.setFilter(ExpenseFilter.none);
      expect(headline(cubit), BigInt.from(1100));
      expect(loaded(cubit).filtered, isFalse);
    });

    test('a text filter: the matching entries in the period', () async {
      await add('2026-10-05', minor: 1, title: 'Cab home');
      await add('2026-10-06', minor: 10, title: 'Lunch');
      await add('2025-10-06', minor: 100, title: 'cab last year');
      final cubit = cubitFor();
      await cubit.setFilter(const ExpenseFilter(text: 'CAB'));
      expect(headline(cubit), BigInt.one);
      cubit.turn(1);
      expect(headline(cubit), BigInt.one, reason: 'only this year');
    });

    test('setFilter with a read held drops the old result', () async {
      await add('2026-10-05', minor: 100, categoryId: 1);
      await add('2026-10-06', minor: 1000, categoryId: 2);
      final cubit = cubitFor();
      expenses.hold = true;
      final old = cubit.load();
      await pumpEventQueue();
      final filtered = cubit.setFilter(const ExpenseFilter(categoryIds: {2}));
      await pumpEventQueue();
      expenses.gates[1].complete();
      await filtered;
      expect(headline(cubit), BigInt.from(1000));
      expenses.gates[0].complete(); // the unfiltered read arrives late
      await old;
      expect(headline(cubit), BigInt.from(1000));
      expect(loaded(cubit).filtered, isTrue);
    });
  });

  test('setDefaultCurrency reorders without reading', () async {
    await add('2026-10-05', minor: 5, code: 'USD');
    await add('2026-10-05', minor: 100);
    final cubit = cubitFor();
    await cubit.load();
    cubit.setDefaultCurrency('USD');
    expect(loaded(cubit).currenciesOf(Period.month), ['USD', 'INR']);
    expect(expenses.reads, 1);
  });

  // Regression (review, 2026-10-06): Home's list hands its filter
  // to the card after its first load, while the card's own first load,
  // with the same filter, is running. That read the rows twice.
  test('setFilter with the same filter reads nothing', () async {
    await add('2026-10-05', minor: 5);
    final cubit = cubitFor();
    final first = cubit.load();
    await cubit.setFilter(ExpenseFilter.none);
    await first;
    expect(expenses.reads, 1);
    expect(headline(cubit), BigInt.from(5));

    await cubit.setFilter(const ExpenseFilter(categoryIds: {1}));
    expect(expenses.reads, 2, reason: 'a new filter reads again');
    await cubit.setFilter(const ExpenseFilter(categoryIds: {1}));
    expect(expenses.reads, 2);
  });
}
