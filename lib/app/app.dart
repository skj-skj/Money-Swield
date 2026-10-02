import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/models/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../ui/core/themes.dart';
import '../ui/features/migration/view_models/migration_cubit.dart';
import '../ui/features/migration/views/migration_screen.dart';
import '../ui/features/settings/view_models/settings_cubit.dart';
import 'app_dependencies.dart';
import 'startup_gate.dart';

/// The root widget: `MaterialApp` with the language and theme from
/// [settingsCubit], then migrations, then startup.
class App extends StatelessWidget {
  const App({
    super.key,
    required this.migrationCubit,
    required this.settingsCubit,
    required this.openDependencies,
  });

  final MigrationCubit migrationCubit;
  final SettingsCubit settingsCubit;

  /// Opens the database once migrations are done. Tests pass an in-memory
  /// one.
  final Future<AppDependencies> Function() openDependencies;

  @override
  Widget build(BuildContext context) {
    // .value because main() owns both cubits for the app's lifetime.
    return BlocSignalProvider<MigrationCubit>.value(
      value: migrationCubit,
      child: BlocSignalProvider<SettingsCubit>.value(
        value: settingsCubit,
        child: BlocSignalBuilder<SettingsCubit, AppSettings>(
          bloc: settingsCubit,
          // Other settings (currency, payment method) don't affect the app
          // as a whole, so they don't rebuild it.
          buildWhen: (previous, current) =>
              previous.locale != current.locale ||
              previous.theme != current.theme,
          builder: (context, settings) => MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeModeOf(settings.theme),
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            // Material's own strings come from material_ui, not from
            // flutter_localizations: material_ui widgets look up
            // material_ui's MaterialLocalizations type, so
            // AppLocalizations.localizationsDelegates (which lists
            // flutter_localizations' delegate) would leave them unlocalized.
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: MigrationGate(
              child: StartupGate(openDependencies: openDependencies),
            ),
          ),
        ),
      ),
    );
  }
}
