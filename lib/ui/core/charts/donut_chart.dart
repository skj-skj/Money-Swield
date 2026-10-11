import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart' show SemanticsProperties;
import 'package:material_ui/material_ui.dart';

/// A ring of slices (phase-8.md §8.5): from 12 o'clock clockwise, in the
/// order given, a gap after each where the card shows through. Knows nothing of money:
/// it draws [sweeps] (degrees, `ringSweeps` in the domain) in [colors].
/// A tap on a slice (or near it) calls [onTap] with its index; each slice
/// is a TalkBack node read as [sliceLabel].
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.sweeps,
    required this.colors,
    required this.sliceLabel,
    required this.onTap,
    required this.size,
    this.selected,
    this.center,
  });

  /// One per slice, in degrees; with the gaps they make 360.
  final List<double> sweeps;
  final List<Color> colors;
  final String Function(int index) sliceLabel;
  final ValueChanged<int> onTap;

  /// The ring's diameter.
  final double size;

  /// The tapped slice, drawn thicker; null for none.
  final int? selected;

  /// Shown in the hole (the count of expenses).
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final painter = DonutPainter(
      sweeps: sweeps,
      colors: colors,
      selected: selected,
      sliceLabel: sliceLabel,
      onTap: onTap,
      textDirection: Directionality.of(context),
    );
    return SizedBox.square(
      dimension: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final index = painter.sliceAt(
            details.localPosition,
            Size.square(size),
          );
          if (index != null) onTap(index);
        },
        child: CustomPaint(
          painter: painter,
          child: center == null
              ? null
              : Center(
                  child: SizedBox(
                    // Inside the hole, with a margin.
                    width: size * DonutPainter.innerRatio * 0.8,
                    child: FittedBox(fit: BoxFit.scaleDown, child: center),
                  ),
                ),
        ),
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.sweeps,
    required this.colors,
    required this.textDirection,
    this.selected,
    this.sliceLabel,
    this.onTap,
  });

  final List<double> sweeps;
  final List<Color> colors;
  final TextDirection textDirection;
  final int? selected;
  final String Function(int index)? sliceLabel;
  final ValueChanged<int>? onTap;

  /// The hole's radius ÷ the ring's (§8.5: 55 %).
  static const innerRatio = 0.55;

  /// The gap after each slice, in degrees (≈ 2 dp on a 120 dp ring).
  static const gapDegrees = 2.0;

  static double _radians(double degrees) => degrees * math.pi / 180;

  /// Where each slice starts, clockwise from 12 o'clock, in degrees.
  List<double> get _starts {
    final starts = <double>[];
    var at = 0.0;
    for (final sweep in sweeps) {
      starts.add(at);
      at += sweep + (sweeps.length > 1 ? gapDegrees : 0);
    }
    return starts;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (sweeps.isEmpty) return;
    final outer = size.shortestSide / 2;
    final width = outer * (1 - innerRatio);
    final center = size.center(Offset.zero);
    final starts = _starts;
    for (var i = 0; i < sweeps.length; i++) {
      // A selected slice is thicker, out over the ring's edge.
      final thick = i == selected ? width : width * 0.86;
      final radius = outer - width + thick / 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick
        ..color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _radians(starts[i] - 90),
        _radians(sweeps[i] == 360 ? 359.999 : sweeps[i]),
        false,
        paint,
      );
    }
  }

  /// The slice under [position], or null: in the ring (or a little out of
  /// it), at its angle. A tap in a gap goes to the nearer slice.
  int? sliceAt(Offset position, Size size) {
    if (sweeps.isEmpty) return null;
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final offset = position - center;
    final distance = offset.distance;
    if (distance < outer * innerRatio * 0.6 || distance > outer + 12) {
      return null;
    }
    // Degrees clockwise from 12 o'clock.
    var angle = math.atan2(offset.dy, offset.dx) * 180 / math.pi + 90;
    if (angle < 0) angle += 360;
    final starts = _starts;
    for (var i = 0; i < sweeps.length; i++) {
      final end = starts[i] + sweeps[i] + gapDegrees / 2;
      if (angle < end) return i;
    }
    return 0;
  }

  /// Each slice is a node TalkBack can read and tap, placed at its middle.
  @override
  SemanticsBuilderCallback? get semanticsBuilder {
    final label = sliceLabel;
    if (label == null) return null;
    return (size) {
      final center = size.center(Offset.zero);
      final outer = size.shortestSide / 2;
      final ring = outer * (1 + innerRatio) / 2;
      final starts = _starts;
      return [
        for (var i = 0; i < sweeps.length; i++)
          CustomPainterSemantics(
            rect: Rect.fromCircle(
              center:
                  center +
                  Offset.fromDirection(
                    _radians(starts[i] + sweeps[i] / 2 - 90),
                    ring,
                  ),
              radius: outer * (1 - innerRatio) / 2,
            ),
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
  bool shouldRepaint(DonutPainter oldDelegate) =>
      !listEquals(oldDelegate.sweeps, sweeps) ||
      !listEquals(oldDelegate.colors, colors) ||
      oldDelegate.selected != selected;

  @override
  bool shouldRebuildSemantics(DonutPainter oldDelegate) =>
      shouldRepaint(oldDelegate) ||
      oldDelegate.sliceLabel != sliceLabel ||
      oldDelegate.textDirection != textDirection;
}
