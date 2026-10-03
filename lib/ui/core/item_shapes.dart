import 'package:material_ui/material_ui.dart';

import '../../domain/models/item_shape.dart';
import '../../l10n/app_localizations.dart';

/// Corner radius of a tile or button of [shape] whose short side is
/// [height]. A circle is a stadium for anything wider than it is tall (the
/// open search bar), so one radius serves both.
double shapeRadius(ItemShape shape, double height) => switch (shape) {
  ItemShape.square => 0,
  ItemShape.rounded => 12,
  ItemShape.circle => height / 2,
};

String shapeName(AppLocalizations l10n, ItemShape shape) => switch (shape) {
  ItemShape.square => l10n.shapeSquare,
  ItemShape.rounded => l10n.shapeRounded,
  ItemShape.circle => l10n.shapeCircle,
};

/// A small sample of [shape], shown next to its name in the Settings dialog.
class ShapePreview extends StatelessWidget {
  const ShapePreview(this.shape, {super.key});

  final ItemShape shape;

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(
            shape == ItemShape.rounded ? 6 : shapeRadius(shape, _size),
          ),
        ),
      ),
    );
  }
}
