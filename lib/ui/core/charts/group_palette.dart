import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

/// The report card's slice colours (phase-8.md §5.3, P8-7, F11): the
/// exception to "colours only from the theme" (phase-5.md P5-28), still
/// fitted to it.
///
/// Five fixed hues (a light set and a dark set, by the theme's
/// brightness), each with its **tone** moved, in HCT, until it has at
/// least 3:1 contrast on the card's colour of the current theme (the
/// user's theme colour or the wallpaper's), so every slice stays visible
/// on any theme. Rotating hues from the theme colour was tried and fails
/// colour-blind separation (F11: protan ΔE fell to 1.0); fixed hues keep
/// adjacent slices apart for normal, protan and deutan vision
/// (`group_palette_test`). A colour follows a slice's rank, not a group:
/// with 20+ categories no fixed hue per category can stay distinct; each
/// slice is named beside it, so colour is never the only cue.
class GroupPalette {
  const GroupPalette._(this.colors, this.other);

  /// For [scheme]'s card colour (`surfaceContainerLow`, the reel's face).
  factory GroupPalette.of(ColorScheme scheme) {
    final background = scheme.surfaceContainerLow;
    final hues = scheme.brightness == Brightness.dark ? _dark : _light;
    return GroupPalette._([
      for (final hue in hues) fitToBackground(Color(hue), background),
    ], scheme.outline);
  }

  /// The light set fitted to white paper, for the PDF's donuts (§6.4):
  /// the same hues as the card's in a light theme.
  factory GroupPalette.onWhite() => GroupPalette._([
    for (final hue in _light) fitToBackground(Color(hue), Colors.white),
  ], const Color(0xFF79747E));

  /// The five slice colours, by rank.
  final List<Color> colors;

  /// The Other slice's (the theme's `outline`).
  final Color other;

  /// The colour of the slice at [index] (0-based), or [other].
  Color slice(int index, {bool isOther = false}) =>
      isOther ? other : colors[index % colors.length];

  /// The dataviz reference palette's five hues (F11).
  static const _light = [
    0xFF2A78D6,
    0xFFEB6834,
    0xFF1BAF7A,
    0xFFEDA100,
    0xFFE87BA4,
  ];
  static const _dark = [
    0xFF3987E5,
    0xFFD95926,
    0xFF199E70,
    0xFFC98500,
    0xFFD55181,
  ];

  /// The contrast every slice keeps with the card (WCAG's for graphics).
  static const minContrast = 3.0;

  /// [color] as it is when it already has [minContrast] on [background],
  /// else with its tone moved away from the background's (darker on a
  /// light card, lighter on a dark one) until it has. Hue and chroma are
  /// kept as far as the colour space allows.
  static Color fitToBackground(Color color, Color background) {
    final hct = Hct.fromInt(color.toARGB32());
    final backTone = Hct.fromInt(background.toARGB32()).tone;
    if (Contrast.ratioOfTones(hct.tone, backTone) >= minContrast + 0.05) {
      return color;
    }
    // A little over 3: the colour is rounded to 8-bit channels after.
    const ratio = minContrast + 0.1;
    final lightBack = backTone >= 50;
    var tone = lightBack
        ? Contrast.darker(tone: backTone, ratio: ratio)
        : Contrast.lighter(tone: backTone, ratio: ratio);
    if (tone < 0) tone = lightBack ? 0 : 100;
    return Color(Hct.from(hct.hue, hct.chroma, tone).toInt());
  }
}
