import 'package:material_ui/material_ui.dart';

import '../../domain/models/app_theme_mode.dart';

/// The theme color when the user picked "Wallpaper colors" but the device
/// has none (before Android 12): Material's baseline purple, neutral enough
/// for any wallpaper.
const defaultSeedColor = Color(0xFF6750A4);

/// The colors offered in Settings → Theme color, besides the wallpaper.
const themeSeedColors = [
  defaultSeedColor,
  Color(0xFF1565C0), // Blue
  Color(0xFF00796B), // Teal
  Color(0xFF2E7D32), // Green
  Color(0xFFF9A825), // Amber
  Color(0xFFE65100), // Orange
  Color(0xFFC62828), // Red
  Color(0xFFAD1457), // Pink
];

/// The color the theme is built from: the one picked in Settings, else the
/// wallpaper's ([wallpaperSeed], Android 12+), else [defaultSeedColor].
Color themeSeedColor({required int? pickedSeed, required int? wallpaperSeed}) =>
    Color(pickedSeed ?? wallpaperSeed ?? defaultSeedColor.toARGB32());

/// Light and dark themes from [seed], with Material 3's tonal palettes (the
/// same algorithm Android uses for its wallpaper colors).
ThemeData lightTheme(Color seed) =>
    ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed));

ThemeData darkTheme(Color seed) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  ),
);

ThemeMode themeModeOf(AppThemeMode theme) => switch (theme) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};
