import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/data_version.dart';
import '../../../../data/repositories/expense_draft_repository.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/services/photo_store.dart';
import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/expense_draft.dart';
import '../../../../domain/photo_groups.dart';
import '../../../../domain/selection.dart';
import '../../../core/emit_if_open.dart';

/// What the Photos screen shows (phase-6.md §7.4). States don't override
/// `==`, so every emitted state reaches the screen.
sealed class AllPhotosState {
  const AllPhotosState();
}

final class AllPhotosLoading extends AllPhotosState {
  const AllPhotosLoading();
}

final class AllPhotosFailed extends AllPhotosState {
  const AllPhotosFailed();
}

final class AllPhotosLoaded extends AllPhotosState {
  const AllPhotosLoaded({
    required this.rows,
    required this.months,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.selection,
    this.saving = false,
  });

  /// The loaded expenses with photos, in Home's order.
  final List<PhotoExpense> rows;

  /// [rows] as month frames and days (`photoGroups`).
  final List<PhotoMonth> months;

  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  /// The selected tiles; null when not selecting (§8.10).
  final Set<PhotoTileKey>? selection;

  /// A Save to Pictures or a Delete is running.
  final bool saving;

  /// Every loaded tile, in order.
  Iterable<PhotoTile> get tiles => [
    for (final month in months)
      for (final day in month.days) ...day.tiles,
  ];

  AllPhotosLoaded copyWith({
    List<PhotoExpense>? rows,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    Set<PhotoTileKey>? Function()? selection,
    bool? saving,
  }) {
    final regroup = rows != null || hasMore != null;
    final nextRows = rows ?? this.rows;
    final more = hasMore ?? this.hasMore;
    return AllPhotosLoaded(
      rows: nextRows,
      months: regroup ? photoGroups(nextRows, hasMore: more) : months,
      hasMore: more,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      selection: selection == null ? this.selection : selection(),
      saving: saving ?? this.saving,
    );
  }
}

/// The photos of what Home's filters show (P6-37): active expenses with
/// photos, newest first, 30 expenses a page (an expense's photos are never
/// split), always by month (§8.9). The filter is fixed while the screen is
/// open; it is changed on Home.
///
/// With a text filter the words are matched in Dart, like Home's list
/// (phase-5.md §6.3): the matches with photos are read 30 at a time.
class AllPhotosCubit extends CubitSignal<AllPhotosState>
    with EmitIfOpen<AllPhotosState> {
  AllPhotosCubit({
    required this._expenses,
    required this._drafts,
    required this._dataVersion,
    required this._store,
    required this.filter,
    required this._fallbackTitle,
    this.pageSize = 30,
  }) : super(initialState: const AllPhotosLoading());

  final ExpenseRepository _expenses;
  final ExpenseDraftRepository _drafts;
  final DataVersion _dataVersion;
  final PhotoStore _store;
  final ExpenseFilter filter;
  final String _fallbackTitle;
  final int pageSize;

  PhotoStore get store => _store;

  /// `DataVersion.value` when the rows shown were loaded.
  int? _loadedVersion;

  /// Bumped by every (re)load, so a page requested before it is dropped.
  int _generation = 0;

  /// With a text filter: the ids of the matching expenses with photos, in
  /// list order, and how many the loaded rows cover.
  List<int>? _matchIds;
  int _matchesUsed = 0;

  /// The load or page running now: a Delete waits for it (§7.4).
  Future<void>? _running;

  Future<void> load() => _track(_loadTop(pageSize));

  /// Reloads at least as many rows as are shown, so the place on screen
  /// stays (after a form closes).
  Future<void> reload() {
    final shown = switch (value) {
      AllPhotosLoaded(:final rows) => rows.length,
      _ => 0,
    };
    return _track(_loadTop(math.max(shown, pageSize)));
  }

  /// Only if something was written since the last load (P2-14).
  Future<bool> reloadIfChanged() async {
    if (_loadedVersion == _dataVersion.value) return false;
    await reload();
    return true;
  }

  Future<void> _loadTop(int limit) async {
    final generation = ++_generation;
    final version = _dataVersion.value;
    try {
      final List<PhotoExpense> rows;
      final bool hasMore;
      var used = 0;
      List<int>? ids;
      if (filter.hasText) {
        ids = await _expenses.textMatchesWithPhotos(filter);
        used = math.min(limit, ids.length);
        rows = await _expenses.photoExpensesByIds(ids.sublist(0, used));
        hasMore = used < ids.length;
      } else {
        rows = await _expenses.photoExpensesPage(filter: filter, limit: limit);
        hasMore = rows.length == limit;
      }
      if (generation != _generation) return;
      _loadedVersion = version;
      _matchIds = ids;
      _matchesUsed = used;
      final selection = switch (value) {
        AllPhotosLoaded(:final selection?) => _stillThere(selection, rows),
        _ => null,
      };
      emitIfOpen(
        AllPhotosLoaded(
          rows: rows,
          months: photoGroups(rows, hasMore: hasMore),
          hasMore: hasMore,
          selection: selection,
        ),
      );
    } catch (error) {
      debugPrint('Loading the photos failed: $error');
      if (generation != _generation) return;
      if (value is! AllPhotosLoaded) emitIfOpen(const AllPhotosFailed());
    }
  }

  /// The next page, guarded like Home's list: one at a time, never onto
  /// rows a reload replaced.
  Future<void> loadMore() async {
    final state = value;
    if (state is! AllPhotosLoaded || !state.hasMore || state.loadingMore) {
      return;
    }
    final generation = _generation;
    emitIfOpen(state.copyWith(loadingMore: true, loadMoreFailed: false));
    await _track(() async {
      try {
        final List<PhotoExpense> page;
        final bool hasMore;
        var used = _matchesUsed;
        final ids = _matchIds;
        if (ids != null) {
          final end = math.min(used + pageSize, ids.length);
          page = await _expenses.photoExpensesByIds(ids.sublist(used, end));
          used = end;
          hasMore = used < ids.length;
        } else {
          page = await _expenses.photoExpensesPage(
            filter: filter,
            after: state.rows.last.expense.cursor,
            limit: pageSize,
          );
          hasMore = page.length == pageSize;
        }
        final current = value;
        if (generation != _generation || current is! AllPhotosLoaded) return;
        _matchesUsed = used;
        emitIfOpen(
          current.copyWith(
            rows: [...current.rows, ...page],
            hasMore: hasMore,
            loadingMore: false,
          ),
        );
      } catch (error) {
        debugPrint('Loading more photos failed: $error');
        final current = value;
        if (generation != _generation || current is! AllPhotosLoaded) return;
        emitIfOpen(current.copyWith(loadingMore: false, loadMoreFailed: true));
      }
    }());
  }

  // Selection (§8.10, owner rev 6).

  void startSelection(PhotoTileKey key) => _setSelection({key});

  void toggleSelected(PhotoTileKey key) {
    final state = value;
    final selection = state is AllPhotosLoaded ? state.selection : null;
    if (selection == null) return;
    _setSelection(toggledSelection(selection, key));
  }

  /// The loaded tiles only (§8.9).
  void selectAll() {
    final state = value;
    if (state is! AllPhotosLoaded || state.selection == null) return;
    _setSelection({for (final tile in state.tiles) tileKeyOf(tile)});
  }

  void clearSelection() => _setSelection(null);

  void _setSelection(Set<PhotoTileKey>? selection) {
    final state = value;
    if (state is AllPhotosLoaded) {
      emitIfOpen(state.copyWith(selection: () => selection));
    }
  }

  /// Save: each picture named from its own expense (§5.9); no confirm;
  /// selection stays. A second call while one runs is ignored.
  Future<SaveToPicturesResult?> saveSelectedToPictures() async {
    final state = value;
    final selection = state is AllPhotosLoaded ? state.selection : null;
    if (state is! AllPhotosLoaded || selection == null || state.saving) {
      return null;
    }
    emitIfOpen(state.copyWith(saving: true));
    try {
      return await _store.saveToPictures([
        for (final tile in state.tiles)
          if (selection.contains(tileKeyOf(tile)))
            pictureOf(tile.expense, tile.photo),
      ], fallbackTitle: _fallbackTitle);
    } finally {
      final current = value;
      if (current is AllPhotosLoaded) {
        emitIfOpen(current.copyWith(saving: false));
      }
    }
  }

  /// Delete, after the screen's confirm (§6.4a, owner rev 6): the selected
  /// photos leave their expenses at once, in one transaction (an expense
  /// binned meanwhile is skipped), and leave that expense's Edit draft, so
  /// the draft can't bring them back. Selection ends; the grid reloads.
  /// Returns how many photos went. A page still loading is waited for.
  Future<int> deleteSelected() async {
    final state = value;
    final selection = state is AllPhotosLoaded ? state.selection : null;
    if (state is! AllPhotosLoaded || selection == null || state.saving) {
      return 0;
    }
    emitIfOpen(state.copyWith(saving: true));
    try {
      await _running;
      final links = selection.toList();
      final removed = await _expenses.removePhotoLinks(links);
      // Only the expenses that lost photos: one binned meanwhile was
      // skipped and keeps them, so its Edit draft must keep them too.
      final byExpense = <int, Set<int>>{};
      for (final link in links) {
        if (!removed.expenseIds.contains(link.expenseId)) continue;
        byExpense.putIfAbsent(link.expenseId, () => {}).add(link.photoId);
      }
      for (final MapEntry(key: expenseId, value: photoIds)
          in byExpense.entries) {
        try {
          await _drafts.dropSavedPhotos(expenseId, photoIds);
        } catch (error) {
          // The draft keeps the photo: its row survives the sweep (the
          // live draft references it), so nothing is lost (§6.4a).
          debugPrint('Taking deleted photos out of the draft failed: $error');
        }
      }
      _setSelection(null);
      await reload();
      return removed.count;
    } finally {
      final current = value;
      if (current is AllPhotosLoaded) {
        emitIfOpen(current.copyWith(saving: false));
      }
    }
  }

  /// Undo of "Moved to bin" (a form opened from here binned its expense).
  Future<void> restore(int id) async {
    await _expenses.restore(id);
    await reload();
  }

  /// The draft slot, for opening the form (phase-4.md §7.4).
  Future<ExpenseDraft?> pendingDraft() async {
    try {
      return await _drafts.read();
    } catch (error) {
      debugPrint('Reading the expense draft failed: $error');
      return null;
    }
  }

  /// The selected keys that are still on screen after a reload.
  static Set<PhotoTileKey>? _stillThere(
    Set<PhotoTileKey> selection,
    List<PhotoExpense> rows,
  ) {
    final present = {
      for (final row in rows)
        for (final photo in row.photos)
          (expenseId: row.expense.id, photoId: photo.id),
    };
    final kept = selection.intersection(present);
    return kept.isEmpty ? null : kept;
  }

  Future<void> _track(Future<void> step) {
    _running = step;
    return step;
  }
}
