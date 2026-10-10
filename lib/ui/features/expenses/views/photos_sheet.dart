import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/photos.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/back_guard.dart';
import '../../../core/widgets/photos/photo_grid.dart';
import '../../../core/widgets/photos/photo_selection_bar.dart';
import '../../../core/widgets/sheet_messenger.dart';
import '../view_models/expense_form_cubit.dart';

/// The expense's photos (phase-6.md §8.3), like Itemize: a sheet with a
/// two-column grid ending in a **+** tile while there is room. It follows
/// the cubit, so photos added from inside it appear.
///
/// A tap opens the viewer ([onOpen]); a long press starts selection
/// (§8.10), whose bar replaces the title row at the sheet's top right
/// (owner rev 7). That row stays pinned while the photos scroll. Back
/// leaves selection before the sheet. Messages are snackbars over the
/// sheet's bottom ([SheetMessenger]): the screen's own would be under it.
Future<void> showPhotosSheet(
  BuildContext context, {
  required ExpenseFormCubit cubit,
  required Future<String?> Function() onAdd,
  required Future<void> Function(int index) onOpen,
  required Future<String?> Function() onSaveSelected,
  required Future<String?> Function() onDeleteSelected,
}) => showAppSheet<void>(
  context,
  builder: (context) => _PhotosSheet(
    cubit: cubit,
    onAdd: onAdd,
    onOpen: onOpen,
    onSaveSelected: onSaveSelected,
    onDeleteSelected: onDeleteSelected,
  ),
);

class _PhotosSheet extends StatefulWidget {
  const _PhotosSheet({
    required this.cubit,
    required this.onAdd,
    required this.onOpen,
    required this.onSaveSelected,
    required this.onDeleteSelected,
  });

  final ExpenseFormCubit cubit;

  /// Each returns the message to show, or null.
  final Future<String?> Function() onAdd;
  final Future<void> Function(int index) onOpen;
  final Future<String?> Function() onSaveSelected;
  final Future<String?> Function() onDeleteSelected;

  @override
  State<_PhotosSheet> createState() => _PhotosSheetState();
}

class _PhotosSheetState extends State<_PhotosSheet> {
  final _messenger = GlobalKey<SheetMessengerState>();

  Future<void> _run(Future<String?> Function() action) async {
    final message = await action();
    if (!mounted || message == null) return;
    _messenger.currentState?.show(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = widget.cubit;
    return SheetMessenger(
      key: _messenger,
      child: BlocSignalBuilder<ExpenseFormCubit, ExpenseFormState>(
        bloc: cubit,
        builder: (context, state) {
          if (state is! ExpenseFormReady) return const SizedBox.shrink();
          final photos = state.fields.photos;
          final selection = state.selection;
          final work = state.photoWork;
          final full = photos.length >= maxPhotosPerExpense;
          return BackGuard(
            intercept: selection != null,
            onBack: cubit.clearSelection,
            // The title row, or the selection bar in its place, stays pinned
            // at the top while the photos scroll under it (owner, 2026-10-09):
            // with 10 photos the grid is taller than the screen, and Save,
            // Delete and Select all must stay in reach.
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The bar takes the sheet's whole width (on 360 dp it then
                  // fits one row in English); the title row takes the bar's
                  // height, so the grid doesn't move under the finger when
                  // selection starts (seen on the Oppo).
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final height = PhotoSelectionBar.heightIn(
                        context,
                        constraints.maxWidth,
                        count: maxPhotosPerExpense,
                        canDelete: true,
                      );
                      return SizedBox(
                        key: const ValueKey('photosSheetHeader'),
                        height: height,
                        child: selection == null
                            ? Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: _titleRow(context, photos.length),
                                ),
                              )
                            : PhotoSelectionBar(
                                count: selection.length,
                                busy: work is PhotoSavingToPictures,
                                onClose: cubit.clearSelection,
                                onSelectAll: cubit.selectAll,
                                onSave: () => _run(widget.onSaveSelected),
                                onDelete: () => _run(widget.onDeleteSelected),
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      key: const ValueKey('photosSheetScroll'),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The bar above is full width; the photos keep the
                          // sheet's 16 dp sides.
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: PhotoGrid(
                              count: photos.length,
                              imageOf: (i, maxPx) =>
                                  cubit.photoStore.image(photos[i], maxPx),
                              selection: selection,
                              onTap: (i) => selection == null
                                  ? widget.onOpen(i)
                                  : cubit.toggleSelected(i),
                              onLongPress: cubit.startSelection,
                              onAdd: full ? null : () => _run(widget.onAdd),
                              adding: work.blocksSave,
                              semanticsOf: (i) =>
                                  l10n.photoNumber(i + 1, photos.length),
                            ),
                          ),
                          if (full)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Text(
                                l10n.photosMaxReached(maxPhotosPerExpense),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          if (work
                              case PhotoSavingToPictures(
                                :final done,
                                :final total,
                              )
                              when total > 1)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Text(l10n.savingToPictures(done, total)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// "Photos" and "3 of 10", at the height of the selection bar.
  Widget _titleRow(BuildContext context, int count) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.photos,
              style: theme.textTheme.titleLarge,
              semanticsLabel: l10n.photos,
            ),
          ),
          Text(
            l10n.photosOfMax(count, maxPhotosPerExpense),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
