import 'package:material_ui/material_ui.dart';

import '../../domain/models/app_theme_mode.dart';

/// The app's one seed color. Placeholder (phase-1.md §12).
const seedColor = Colors.teal;

final lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
);

final darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  ),
);

ThemeMode themeModeOf(AppThemeMode theme) => switch (theme) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};
