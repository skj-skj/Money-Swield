import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';

/// The bar of selection mode (phase-6.md §8.10, P6-50), the same in an
/// expense's Photos sheet, on the Photos screen and (Save only) in the Bin
/// detail:
///
/// ✕ · "2 selected" · Select all · … · Save ‖ 8 dp ‖ Delete
///
/// **Save** and **Delete** sit at the top right as icons (their names are
/// tooltips and what TalkBack says; the owner found the labels redundant),
/// with [gap] of empty, non-tappable space between their touch targets and
/// Delete at the edge, in the error colour. Owner rev 6 had 48 dp apart
/// against a fat finger; after the Oppo run the owner found that too far.
/// The touch targets still don't touch, and Delete always asks first.
/// When the row is too narrow (a large font),
/// Select all becomes its icon, then the title shortens to the number; if
/// Save and Delete still don't fit beside them, they move to a row of
/// their own. The gap never shrinks.
class PhotoSelectionBar extends StatelessWidget {
  const PhotoSelectionBar({
    super.key,
    required this.count,
    required this.onSelectAll,
    required this.onSave,
    required this.onClose,
    this.onDelete,
    this.busy = false,
  });

  final int count;
  final VoidCallback onSelectAll;
  final VoidCallback onSave;
  final VoidCallback onClose;

  /// Null where photos can't be deleted (the Bin detail, P6-43).
  final VoidCallback? onDelete;

  /// A save is running: both actions are off (a double tap does nothing).
  final bool busy;

  /// The space between Save's and Delete's touch targets.
  static const gap = 8.0;

  static const saveKey = ValueKey('selectionSave');
  static const deleteKey = ValueKey('selectionDelete');
  static const selectAllKey = ValueKey('selectionSelectAll');
  static const closeKey = ValueKey('selectionClose');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    final onDelete = this.onDelete;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        IconButton(
          key: saveKey,
          tooltip: l10n.saveToPictures,
          onPressed: busy ? null : onSave,
          icon: const Icon(Icons.download_outlined),
        ),
        if (onDelete != null)
          IconButton(
            key: deleteKey,
            tooltip: l10n.delete,
            onPressed: busy ? null : onDelete,
            color: error,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
    final close = IconButton(
      key: closeKey,
      tooltip: l10n.endSelection,
      onPressed: onClose,
      icon: const Icon(Icons.close),
    );
    return Semantics(
      container: true,
      header: true,
      label: l10n.photosSelectedCount(count),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (fitsOneRow(
              context,
              constraints.maxWidth,
              count: count,
              canDelete: onDelete != null,
            )) {
              return Row(
                children: [
                  close,
                  Expanded(child: _titleAndSelectAll()),
                  actions,
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    close,
                    Expanded(child: _titleAndSelectAll()),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Whether the bar is one row in [width] (else Save and Delete take a
  /// second row): ✕ (48), the number (with its 12 of padding) and the
  /// Select all icon (48) beside Save, the gap and Delete. A screen
  /// reserves the bar's height with it, so starting selection doesn't move
  /// the photos under the user's finger (seen on the Oppo, phase-6.md
  /// §12a).
  static bool fitsOneRow(
    BuildContext context,
    double width, {
    required int count,
    required bool canDelete,
  }) {
    final needed =
        48 +
        textWidth(context, '$count') +
        12 +
        48 +
        actionsWidth(canDelete: canDelete);
    // The bar's own 4 of padding at the end.
    return needed <= width - 4;
  }

  /// The height of the bar in [width]: one row of 48, or two when Save
  /// and Delete need their own.
  static double heightIn(
    BuildContext context,
    double width, {
    required int count,
    required bool canDelete,
  }) =>
      fitsOneRow(context, width, count: count, canDelete: canDelete) ? 48 : 96;

  /// Save, the gap and Delete (without [canDelete], Save alone) side by
  /// side: two icon buttons of 48. The viewer measures with it too.
  static double actionsWidth({required bool canDelete}) =>
      48 + (canDelete ? gap + 48 : 0);

  /// "2 selected" and a labelled Select all when both fit in the width
  /// left; else "2 selected" and the Select all icon; else the number and
  /// the icon. (Without the middle step the Oppo showed a bare "1" beside
  /// plenty of room.)
  Widget _titleAndSelectAll() => LayoutBuilder(
    builder: (context, constraints) {
      final l10n = AppLocalizations.of(context);
      final full = l10n.selectedCount(count);
      final fullWidth = textWidth(context, full) + 12;
      final labelled =
          fullWidth + textWidth(context, l10n.selectAll, button: true) + 24 <=
          constraints.maxWidth;
      final fullTitle = labelled || fullWidth + 48 <= constraints.maxWidth;
      final title = ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
          child: Text(
            fullTitle ? full : '$count',
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      return Row(
        children: [
          Flexible(child: title),
          if (labelled)
            TextButton(
              key: selectAllKey,
              onPressed: onSelectAll,
              child: Text(l10n.selectAll, maxLines: 1, softWrap: false),
            )
          else
            IconButton(
              key: selectAllKey,
              tooltip: l10n.selectAll,
              onPressed: onSelectAll,
              icon: const Icon(Icons.select_all),
            ),
        ],
      );
    },
  );

  /// [text] on one line at the phone's font size: the title's style
  /// (`titleMedium`), or a button's ([button]).
  static double textWidth(
    BuildContext context,
    String text, {
    bool button = false,
  }) {
    final theme = Theme.of(context).textTheme;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: button ? theme.labelLarge : theme.titleMedium,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// Where photos are being deleted from: the confirm's text says what
/// "permanently" means there (§8.10).
enum PhotoDeletePlace {
  /// The Photos screen: they go from their expenses at once.
  photosScreen,

  /// A saved expense's sheet or viewer: they go when Update is tapped.
  savedExpense,

  /// A new expense: they go when it is saved.
  newExpense,
}

/// Asks before deleting [count] photos (§8.10, P6-8): "Delete 3 photos?",
/// a warning that they will be deleted permanently and that copies saved to
/// Pictures stay, and **Cancel** first (focused) · **Delete** in the error
/// colour. True when confirmed.
Future<bool> confirmPhotoDelete(
  BuildContext context, {
  required int count,
  required PhotoDeletePlace place,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.photosDeleteTitle(count)),
      content: Text(switch (place) {
        PhotoDeletePlace.photosScreen => l10n.photosDeleteWarningScreen(count),
        PhotoDeletePlace.savedExpense => l10n.photosDeleteWarningForm(count),
        PhotoDeletePlace.newExpense => l10n.photosDeleteWarningNew(count),
      }),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
