import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_draft_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/ui/features/home/view_models/expense_list_cubit.dart';

import '../../../../helpers/fake_timers.dart';
import '../../../../helpers/test_database.dart';

/// Home's chips and unsaved mark (phase-4.md §8, §9).
void main() {
  late AppDependencies deps;
  late TestClock clock;
  late ExpenseDraftRepository drafts;

  setUp(() async {
    clock = TestClock();
    deps = await openTestDependencies(clock: clock);
    drafts = ExpenseDraftRepository(deps.database, timer: FakeTimers().call);
  });

  ExpenseListCubit cubitFor({
    ExpenseRepository? expenses,
    ExpenseDraftRepository? using,
    String currency = 'INR',
  }) {
    final cubit = ExpenseListCubit(
      expenses: expenses ?? deps.expenses,
      categories: deps.categories,
      paymentMethods: deps.paymentMethods,
      events: deps.events,
      drafts: using ?? drafts,
      dataVersion: deps.dataVersion,
      defaultCurrency: currency,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  ExpenseListLoaded loaded(ExpenseListCubit cubit) =>
      cubit.value as ExpenseListLoaded;

  Future<Expense> add(int amountMinor, {String currency = 'INR'}) =>
      deps.expenses.add(
        ExpenseInput(
          title: 'x',
          description: null,
          amount: Money(amountMinor, currency),
          occurredAt: clock.now.subtract(const Duration(days: 1)),
          utcOffsetMinutes: 0,
          categoryId: 1,
          paymentMethodId: 1,
          eventIds: const {},
        ),
      );

  ExpenseDraft draftFor(int? expenseId) => ExpenseDraft(
    editingExpenseId: expenseId,
    title: 'Draft',
    amountExpression: '',
    description: '',
    categoryId: null,
    eventIds: const {},
    paymentMethodId: 1,
    currencyCode: 'INR',
    pickedWallClock: null,
    touched: const {},
    itemizeLine: null,
    itemizeLabels: const [],
    itemizeTerms: const [],
    updatedAt: DateTime.utc(2026),
  );

  group('chips', () {
    test(
      'loaded with the list: popular amounts topped up, ascending',
      () async {
        await add(3500);
        await add(3500);
        final cubit = cubitFor();
        await cubit.load();
        expect(loaded(cubit).chips.map((m) => m.amountMinor), [
          1000,
          3500,
          5000,
          10000,
          20000,
          50000,
        ]);
        expect(loaded(cubit).chips.map((m) => m.currencyCode).toSet(), {'INR'});
      },
    );

    test('shown with no expenses (the empty state)', () async {
      final cubit = cubitFor();
      await cubit.load();
      expect(loaded(cubit).expenses, isEmpty);
      expect(loaded(cubit).chips, hasLength(6));
    });

    test('a currency change reloads them', () async {
      await add(250, currency: 'USD');
      await add(250, currency: 'USD');
      final cubit = cubitFor();
      await cubit.load();
      await cubit.setDefaultCurrency('USD');
      expect(loaded(cubit).chips.map((m) => m.amountMinor), [
        100,
        250,
        500,
        1000,
        2000,
        5000,
      ]);
      expect(loaded(cubit).chips.first.currencyCode, 'USD');
    });

    test(
      "a reload in flight doesn't put the old currency's chips back",
      () async {
        final gated = _GatedChips(deps);
        final cubit = cubitFor(expenses: gated);
        await cubit.load();
        // The reload is inside its INR chip query when the currency changes.
        final gate = gated.gate = Completer<void>();
        final reloading = cubit.reload();
        await pumpEventQueue();
        expect(gated.waiting, isTrue);
        gated.gate = null;
        await cubit.setDefaultCurrency('USD');
        gate.complete();
        await reloading;
        expect(loaded(cubit).chips.map((m) => m.currencyCode).toSet(), {'USD'});
      },
    );

    test('a currency without fallbacks and no history: none', () async {
      final cubit = cubitFor(currency: 'KWD');
      await cubit.load();
      expect(loaded(cubit).chips, isEmpty);
    });

    test('a failing chips query hides them; the list still loads', () async {
      await add(100);
      final cubit = cubitFor(expenses: _NoChips(deps));
      await cubit.load();
      expect(loaded(cubit).expenses, hasLength(1));
      expect(loaded(cubit).chips, isEmpty);
    });

    test('the chips change after a save (reload)', () async {
      final cubit = cubitFor();
      await cubit.load();
      await add(4200);
      await add(4200);
      await cubit.reload();
      expect(loaded(cubit).chips.map((m) => m.amountMinor), contains(4200));
    });
  });

  group('the draft slot', () {
    test('pendingDraft failing → null, nothing thrown', () async {
      final broken = ExpenseDraftRepository(deps.database);
      await deps.database.execute('DROP TABLE expense_draft');
      final cubit = cubitFor(using: broken);
      expect(await cubit.pendingDraft(), isNull);
      await cubit.load();
      expect(cubit.value, isA<ExpenseListLoaded>());
    });

    test('draftExpenseId follows the slot', () async {
      final e = await add(100);
      final cubit = cubitFor();
      await cubit.load();
      expect(loaded(cubit).draftExpenseId, isNull);

      drafts.update(draftFor(e.id));
      await cubit.refreshDraftMark();
      expect(loaded(cubit).draftExpenseId, e.id);

      drafts.update(draftFor(null)); // An Add draft replaced it.
      await cubit.refreshDraftMark();
      expect(loaded(cubit).draftExpenseId, isNull);

      drafts.update(draftFor(e.id));
      await cubit.reload();
      expect(loaded(cubit).draftExpenseId, e.id, reason: 'with every load');

      await drafts.clear();
      await cubit.refreshDraftMark();
      expect(loaded(cubit).draftExpenseId, isNull);
    });

    test('a draft never shows as an expense row', () async {
      drafts.update(draftFor(null));
      await drafts.flush();
      final cubit = cubitFor();
      await cubit.load();
      expect(loaded(cubit).expenses, isEmpty);
    });
  });
}

/// An expense repository whose chip query fails.
class _NoChips extends ExpenseRepository {
  _NoChips(AppDependencies deps)
    : super(deps.database, dataVersion: deps.dataVersion);

  @override
  Future<List<int>> amountChipStats(String currencyCode) async =>
      throw StateError('no chips');
}

/// An expense repository whose chip query waits for [gate] while it is set.
class _GatedChips extends ExpenseRepository {
  _GatedChips(AppDependencies deps)
    : super(deps.database, dataVersion: deps.dataVersion);

  Completer<void>? gate;
  bool waiting = false;

  @override
  Future<List<int>> amountChipStats(String currencyCode) async {
    if (gate case final gate?) {
      waiting = true;
      await gate.future;
    }
    return super.amountChipStats(currencyCode);
  }
}
