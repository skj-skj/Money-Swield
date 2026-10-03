import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'data/services/database/app_database.dart';
import 'data/services/dynamic_color_service.dart';
import 'domain/models/app_settings.dart';
import 'domain/models/currency.dart';
import 'ui/features/migration/view_models/migration_cubit.dart';
import 'ui/features/settings/view_models/settings_cubit.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Read once at start, before the first frame, so the app never flashes
  // in the default color. A wallpaper change while the app runs shows on
  // the next start.
  final wallpaperSeed = await const DynamicColorService().accentColor();
  final deviceLocale = binding.platformDispatcher.locale;
  final appDatabase = AppDatabase();

  // Both cubits are created before runApp and live as long as the app, so
  // nothing needs to close them. Migrations start without waiting for the
  // first frame.
  final migrationCubit = MigrationCubit(
    database: appDatabase,
    locale: deviceLocale,
  );
  // Not awaited: the migration screen shows its progress.
  unawaited(migrationCubit.run());
  // Starts with the device language and theme; StartupGate loads the saved
  // settings once the database is ready.
  final settingsCubit = SettingsCubit(initial: AppSettings.beforeLoad);

  runApp(
    App(
      migrationCubit: migrationCubit,
      settingsCubit: settingsCubit,
      wallpaperSeed: wallpaperSeed,
      openDependencies: () => AppDependencies.open(
        appDatabase,
        deviceCurrency: deviceCurrency(deviceLocale),
        wallpaperSeed: wallpaperSeed,
      ),
    ),
  );
}
