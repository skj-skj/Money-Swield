import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import 'photo_thumb.dart';

/// Square cells, two per row, 8 dp apart (phase-6.md §8.3, §8.9).
const photoGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
);

/// The photos of one grid (an expense's sheet, the Bin detail) as a box:
/// [count] tiles, then a **+** tile while [onAdd] is given (the form,
/// below 10). Selection as [PhotoThumb] shows it: a tap toggles while
/// [selection] isn't null, a long press starts it.
///
/// While selecting, the + tile is hidden but its cell stays, empty: a
/// bottom sheet is as tall as its content, so dropping a row moved every
/// photo down under the finger (184 dp in the sheet, found by a test after
/// the Oppo run).
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.count,
    required this.imageOf,
    required this.onTap,
    this.onLongPress,
    this.selection,
    this.onAdd,
    required this.semanticsOf,
    this.adding = false,
  });

  final int count;

  /// Photo `index` decoded at `maxPx` pixels at most.
  final ImageProvider Function(int index, int maxPx) imageOf;

  final ValueChanged<int> onTap;
  final ValueChanged<int>? onLongPress;
  final Set<int>? selection;
  final VoidCallback? onAdd;

  /// Photos are being added: the + tile shows progress and takes no taps.
  final bool adding;

  /// What TalkBack says for photo `index` ("Photo 2 of 3"). Required: the
  /// Bin detail's tiles had none (found on the Oppo, phase-6.md §12a).
  final String Function(int index) semanticsOf;

  @override
  Widget build(BuildContext context) {
    final onAdd = this.onAdd;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - 8) / 2;
        final maxPx = PhotoThumb.decodeSize(context, cell);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: photoGridDelegate,
          itemCount: count + (onAdd != null ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == count) {
              return selection == null
                  ? AddPhotoTile(onTap: adding ? null : onAdd, busy: adding)
                  : const SizedBox.shrink();
            }
            return PhotoThumb(
              key: ValueKey('photoTile $i'),
              image: imageOf(i, maxPx),
              semanticLabel: semanticsOf(i),
              selected: selection?.contains(i),
              onTap: () => onTap(i),
              onLongPress: onLongPress == null ? null : () => onLongPress!(i),
            );
          },
        );
      },
    );
  }
}

/// The last cell of an expense's grid: + to add photos. A small round
/// button in the middle of the cell, with no fill: a cell-sized tile read
/// as one more photo (owner, after the Oppo run). The cell itself stays,
/// so the grid keeps its rows.
class AddPhotoTile extends StatelessWidget {
  const AddPhotoTile({super.key, required this.onTap, this.busy = false});

  static const size = 64.0;

  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: Material(
          key: const ValueKey('addPhotoTile'),
          type: MaterialType.transparency,
          shape: CircleBorder(side: BorderSide(color: scheme.outline)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      Icons.add,
                      size: 32,
                      color: scheme.primary,
                      semanticLabel: AppLocalizations.of(context).addPhotos,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
