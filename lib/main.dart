import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'data/services/database/app_database.dart';
import 'domain/models/app_settings.dart';
import 'domain/models/currency.dart';
import 'ui/features/migration/view_models/migration_cubit.dart';
import 'ui/features/settings/view_models/settings_cubit.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final deviceLocale = binding.platformDispatcher.locale;
  final appDatabase = AppDatabase();

  // Both cubits are created before runApp and live as long as the app, so
  // nothing needs to close them. Migrations start without waiting for the
  // first frame.
  final migrationCubit = MigrationCubit(
    database: appDatabase,
    locale: deviceLocale,
  )..run();
  // Starts with the device language and theme; StartupGate loads the saved
  // settings once the database is ready.
  final settingsCubit = SettingsCubit(initial: AppSettings.beforeLoad);

  runApp(
    App(
      migrationCubit: migrationCubit,
      settingsCubit: settingsCubit,
      openDependencies: () => AppDependencies.open(
        appDatabase,
        deviceCurrency: deviceCurrency(deviceLocale),
      ),
    ),
  );
}
