import 'package:material_ui/material_ui.dart';

/// Lays [children] out in two columns, each stacking its items at their own
/// height, so a card with a long description doesn't leave a gap next to a
/// short one.
///
/// Items alternate left, right, left …, so a list sorted by name still reads
/// left to right, top to bottom. (Placing each item in the shorter column
/// would balance the columns better, but would scramble that order.)
///
/// Builds every child at once, not lazily: the lists it shows have tens of
/// items, not thousands.
class TwoColumnMasonry extends StatelessWidget {
  const TwoColumnMasonry({
    super.key,
    required this.children,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    Widget column(int start) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = start; i < children.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: children[i],
            ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column(0),
        SizedBox(width: spacing),
        column(1),
      ],
    );
  }
}
