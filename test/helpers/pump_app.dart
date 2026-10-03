import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/models/app_settings.dart';
import 'package:my_expense_tracker_app/ui/features/migration/view_models/migration_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/settings/view_models/settings_cubit.dart';

import 'fake_app_database.dart';

/// Pumps the whole app the way `main()` builds it, with migrations that
/// finish at once (unless [migrationCubit] is given) and [dependencies] as
/// the "opened" database. Returns the app's settings cubit.
Future<SettingsCubit> pumpApp(
  WidgetTester tester, {
  required AppDependencies dependencies,
  MigrationCubit? migrationCubit,
}) async {
  return pumpAppWith(
    tester,
    openDependencies: () async => dependencies,
    migrationCubit: migrationCubit,
    wallpaperSeed: dependencies.wallpaperSeed,
  );
}

/// Like [pumpApp], but with full control over opening the database, e.g.
/// to make it fail.
Future<SettingsCubit> pumpAppWith(
  WidgetTester tester, {
  required Future<AppDependencies> Function() openDependencies,
  MigrationCubit? migrationCubit,
  int? wallpaperSeed,
}) async {
  final settingsCubit = SettingsCubit(initial: AppSettings.beforeLoad);
  addTearDown(settingsCubit.close);
  final migrations =
      migrationCubit ??
      cubitFor(FakeAppDatabase((prompter, onProgress) async {}));

  await tester.pumpWidget(
    App(
      migrationCubit: migrations,
      settingsCubit: settingsCubit,
      openDependencies: openDependencies,
      wallpaperSeed: wallpaperSeed,
    ),
  );
  // With the caller's migrations, the test drives them; an indeterminate
  // progress bar would keep pumpAndSettle from ever settling.
  if (migrationCubit != null) return settingsCubit;
  await migrations.run();
  await tester.pumpAndSettle();
  return settingsCubit;
}

/// Pumps until [condition] holds, letting real file I/O and isolates (a
/// backup, a restore, migrations on a real file) run in between: the
/// widget test's clock is fake, so they only progress inside `runAsync`.
///
/// [timeout] is only a deadline (it returns as soon as [condition] holds),
/// generous because each real I/O step costs a loop here, and test files
/// run in parallel.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  String? description,
  Duration timeout = const Duration(minutes: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Not true within $timeout: ${description ?? ''}');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [pumpUntil] [finder] finds something.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) => pumpUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  description: '$finder',
);

/// [pumpUntil] [finder] finds nothing.
Future<void> pumpUntilGone(WidgetTester tester, Finder finder) => pumpUntil(
  tester,
  () => finder.evaluate().isEmpty,
  description: 'gone: $finder',
);
