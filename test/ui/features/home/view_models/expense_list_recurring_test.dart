import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';
import 'package:my_expense_tracker_app/ui/features/home/view_models/expense_list_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/manage/view_models/manage_cubit.dart';

import '../../../../helpers/test_database.dart';

/// Home's catch-up on a new day and the Manage count.
void main() {
  late AppDependencies deps;
  late TestClock clock;

  setUp(() async {
    clock = TestClock(DateTime(2026, 10, 9, 12));
    deps = await openTestDependencies(clock: clock);
  });

  Future<void> dailyMilk() => deps.expenses.addRepeating(
    ExpenseInput(
      title: 'Milk',
      description: null,
      amount: const Money(3000, 'INR'),
      occurredAt: clock.now.toUtc(),
      utcOffsetMinutes: clock.now.timeZoneOffset.inMinutes,
      categoryId: 3,
      paymentMethodId: 1,
      eventIds: const {},
    ),
    const RepeatChoice(frequency: Frequency.daily),
  );

  Future<ExpenseListCubit> home() async {
    final cubit = ExpenseListCubit(
      expenses: deps.expenses,
      categories: deps.categories,
      paymentMethods: deps.paymentMethods,
      events: deps.events,
      drafts: deps.drafts,
      dataVersion: deps.dataVersion,
      defaultCurrency: 'INR',
      recurring: deps.recurring,
      now: clock.call,
    );
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  int rows(ExpenseListCubit cubit) =>
      (cubit.value as ExpenseListLoaded).expenses.length;

  test('the same day: no run', () async {
    await dailyMilk();
    final cubit = await home();
    expect((await cubit.catchUpRecurring()).added, 0);
    expect(rows(cubit), 1);
  });

  test('a new day: one run, the list reloads; again that day: none', () async {
    await dailyMilk();
    final cubit = await home();
    clock.now = DateTime(2026, 10, 10, 0, 0, 5);
    final report = await cubit.catchUpRecurring();
    expect(report.added, 1);
    expect(rows(cubit), 2);
    expect((await cubit.catchUpRecurring()).added, 0);
  });

  test('two calls at once (resume and midnight together): one run', () async {
    await dailyMilk();
    final cubit = await home();
    clock.now = DateTime(2026, 10, 11, 9);
    final reports = await Future.wait([
      cubit.catchUpRecurring(),
      cubit.catchUpRecurring(),
    ]);
    expect(reports.map((r) => r.added).reduce((a, b) => a + b), 2);
    expect(rows(cubit), 3);
  });

  test('a failed run is tried again on the next signal', () async {
    await dailyMilk();
    final cubit = await home();
    clock.now = DateTime(2026, 10, 10, 9);
    await deps.database.execute('ALTER TABLE recurring_expenses RENAME TO x');
    expect((await cubit.catchUpRecurring()).added, 0);
    await deps.database.execute('ALTER TABLE x RENAME TO recurring_expenses');
    expect((await cubit.catchUpRecurring()).added, 1);
  });

  test('Manage counts running items only', () async {
    await dailyMilk();
    await dailyMilk();
    final first = (await deps.recurring.all()).first;
    await deps.recurring.archive(first.id);
    final cubit = ManageCubit(
      categories: deps.categories,
      events: deps.events,
      paymentMethods: deps.paymentMethods,
      recurring: deps.recurring,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.value!.recurring, 1);
  });

  group('upcomingIcon', () {
    FilteredScreenIcon icon(ExpenseListCubit cubit) =>
        (cubit.value as ExpenseListLoaded).upcomingIcon;

    test('hidden with nothing running, shown once an item runs, hidden '
        'again when it is stopped; follows the filter like the photos icon '
        '(owner, 2026-10-10): greyed when it hides every item', () async {
      final cubit = await home();
      expect(icon(cubit), FilteredScreenIcon.hidden);
      await dailyMilk(); // category 3, no events, "Milk"
      await cubit.reloadIfChanged();
      expect(icon(cubit), FilteredScreenIcon.enabled);
      // Another category (999 would be dropped: it doesn't exist).
      await cubit.setFilter(const ExpenseFilter(categoryIds: {1}));
      expect(icon(cubit), FilteredScreenIcon.disabled);
      await cubit.setFilter(const ExpenseFilter(categoryIds: {3}));
      expect(icon(cubit), FilteredScreenIcon.enabled);
      await cubit.setFilter(const ExpenseFilter(text: 'mil'));
      expect(icon(cubit), FilteredScreenIcon.enabled);
      await cubit.setFilter(const ExpenseFilter(text: 'bread'));
      expect(icon(cubit), FilteredScreenIcon.disabled);
      await cubit.setFilter(const ExpenseFilter(onlyRecurring: true));
      expect(icon(cubit), FilteredScreenIcon.enabled);
      final milk = (await deps.recurring.all()).single;
      await deps.recurring.archive(milk.id);
      await cubit.reloadIfChanged();
      expect(icon(cubit), FilteredScreenIcon.hidden);
    });

    test('a failed read hides it; the list still loads', () async {
      await dailyMilk();
      final cubit = await home();
      await deps.database.execute('ALTER TABLE recurring_expenses RENAME TO x');
      await cubit.reload();
      expect(icon(cubit), FilteredScreenIcon.hidden);
      expect(rows(cubit), 1);
    });
  });
}
