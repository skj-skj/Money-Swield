import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/domain/expense_filter.dart';
import 'package:money_swield/domain/models/expense.dart';
import 'package:money_swield/domain/models/money.dart';
import 'package:money_swield/domain/repeat_input.dart';
import 'package:money_swield/domain/upcoming.dart';
import 'package:money_swield/ui/features/recurring/view_models/upcoming_cubit.dart';

import '../../../../helpers/test_database.dart';

/// `UpcomingCubit`. Today is 2026-10-09, noon.
void main() {
  late AppDependencies deps;
  late TestClock clock;

  setUp(() async {
    clock = TestClock(DateTime(2026, 10, 9, 12));
    deps = await openTestDependencies(clock: clock);
  });

  Future<int> item(
    String title, {
    String start = '2026-10-09',
    RepeatChoice choice = const RepeatChoice(),
  }) async {
    final local = DateTime(
      int.parse(start.substring(0, 4)),
      int.parse(start.substring(5, 7)),
      int.parse(start.substring(8, 10)),
      10,
    );
    final (:expense, pastAdded: _) = await deps.expenses.addRepeating(
      ExpenseInput(
        title: title,
        description: null,
        amount: const Money(64900, 'INR'),
        occurredAt: local.toUtc(),
        utcOffsetMinutes: local.timeZoneOffset.inMinutes,
        categoryId: 17,
        paymentMethodId: 4,
        eventIds: const {},
      ),
      choice,
    );
    return expense.recurringExpenseId!;
  }

  Future<UpcomingCubit> open() async {
    final cubit = UpcomingCubit(
      recurring: deps.recurring,
      categories: deps.categories,
      dataVersion: deps.dataVersion,
      now: clock.call,
    );
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  UpcomingLoaded loaded(UpcomingCubit c) => c.value as UpcomingLoaded;

  List<UpcomingPayment> rows(UpcomingCubit c) => [
    for (final m in loaded(c).months)
      for (final d in m.days) ...d.payments,
  ];

  test('Home\'s filter applies (owner, 2026-10-10): only the items it lets '
      'through; skips still work on them', () async {
    await item('Netflix');
    await item('Gym', choice: const RepeatChoice(frequency: Frequency.weekly));
    final cubit = UpcomingCubit(
      recurring: deps.recurring,
      categories: deps.categories,
      dataVersion: deps.dataVersion,
      filter: const ExpenseFilter(text: 'gym'),
      now: clock.call,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect({for (final p in rows(cubit)) p.title}, {'Gym'});
    expect(await cubit.skipOnce(rows(cubit).first), isTrue);
    expect(rows(cubit).first.skipped, isTrue);
    expect({for (final p in rows(cubit)) p.title}, {'Gym'});
  });

  test('a filter that hides every item: empty', () async {
    await item('Netflix');
    final cubit = UpcomingCubit(
      recurring: deps.recurring,
      categories: deps.categories,
      dataVersion: deps.dataVersion,
      filter: const ExpenseFilter(categoryIds: {1}),
      now: clock.call,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(loaded(cubit).isEmpty, isTrue);
  });

  test('nothing running: empty', () async {
    final cubit = await open();
    expect(loaded(cubit).isEmpty, isTrue);
  });

  test('pages a month at a time, up to 12 months on; empty months are '
      'passed over', () async {
    // Netflix monthly from 9 Oct: Oct has nothing after today, so the first
    // page read is Nov.
    await item('Netflix');
    final cubit = await open();
    // October (nothing left after today) has no frame.
    expect([for (final m in loaded(cubit).months) m.month], ['2026-11-01']);
    expect(rows(cubit).first.day, '2026-11-09');
    expect(loaded(cubit).hasMore, isTrue);
    for (var i = 0; i < 20; i++) {
      cubit.loadMore();
    }
    expect(loaded(cubit).hasMore, isFalse);
    expect(rows(cubit), hasLength(12));
    expect(rows(cubit).last.day, '2027-10-09');
  });

  test('skip once → the row stays, skipped; Undo (unskip) → back', () async {
    final id = await item(
      'Gym',
      choice: const RepeatChoice(frequency: Frequency.weekly),
    );
    final cubit = await open();
    final first = rows(cubit).first;
    expect(first.day, '2026-10-16');
    expect(await cubit.skipOnce(first), isTrue);
    expect(rows(cubit).first.skipped, isTrue);
    expect(rows(cubit).first.day, '2026-10-16', reason: 'still listed');
    expect(await deps.recurring.skips(after: '2026-10-09'), {
      (itemId: id, day: '2026-10-16'),
    });
    expect(await cubit.unskip(rows(cubit).first), isTrue);
    expect(rows(cubit).first.skipped, isFalse);
  });

  test(
    'a double tap on Skip: one skip, the second call does nothing',
    () async {
      await item(
        'Gym',
        choice: const RepeatChoice(frequency: Frequency.weekly),
      );
      final cubit = await open();
      final first = rows(cubit).first;
      final results = await Future.wait([
        cubit.skipOnce(first),
        cubit.skipOnce(first),
      ]);
      expect(results.where((r) => r), hasLength(1));
      expect(await deps.recurring.skips(after: '2026-10-09'), hasLength(1));
    },
  );

  test('stop → its rows leave; Undo → back', () async {
    final gym = await item(
      'Gym',
      choice: const RepeatChoice(frequency: Frequency.weekly),
    );
    await item('Netflix');
    final cubit = await open();
    final undo = await cubit.stopItem(gym);
    expect(undo, isNotNull);
    expect(rows(cubit).where((p) => p.itemId == gym), isEmpty);
    expect(await cubit.undoStop(undo!), isTrue);
    expect(rows(cubit).where((p) => p.itemId == gym), isNotEmpty);
    // A second Undo: it runs already, refused (the screen says so).
    expect(await cubit.undoStop(undo), isFalse);
  });

  test('reloadIfChanged: nothing changed → no read; a write → read; a new '
      'day → recomputed from tomorrow', () async {
    await item('Milk', choice: const RepeatChoice(frequency: Frequency.daily));
    final cubit = await open();
    expect(rows(cubit).first.day, '2026-10-10');
    expect(await cubit.reloadIfChanged(), isFalse);
    clock.now = DateTime(2026, 10, 10, 12);
    await deps.recurring.generateDue();
    expect(await cubit.reloadIfChanged(), isTrue);
    expect(rows(cubit).first.day, '2026-10-11');
  });

  test('a skip that turned stale (the day passed) is refused; the list '
      'reads again', () async {
    await item('Milk', choice: const RepeatChoice(frequency: Frequency.daily));
    final cubit = await open();
    final first = rows(cubit).first;
    clock.now = DateTime(2026, 10, 10, 12);
    await expectLater(cubit.skipOnce(first), throwsA(anything));
    expect(rows(cubit).first.day, '2026-10-11');
    expect(loaded(cubit).busy, isEmpty);
  });
}
