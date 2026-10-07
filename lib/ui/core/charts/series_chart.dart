import 'package:material_ui/material_ui.dart';

import 'chart_colors.dart';
import 'chart_kind.dart';
import 'series_painter.dart';

/// One series drawn as [kind], [height] tall, with [labels] under some
/// slots. Tapping a slot (or near a point) calls [onTap] with its index.
class SeriesChart extends StatelessWidget {
  const SeriesChart({
    super.key,
    required this.fractions,
    required this.kind,
    required this.labels,
    required this.pointLabel,
    required this.onTap,
    this.height = 120,
    this.highlighted,
    this.selected,
  });

  /// One per slot, 0..1: each value ÷ the largest. Geometry only.
  final List<double> fractions;

  final ChartKind kind;

  /// Text under some slots: slot index → label.
  final Map<int, String> labels;

  /// What TalkBack reads for a slot, e.g. "Mon, 5 Oct, ₹250.00".
  final String Function(int index) pointLabel;

  final ValueChanged<int> onTap;

  /// The drawing's height; the labels come under it.
  final double height;

  /// A slot drawn strong (today's), or null.
  final int? highlighted;

  /// The tapped slot, or null.
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final slot = width / fractions.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => onTap(
                (details.localPosition.dx / slot).floor().clamp(
                  0,
                  fractions.length - 1,
                ),
              ),
              child: CustomPaint(
                size: Size(width, height),
                painter: SeriesPainter.of(
                  kind,
                  fractions: fractions,
                  colors: ChartColors.of(context),
                  textDirection: Directionality.of(context),
                  highlighted: highlighted,
                  selected: selected,
                  pointLabel: pointLabel,
                  onTap: onTap,
                ),
              ),
            ),
            if (labels.isNotEmpty) ...[
              const SizedBox(height: 4),
              // A label may be wider than its slot (a month's "29" in a
              // 31-slot chart): each is centred on its slot and scaled
              // down to a fixed box, never wrapped.
              SizedBox(
                height: 16,
                child: ExcludeSemantics(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final MapEntry(key: index, value: text)
                          in labels.entries)
                        Positioned(
                          left: (index + 0.5) * slot - _labelWidth(slot) / 2,
                          width: _labelWidth(slot),
                          top: 0,
                          bottom: 0,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(text, style: labelStyle),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static double _labelWidth(double slot) => slot < 24 ? 24 : slot;
}

/// A tiny drawing of [kind], for its choice in a settings dialog.
class SeriesChartPreview extends StatelessWidget {
  const SeriesChartPreview({super.key, required this.kind, this.sample});

  final ChartKind kind;

  /// The values drawn; a fixed wave by default.
  final List<double>? sample;

  static const _wave = [0.2, 0.55, 0.35, 0.9, 0.5, 0.0, 0.7];

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(48, 24),
      painter: SeriesPainter.of(
        kind,
        fractions: sample ?? _wave,
        colors: ChartColors.of(context),
        textDirection: Directionality.of(context),
      ),
    ),
  );
}
