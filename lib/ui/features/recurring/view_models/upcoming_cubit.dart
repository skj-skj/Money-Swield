import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/data_version.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/upcoming.dart';
import '../../../core/emit_if_open.dart';

/// What Upcoming payments shows. States don't override `==`, so every emitted
/// state reaches the screen.
sealed class UpcomingState {
  const UpcomingState();
}

final class UpcomingLoading extends UpcomingState {
  const UpcomingLoading();
}

final class UpcomingFailed extends UpcomingState {
  const UpcomingFailed(this.error);

  final Object error;
}

final class UpcomingLoaded extends UpcomingState {
  const UpcomingLoaded({
    required this.months,
    required this.hasMore,
    required this.categories,
    required this.today,
    this.busy = const {},
    this.busyItems = const {},
  });

  /// The pages read so far as month frames, nearest first.
  final List<UpcomingMonth> months;

  /// More months follow (up to 12 months on).
  final bool hasMore;

  /// By id, for the rows' emoji.
  final Map<int, Category> categories;

  /// The day the payments were computed for.
  final String today;

  /// Rows whose Skip or Bring back is running: their buttons are off.
  final Set<SkipKey> busy;

  /// Items whose Stop is running.
  final Set<int> busyItems;

  bool get isEmpty => months.isEmpty && !hasMore;

  bool isBusy(UpcomingPayment p) =>
      busy.contains(p.key) || busyItems.contains(p.itemId);

  UpcomingLoaded copyWith({
    List<UpcomingMonth>? months,
    bool? hasMore,
    Set<SkipKey>? busy,
    Set<int>? busyItems,
  }) => UpcomingLoaded(
    months: months ?? this.months,
    hasMore: hasMore ?? this.hasMore,
    categories: categories,
    today: today,
    busy: busy ?? this.busy,
    busyItems: busyItems ?? this.busyItems,
  );
}

/// **Upcoming payments**: every payment of the
/// running items over the next 12 months, a month a page as the screen scrolls;
/// each can be skipped once, brought back, or its item stopped. Computed from
/// the items and the stored skips, read once per (re)load: paging needs no
/// further reads.
class UpcomingCubit extends CubitSignal<UpcomingState>
    with EmitIfOpen<UpcomingState> {
  UpcomingCubit({
    required this._recurring,
    required this._categories,
    required this._dataVersion,
    this.filter = ExpenseFilter.none,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(initialState: const UpcomingLoading());

  final RecurringRepository _recurring;
  final CategoryRepository _categories;
  final DataVersion _dataVersion;
  final DateTime Function() _now;

  /// Home's filter, fixed while the screen is open (owner, 2026-10-10:
  /// like the Photos screen): only the items it lets through are listed.
  final ExpenseFilter filter;

  List<RecurringItem> _items = const [];
  Set<SkipKey> _skips = const {};
  Map<int, Category> _categoryMap = const {};
  List<PeriodRange> _pages = const [];

  /// How many pages are shown.
  int _shown = 0;

  /// The payments of each page computed since the last read, by page: a
  /// page more doesn't compute the ones before it again.
  final List<List<UpcomingPayment>> _pagePayments = [];

  /// `DataVersion.value` and the day when the items were read.
  int? _loadedVersion;
  String? _loadedDay;

  String get _today => todayOn(_now());

  UpcomingLoaded? get _loaded => switch (value) {
    final UpcomingLoaded loaded => loaded,
    _ => null,
  };

  /// Reads the items and skips, then shows the first month that has a
  /// payment (empty months are passed over, so the screen always has
  /// something to scroll, or says it is empty). A reload keeps the months
  /// shown.
  Future<void> load() async {
    final version = _dataVersion.value;
    final today = _today;
    try {
      final items = await _recurring.all();
      final skips = await _recurring.skips(after: today);
      final categories = await _categories.all();
      _items = [
        for (final item in items)
          if (upcomingItemMatches(item, filter)) item,
      ];
      _skips = skips;
      _pagePayments.clear();
      _categoryMap = {for (final c in categories) c.id: c};
      if (today != _loadedDay) {
        // A new day: the pages move with it (from tomorrow).
        _pages = upcomingPages(today);
        _shown = 0;
      }
      _loadedVersion = version;
      _loadedDay = today;
      _emitPages(today, wanted: _shown == 0 ? 1 : _shown);
    } catch (error) {
      if (_loaded == null) emitIfOpen(UpcomingFailed(error));
    }
  }

  /// The next month with payments, up to 12 months on (the screen asks as
  /// it nears the end).
  void loadMore() {
    final loaded = _loaded;
    if (loaded == null || !loaded.hasMore) return;
    _emitPages(loaded.today, wanted: _shown + 1);
  }

  /// Back on the screen (from an item's page): reads again only if
  /// something was written, or the day changed.
  Future<bool> reloadIfChanged() async {
    if (_dataVersion.value == _loadedVersion && _today == _loadedDay) {
      return false;
    }
    await load();
    return true;
  }

  /// Shows at least [wanted] pages, and more while the last one read has
  /// no payment: an empty month adds nothing to scroll, so the next one
  /// would never be asked for.
  void _emitPages(String today, {required int wanted}) {
    final list = <UpcomingPayment>[];
    var shown = 0;
    var lastEmpty = true;
    while (shown < _pages.length && (shown < wanted || lastEmpty)) {
      if (shown == _pagePayments.length) {
        _pagePayments.add(
          upcomingPayments(
            _items,
            _skips,
            today: today,
            from: _pages[shown].from,
            through: _pages[shown].to,
          ),
        );
      }
      final page = _pagePayments[shown];
      list.addAll(page);
      lastEmpty = page.isEmpty;
      shown++;
    }
    _shown = shown;
    final current = _loaded;
    emitIfOpen(
      UpcomingLoaded(
        months: upcomingGroups(list),
        hasMore: shown < _pages.length,
        categories: _categoryMap,
        today: today,
        busy: current?.busy ?? const {},
        busyItems: current?.busyItems ?? const {},
      ),
    );
  }

  /// Runs [action] for [key] once at a time (a double tap does it once),
  /// then reads again. Null when it was already running. Rethrows a failed
  /// write; the screen says "Couldn't save".
  Future<T?> _busyRow<T>(SkipKey key, Future<T> Function() action) async {
    final loaded = _loaded;
    if (loaded == null || loaded.busy.contains(key)) return null;
    emitIfOpen(loaded.copyWith(busy: {...loaded.busy, key}));
    try {
      return await action();
    } finally {
      final current = _loaded;
      if (current != null) {
        emitIfOpen(current.copyWith(busy: {...current.busy}..remove(key)));
      }
      await load();
    }
  }

  /// **Skip once**: the row stays, greyed. True when skipped (the
  /// screen offers Undo, which is [unskip]).
  Future<bool> skipOnce(UpcomingPayment payment) async =>
      await _busyRow(payment.key, () async {
        await _recurring.skipOnce(payment.itemId, payment.day);
        return true;
      }) ??
      false;

  /// **Bring back** a skipped payment; Undo of [skipOnce]. True when done.
  Future<bool> unskip(UpcomingPayment payment) async =>
      await _busyRow(payment.key, () async {
        await _recurring.unskip(payment.itemId, payment.day);
        return true;
      }) ??
      false;

  /// **Stop** the item from the skip dialog: archived (its rows leave),
  /// with Undo ([undoStop]). Null when a Stop of it is running.
  Future<ArchiveUndo?> stopItem(int itemId) async {
    final loaded = _loaded;
    if (loaded == null || loaded.busyItems.contains(itemId)) return null;
    emitIfOpen(loaded.copyWith(busyItems: {...loaded.busyItems, itemId}));
    try {
      return await _recurring.archive(itemId);
    } finally {
      final current = _loaded;
      if (current != null) {
        emitIfOpen(
          current.copyWith(busyItems: {...current.busyItems}..remove(itemId)),
        );
      }
      await load();
    }
  }

  /// Undo of [stopItem]: running again, unless it changed since (false:
  /// the screen says so).
  Future<bool> undoStop(ArchiveUndo undo) async {
    final done = await _recurring.undoArchive(undo);
    await load();
    return done;
  }
}
