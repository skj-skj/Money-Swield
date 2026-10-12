import 'dart:math' as math;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/data_version.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/expense_draft_repository.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../../../domain/amount_chips.dart';
import '../../../../domain/expense_filter.dart';
import '../../../../domain/home_list.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/currency.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/expense_draft.dart';
import '../../../../domain/models/money.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/totals.dart';
import '../../../../domain/upcoming.dart'
    show hasUpcomingPayment, upcomingItemMatches;
import '../../../core/emit_if_open.dart';
import '../../../core/recent_currencies.dart';

/// What the Home list shows. States don't override `==`, so every emitted
/// state reaches the screen.
sealed class ExpenseListState {
  const ExpenseListState();
}

final class ExpenseListLoading extends ExpenseListState {
  const ExpenseListLoading();
}

/// A group's or a day's subtotal key: its range.
typedef SubtotalKey = PeriodRange;

/// A subtotal of a group or a day. A key with no entry hasn't been asked
/// for (its header hasn't been on screen).
sealed class SubtotalState {
  const SubtotalState();
}

/// Asked for, being read: the header shows a spinner after 300 ms. Only
/// headers that were on screen get here, so off-screen ones never spin.
final class SubtotalLoading extends SubtotalState {
  const SubtotalLoading();
}

final class SubtotalReady extends SubtotalState {
  const SubtotalReady(this.totals);

  /// Only currencies with rows; empty when the period has none under the
  /// filters.
  final CurrencyTotals totals;
}

final class SubtotalFailed extends SubtotalState {
  const SubtotalFailed();
}

final class ExpenseListLoaded extends ExpenseListState {
  const ExpenseListLoaded({
    required this.expenses,
    required this.groups,
    required this.categories,
    required this.paymentMethods,
    required this.events,
    required this.hasMore,
    required this.filter,
    required this.grouping,
    required this.weekStart,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.chips = const [],
    this.draftExpenseId,
    this.subtotals = const {},
    this.photosIcon = FilteredScreenIcon.hidden,
    this.upcomingIcon = FilteredScreenIcon.hidden,
  });

  /// In list order: by local date, then moment.
  final List<Expense> expenses;

  /// [expenses] as frames and days (`homeGroups`).
  final List<ListGroup> groups;

  /// By id, for the emoji on each row and the filter sheet.
  final Map<int, Category> categories;
  final Map<int, PaymentMethod> paymentMethods;

  /// By id, archived ones included (the filter sheet offers them).
  final Map<int, Event> events;

  /// Whether another page may follow.
  final bool hasMore;

  /// What the list (and its subtotals) show. Not saved.
  final ExpenseFilter filter;

  final Period grouping;
  final WeekStart weekStart;

  /// A page is being loaded; further [ExpenseListCubit.loadMore] calls
  /// return at once.
  final bool loadingMore;

  /// The last page failed: the list keeps its rows and shows a retry row.
  final bool loadMoreFailed;

  /// The amount chips, ascending; empty hides the row.
  final List<Money> chips;

  /// The expense with unsaved changes in the draft slot, or null; its row shows
  /// a mark.
  final int? draftExpenseId;

  /// Read lazily, per group and per day, for exactly what [filter] lets
  /// through.
  final Map<SubtotalKey, SubtotalState> subtotals;

  /// Read with every load and filter change.
  final FilteredScreenIcon photosIcon;

  /// The Upcoming payments icon: hidden while no item runs, greyed when the
  /// filters hide every upcoming payment (owner, 2026-10-10: Upcoming follows
  /// the filters, like the Photos screen).
  final FilteredScreenIcon upcomingIcon;

  /// Whether this state differs from [other] only in its subtotals, so the
  /// list itself needn't be built again (each frame top and day header
  /// watches its own subtotal).
  bool sameListAs(ExpenseListLoaded other) =>
      identical(expenses, other.expenses) &&
      identical(groups, other.groups) &&
      identical(categories, other.categories) &&
      identical(paymentMethods, other.paymentMethods) &&
      identical(events, other.events) &&
      hasMore == other.hasMore &&
      filter == other.filter &&
      grouping == other.grouping &&
      weekStart == other.weekStart &&
      loadingMore == other.loadingMore &&
      loadMoreFailed == other.loadMoreFailed &&
      identical(chips, other.chips) &&
      draftExpenseId == other.draftExpenseId &&
      photosIcon == other.photosIcon &&
      upcomingIcon == other.upcomingIcon;

  /// A copy; [groups] are rebuilt when the rows, [hasMore], the grouping
  /// or the week start change.
  ExpenseListLoaded copyWith({
    List<Expense>? expenses,
    bool? hasMore,
    Period? grouping,
    WeekStart? weekStart,
    bool? loadingMore,
    bool? loadMoreFailed,
    List<Money>? chips,
    int? Function()? draftExpenseId,
    Map<SubtotalKey, SubtotalState>? subtotals,
  }) {
    final regroup =
        expenses != null ||
        hasMore != null ||
        grouping != null ||
        weekStart != null;
    final rows = expenses ?? this.expenses;
    final more = hasMore ?? this.hasMore;
    final by = grouping ?? this.grouping;
    final start = weekStart ?? this.weekStart;
    return ExpenseListLoaded(
      expenses: rows,
      groups: regroup
          ? homeGroups(rows, grouping: by, weekStart: start, hasMore: more)
          : groups,
      categories: categories,
      paymentMethods: paymentMethods,
      events: events,
      hasMore: more,
      filter: filter,
      grouping: by,
      weekStart: start,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      chips: chips ?? this.chips,
      draftExpenseId: draftExpenseId == null
          ? this.draftExpenseId
          : draftExpenseId(),
      subtotals: subtotals ?? this.subtotals,
      photosIcon: photosIcon,
      upcomingIcon: upcomingIcon,
    );
  }
}

/// An icon on Home's filter bar that opens a screen following Home's filters:
/// the photos icon and the Upcoming payments icon (owner 2026-10-10).
enum FilteredScreenIcon {
  /// Nothing to show at all (no photo; no running item), or it couldn't
  /// be counted.
  hidden,

  /// The filters let at least one through.
  enabled,

  /// Some exist, but the filters hide every one: greyed out.
  disabled,
}

final class ExpenseListFailed extends ExpenseListState {
  const ExpenseListFailed(this.error);

  final Object error;
}

/// The Home tab's expense list: keyset pages of [pageSize] in list order,
/// grouped and filtered, with lazy subtotals, the amount chips and the unsaved
/// mark.
class ExpenseListCubit extends CubitSignal<ExpenseListState>
    with EmitIfOpen<ExpenseListState> {
  /// Chips are for `defaultCurrency`; Home keeps it, the grouping and the
  /// week start up to date ([setDefaultCurrency], [setGrouping],
  /// [setWeekStart]).
  ExpenseListCubit({
    required this._expenses,
    required this._categories,
    required this._paymentMethods,
    required this._events,
    required this._drafts,
    required this._dataVersion,
    required String defaultCurrency,
    this._grouping = Period.week,
    this._weekStart = WeekStart.monday,
    this.pageSize = 30,
    this._recurring,
    DateTime Function()? now,
  }) : _chipCurrency = defaultCurrency,
       _now = now ?? DateTime.now,
       super(initialState: const ExpenseListLoading()) {
    _lastRunDay = todayOn(_now());
  }

  /// Runs the recurring generator when a new day is noticed while the app runs.
  /// Null in tests that don't need it.
  final RecurringRepository? _recurring;
  final DateTime Function() _now;

  /// The day the generator last ran: the startup run's day at first (the
  /// startup ran just before Home was built).
  late String _lastRunDay;

  /// A run in flight: an overlapping call doesn't start another.
  bool _catchingUp = false;

  /// Resume or local midnight on a new day: adds what came due since the last
  /// run, then reloads if anything changed. Once per day, one run at a time; a
  /// failure is logged and the next new-day signal tries again. Returns what
  /// the run did, for Home's messages.
  Future<GenerateReport> catchUpRecurring() async {
    final recurring = _recurring;
    final today = todayOn(_now());
    if (recurring == null || today == _lastRunDay || _catchingUp) {
      return GenerateReport.none;
    }
    _catchingUp = true;
    try {
      final report = await recurring.generateDue();
      _lastRunDay = today;
      await reloadIfChanged();
      return report;
    } catch (error, stackTrace) {
      debugPrint('Adding recurring payments failed: $error\n$stackTrace');
      return GenerateReport.none;
    } finally {
      _catchingUp = false;
    }
  }

  final ExpenseDraftRepository _drafts;
  String _chipCurrency;
  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final PaymentMethodRepository _paymentMethods;
  final EventRepository _events;
  final DataVersion _dataVersion;
  final int pageSize;

  /// The filter of the rows on screen: every page and subtotal reads
  /// with it.
  ExpenseFilter _filter = ExpenseFilter.none;

  /// The filter the next (re)load reads with: the last one asked for. It
  /// becomes [_filter] once its rows are shown, and goes back to it when
  /// they can't be read, so a later page never mixes two filters.
  ExpenseFilter _requested = ExpenseFilter.none;
  Period _grouping;
  WeekStart _weekStart;

  /// `DataVersion.value` when the rows shown were loaded.
  int? _loadedVersion;

  /// Bumped by every (re)load and filter change, so a page that was
  /// requested before it can't be appended to the fresh rows (which would
  /// duplicate them). [loadMore] also checks that the rows it continues
  /// are still the ones shown, which covers a page requested while a
  /// reload was running.
  int _generation = 0;

  /// With a text filter: every matching entry, in list order, and how many of
  /// them the loaded rows cover. Null without one.
  List<SearchEntry>? _matches;
  int _matchesUsed = 0;

  /// Bumped whenever the subtotals are dropped (filter, grouping, week
  /// start, any reload), so a read in flight can't store an old value.
  int _subtotalGeneration = 0;

  /// Subtotals waiting to be read, one at a time, in request order.
  final _subtotalQueue = <SubtotalKey>[];
  bool _readingSubtotals = false;

  /// Loads the lookups and the first page.
  Future<void> load() => _loadTop(pageSize);

  /// Reloads from the top as many rows as are loaded (at least a page), in
  /// one query, so the loaded rows and the scroll position stay. The
  /// subtotals are read again (data changed).
  Future<void> reload() {
    final loaded = switch (value) {
      ExpenseListLoaded(:final expenses) => expenses.length,
      _ => 0,
    };
    return _loadTop(math.max(pageSize, loaded));
  }

  /// Called when the Home tab becomes visible again. Reloads only if something
  /// was written since the last load: Manage may have renamed a category,
  /// Settings → Bin may have restored an expense. Returns whether it reloaded,
  /// so Home reloads the trend card too.
  Future<bool> reloadIfChanged() async {
    if (_dataVersion.value == _loadedVersion) return false;
    await reload();
    return true;
  }

  /// Shows what [filter] lets through, from the top. A page in flight is
  /// dropped. Returns false when the rows couldn't be read: the list then keeps
  /// the old filter and its rows, and the screen says so.
  Future<bool> setFilter(ExpenseFilter filter) {
    _requested = filter;
    return _loadTop(pageSize);
  }

  /// Groups the loaded rows by [grouping]; subtotals are read again.
  void setGrouping(Period grouping) {
    if (grouping == _grouping) return;
    _grouping = grouping;
    _regroup((state) => state.copyWith(grouping: grouping));
  }

  /// Weeks start on [weekStart]; subtotals are read again.
  void setWeekStart(WeekStart weekStart) {
    if (weekStart == _weekStart) return;
    _weekStart = weekStart;
    _regroup((state) => state.copyWith(weekStart: weekStart));
  }

  /// Regroups the rows on screen. Loads in flight are left alone, on
  /// purpose: a (re)load groups its rows with [_grouping] and [_weekStart]
  /// as they are when it emits, and a page appended by [loadMore] is
  /// regrouped by `copyWith` with the current ones. Cancelling them here
  /// left a first load stuck on Loading and dropped a new filter's rows.
  void _regroup(ExpenseListLoaded Function(ExpenseListLoaded) change) {
    _dropSubtotals();
    final state = value;
    if (state is ExpenseListLoaded) {
      emitIfOpen(change(state).copyWith(subtotals: const {}));
    }
  }

  /// Loads the next page after the last loaded row. One request at a time.
  Future<void> loadMore() async {
    final state = value;
    if (state is! ExpenseListLoaded || !state.hasMore || state.loadingMore) {
      return;
    }
    final generation = _generation;
    final rows = state.expenses;
    final matches = _matches;
    // Whether the page still continues the rows on screen. A reload that
    // finished meanwhile replaced them (and may have shifted them, e.g.
    // after a delete), so the page would duplicate or skip rows; it is
    // dropped, and the list asks again from the new last row.
    bool stillCurrent(ExpenseListLoaded current) =>
        generation == _generation && identical(current.expenses, rows);
    emitIfOpen(state.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final List<Expense> page;
      final bool hasMore;
      var used = _matchesUsed;
      if (matches != null) {
        (page, used) = await _pageOfMatches(matches, used, pageSize);
        hasMore = used < matches.length;
      } else {
        // The cursor comes from the last loaded row, never from a counter.
        page = await _expenses.page(
          filter: _filter,
          after: rows.lastOrNull?.cursor,
          limit: pageSize,
        );
        hasMore = page.length == pageSize;
      }
      final current = value;
      if (current is! ExpenseListLoaded || !stillCurrent(current)) return;
      _matchesUsed = used;
      emitIfOpen(
        current.copyWith(
          expenses: [...current.expenses, ...page],
          hasMore: hasMore,
          loadingMore: false,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Loading more expenses failed: $error\n$stackTrace');
      final current = value;
      if (current is! ExpenseListLoaded || !stillCurrent(current)) return;
      emitIfOpen(current.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  /// Reads the subtotal of [key] (a group's or a day's range) unless it is read
  /// or being read. Called by a frame top or day header when it shows. One read
  /// at a time, in request order.
  void requestSubtotal(SubtotalKey key) {
    final state = value;
    if (state is! ExpenseListLoaded || state.subtotals.containsKey(key)) {
      return;
    }
    // With a text filter the matching entries are in memory already.
    if (_matches case final matches?) {
      _setSubtotal(key, SubtotalReady(_sumMatches(matches, key)));
      return;
    }
    _setSubtotal(key, const SubtotalLoading());
    _subtotalQueue.add(key);
    _readSubtotals();
  }

  /// Reads [key]'s subtotal again after it failed (the retry icon).
  void retrySubtotal(SubtotalKey key) {
    final state = value;
    if (state is! ExpenseListLoaded ||
        state.subtotals[key] is! SubtotalFailed) {
      return;
    }
    emitIfOpen(state.copyWith(subtotals: {...state.subtotals}..remove(key)));
    requestSubtotal(key);
  }

  Future<void> _readSubtotals() async {
    if (_readingSubtotals) return;
    _readingSubtotals = true;
    try {
      while (_subtotalQueue.isNotEmpty && !isClosed) {
        final key = _subtotalQueue.removeAt(0);
        final generation = _subtotalGeneration;
        final filter = _filter;
        SubtotalState result;
        try {
          final rows = await _expenses.amountsIn(
            from: key.from,
            to: key.to,
            filter: filter,
          );
          result = SubtotalReady(
            sumByCurrency([for (final (_, code, minor) in rows) (code, minor)]),
          );
        } catch (error) {
          debugPrint('Loading a subtotal failed: $error');
          result = const SubtotalFailed();
        }
        // Dropped meanwhile (filter, grouping, a write): the new list asks
        // again.
        if (generation != _subtotalGeneration) continue;
        _setSubtotal(key, result);
      }
    } finally {
      _readingSubtotals = false;
    }
  }

  void _setSubtotal(SubtotalKey key, SubtotalState subtotal) {
    final state = value;
    if (state is! ExpenseListLoaded) return;
    emitIfOpen(state.copyWith(subtotals: {...state.subtotals, key: subtotal}));
  }

  void _dropSubtotals() {
    _subtotalGeneration++;
    _subtotalQueue.clear();
  }

  static CurrencyTotals _sumMatches(List<SearchEntry> matches, PeriodRange r) =>
      sumByCurrency([
        for (final entry in matches)
          if (entry.day.compareTo(r.from) >= 0 &&
              entry.day.compareTo(r.to) <= 0)
            (entry.currencyCode, entry.amountMinor),
      ]);

  /// Undo for "Moved to bin": takes [id] out of the bin and reloads. Does
  /// nothing if it is no longer there (the bin was emptied meanwhile).
  /// Rethrows a failed write; the screen tells the user.
  Future<void> restore(int id) async {
    await _expenses.restore(id);
    await reload();
  }

  /// Shows the chips of [code] (the default currency changed). Settings
  /// writes don't bump `DataVersion`, so Home calls this itself. Subtotals
  /// only change order, which the screen takes from the settings.
  Future<void> setDefaultCurrency(String code) async {
    if (code == _chipCurrency) return;
    _chipCurrency = code;
    final chips = await _loadChips();
    final current = value;
    if (current is ExpenseListLoaded && code == _chipCurrency) {
      emitIfOpen(current.copyWith(chips: chips));
    }
  }

  /// The draft slot, for opening the form. Null when empty or when it can't be
  /// read (logged): the form then opens without a draft.
  Future<ExpenseDraft?> pendingDraft() => _drafts.readOrNull();

  /// Re-reads which expense has unsaved changes, after a form closed: draft
  /// writes don't bump `DataVersion`.
  Future<void> refreshDraftMark() async {
    final id = (await pendingDraft())?.editingExpenseId;
    final current = value;
    if (current is ExpenseListLoaded && current.draftExpenseId != id) {
      emitIfOpen(current.copyWith(draftExpenseId: () => id));
    }
  }

  /// The currencies of the latest entered expenses, for the currency
  /// sheet's Recent section. Empty if they can't be read: the sheet still
  /// works without them.
  Future<List<String>> recentCurrencies() => recentCurrenciesOrEmpty(_expenses);

  /// Reads the lookups and the first [limit] rows of the requested filter.
  /// Returns false only when that read failed; a load overtaken by a newer
  /// one returns true (the newer one shows the same requested filter).
  Future<bool> _loadTop(int limit) async {
    final generation = ++_generation;
    final version = _dataVersion.value;
    try {
      final categories = await _categories.all();
      final paymentMethods = await _paymentMethods.all();
      final events = await _events.all();
      // Categories or events deleted in Manage leave the filter, before
      // the rows are read with it: "only a deleted category" must show
      // everything, not nothing.
      final filter = _withoutDeleted(_requested, categories, events);
      final List<Expense> expenses;
      final bool hasMore;
      List<SearchEntry>? matches;
      var used = 0;
      if (filter.hasText) {
        final words = searchWords(filter.text);
        matches = [
          for (final entry in await _expenses.searchEntries(
            filter: filter.withoutText,
          ))
            if (matchesText(entry, words)) entry,
        ];
        (expenses, used) = await _pageOfMatches(matches, 0, limit);
        hasMore = used < matches.length;
      } else {
        expenses = await _expenses.page(filter: filter, limit: limit);
        hasMore = expenses.length == limit;
      }
      final draft = await pendingDraft();
      final photosIcon = await _photosIcon(filter, matches);
      final upcomingIcon = await _upcomingIcon(filter);
      // Last, with no await after it: the chips are for the chip currency
      // as it is when this emits, even if it changed while loading.
      final chips = await _loadChips();
      if (generation != _generation) return true;
      _loadedVersion = version;
      _filter = filter;
      _requested = filter;
      _matches = matches;
      _matchesUsed = used;
      _dropSubtotals();
      emitIfOpen(
        ExpenseListLoaded(
          expenses: expenses,
          groups: homeGroups(
            expenses,
            grouping: _grouping,
            weekStart: _weekStart,
            hasMore: hasMore,
          ),
          categories: {for (final c in categories) c.id: c},
          paymentMethods: {for (final m in paymentMethods) m.id: m},
          events: {for (final e in events) e.id: e},
          hasMore: hasMore,
          filter: filter,
          grouping: _grouping,
          weekStart: _weekStart,
          chips: chips,
          draftExpenseId: draft?.editingExpenseId,
          photosIcon: photosIcon,
          upcomingIcon: upcomingIcon,
        ),
      );
      return true;
    } catch (error) {
      debugPrint('Loading expenses failed: $error');
      if (generation != _generation) return true;
      _requested = _filter;
      // A failed reload keeps the rows on screen; only a first load shows
      // the error view.
      if (value is! ExpenseListLoaded) emitIfOpen(ExpenseListFailed(error));
      return false;
    }
  }

  /// Whether Home's photos icon shows, and whether [filter] lets a photo
  /// through. With a text filter its [matches] are already read: they are
  /// checked against the expenses with photos. Its own try/catch: a failure
  /// hides the icon (logged), the list loads normally.
  Future<FilteredScreenIcon> _photosIcon(
    ExpenseFilter filter,
    List<SearchEntry>? matches,
  ) async {
    try {
      if (!await _expenses.hasPhotos()) return FilteredScreenIcon.hidden;
      final bool any;
      if (matches != null) {
        any = (await _expenses.withPhotos(matches)).isNotEmpty;
      } else {
        any = await _expenses.hasMatchingPhotos(filter);
      }
      return any ? FilteredScreenIcon.enabled : FilteredScreenIcon.disabled;
    } catch (error) {
      debugPrint('Checking for photos failed: $error');
      return FilteredScreenIcon.hidden;
    }
  }

  /// Home's Upcoming icon: hidden while no item has a payment Upcoming would
  /// list ([hasUpcomingPayment]), greyed when [filter] lets none of them
  /// through ([upcomingItemMatches]). Its own try/catch: a failure hides the
  /// icon (logged), the list loads normally.
  Future<FilteredScreenIcon> _upcomingIcon(ExpenseFilter filter) async {
    final recurring = _recurring;
    if (recurring == null) return FilteredScreenIcon.hidden;
    try {
      final today = todayOn(_now());
      final items = [
        for (final item in await recurring.all())
          if (hasUpcomingPayment(item, today: today)) item,
      ];
      if (items.isEmpty) return FilteredScreenIcon.hidden;
      return items.any((item) => upcomingItemMatches(item, filter))
          ? FilteredScreenIcon.enabled
          : FilteredScreenIcon.disabled;
    } catch (error) {
      debugPrint('Reading recurring items failed: $error');
      return FilteredScreenIcon.hidden;
    }
  }

  /// Up to [count] rows of [matches] from [start], and where the next page
  /// starts. Ids that `byIds` doesn't return (binned since) are skipped.
  Future<(List<Expense>, int)> _pageOfMatches(
    List<SearchEntry> matches,
    int start,
    int count,
  ) async {
    final end = math.min(start + count, matches.length);
    final rows = await _expenses.byIds([
      for (final entry in matches.sublist(start, end)) entry.id,
    ]);
    return (rows, end);
  }

  static ExpenseFilter _withoutDeleted(
    ExpenseFilter filter,
    List<Category> categories,
    List<Event> events,
  ) {
    final categoryIds = {for (final c in categories) c.id};
    final eventIds = {for (final e in events) e.id};
    if (categoryIds.containsAll(filter.categoryIds) &&
        eventIds.containsAll(filter.eventIds)) {
      return filter;
    }
    return filter.copyWith(
      categoryIds: filter.categoryIds.intersection(categoryIds),
      eventIds: filter.eventIds.intersection(eventIds),
    );
  }

  /// The chips of the chip currency. Their own try/catch: a failure hides the
  /// row (logged) and the list loads normally. Read again if the currency
  /// changed during the query, so a reload in flight can't put the old
  /// currency's chips back.
  Future<List<Money>> _loadChips() async {
    final code = _chipCurrency;
    try {
      final popular = await _expenses.amountChipStats(code);
      if (code != _chipCurrency) return await _loadChips();
      return [
        for (final amount in amountChips(
          popular,
          currencyCode: code,
          minorDigits: findCurrency(code)?.minorDigits ?? 2,
        ))
          Money(amount, code),
      ];
    } catch (error) {
      debugPrint('Loading the amount chips failed: $error');
      return const [];
    }
  }
}
