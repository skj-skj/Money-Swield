import 'package:material_ui/material_ui.dart';

/// A chart's colours, only from the theme's colour roles (built from the
/// app's theme colour or the wallpaper), so dark mode follows.
class ChartColors {
  const ChartColors({
    required this.strong,
    required this.weak,
    required this.guide,
  });

  factory ChartColors.of(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChartColors(
      strong: colors.primary,
      weak: colors.primaryContainer,
      guide: colors.outlineVariant,
    );
  }

  /// The line, the dots, and the highlighted or selected bar.
  final Color strong;

  /// The other bars.
  final Color weak;

  /// The baseline and the selected slot's guide line.
  final Color guide;

  @override
  bool operator ==(Object other) =>
      other is ChartColors &&
      other.strong == strong &&
      other.weak == weak &&
      other.guide == guide;

  @override
  int get hashCode => Object.hash(strong, weak, guide);
}
