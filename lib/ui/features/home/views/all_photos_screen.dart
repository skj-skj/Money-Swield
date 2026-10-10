import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/photo_groups.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/period_names.dart';
import '../../../core/scroll_paging.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/back_guard.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/filtered_chip.dart';
import '../../../core/widgets/list_frames.dart';
import '../../../core/widgets/photos/photo_grid.dart';
import '../../../core/widgets/photos/photo_selection_bar.dart';
import '../../../core/widgets/photos/photo_thumb.dart';
import '../../../core/widgets/photos/saved_to_pictures_message.dart';
import '../../../core/widgets/retry_row.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/show_message.dart';
import '../../expenses/expense_form_opener.dart';
import '../../recurring/views/recurring_navigation.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/all_photos_cubit.dart';

/// Every photo of what Home's filters show (phase-6.md §8.9, P6-37 – P6-41):
/// month frames ("Oct 2026") with sticky day headers, two photos a row, each
/// day starting a new row; no subtotals. A tap opens that photo's expense
/// (Home's form rules); Back returns here, at the same place. A long press
/// selects photos to Save to Pictures or Delete (owner rev 6).
class AllPhotosScreen extends StatefulWidget {
  const AllPhotosScreen({
    super.key,
    required this.dependencies,
    required this.filter,
  });

  final AppDependencies dependencies;

  /// Home's filter, fixed while this screen is open.
  final ExpenseFilter filter;

  @override
  State<AllPhotosScreen> createState() => _AllPhotosScreenState();
}

class _AllPhotosScreenState extends State<AllPhotosScreen>
    with ScrollPaging<AllPhotosScreen> {
  late final AllPhotosCubit _cubit = AllPhotosCubit(
    expenses: widget.dependencies.expenses,
    drafts: widget.dependencies.drafts,
    dataVersion: widget.dependencies.dataVersion,
    store: widget.dependencies.photos,
    filter: widget.filter,
    fallbackTitle: AppLocalizations.of(context).defaultPictureTitle,
  )..load();

  late final _opener = ExpenseFormOpener(
    dependencies: widget.dependencies,
    pendingDraft: _cubit.pendingDraft,
    onOpenRecurring: (context, id) =>
        openRecurringFromForm(context, widget.dependencies, id),
  );

  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The next page once less than about two rows are left below.
  @override
  double get loadMoreLead => 400.0;

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  void loadMore() => _cubit.loadMore();

  BuildContext get _messengerContext => _scaffoldKey.currentContext ?? context;

  /// The photo's expense in the form; back here, the grid reloads if the
  /// form (or anything) changed data, and the form's result shows here.
  Future<void> _open(PhotoTile tile) async {
    final (:opened, :result) = await _opener.open(
      context,
      expenseId: tile.expense.id,
    );
    if (!opened || !mounted) return;
    await _cubit.reloadIfChanged();
    if (!mounted) return;
    showExpenseFormResult(
      _messenger.currentState,
      AppLocalizations.of(context),
      result,
      onUndoBin: (id) =>
          saveOrShowError(_messengerContext, () => _cubit.restore(id)),
    );
  }

  Future<void> _save() async {
    final message = await saveToPicturesMessage(
      AppLocalizations.of(context),
      _cubit.saveSelectedToPictures,
    );
    if (message != null && mounted) {
      showMessage(_messenger.currentState, message);
    }
  }

  Future<void> _delete(int count) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmPhotoDelete(
      context,
      count: count,
      place: PhotoDeletePlace.photosScreen,
    );
    if (!confirmed || !mounted) return;
    var removed = 0;
    final done = await saveOrShowError(
      _messengerContext,
      () async => removed = await _cubit.deleteSelected(),
    );
    if (done && mounted) {
      showMessage(_messenger.currentState, l10n.photosDeleted(removed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalBuilder<AllPhotosCubit, AllPhotosState>(
      bloc: _cubit,
      builder: (context, state) {
        final selection = switch (state) {
          AllPhotosLoaded(:final selection) => selection,
          _ => null,
        };
        return BackGuard(
          // Back leaves selection first.
          intercept: selection != null,
          onBack: _cubit.clearSelection,
          child: ScaffoldMessenger(
            key: _messenger,
            child: Scaffold(
              key: _scaffoldKey,
              appBar: selection == null
                  ? AppBar(
                      title: Text(l10n.photos),
                      actions: [
                        if (!widget.filter.isEmpty)
                          const FilteredChip(key: ValueKey('photosFiltered')),
                      ],
                    )
                  : null,
              body: SafeArea(
                top: selection != null,
                child: Column(
                  children: [
                    if (selection != null && state is AllPhotosLoaded)
                      // At least the app bar's height, so the grid doesn't
                      // move under the finger when selection starts.
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: kToolbarHeight,
                        ),
                        child: Center(
                          child: PhotoSelectionBar(
                            count: selection.length,
                            busy: state.saving,
                            onClose: _cubit.clearSelection,
                            onSelectAll: _cubit.selectAll,
                            onSave: _save,
                            onDelete: () => _delete(selection.length),
                          ),
                        ),
                      ),
                    Expanded(
                      child: AsyncBody(
                        phase: switch (state) {
                          AllPhotosLoading() => LoadPhase.loading,
                          AllPhotosFailed() => LoadPhase.failed,
                          AllPhotosLoaded(:final rows) when rows.isEmpty =>
                            LoadPhase.empty,
                          AllPhotosLoaded() => LoadPhase.loaded,
                        },
                        onRetry: _cubit.load,
                        empty: EmptyStateView(
                          icon: Icons.photo_library_outlined,
                          title: l10n.noPhotosMatchFilters,
                        ),
                        builder: (context) =>
                            _grid(context, state as AllPhotosLoaded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _grid(BuildContext context, AllPhotosLoaded state) {
    final settings = context.read<SettingsCubit>().value;
    final names = _names(context, settings);
    final outline = Theme.of(context).colorScheme.outlineVariant;
    final footer = state.loadingMore || state.loadMoreFailed;
    // A short first page may not fill the screen: no scroll would ever
    // ask for the next one.
    if (state.hasMore && !state.loadingMore && !state.loadMoreFailed) {
      loadMoreAfterFrame();
    }
    return CustomScrollView(
      controller: pagingScroll,
      slivers: [
        for (final month in state.months)
          DecoratedSliver(
            key: ValueKey('month ${month.range.from}'),
            decoration: FrameDecoration(color: outline, open: month.open),
            sliver: SliverMainAxisGroup(
              slivers: [
                PinnedHeaderSliver(
                  child: FrameTop(name: names.monthWithYear(month.range.from)),
                ),
                for (final day in month.days)
                  SliverMainAxisGroup(
                    slivers: [
                      PinnedHeaderSliver(
                        child: DayHeaderBar(
                          child: Text(
                            names.day(day.day),
                            semanticsLabel: names.spokenDay(day.day),
                            style: DayHeaderBar.dateStyle(context),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          frameMargin + frameInset,
                          4,
                          frameMargin + frameInset,
                          8,
                        ),
                        sliver: _dayGrid(context, state, day, names),
                      ),
                    ],
                  ),
                if (month.open && footer)
                  SliverToBoxAdapter(
                    child: state.loadMoreFailed
                        ? RetryRow(
                            message: AppLocalizations.of(context)
                                .loadMoreFailed,
                            onRetry: _cubit.loadMore,
                          )
                        : const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  /// A day's photos, two a row; an odd count leaves its last cell empty.
  Widget _dayGrid(
    BuildContext context,
    AllPhotosLoaded state,
    PhotoDay day,
    PeriodNames names,
  ) {
    final l10n = AppLocalizations.of(context);
    final width =
        MediaQuery.sizeOf(context).width - 2 * (frameMargin + frameInset);
    final maxPx = PhotoThumb.decodeSize(context, (width - 8) / 2);
    final selection = state.selection;
    return SliverGrid.builder(
      gridDelegate: photoGridDelegate,
      itemCount: day.tiles.length,
      itemBuilder: (context, i) {
        final tile = day.tiles[i];
        final key = tileKeyOf(tile);
        return PhotoThumb(
          key: ValueKey('photo ${key.expenseId} ${key.photoId}'),
          image: _cubit.store.image(tile.photo, maxPx),
          semanticLabel: l10n.photoOfExpense(
            tile.expense.title,
            names.day(day.day),
          ),
          selected: selection?.contains(key),
          onTap: () =>
              selection == null ? _open(tile) : _cubit.toggleSelected(key),
          onLongPress: () => _cubit.startSelection(key),
        );
      },
    );
  }

  PeriodNames _names(BuildContext context, AppSettings settings) =>
      PeriodNames.of(
        context,
        today: todayOn(widget.dependencies.now()),
        weekLabel: settings.weekLabel,
      );
}
