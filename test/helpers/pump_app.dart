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
  );
}

/// Like [pumpApp], but with full control over opening the database, e.g.
/// to make it fail.
Future<SettingsCubit> pumpAppWith(
  WidgetTester tester, {
  required Future<AppDependencies> Function() openDependencies,
  MigrationCubit? migrationCubit,
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
    ),
  );
  // With the caller's migrations, the test drives them; an indeterminate
  // progress bar would keep pumpAndSettle from ever settling.
  if (migrationCubit != null) return settingsCubit;
  await migrations.run();
  await tester.pumpAndSettle();
  return settingsCubit;
}
