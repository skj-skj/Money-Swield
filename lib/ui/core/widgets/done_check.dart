import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A circle that draws itself from 0 to 100 %, then a tick drawn inside
/// it: "done". Calls [onCompleted] once the tick is complete. With
/// animations turned off in the system settings it shows the end state at
/// once.
class DoneCheck extends StatefulWidget {
  const DoneCheck({super.key, this.size = 96, this.onCompleted});

  final double size;
  final VoidCallback? onCompleted;

  /// Circle, then tick.
  static const duration = Duration(milliseconds: 1100);

  @override
  State<DoneCheck> createState() => _DoneCheckState();
}

class _DoneCheckState extends State<DoneCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: DoneCheck.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onCompleted?.call();
        });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onCompleted?.call(),
      );
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _DoneCheckPainter(
            // The first 70 % draws the circle, the rest the tick.
            circle: Curves.easeInOut.transform(
              (_controller.value / 0.7).clamp(0.0, 1.0),
            ),
            tick: Curves.easeOut.transform(
              ((_controller.value - 0.7) / 0.3).clamp(0.0, 1.0),
            ),
            color: colors.primary,
            track: colors.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

class _DoneCheckPainter extends CustomPainter {
  const _DoneCheckPainter({
    required this.circle,
    required this.tick,
    required this.color,
    required this.track,
  });

  /// How much of each is drawn, 0 to 1.
  final double circle;
  final double tick;

  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.08;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(arc, paint..color = track);
    if (circle > 0) {
      // From the top, clockwise.
      canvas.drawArc(
        arc,
        -math.pi / 2,
        2 * math.pi * circle,
        false,
        paint..color = color,
      );
    }
    if (tick > 0) {
      final w = size.width;
      final start = Offset(w * 0.28, w * 0.52);
      final corner = Offset(w * 0.44, w * 0.67);
      final end = Offset(w * 0.73, w * 0.36);
      final first = (start - corner).distance;
      final second = (end - corner).distance;
      final drawn = tick * (first + second);
      final path = Path()..moveTo(start.dx, start.dy);
      if (drawn <= first) {
        final p = Offset.lerp(start, corner, drawn / first)!;
        path.lineTo(p.dx, p.dy);
      } else {
        final p = Offset.lerp(corner, end, (drawn - first) / second)!;
        path
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_DoneCheckPainter old) =>
      old.circle != circle ||
      old.tick != tick ||
      old.color != color ||
      old.track != track;
}
