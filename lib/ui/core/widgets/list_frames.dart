import 'package:material_ui/material_ui.dart';

/// The outlined groups of a long list (phase-5.md §8.3, P5-30): Home's
/// days, weeks, months and years, and the Photos screen's months
/// (phase-6.md §8.9, R17). Shared, so both read the same; each screen puts
/// its own content (Home's subtotals) in them.

/// Where a frame's side lines are, from the screen's edges.
const frameMargin = 16.0;

/// From a side line to the text inside the frame.
const frameInset = 12.0;

const _radius = 12.0;

/// The outline of one group: side lines and, once the group has ended, the
/// rounded bottom. The top is drawn by the group's [FrameTop], which
/// covers this part, pinned or not. Painted by `DecoratedSliver` for the
/// whole group, offset by how far it has scrolled, so the corners stay
/// where the group really ends.
class FrameDecoration extends Decoration {
  const FrameDecoration({required this.color, required this.open});

  final Color color;

  /// More pages may still add to the group: no bottom yet.
  final bool open;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _FramePainter(this);

  @override
  bool operator ==(Object other) =>
      other is FrameDecoration && other.color == color && other.open == open;

  @override
  int get hashCode => Object.hash(color, open);
}

class _FramePainter extends BoxPainter {
  _FramePainter(this.decoration);

  final FrameDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    final left = offset.dx + frameMargin;
    final right = offset.dx + size.width - frameMargin;
    final top = offset.dy;
    final bottom = offset.dy + size.height;
    final path = Path()..moveTo(left, top);
    if (decoration.open) {
      path
        ..lineTo(left, bottom)
        ..moveTo(right, bottom)
        ..lineTo(right, top);
    } else {
      path
        ..lineTo(left, bottom - _radius)
        ..arcToPoint(
          Offset(left + _radius, bottom),
          radius: const Radius.circular(_radius),
          clockwise: false,
        )
        ..lineTo(right - _radius, bottom)
        ..arcToPoint(
          Offset(right, bottom - _radius),
          radius: const Radius.circular(_radius),
          clockwise: false,
        )
        ..lineTo(right, top);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = decoration.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

/// A frame's top, sticky while its group is on screen (P5-12): the
/// group's [name] on the border at the left and [trailing] (Home's
/// subtotal) from the middle to the right, on a page-coloured strip with
/// the frame's top and side lines, so it still reads as the frame's top
/// when pinned.
class FrameTop extends StatelessWidget {
  const FrameTop({super.key, required this.name, this.trailing});

  final String name;

  /// Null leaves the right half empty. A trailing widget reads [name] to
  /// TalkBack itself (Home's subtotal says "Oct, ₹…"), so then the name
  /// isn't read twice.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = theme.colorScheme.surface;
    final trailing = this.trailing;
    final title = ColoredBox(
      color: page,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          name,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return ColoredBox(
      color: page,
      child: CustomPaint(
        painter: _FrameTopPainter(theme.colorScheme.outlineVariant),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: frameMargin + frameInset - 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Two equal halves: the name on the left one, the trailing
              // part from the middle to the right. Their page-coloured
              // background cuts the border line.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: trailing == null
                      ? Semantics(header: true, child: title)
                      : ExcludeSemantics(child: title),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing == null
                      ? const SizedBox(height: 32)
                      : ColoredBox(
                          color: page,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: trailing,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrameTopPainter extends CustomPainter {
  _FrameTopPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    const left = frameMargin;
    final right = size.width - frameMargin;
    final path = Path()
      ..moveTo(left, size.height)
      ..lineTo(left, mid + _radius)
      ..arcToPoint(
        Offset(left + _radius, mid),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(right - _radius, mid)
      ..arcToPoint(
        Offset(right, mid + _radius),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(right, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FrameTopPainter old) => old.color != color;
}

/// A day inside a frame, sticky below the frame top until its day ends:
/// [child] (Home: the date and its subtotal; Photos: the date) on a
/// page-coloured strip with the frame's side lines, so the frame doesn't
/// look broken where the header covers it.
class DayHeaderBar extends StatelessWidget {
  const DayHeaderBar({super.key, required this.child});

  final Widget child;

  /// The style of a day's date.
  static TextStyle? dateStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: CustomPaint(
        painter: _SideLines(theme.colorScheme.outlineVariant),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            frameMargin + frameInset,
            6,
            frameMargin + frameInset,
            2,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SideLines extends CustomPainter {
  _SideLines(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        const Offset(frameMargin, 0),
        Offset(frameMargin, size.height),
        paint,
      )
      ..drawLine(
        Offset(size.width - frameMargin, 0),
        Offset(size.width - frameMargin, size.height),
        paint,
      );
  }

  @override
  bool shouldRepaint(_SideLines old) => old.color != color;
}
