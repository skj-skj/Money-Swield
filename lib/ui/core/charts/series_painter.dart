import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart' show SemanticsProperties;
import 'package:material_ui/material_ui.dart';

import '../../../domain/smooth_line.dart';
import 'chart_colors.dart';
import 'chart_kind.dart';

/// What every series painter shares: the slots, the selected slot's guide
/// line, the baseline, and one TalkBack node per slot. A subclass draws
/// the values ([paintSeries]).
abstract class SeriesPainter extends CustomPainter {
  SeriesPainter({
    required this.fractions,
    required this.colors,
    required this.textDirection,
    this.highlighted,
    this.selected,
    this.pointLabel,
    this.onTap,
  });

  /// The painter for [kind].
  factory SeriesPainter.of(
    ChartKind kind, {
    required List<double> fractions,
    required ChartColors colors,
    required TextDirection textDirection,
    int? highlighted,
    int? selected,
    String Function(int index)? pointLabel,
    ValueChanged<int>? onTap,
  }) => switch (kind) {
    ChartKind.bars => BarPainter(
      fractions: fractions,
      colors: colors,
      textDirection: textDirection,
      highlighted: highlighted,
      selected: selected,
      pointLabel: pointLabel,
      onTap: onTap,
    ),
    ChartKind.line || ChartKind.area => LinePainter(
      filled: kind == ChartKind.area,
      fractions: fractions,
      colors: colors,
      textDirection: textDirection,
      highlighted: highlighted,
      selected: selected,
      pointLabel: pointLabel,
      onTap: onTap,
    ),
    ChartKind.dots => DotPainter(
      fractions: fractions,
      colors: colors,
      textDirection: textDirection,
      highlighted: highlighted,
      selected: selected,
      pointLabel: pointLabel,
      onTap: onTap,
    ),
  };

  /// One per slot, 0..1: each value ÷ the largest. Geometry only.
  final List<double> fractions;
  final ChartColors colors;

  /// For the slots' TalkBack labels, which need one.
  final TextDirection textDirection;

  /// A slot drawn strong (today's), or null.
  final int? highlighted;

  /// The tapped slot, or null: drawn strong, with a guide line.
  final int? selected;

  /// What TalkBack reads for a slot; null for no nodes (a preview).
  final String Function(int index)? pointLabel;
  final ValueChanged<int>? onTap;

  /// Room above the highest point, for its dot.
  static const top = 6.0;

  /// Draws the values. [x] and [y] give a slot's centre and its value's
  /// height; [base] is the baseline's y.
  void paintSeries(
    Canvas canvas,
    Size size, {
    required double slot,
    required double base,
    required double Function(int) x,
    required double Function(int) y,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fractions.isEmpty) return;
    final slot = size.width / fractions.length;
    final base = size.height - 1;
    double x(int i) => (i + 0.5) * slot;
    double y(int i) => base - fractions[i] * (base - top);
    if (selected case final s?) {
      canvas.drawLine(Offset(x(s), 0), Offset(x(s), base), _guide);
    }
    paintSeries(canvas, size, slot: slot, base: base, x: x, y: y);
    canvas.drawLine(Offset(0, base), Offset(size.width, base), _guide);
  }

  Paint get _guide => Paint()
    ..color = colors.guide
    ..strokeWidth = 1;

  /// Each slot is a node TalkBack can read and tap.
  @override
  SemanticsBuilderCallback? get semanticsBuilder {
    final label = pointLabel;
    if (label == null) return null;
    return (size) {
      final slot = size.width / fractions.length;
      return [
        for (var i = 0; i < fractions.length; i++)
          CustomPainterSemantics(
            rect: Rect.fromLTWH(i * slot, 0, slot, size.height),
            properties: SemanticsProperties(
              label: label(i),
              textDirection: textDirection,
              selected: i == selected,
              onTap: onTap == null ? null : () => onTap!(i),
            ),
          ),
      ];
    };
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) =>
      oldDelegate.runtimeType != runtimeType ||
      !listEquals(oldDelegate.fractions, fractions) ||
      oldDelegate.colors != colors ||
      oldDelegate.highlighted != highlighted ||
      oldDelegate.selected != selected;

  @override
  bool shouldRebuildSemantics(SeriesPainter oldDelegate) =>
      shouldRepaint(oldDelegate) ||
      oldDelegate.pointLabel != pointLabel ||
      oldDelegate.textDirection != textDirection;
}

/// [ChartKind.bars].
class BarPainter extends SeriesPainter {
  BarPainter({
    required super.fractions,
    required super.colors,
    required super.textDirection,
    super.highlighted,
    super.selected,
    super.pointLabel,
    super.onTap,
  });

  @override
  void paintSeries(
    Canvas canvas,
    Size size, {
    required double slot,
    required double base,
    required double Function(int) x,
    required double Function(int) y,
  }) {
    final width = (slot * 0.6).clamp(2.0, double.infinity);
    for (var i = 0; i < fractions.length; i++) {
      // 0 draws nothing over the baseline.
      if (fractions[i] == 0) continue;
      final strong = i == highlighted || i == selected;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x(i) - width / 2, y(i), x(i) + width / 2, base),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        Paint()..color = strong ? colors.strong : colors.weak,
      );
    }
  }
}

/// [ChartKind.line], or [ChartKind.area] when [filled].
class LinePainter extends SeriesPainter {
  LinePainter({
    required this.filled,
    required super.fractions,
    required super.colors,
    required super.textDirection,
    super.highlighted,
    super.selected,
    super.pointLabel,
    super.onTap,
  });

  final bool filled;

  @override
  void paintSeries(
    Canvas canvas,
    Size size, {
    required double slot,
    required double base,
    required double Function(int) x,
    required double Function(int) y,
  }) {
    final ys = [for (var i = 0; i < fractions.length; i++) y(i)];
    // A monotone cubic: never above or below a segment's two ends, so it
    // never dips under the baseline (domain/smooth_line.dart).
    final m = monotoneTangents(ys);
    final path = Path()..moveTo(x(0), ys[0]);
    for (var i = 0; i < ys.length - 1; i++) {
      path.cubicTo(
        x(i) + slot / 3,
        ys[i] + m[i] / 3,
        x(i + 1) - slot / 3,
        ys[i + 1] - m[i + 1] / 3,
        x(i + 1),
        ys[i + 1],
      );
    }
    if (filled) {
      final area = Path.from(path)
        ..lineTo(x(ys.length - 1), base)
        ..lineTo(x(0), base)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.strong.withValues(alpha: 0.3),
              colors.strong.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTRB(0, SeriesPainter.top, size.width, base)),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.strong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (final i in {?highlighted, ?selected}) {
      canvas.drawCircle(
        Offset(x(i), ys[i]),
        i == selected ? 5 : 3.5,
        Paint()..color = colors.strong,
      );
    }
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) =>
      super.shouldRepaint(oldDelegate) ||
      (oldDelegate as LinePainter).filled != filled;
}

/// [ChartKind.dots].
class DotPainter extends SeriesPainter {
  DotPainter({
    required super.fractions,
    required super.colors,
    required super.textDirection,
    super.highlighted,
    super.selected,
    super.pointLabel,
    super.onTap,
  });

  @override
  void paintSeries(
    Canvas canvas,
    Size size, {
    required double slot,
    required double base,
    required double Function(int) x,
    required double Function(int) y,
  }) {
    final radius = (slot * 0.25).clamp(1.5, 4.0);
    for (var i = 0; i < fractions.length; i++) {
      if (fractions[i] == 0) continue;
      final strong = i == highlighted || i == selected;
      final color = strong
          ? colors.strong
          : colors.strong.withValues(alpha: .6);
      canvas
        ..drawLine(
          Offset(x(i), base),
          Offset(x(i), y(i)),
          Paint()
            ..color = colors.weak
            ..strokeWidth = 1.5,
        )
        ..drawCircle(
          Offset(x(i), y(i)),
          i == selected ? radius + 1.5 : radius,
          Paint()..color = color,
        );
    }
  }
}
