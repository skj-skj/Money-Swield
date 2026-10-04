import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/ui/features/home/view_models/expense_list_cubit.dart';

import '../../../../helpers/test_database.dart';

/// Holds each `page()` call until the test completes its gate, so the
/// order in which overlapping loads finish can be chosen.
class _GatedExpenses extends ExpenseRepository {
  _GatedExpenses(super.db, {required super.dataVersion});

  final gates = <Completer<void>>[];

  @override
  Future<List<Expense>> page({ExpenseCursor? after, int limit = 30}) async {
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return super.page(after: after, limit: limit);
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
      drafts: deps.drafts,
      dataVersion: deps.dataVersion,
      chipCurrency: 'INR',
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
        drafts: deps.drafts,
        dataVersion: deps.dataVersion,
        chipCurrency: 'INR',
        pageSize: 3,
      );
      addTearDown(cubit.close);
      final load = cubit.load();
      gated.gates.single.complete();
      await load;
      expect(titles(cubit), ['E6', 'E5', 'E4']);

      // E5 is deleted on the edit screen and Home reloads on return; while
      // that runs, the list (scrolled near its end) asks for the next page,
      // continuing after E4. The reload finishes first.
      await deps.expenses.moveToBin(e5.id);
      final reload = cubit.reload();
      final more = cubit.loadMore();
      gated.gates[1].complete();
      await reload;
      expect(titles(cubit), ['E6', 'E4', 'E3']);
      gated.gates[2].complete();
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
