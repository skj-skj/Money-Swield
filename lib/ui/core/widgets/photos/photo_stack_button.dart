import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import 'photo_thumb.dart';

/// The form's photo button, left of the description and centred on it: 56 × 56,
/// outlined like the fields. Empty it shows a camera-with-plus; with photos, up
/// to three of them fanned out like a hand of playing cards (the newest on the
/// right, on top) and the count; busy, a progress ring and no taps.
///
/// The cards are taller than the button and turn about their bottom
/// middle, so they spill over its outline (owner, after the Oppo run: a
/// neat pile inside the outline left the button looking empty; a random
/// pile, tried next, looked odd).
class PhotoStackButton extends StatelessWidget {
  const PhotoStackButton({
    super.key,
    required this.count,
    required this.imageOf,
    required this.onTap,
    this.busy = false,
  });

  static const size = 56.0;

  /// A card: portrait, 4 dp above the button's top.
  static const _cardWidth = 40.0;
  static const _cardHeight = 58.0;

  final int count;

  /// Photo `index` decoded at `maxPx` pixels at most.
  final ImageProvider Function(int index, int maxPx) imageOf;

  final VoidCallback onTap;
  final bool busy;

  /// The turn of each of [shown] cards, left to right, in radians: one
  /// upright, two at ±10°, three at −14°, 0, +14°. At 14° the outer
  /// cards' top corners reach ~5 dp past the sides, inside the 8 dp before
  /// the description.
  static List<double> fanOf(int shown) => switch (shown) {
    1 => const [0.0],
    2 => const [-10 * math.pi / 180, 10 * math.pi / 180],
    _ => const [-14 * math.pi / 180, 0.0, 14 * math.pi / 180],
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxPx = PhotoThumb.decodeSize(context, _cardHeight);
    final shown = busy ? 0 : count.clamp(0, 3);
    final fan = shown == 0 ? const <double>[] : fanOf(shown);
    return Semantics(
      // Its own node: without it the button merged with the description next to
      // it into one unlabelled button TalkBack couldn't use (seen on the Oppo;
      // the currency box had the same).
      container: true,
      button: true,
      label: count == 0 ? l10n.addPhotos : l10n.photosCountOpen(count),
      excludeSemantics: true,
      child: SizedBox.square(
        key: const ValueKey('photoButton'),
        dimension: size,
        // Clip.none: the cards and the count are drawn past the outline;
        // taps there pass through (IgnorePointer) or miss, so only the
        // button itself takes them.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: scheme.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: busy ? null : onTap,
                  child: busy
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : count == 0
                      ? Icon(Icons.add_a_photo_outlined, color: scheme.primary)
                      : null,
                ),
              ),
            ),
            // Oldest of the last three first, on the left, so the newest
            // is drawn on top.
            for (var i = 0; i < shown; i++)
              Positioned(
                left: (size - _cardWidth) / 2,
                top: size - 2 - _cardHeight,
                width: _cardWidth,
                height: _cardHeight,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: fan[i],
                    alignment: Alignment.bottomCenter,
                    child: _photo(scheme, imageOf(count - shown + i, maxPx)),
                  ),
                ),
              ),
            if (shown > 0)
              PositionedDirectional(
                end: -6,
                bottom: -6,
                child: IgnorePointer(
                  child: Badge(
                    label: Text('$count'),
                    backgroundColor: scheme.primary,
                    textColor: scheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// One card, edged in the surface colour so the cards
  /// under it stay apart.
  Widget _photo(ColorScheme scheme, ImageProvider image) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: scheme.surface, width: 1.5),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image(
        image: image,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}
