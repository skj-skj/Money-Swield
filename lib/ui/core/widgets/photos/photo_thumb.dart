import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';

/// One photo as a square-cropped thumbnail: rounded 8, the picture filling it.
/// A file that can't be loaded shows **image missing** (a broken-image icon,
/// read as "Image missing"), never an error, and the tile still works.
///
/// [selected] non-null shows the selection tick and tells TalkBack "Selected" /
/// "Not selected".
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.image,
    this.semanticLabel,
    this.selected,
    this.onTap,
    this.onLongPress,
  });

  final ImageProvider image;

  /// What TalkBack reads for the photo, e.g. "Photo of Lunch, 5 Oct".
  final String? semanticLabel;

  final bool? selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Decode size for a thumbnail [logicalSize] dp wide on this screen: the
  /// pixels it covers, so a 50 MP original never becomes a full bitmap.
  static int decodeSize(BuildContext context, double logicalSize) =>
      (logicalSize * MediaQuery.devicePixelRatioOf(context)).ceil();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = this.selected;
    final picture = Image(
      image: image,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // Missing, deleted by hand, never restored: shown, never fatal.
      errorBuilder: (context, _, _) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: scheme.onSurfaceVariant,
            semanticLabel: l10n.imageMissing,
          ),
        ),
      ),
    );
    return Semantics(
      label: semanticLabel,
      selected: selected,
      value: switch (selected) {
        true => l10n.selected,
        false => l10n.notSelected,
        null => null,
      },
      button: onTap != null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: scheme.surfaceContainerHighest,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              fit: StackFit.expand,
              children: [
                picture,
                if (selected != null) ...[
                  if (selected)
                    ColoredBox(color: scheme.primary.withValues(alpha: 0.25)),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: ExcludeSemantics(
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected ? scheme.primary : Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 3, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
