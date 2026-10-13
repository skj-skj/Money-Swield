import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/data/repositories/expense_repository.dart';
import 'package:money_swield/domain/expense_filter.dart';
import 'package:money_swield/domain/models/expense.dart';
import 'package:money_swield/domain/models/money.dart';
import 'package:money_swield/ui/features/home/view_models/expense_list_cubit.dart';

import '../../../../helpers/test_database.dart';

/// Holds each `page()` call until the test completes its gate, so the
/// order in which overlapping loads finish can be chosen.
class _GatedExpenses extends ExpenseRepository {
  _GatedExpenses(super.db, {required super.dataVersion});

  final gates = <Completer<void>>[];

  /// Whether each gated call continues after a cursor (a next page) or is
  /// a load from the top, in call order.
  final continues = <bool>[];

  /// The gate of the first call matching [next] not yet released, once
  /// it has been made (a load reads the lookups before its page).
  Future<Completer<void>> gateOf({required bool next}) async {
    for (var i = 0; i < 100; i++) {
      for (final (index, gate) in gates.indexed) {
        if (continues[index] == next && !gate.isCompleted) return gate;
      }
      await pumpEventQueue(times: 1);
    }
    throw StateError('no ${next ? 'next-page' : 'top'} call');
  }

  @override
  Future<List<Expense>> page({
    ExpenseFilter filter = ExpenseFilter.none,
    ExpenseCursor? after,
    int limit = 30,
  }) async {
    final gate = Completer<void>();
    gates.add(gate);
    continues.add(after != null);
    await gate.future;
    return super.page(filter: filter, after: after, limit: limit);
  }
}

void main() {
  late AppDependencies deps;
  late DateTime next;

  setUp(() async {
    deps = await openTestDependencies();
    next = DateTime.utc(2026, 10, 1, 12);
  });

  ExpenseListCubit cubitFor({int pageSize = 3}) {
    final cubit = ExpenseListCubit(
      expenses: deps.expenses,
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

  /// Adds expenses, each one minute later than the last.
  Future<List<Expense>> addExpenses(int count) async => [
    for (var i = 0; i < count; i++)
      await deps.expenses.add(
        ExpenseInput(
          title: 'E$i',
          description: null,
          amount: const Money(100, 'INR'),
          occurredAt: next = next.add(const Duration(minutes: 1)),
          utcOffsetMinutes: 0,
          categoryId: 1,
          paymentMethodId: 1,
          eventIds: const {},
        ),
      ),
  ];

  ExpenseListLoaded loaded(ExpenseListCubit cubit) =>
      cubit.value as ExpenseListLoaded;

  List<String> titles(ExpenseListCubit cubit) => [
    for (final e in loaded(cubit).expenses) e.title,
  ];

  test('load shows the first page and the lookups', () async {
    await addExpenses(4);
    final cubit = cubitFor();
    await cubit.load();
    expect(titles(cubit), ['E3', 'E2', 'E1']);
    expect(loaded(cubit).hasMore, isTrue);
    expect(loaded(cubit).categories[1]!.builtinKey, 'food');
    expect(loaded(cubit).paymentMethods[1]!.builtinKey, 'cash');
  });

  test('an empty list has nothing more', () async {
    final cubit = cubitFor();
    await cubit.load();
    expect(loaded(cubit).expenses, isEmpty);
    expect(loaded(cubit).hasMore, isFalse);
  });

  test('loadMore continues from the last loaded row until the end', () async {
    await addExpenses(7);
    final cubit = cubitFor();
    await cubit.load();
    await cubit.loadMore();
    expect(titles(cubit), ['E6', 'E5', 'E4', 'E3', 'E2', 'E1']);
    await cubit.loadMore();
    expect(titles(cubit), hasLength(7));
    expect(loaded(cubit).hasMore, isFalse);

    await cubit.loadMore(); // Nothing more: no-op.
    expect(titles(cubit), hasLength(7));
  });

  test('takes the cursor from the last row, even if rows were added', () async {
    await addExpenses(4);
    final cubit = cubitFor();
    await cubit.load();
    // A new expense at the top doesn't shift the next page.
    await addExpenses(1);
    await cubit.loadMore();
    expect(titles(cubit), ['E3', 'E2', 'E1', 'E0']);
  });

  test('a second loadMore while one runs is ignored', () async {
    await addExpenses(9);
    final cubit = cubitFor();
    await cubit.load();
    final first = cubit.loadMore();
    expect(loaded(cubit).loadingMore, isTrue);
    await cubit.loadMore();
    await first;
    expect(titles(cubit), hasLength(6));
    expect(titles(cubit).toSet(), hasLength(6), reason: 'no duplicates');
  });

  test('reload reloads as many rows as are loaded', () async {
    await addExpenses(7);
    final cubit = cubitFor();
    await cubit.load();
    await cubit.loadMore();
    await addExpenses(1); // E0 again, newest.

    await cubit.reload();
    expect(titles(cubit), hasLength(6));
    expect(titles(cubit).first, 'E0');
    expect(loaded(cubit).hasMore, isTrue);
  });

  test('reloadIfChanged does nothing when no repository wrote', () async {
    await addExpenses(1);
    final cubit = cubitFor();
    await cubit.load();

    // Written behind the repositories' back: DataVersion doesn't move, so
    // the tab switch must not reload.
    await insertExpenseRow(deps.database);
    await cubit.reloadIfChanged();
    expect(titles(cubit), ['E0']);

    await deps.categories.add(name: 'Pets', emoji: '🐶');
    await cubit.reloadIfChanged();
    expect(titles(cubit), hasLength(2));
    expect(
      loaded(cubit).categories.values.map((c) => c.name),
      contains('Pets'),
    );
  });

  test('a failed loadMore keeps the rows and offers a retry', () async {
    await addExpenses(4);
    final cubit = cubitFor();
    await cubit.load();
    await deps.database.execute('ALTER TABLE expenses RENAME TO gone');

    await cubit.loadMore();
    expect(titles(cubit), ['E3', 'E2', 'E1']);
    expect(loaded(cubit).loadMoreFailed, isTrue);
    expect(loaded(cubit).loadingMore, isFalse);

    await deps.database.execute('ALTER TABLE gone RENAME TO expenses');
    await cubit.loadMore();
    expect(titles(cubit), ['E3', 'E2', 'E1', 'E0']);
    expect(loaded(cubit).loadMoreFailed, isFalse);
  });

  test('a page requested before a reload is not appended to it', () async {
    await addExpenses(7);
    final cubit = cubitFor();
    await cubit.load();
    final more = cubit.loadMore();
    final reload = cubit.reload();
    await Future.wait([more, reload]);
    expect(titles(cubit).toSet().length, titles(cubit).length);
  });

  test(
    'a page requested during a reload is not appended to its rows',
    () async {
      final [..., e5, _] = await addExpenses(7);
      final gated = _GatedExpenses(
        deps.database,
        dataVersion: deps.dataVersion,
      );
      final cubit = ExpenseListCubit(
        expenses: gated,
        categories: deps.categories,
        paymentMethods: deps.paymentMethods,
        events: deps.events,
        drafts: deps.drafts,
        dataVersion: deps.dataVersion,
        defaultCurrency: 'INR',
        pageSize: 3,
      );
      addTearDown(cubit.close);
      final load = cubit.load();
      (await gated.gateOf(next: false)).complete();
      await load;
      expect(titles(cubit), ['E6', 'E5', 'E4']);

      // E5 is deleted on the edit screen and Home reloads on return; while
      // that runs, the list (scrolled near its end) asks for the next page,
      // continuing after E4. The reload finishes first.
      await deps.expenses.moveToBin(e5.id);
      final reload = cubit.reload();
      final more = cubit.loadMore();
      final staleNext = await gated.gateOf(next: true);
      (await gated.gateOf(next: false)).complete();
      await reload;
      expect(titles(cubit), ['E6', 'E4', 'E3']);
      staleNext.complete();
      await more;

      // The stale page (E3, E2, E1) must not be added after E3 again.
      expect(titles(cubit), ['E6', 'E4', 'E3']);
      expect(loaded(cubit).loadingMore, isFalse);
    },
  );

  test('restore takes an expense out of the bin and reloads', () async {
    final [expense] = await addExpenses(1);
    await deps.expenses.moveToBin(expense.id);
    final cubit = cubitFor();
    await cubit.load();
    expect(titles(cubit), isEmpty);

    await cubit.restore(expense.id);
    expect(titles(cubit), ['E0']);
  });
}
