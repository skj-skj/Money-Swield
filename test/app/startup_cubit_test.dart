import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/app/startup_cubit.dart';
import 'package:my_expense_tracker_app/domain/models/app_settings.dart';
import 'package:my_expense_tracker_app/ui/features/settings/view_models/settings_cubit.dart';

import '../helpers/test_database.dart';

/// The bin purge at startup (phase-2.md §9.3).
void main() {
  late AppDependencies deps;
  late TestClock clock;

  setUp(() async {
    clock = TestClock();
    deps = await openTestDependencies(clock: clock);
  });

  StartupCubit cubitFor(AppDependencies dependencies) {
    final settings = SettingsCubit(initial: AppSettings.beforeLoad);
    final cubit = StartupCubit(
      openDependencies: () async => dependencies,
      settingsCubit: settings,
    );
    addTearDown(() async {
      await cubit.close();
      await settings.close();
    });
    return cubit;
  }

  test(
    'empties expenses binned more than 30 days ago, keeps the rest',
    () async {
      final day = const Duration(days: 1).inMilliseconds;
      final now = clock.now.millisecondsSinceEpoch;
      final old = await insertExpenseRow(
        deps.database,
        deletedAt: now - 31 * day,
      );
      final recent = await insertExpenseRow(
        deps.database,
        deletedAt: now - 29 * day,
      );
      final active = await insertExpenseRow(deps.database);

      final cubit = cubitFor(deps);
      await cubit.start();

      expect(cubit.value, isA<StartupReady>());
      final ids = [
        for (final row in await deps.database.query('expenses')) row['id'],
      ];
      expect(ids, unorderedEquals([recent, active]));
      expect(ids, isNot(contains(old)));
    },
  );

  test('a failing purge does not block the app', () async {
    // Without the tables the purge throws, but the rest of startup works.
    await deps.database.execute('DROP TABLE expense_events');
    await deps.database.execute('DROP TABLE expenses');

    final cubit = cubitFor(deps);
    await cubit.start();
    expect(cubit.value, isA<StartupReady>());
  });
}
