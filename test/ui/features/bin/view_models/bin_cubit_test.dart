import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/ui/features/bin/view_models/bin_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/bin/views/bin_screen.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('BinCubit', () {
    late AppDependencies deps;
    late TestClock clock;

    setUp(() async {
      clock = TestClock();
      deps = await openTestDependencies(clock: clock);
    });

    BinCubit cubitFor() {
      final cubit = BinCubit(
        expenses: deps.expenses,
        categories: deps.categories,
        events: deps.events,
        paymentMethods: deps.paymentMethods,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    /// Two binned (a, then b a minute later) and one active.
    Future<(int, int, int)> seed() async {
      final a = await insertExpenseRow(deps.database);
      final b = await insertExpenseRow(deps.database, eventIds: {1});
      final active = await insertExpenseRow(deps.database);
      await deps.expenses.moveToBin(a);
      clock.advance(const Duration(minutes: 1));
      await deps.expenses.moveToBin(b);
      return (a, b, active);
    }

    List<int> ids(BinCubit cubit) => [
      for (final e in (cubit.value as BinLoaded).expenses) e.id,
    ];

    test('lists the bin, most recently deleted first, with lookups', () async {
      final (a, b, _) = await seed();
      final cubit = cubitFor();
      await cubit.load();
      expect(ids(cubit), [b, a]);
      final lookups = (cubit.value as BinLoaded).lookups;
      expect(lookups.categories[1]!.builtinKey, 'food');
      expect(lookups.events[1]!.builtinKey, 'birthday');
    });

    test('restore and restoreAll reload the list', () async {
      final (a, b, active) = await seed();
      final cubit = cubitFor();
      await cubit.load();

      await cubit.restore(b);
      expect(ids(cubit), [a]);
      await cubit.restoreAll();
      expect(ids(cubit), isEmpty);
      expect([
        for (final e in await deps.expenses.page()) e.id,
      ], [active, b, a]..sort((x, y) => y.compareTo(x)));
    });

    test('deletePermanently and emptyBin delete for good', () async {
      final (a, b, active) = await seed();
      final cubit = cubitFor();
      await cubit.load();

      await cubit.deletePermanently(b);
      expect(ids(cubit), [a]);
      await cubit.emptyBin();
      expect(ids(cubit), isEmpty);
      expect(
        [for (final row in await deps.database.query('expenses')) row['id']],
        [active],
      );
    });
  });

  group('binAge', () {
    test('days ago are calendar days on the device', () {
      final lateEvening = DateTime(2026, 10, 1, 23);
      expect(binAge(lateEvening, DateTime(2026, 10, 1, 23, 30)).daysAgo, 0);
      // Two hours later it is already "yesterday".
      expect(binAge(lateEvening, DateTime(2026, 10, 2, 1)).daysAgo, 1);
      expect(binAge(lateEvening, DateTime(2026, 10, 11, 0, 5)).daysAgo, 10);
    });

    test('days left are 24-hour periods, rounded up, like the purge', () {
      final deleted = DateTime(2026, 10, 1, 23);
      expect(binAge(deleted, deleted).daysLeft, 30);
      expect(
        binAge(deleted, deleted.add(const Duration(hours: 2))).daysLeft,
        30,
      );
      expect(
        binAge(deleted, deleted.add(const Duration(days: 1))).daysLeft,
        29,
      );
      final end = deleted.add(const Duration(days: 30));
      expect(
        binAge(deleted, end.subtract(const Duration(milliseconds: 1))).daysLeft,
        1,
      );
      expect(binAge(deleted, end).daysLeft, isNull);
      expect(
        binAge(deleted, end.add(const Duration(days: 2))).daysLeft,
        isNull,
      );
    });
  });

  group('binAgeText', () {
    final l10n = l10nFor('en');

    test('reads naturally at the edges', () {
      expect(
        binAgeText(l10n, (daysAgo: 0, daysLeft: 30)),
        'Deleted today · removed in 30 days',
      );
      expect(
        binAgeText(l10n, (daysAgo: 1, daysLeft: 29)),
        'Deleted yesterday · removed in 29 days',
      );
      expect(
        binAgeText(l10n, (daysAgo: 29, daysLeft: 1)),
        'Deleted 29 days ago · removed in 1 day',
      );
      expect(
        binAgeText(l10n, (daysAgo: 31, daysLeft: null)),
        'Deleted 31 days ago · removed on next start',
      );
    });
  });
}
