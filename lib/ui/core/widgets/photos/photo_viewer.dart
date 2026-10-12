import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../show_message.dart';
import 'photo_selection_bar.dart';

/// Photos full screen: swipe between them, pinch to zoom (1–5×), double tap for
/// 2.5×; "2 / 5" in the bar, **Save to Pictures** and, where photos can be
/// deleted, **Delete**, apart like the selection bar's. Each photo is decoded
/// at most twice the screen's long edge, so an original never becomes a huge
/// bitmap.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.count,
    required this.initial,
    required this.imageOf,
    required this.onSave,
    this.onDelete,
  });

  /// Opens the viewer at photo [initial] of [count].
  ///
  /// [onSave] saves photo `index` to Pictures and returns the message to
  /// show (null for none). [onDelete] asks and deletes photo `index`,
  /// returning whether it did; the viewer then shows the next photo, or
  /// closes after the last.
  static Future<void> open(
    BuildContext context, {
    required int count,
    required int initial,
    required ImageProvider Function(int index, int maxPx) imageOf,
    required Future<String?> Function(int index) onSave,
    Future<bool> Function(int index)? onDelete,
  }) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => PhotoViewer(
        count: count,
        initial: initial,
        imageOf: imageOf,
        onSave: onSave,
        onDelete: onDelete,
      ),
    ),
  );

  final int count;
  final int initial;
  final ImageProvider Function(int index, int maxPx) imageOf;
  final Future<String?> Function(int index) onSave;
  final Future<bool> Function(int index)? onDelete;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late int _count = widget.count;
  late int _page = widget.initial;
  late final _pages = PageController(initialPage: widget.initial);
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  var _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await widget.onSave(_page);
      if (message != null && mounted) {
        showMessage(_messenger.currentState, message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _busy) return;
    final deleted = await onDelete(_page);
    if (!deleted || !mounted) return;
    if (_count == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _count--;
      _page = math.min(_page, _count - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final maxPx =
        (size.longestSide * MediaQuery.devicePixelRatioOf(context) * 2).ceil();
    // Dark, so the error colour of Delete reads on the black page.
    final theme = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: Theme.of(context).colorScheme.primary,
    );
    final canDelete = widget.onDelete != null;
    // Save and Delete are icons, apart as in the selection bar. They sit beside
    // the counter when it fits at its widest ("10 / 10"), else on a row of
    // their own under it: on the Oppo (360 dp) the counter was cut to "2 …".
    final actionsBeside =
        kToolbarHeight +
            PhotoSelectionBar.textWidth(
              context,
              l10n.photoCounter(_count, _count),
            ) +
            16 +
            PhotoSelectionBar.actionsWidth(canDelete: canDelete) +
            4 <=
        size.width;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: PhotoSelectionBar.gap,
      children: [
        IconButton(
          key: const ValueKey('viewerSave'),
          tooltip: l10n.saveToPictures,
          color: Colors.white,
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.download_outlined),
        ),
        if (canDelete)
          IconButton(
            key: const ValueKey('viewerDelete'),
            tooltip: l10n.delete,
            color: theme.colorScheme.error,
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
    return Theme(
      data: theme,
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            titleSpacing: 0,
            titleTextStyle: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
            ),
            title: Text(
              l10n.photoCounter(_page + 1, _count),
              maxLines: 1,
              softWrap: false,
            ),
            actions: actionsBeside ? [actions, const SizedBox(width: 4)] : null,
            bottom: actionsBeside
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: actions,
                      ),
                    ),
                  ),
          ),
          body: PageView.builder(
            controller: _pages,
            itemCount: _count,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => _ZoomablePhoto(
              key: ValueKey('viewerPage $index of $_count'),
              image: widget.imageOf(index, maxPx),
            ),
          ),
        ),
      ),
    );
  }
}

/// One page: pinch 1–5×, double tap 2.5× and back.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({super.key, required this.image});

  final ImageProvider image;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _zoom = TransformationController();
  TapDownDetails? _doubleTap;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoom.value.getMaxScaleOnAxis() > 1) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final at = _doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-at.dx * (scale - 1), -at.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTap = details,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _zoom,
        maxScale: 5,
        child: Center(
          child: Image(
            image: widget.image,
            fit: BoxFit.contain,
            errorBuilder: (context, _, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: Colors.white70,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.imageMissing,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
