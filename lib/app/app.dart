import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/models/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../ui/core/themes.dart';
import '../ui/features/migration/view_models/migration_cubit.dart';
import '../ui/features/migration/views/migration_screen.dart';
import '../ui/features/settings/view_models/settings_cubit.dart';
import 'app_dependencies.dart';
import 'app_restart.dart';
import 'restore_tools.dart';
import 'startup_gate.dart';

/// The root widget: `MaterialApp` with the language and theme from
/// [settingsCubit], then migrations, then startup.
class App extends StatefulWidget {
  const App({
    super.key,
    required this.migrationCubit,
    required this.settingsCubit,
    required this.openDependencies,
    this.restoreTools,
    this.wallpaperSeed,
  });

  final MigrationCubit migrationCubit;
  final SettingsCubit settingsCubit;

  /// Opens the database once migrations are done. Tests pass an in-memory
  /// one.
  final Future<AppDependencies> Function() openDependencies;

  /// For "Undo last restore" on the startup-failed screen, where there are
  /// no [AppDependencies]. Null in tests that don't need it.
  final RestoreTools? restoreTools;

  /// The wallpaper's accent color (Android 12+), or null.
  final int? wallpaperSeed;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  /// Bumped by a restart; keys everything below, so the whole tree
  /// (Navigator, every route, the startup gate) is built anew.
  int _generation = 0;

  late final _restart = AppRestartController(_rebuild);

  void _rebuild() {
    // Otherwise a fresh install that restored would say "Database
    // initialized".
    widget.restoreTools?.appDatabase.resetRunHistory();
    // Back to "in progress" at once, so the old tree isn't shown again.
    unawaited(widget.migrationCubit.restart());
    setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    // .value because main() owns both cubits for the app's lifetime.
    return AppRestart(
      controller: _restart,
      child: BlocSignalProvider<MigrationCubit>.value(
        value: widget.migrationCubit,
        child: BlocSignalProvider<SettingsCubit>.value(
          value: widget.settingsCubit,
          // Outside the builder, so its buildWhen can't keep a restart
          // from reaching MaterialApp.
          child: KeyedSubtree(
            key: ValueKey(_generation),
            child: BlocSignalBuilder<SettingsCubit, AppSettings>(
              bloc: widget.settingsCubit,
              // Other settings (currency, payment method) don't affect the
              // app as a whole, so they don't rebuild it.
              buildWhen: (previous, current) =>
                  previous.locale != current.locale ||
                  previous.theme != current.theme ||
                  previous.themeSeed != current.themeSeed,
              builder: (context, settings) => _materialApp(settings),
            ),
          ),
        ),
      ),
    );
  }

  Widget _materialApp(AppSettings settings) => appMaterialApp(
    settings: settings,
    wallpaperSeed: widget.wallpaperSeed,
    home: MigrationGate(
      child: StartupGate(
        openDependencies: widget.openDependencies,
        restoreTools: widget.restoreTools,
      ),
    ),
  );
}

/// The app's [MaterialApp] for [settings]: themes, language and
/// localizations, with [home] as its first screen. [App] builds it; widget
/// tests of one screen use it too, so they look exactly like the app.
Widget appMaterialApp({
  required AppSettings settings,
  required int? wallpaperSeed,
  required Widget home,
}) {
  final seed = themeSeedColor(
    pickedSeed: settings.themeSeed,
    wallpaperSeed: wallpaperSeed,
  );
  return MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    theme: lightTheme(seed),
    darkTheme: darkTheme(seed),
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
    home: home,
  );
}
