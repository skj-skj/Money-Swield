import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Home's "+ Add expense" button, which folds into a round "+" while the
/// list scrolls down and unfolds when it scrolls back (owner, 2026-10-07).
///
/// Built on an always-extended `FloatingActionButton.extended` whose label,
/// spacing and end padding shrink with one animation: the label slides
/// shut while it fades, and the "+" turns a quarter (it looks the same at
/// both ends). Material's own `isExtended` swaps the content in one frame,
/// and its collapsed button keeps the extended padding (16 dp before the
/// icon, 20 after: a 60 dp pill with the "+" 2 dp off centre); here the
/// folded button is the regular 56 dp circle with the "+" centred.
class AddExpenseFab extends StatefulWidget {
  const AddExpenseFab({
    super.key,
    required this.extended,
    required this.label,
    required this.onPressed,
  });

  final bool extended;
  final String label;
  final VoidCallback onPressed;

  /// Unfolding and folding: long enough to read as one smooth motion,
  /// short enough to keep up with the scroll.
  static const duration = Duration(milliseconds: 300);
  static const reverseDuration = Duration(milliseconds: 300);

  @override
  State<AddExpenseFab> createState() => _AddExpenseFabState();
}

class _AddExpenseFabState extends State<AddExpenseFab>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AddExpenseFab.duration,
    reverseDuration: AddExpenseFab.reverseDuration,
    value: widget.extended ? 1 : 0,
  );

  /// A gentle ease in and out, the same both ways, so the size changes a
  /// little each frame. Owner, 2026-10-07, found folding "snappy":
  /// `easeInCubic` sped up to the end and stopped dead on the circle, and
  /// Material's emphasized easing (tried next) moved 60 % of the way in a
  /// single frame (measured in the test). Sine's steepest frame is about
  /// 9 % of the change.
  late final _open = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutSine,
  );

  @override
  void didUpdateWidget(AddExpenseFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.extended == oldWidget.extended) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.extended ? 1 : 0;
    } else if (widget.extended) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _open.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _open,
      builder: (context, _) {
        final t = _open.value;
        // The text fades in as the button widens (and out as it narrows),
        // starting a third of the way, so it never shows squeezed and never
        // pops in at the end.
        final textOpacity = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
        return FloatingActionButton.extended(
          onPressed: widget.onPressed,
          // Folded, the "+" alone says nothing: the tooltip names it. Set by
          // where the button is going, not per frame: adding the tooltip
          // changes the button's tree, which rebuilds it all.
          tooltip: widget.extended ? null : widget.label,
          // 16 + 24 + 16 = 56 folded: a circle with the "+" centred;
          // Material's 16 / 20 unfolded.
          extendedPadding: EdgeInsetsDirectional.only(
            start: 16,
            end: 16 + 4 * t,
          ),
          extendedIconLabelSpacing: 8 * t,
          icon: Transform.rotate(
            angle: (1 - t) * math.pi / 2,
            child: const Icon(Icons.add),
          ),
          label: ClipRect(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: t,
              child: Opacity(opacity: textOpacity, child: Text(widget.label)),
            ),
          ),
        );
      },
    );
  }
}
