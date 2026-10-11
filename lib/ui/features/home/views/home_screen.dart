import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../app/app_restart.dart';
import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/dashboard_options.dart';
import '../../../../domain/models/money.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/currency_labels.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/period_names.dart';
import '../../../core/scroll_paging.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/retry_row.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/show_message.dart';
import '../../expenses/expense_form_opener.dart';
import '../../expenses/view_models/expense_form_cubit.dart';
import '../../recurring/views/recurring_list_screen.dart';
import '../../recurring/views/recurring_navigation.dart';
import '../../recurring/views/upcoming_screen.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/expense_list_cubit.dart';
import '../view_models/trend_cubit.dart';
import 'add_expense_fab.dart';
import 'all_photos_screen.dart';
import 'amount_chips_row.dart';
import 'filter_bar.dart';
import 'filter_sheet.dart';
import 'home_list_slivers.dart';
import 'trend_card.dart';

/// The Home tab (phase-2.md §7, phase-5.md §8.1): the trend card, the
/// filter bar, the amount chips and every expense in outlined groups (a
/// day, week, month or year each) with sticky tops, day headers inside
/// them and subtotals per currency.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dependencies,
    required this.isVisible,
    this.restoreNotice,
    this.recurringReport = GenerateReport.none,
  });

  final AppDependencies dependencies;

  /// What the recurring generator did at startup (phase-7a.md §8.6, §8.9):
  /// said once, after the restore message.
  final GenerateReport recurringReport;

  /// Said once, right after the app restarted on restored data
  /// (phase-3.md §6.6): "Backup restored", or that its settings were
  /// missing and the defaults are used. Null says nothing.
  final RestoreNotice? restoreNotice;

  /// Whether this tab is the one shown. The shell keeps the tab alive while
  /// hidden, and Manage or the bin may change data meanwhile, so the list
  /// reloads when the tab comes back, if anything changed.
  final bool isVisible;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ScrollPaging<HomeScreen> {
  late final AppSettings _startSettings = context.read<SettingsCubit>().value;

  late final ExpenseListCubit _cubit = ExpenseListCubit(
    expenses: widget.dependencies.expenses,
    categories: widget.dependencies.categories,
    paymentMethods: widget.dependencies.paymentMethods,
    events: widget.dependencies.events,
    drafts: widget.dependencies.drafts,
    dataVersion: widget.dependencies.dataVersion,
    defaultCurrency: _startSettings.defaultCurrency,
    grouping: _startSettings.listGrouping,
    weekStart: _startSettings.weekStart,
    recurring: widget.dependencies.recurring,
    now: widget.dependencies.now,
  )..load();

  late final TrendCubit _trend = TrendCubit(
    expenses: widget.dependencies.expenses,
    now: widget.dependencies.now,
    defaultCurrency: _startSettings.defaultCurrency,
    period: _startSettings.cardPeriod,
    weekStart: _startSettings.weekStart,
  )..load();

  /// Opens the form with Home's draft rules and double-tap guard, shared
  /// with the Photos screen (phase-6.md R17).
  late final _opener = ExpenseFormOpener(
    dependencies: widget.dependencies,
    pendingDraft: _cubit.pendingDraft,
    onOpenRecurring: (context, id) =>
        openRecurringFromForm(context, widget.dependencies, id),
  );

  bool _fabExtended = true;

  /// Home's own messenger, so its snackbars show on Home's Scaffold (which
  /// moves the FAB up for them) and not on other tabs or pushed screens.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// Home's Scaffold. Its context is below [_messenger], so
  /// `saveOrShowError` finds Home's messenger with it; this State's own
  /// context is above it and would find the app's root one.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  BuildContext get _messengerContext => _scaffoldKey.currentContext ?? context;

  /// Next page once fewer than about 5 rows are left below the screen.
  @override
  double get loadMoreLead => 5 * 72.0;

  /// Fires at the next local midnight, so a new day can start a new week,
  /// month or year on the card and in the names (R5) while the app is
  /// open. Timers don't run while the app is in the background, so
  /// resuming checks again ([_lifecycle]).
  Timer? _midnight;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _rebuildForNewDay);
    _scheduleMidnight();
    // On Home's own messenger, like its other snackbars, so the FAB moves
    // up for it instead of being covered. The restore message first, then
    // what the recurring generator did, queued behind it (§7.5).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.restoreNotice case final notice?) _showRestoreNotice(notice);
      _showRecurringReport(widget.recurringReport);
    });
  }

  void _showRestoreNotice(RestoreNotice notice) {
    final l10n = AppLocalizations.of(context);
    // Longer when there's more to read: where to go next, or which
    // photos are missing.
    if (notice.settingsReset) {
      _showMessage(l10n.backupRestoredDefaultSettings, long: true);
    } else if (notice.failedPhotos > 0) {
      _showMessage(
        l10n.backupRestoredFailedPhotos(notice.failedPhotos),
        long: true,
      );
    } else {
      _showMessage(l10n.backupRestored);
    }
  }

  /// "Added 2 recurring expenses" (no Undo: delete them one by one, P7a-8),
  /// and the backlogs waiting: "Gym has 10 payments waiting" (Review) for
  /// one (its page), "2 recurring items have payments waiting" (Review)
  /// for several (the list). Queued behind what is showing.
  void _showRecurringReport(GenerateReport report) {
    final l10n = AppLocalizations.of(context);
    final messenger = _messenger.currentState;
    if (report.added > 0) {
      queueMessage(messenger, l10n.addedRecurring(report.added));
    }
    final held = report.held;
    if (held.isEmpty) return;
    final one = held.length == 1 ? held.single : null;
    queueMessage(
      messenger,
      one == null
          ? l10n.heldMany(held.length)
          : l10n.heldOne(one.title, one.count),
      long: true,
      action: SnackBarAction(
        label: l10n.review,
        onPressed: () => one == null ? _openRecurringList() : _review(one.id),
      ),
    );
  }

  /// Review on a held message: the item's page; back here, the list
  /// reloads if Add all or Skip them changed it.
  Future<void> _review(int id) async {
    final result = await openRecurringPage(context, widget.dependencies, id);
    if (!mounted) return;
    await _reload();
    _showPageResult(result);
  }

  Future<void> _openRecurringList() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringListScreen(dependencies: widget.dependencies),
      ),
    );
    if (mounted) await _reloadIfChanged();
  }

  void _showPageResult(RecurringPageResult? result) => showRecurringPageResult(
    _messenger.currentState,
    _l10n,
    dateLocaleOf(context),
    result,
    today: todayOn(widget.dependencies.now()),
    onUndoStop: (undo) => undoStopOrSay(_messengerContext, () async {
      final done = await widget.dependencies.recurring.undoArchive(undo);
      await _reload();
      return done;
    }),
  );

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = widget.dependencies.now().toLocal();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(nextMidnight.difference(now), _rebuildForNewDay);
  }

  /// Names are computed in build from the clock; the card reloads, so it
  /// shows the new current period (R5). On a new day the recurring
  /// payments that came due are added too (phase-7a.md R12).
  void _rebuildForNewDay() {
    if (!mounted) return;
    setState(() {});
    _trend.load();
    _scheduleMidnight();
    _catchUpRecurring();
  }

  Future<void> _catchUpRecurring() async {
    final report = await _cubit.catchUpRecurring();
    if (!mounted) return;
    if (report.added > 0) await _trend.load();
    if (mounted) _showRecurringReport(report);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) _reloadIfChanged();
  }

  /// Reloads the list and the card after a write (save, bin, Undo).
  Future<void> _reload() => Future.wait([_cubit.reload(), _trend.load()]);

  /// Only if something was written since the last load (P2-14).
  Future<void> _reloadIfChanged() async {
    if (await _cubit.reloadIfChanged()) await _trend.load();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    _cubit.close();
    _trend.close();
    super.dispose();
  }

  @override
  void loadMore() => _cubit.loadMore();

  /// Opens Add (no [expenseId]; [chipAmount] from a chip) or Edit
  /// ([ExpenseFormOpener]), then reloads what the form changed and says
  /// what happened, on Home's own messenger (phase-2.md §9.1, §12a).
  Future<void> _openForm({int? expenseId, Money? chipAmount}) async {
    final (:opened, :result) = await _opener.open(
      context,
      expenseId: expenseId,
      chipAmount: chipAmount,
    );
    if (!opened || !mounted) return;
    switch (result) {
      case ExpenseSaved() || ExpenseBinned() || ExpenseGone():
        await _reload();
      case ExpenseDraftKept() || null:
        // Back: reload only if something changed data.
        await _reloadIfChanged();
        await _cubit.refreshDraftMark();
    }
    if (!mounted) return;
    showExpenseFormResult(
      _messenger.currentState,
      _l10n,
      result,
      onUndoBin: _undoBin,
    );
  }

  /// The Photos screen, for Home's filters (phase-6.md §8.9). Photos can
  /// be deleted and expenses edited there, so back here the list reloads
  /// if anything changed (with the icon's state), and the unsaved mark is
  /// read again.
  Future<void> _openPhotos(ExpenseFilter filter) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AllPhotosScreen(dependencies: widget.dependencies, filter: filter),
      ),
    );
    if (!mounted) return;
    await _reloadIfChanged();
    await _cubit.refreshDraftMark();
  }

  /// Upcoming payments for Home's filters (phase-7b.md §8.3; owner,
  /// 2026-10-10: like the Photos screen). Skips, stops and the item pages
  /// opened there change data: back here the list reloads if anything
  /// changed (DataVersion), with the trend card.
  Future<void> _openUpcoming(ExpenseFilter filter) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            UpcomingScreen(dependencies: widget.dependencies, filter: filter),
      ),
    );
    if (!mounted) return;
    await _reloadIfChanged();
  }

  /// Undo of "Moved to bin".
  void _undoBin(int id) => saveOrShowError(_messengerContext, () async {
    await _cubit.restore(id);
    await _trend.load();
  });

  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// A message on Home's own messenger, so the FAB moves up for it.
  void _showMessage(String message, {bool long = false}) =>
      showMessage(_messenger.currentState, message, long: long);

  Future<void> _pickCurrency(AppSettings settings) async {
    final recent = await _cubit.recentCurrencies();
    if (!mounted) return;
    final code = await showCurrencyPicker(
      context,
      selected: settings.defaultCurrency,
      recent: recent,
    );
    if (code == null || !mounted) return;
    // D1: the default for new expenses only; existing ones keep theirs.
    final settingsCubit = context.read<SettingsCubit>();
    await saveOrShowError(
      _messengerContext,
      () => settingsCubit.setDefaultCurrency(code),
    );
  }

  /// The chips, groups and card follow the settings, wherever they are
  /// changed (Home or Settings): settings writes don't bump `DataVersion`
  /// (R6). Each setter does nothing when its value didn't change.
  void _onSettings(BuildContext context, AppSettings settings) {
    _cubit.setDefaultCurrency(settings.defaultCurrency);
    _trend.setDefaultCurrency(settings.defaultCurrency);
    final list = _cubit.value;
    if (list is ExpenseListLoaded && list.grouping != settings.listGrouping) {
      _cubit.setGrouping(settings.listGrouping);
      _scrollToTop();
    }
    _cubit.setWeekStart(settings.weekStart);
    _trend.setWeekStart(settings.weekStart);
  }

  /// After the filters or the grouping changed (P5-34).
  void _scrollToTop() {
    if (pagingScroll.hasClients) pagingScroll.jumpTo(0);
  }

  /// Applies [filter] to the list; the card follows (the list's listener),
  /// with categories or events deleted meanwhile already left out.
  Future<void> _setFilter(ExpenseFilter filter) async {
    // Only whitespace is no text filter; spaces around words don't count.
    final words = searchWords(filter.text);
    final shown = await _cubit.setFilter(
      filter.copyWith(text: words.isEmpty ? '' : filter.text.trim()),
    );
    if (!mounted) return;
    // The list kept the old filter and its rows: say the new one failed.
    if (!shown) return _showMessage(_l10n.loadFailed);
    _scrollToTop();
  }

  Future<void> _openFilters(ExpenseListLoaded state) async {
    final result = await showHomeFilterSheet(
      context,
      filter: state.filter,
      grouping: state.grouping,
      categories: state.categories,
      events: state.events,
    );
    if (!mounted) return;
    if (result.grouping != state.grouping) {
      final settings = context.read<SettingsCubit>();
      // The settings listener regroups the list once it is saved.
      await saveOrShowError(
        _messengerContext,
        () => settings.setListGrouping(result.grouping),
      );
    }
    if (result.filter != state.filter) await _setFilter(result.filter);
  }

  /// A swipe on the card turned it [steps] faces: shown at once, then
  /// saved, once per swipe however far the reel spun (P5-1).
  void _turnCard(int steps) {
    final period = _trend.turn(steps);
    final settings = context.read<SettingsCubit>();
    saveOrShowError(_messengerContext, () => settings.setCardPeriod(period));
  }

  bool _onUserScroll(UserScrollNotification notification) {
    final extended = switch (notification.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _fabExtended,
    };
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(key: _messenger, child: _scaffold(context));
  }

  Widget _scaffold(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          BlocSignalBuilder<SettingsCubit, AppSettings>(
            buildWhen: (previous, current) =>
                previous.defaultCurrency != current.defaultCurrency,
            builder: (context, settings) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ActionChip(
                key: const ValueKey('currencyChip'),
                label: Text(currencyShortLabel(settings.defaultCurrency)),
                tooltip: l10n.settingDefaultCurrency,
                onPressed: () => _pickCurrency(settings),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AddExpenseFab(
        extended: _fabExtended,
        label: l10n.addExpense,
        onPressed: _openForm,
      ),
      body: BlocSignalListener<SettingsCubit, AppSettings>(
        listenWhen: (previous, current) =>
            previous.defaultCurrency != current.defaultCurrency ||
            previous.listGrouping != current.listGrouping ||
            previous.weekStart != current.weekStart,
        listener: _onSettings,
        child: BlocSignalListener<ExpenseListCubit, ExpenseListState>(
          bloc: _cubit,
          // The card follows the list's filter (P5-31), including when a
          // reload dropped a deleted category from it.
          listenWhen: (previous, current) =>
              current is ExpenseListLoaded &&
              (previous is! ExpenseListLoaded ||
                  previous.filter != current.filter),
          listener: (context, state) =>
              _trend.setFilter((state as ExpenseListLoaded).filter),
          child: BlocSignalBuilder<SettingsCubit, AppSettings>(
            buildWhen: (previous, current) =>
                previous.defaultCurrency != current.defaultCurrency ||
                previous.weekLabel != current.weekLabel ||
                previous.trendChartStyle != current.trendChartStyle ||
                previous.trendCardPosition != current.trendCardPosition ||
                previous.trendCardSize != current.trendCardSize ||
                previous.trendCardHaptics != current.trendCardHaptics,
            builder: (context, settings) =>
                BlocSignalBuilder<ExpenseListCubit, ExpenseListState>(
                  bloc: _cubit,
                  // Subtotals alone don't rebuild the list: each header
                  // watches its own.
                  buildWhen: (previous, current) =>
                      previous is! ExpenseListLoaded ||
                      current is! ExpenseListLoaded ||
                      !current.sameListAs(previous),
                  // The empty state needs the chips row too: _loaded shows it.
                  builder: (context, state) => AsyncBody(
                    phase: switch (state) {
                      ExpenseListLoading() => LoadPhase.loading,
                      ExpenseListFailed() => LoadPhase.failed,
                      ExpenseListLoaded() => LoadPhase.loaded,
                    },
                    onRetry: _cubit.load,
                    empty: const SizedBox.shrink(),
                    builder: (context) =>
                        _loaded(state as ExpenseListLoaded, settings),
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _loaded(ExpenseListLoaded state, AppSettings settings) {
    final chips = AmountChipsRow(
      chips: state.chips,
      onTap: (amount) => _openForm(chipAmount: amount),
    );
    // No active expenses at all: no card, no filter bar (P5-20).
    if (state.expenses.isEmpty && state.filter.isEmpty) {
      return Column(
        children: [
          // Shown on the empty state too (phase-4.md §8.1).
          chips,
          Expanded(
            child: EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: AppLocalizations.of(context).homeEmptyTitle,
              message: AppLocalizations.of(context).homeEmptyMessage,
            ),
          ),
        ],
      );
    }
    // A short first page may not fill the screen, and then no scroll ever
    // asks for the next one.
    if (state.hasMore && !state.loadingMore && !state.loadMoreFailed) {
      loadMoreAfterFrame();
    }
    final names = PeriodNames.of(
      context,
      today: todayOn(widget.dependencies.now()),
      weekLabel: settings.weekLabel,
    );
    final card = _trendCard(settings, names);
    final bar = FilterBar(
      filter: state.filter,
      grouping: state.grouping,
      categories: state.categories,
      events: state.events,
      onOpen: () => _openFilters(state),
      onChange: _setFilter,
      photosIcon: state.photosIcon,
      onPhotos: () => _openPhotos(state.filter),
      upcomingIcon: state.upcomingIcon,
      onUpcoming: () => _openUpcoming(state.filter),
    );
    final locked = settings.trendCardPosition == TrendCardPosition.locked;
    final list = NotificationListener<UserScrollNotification>(
      onNotification: _onUserScroll,
      child: CustomScrollView(
        controller: pagingScroll,
        slivers: [
          if (!locked) ...[
            SliverToBoxAdapter(child: card),
            PinnedHeaderSliver(child: bar),
          ],
          SliverToBoxAdapter(child: chips),
          if (state.expenses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateView(
                icon: Icons.filter_alt_off,
                title: AppLocalizations.of(context).noFilterMatches,
                actionLabel: AppLocalizations.of(context).clearFilters,
                actionKey: const ValueKey('clearFilters'),
                scrollable: false,
                onAction: () => _setFilter(ExpenseFilter.none),
              ),
            )
          else
            ...homeListSlivers(
              context: context,
              state: state,
              cubit: _cubit,
              names: names,
              defaultCurrency: settings.defaultCurrency,
              onOpen: (id) => _openForm(expenseId: id),
            ),
          // Room for the floating button under the last row.
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
    if (!locked) return list;
    return Column(
      children: [
        card,
        bar,
        Expanded(child: list),
      ],
    );
  }

  Widget _trendCard(AppSettings settings, PeriodNames names) =>
      BlocSignalBuilder<TrendCubit, TrendState>(
        bloc: _trend,
        builder: (context, state) => switch (state) {
          TrendLoading() => const Card(
            margin: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SizedBox(
              height: 160,
              child: Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),
          ),
          TrendFailed() => Card(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Center(
              child: RetryRow(
                message: AppLocalizations.of(context).totalsLoadFailed,
                onRetry: _trend.load,
              ),
            ),
          ),
          TrendLoaded() => TrendCard(
            state: state,
            names: names,
            style: settings.trendChartStyle,
            size: settings.trendCardSize,
            haptics: settings.trendCardHaptics,
            defaultCurrency: settings.defaultCurrency,
            onTurn: _turnCard,
            onCurrency: _trend.moveCurrency,
            onSelect: _trend.select,
          ),
        },
      );
}
