import 'package:material_ui/material_ui.dart';

import '../../../../domain/photo_sizing.dart';
import '../../../../l10n/app_localizations.dart';
import '../back_guard.dart';

/// What the review after the camera decided (phase-6.md §8.2a).
sealed class ReviewDecision {
  const ReviewDecision();
}

/// Use photo, or Back (P6-33): keep it, turned [quarterTurns] clockwise.
final class UseReviewedPhoto extends ReviewDecision {
  const UseReviewedPhoto(this.quarterTurns);

  final int quarterTurns;
}

final class DiscardReviewedPhoto extends ReviewDecision {
  const DiscardReviewedPhoto();
}

/// The camera's photo, full screen on black, to turn before it is added:
/// the only time a photo can be turned (P6-32). Turning is on screen only;
/// the photo is encoded once, from the camera's file, when it is used
/// (P6-34). **Back = Use photo as shown**: Back never loses a shot.
class PhotoReviewScreen extends StatefulWidget {
  const PhotoReviewScreen({super.key, required this.image, this.notice});

  /// The small preview of the shot.
  final ImageProvider image;

  /// Said above the photo: "The photo you took is back" when the app was
  /// killed while it waited.
  final String? notice;

  @override
  State<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

class _PhotoReviewScreenState extends State<PhotoReviewScreen> {
  var _turns = 0;

  /// Counts every turn, so the animation goes the short way round (3 → 4,
  /// not 3 → 0).
  var _shown = 0;

  void _turn(int delta) => setState(() {
    _turns = addQuarterTurns(_turns, delta);
    _shown += delta;
  });

  void _use() => Navigator.pop(context, UseReviewedPhoto(_turns));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final odd = _turns.isOdd;
    return BackGuard(
      onBack: _use,
      child: Theme(
        data: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Theme.of(context).colorScheme.primary,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(l10n.reviewPhoto),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (widget.notice case final notice?)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        notice,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Center(
                      child: AnimatedRotation(
                        turns: _shown / 4,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 150),
                        // Turned a quarter, the box swaps its sides so the
                        // picture still fits the screen.
                        child: SizedBox(
                          width: odd
                              ? constraints.maxHeight
                              : constraints.maxWidth,
                          height: odd
                              ? constraints.maxWidth
                              : constraints.maxHeight,
                          child: Image(
                            key: const ValueKey('reviewImage'),
                            image: widget.image,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _turns == 0 ? '' : l10n.rotatedDegrees(_turns * 90),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      IconButton(
                        key: const ValueKey('rotateLeft'),
                        tooltip: l10n.rotateLeft,
                        onPressed: () => _turn(-1),
                        icon: const Icon(Icons.rotate_left),
                      ),
                      IconButton(
                        key: const ValueKey('rotateRight'),
                        tooltip: l10n.rotateRight,
                        onPressed: () => _turn(1),
                        icon: const Icon(Icons.rotate_right),
                      ),
                      TextButton(
                        key: const ValueKey('discardPhoto'),
                        onPressed: () => Navigator.pop(
                          context,
                          const DiscardReviewedPhoto(),
                        ),
                        child: Text(l10n.discardPhoto),
                      ),
                      FilledButton(
                        key: const ValueKey('usePhoto'),
                        onPressed: _use,
                        child: Text(l10n.usePhoto),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
