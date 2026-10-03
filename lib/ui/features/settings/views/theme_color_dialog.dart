import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/themes.dart';

/// What the theme color dialog returns: `seed` as ARGB, or null for the
/// wallpaper colors. The dialog itself returns null when dismissed.
typedef ThemeColorChoice = ({int? seed});

/// The name of a theme color: "Wallpaper colors" or one of
/// [themeSeedColors]'s names.
String themeColorName(
  AppLocalizations l10n, {
  required int? seed,
  required int? wallpaperSeed,
}) {
  final shown =
      seed ?? (wallpaperSeed == null ? defaultSeedColor.toARGB32() : null);
  if (shown == null) return l10n.themeColorWallpaper;
  final index = themeSeedColors.indexWhere((c) => c.toARGB32() == shown);
  return switch (index) {
    0 => l10n.colorPurple,
    1 => l10n.colorBlue,
    2 => l10n.colorTeal,
    3 => l10n.colorGreen,
    4 => l10n.colorAmber,
    5 => l10n.colorOrange,
    6 => l10n.colorRed,
    7 => l10n.colorPink,
    // A color from a newer app's list: show it without a name.
    _ => '#${shown.toRadixString(16).padLeft(8, '0').substring(2)}',
  };
}

/// Asks for the theme color: the wallpaper's (only offered when the device
/// has one, Android 12+) or one of [themeSeedColors]. All options are shown
/// at once as swatches.
Future<ThemeColorChoice?> showThemeColorDialog(
  BuildContext context, {
  required int? current,
  required int? wallpaperSeed,
}) {
  final l10n = AppLocalizations.of(context);
  // With no wallpaper colors, "follow the wallpaper" shows the default.
  final selected =
      current ?? (wallpaperSeed == null ? defaultSeedColor.toARGB32() : null);
  return showDialog<ThemeColorChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settingThemeColor),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wallpaperSeed != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _Swatch(
                color: Color(wallpaperSeed),
                selected: selected == null,
              ),
              title: Text(l10n.themeColorWallpaper),
              onTap: () => Navigator.pop(context, (seed: null)),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in themeSeedColors)
                Tooltip(
                  message: themeColorName(
                    l10n,
                    seed: color.toARGB32(),
                    wallpaperSeed: wallpaperSeed,
                  ),
                  child: InkResponse(
                    onTap: () =>
                        Navigator.pop(context, (seed: color.toARGB32())),
                    child: _Swatch(
                      color: color,
                      selected: selected == color.toARGB32(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// A color disc, with a check mark when selected.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // The check uses the scheme this color would produce, so it reads on
    // light and dark swatches alike.
    final scheme = ColorScheme.fromSeed(seedColor: color);
    return Semantics(
      selected: selected,
      child: SizedBox.square(
        dimension: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
          child: selected
              ? Icon(Icons.check, color: scheme.onPrimary)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
