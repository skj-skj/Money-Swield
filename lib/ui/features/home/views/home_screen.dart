import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../app/app_restart.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/money_formatter.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/save_error.dart';
import '../../expenses/view_models/expense_form_cubit.dart';
import '../../expenses/views/expense_form_screen.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/expense_list_cubit.dart';
import 'amount_chips_row.dart';

/// The Home tab: every expense, newest first, with a header per day
/// (phase-2.md §7). Phase 5 replaces the day headers with Week / Month /
/// Year grouping and subtotals.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dependencies,
    required this.isVisible,
    this.restoreNotice,
  });

  final AppDependencies dependencies;

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

class _HomeScreenState extends State<HomeScreen> {
  late final ExpenseListCubit _cubit = ExpenseListCubit(
    expenses: widget.dependencies.expenses,
    categories: widget.dependencies.categories,
    paymentMethods: widget.dependencies.paymentMethods,
    drafts: widget.dependencies.drafts,
    dataVersion: widget.dependencies.dataVersion,
    chipCurrency: context.read<SettingsCubit>().value.defaultCurrency,
  )..load();

  /// A form is being opened: reading the draft slot first is async, and
  /// taps on the FAB, a chip or a row in that gap would open a second form
  /// (R12). Every open is ignored until the current one is pushed.
  bool _opening = false;

  final _scroll = ScrollController();
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
  static const _loadMoreLead = 5 * 72.0;

  /// Fires at the next local midnight, so "Today" becomes "Yesterday"
  /// while the app is open. Timers don't run while the app is in the
  /// background, so resuming checks again ([_lifecycle]).
  Timer? _midnight;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _lifecycle = AppLifecycleListener(onResume: _rebuildForNewDay);
    _scheduleMidnight();
    // On Home's own messenger, like its other snackbars, so the FAB moves
    // up for it instead of being covered.
    if (widget.restoreNotice case final notice?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        _messenger.currentState?.showSnackBar(switch (notice) {
          RestoreNotice.restored => SnackBar(
            content: Text(l10n.backupRestored),
          ),
          // Longer: there's more to read, and it says where to go next.
          RestoreNotice.restoredWithDefaultSettings => SnackBar(
            content: Text(l10n.backupRestoredDefaultSettings),
            duration: const Duration(seconds: 10),
            showCloseIcon: true,
          ),
        });
      });
    }
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = widget.dependencies.now().toLocal();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(nextMidnight.difference(now), _rebuildForNewDay);
  }

  /// The day headers are computed in build from the clock; rebuilding is
  /// all a new day needs.
  void _rebuildForNewDay() {
    if (!mounted) return;
    setState(() {});
    _scheduleMidnight();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) _cubit.reloadIfChanged();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    _scroll.dispose();
    _cubit.close();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < _loadMoreLead) {
      _cubit.loadMore();
    }
  }

  /// Opens Add (no [expenseId]; [chipAmount] from a chip) or Edit. The
  /// form starts from the draft slot when the slot holds a draft for it:
  /// an Add draft for Add, this expense's Edit draft for Edit; otherwise
  /// the slot is left alone until the form gets a change (phase-4.md §7.4).
  Future<void> _openForm({int? expenseId, Money? chipAmount}) async {
    if (_opening) return;
    _opening = true;
    final Future<ExpenseFormResult?> closed;
    try {
      final slot = await _cubit.pendingDraft();
      if (!mounted) return;
      final draft = slot?.editingExpenseId == expenseId ? slot : null;
      closed = Navigator.push<ExpenseFormResult>(
        context,
        MaterialPageRoute(
          builder: (_) => ExpenseFormScreen(
            dependencies: widget.dependencies,
            expenseId: expenseId,
            draft: draft,
            chipAmount: chipAmount,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
    final result = await closed;
    // Snackbars are shown here, after the pop, not by the form before it,
    // so they show on Home's own messenger only (phase-2.md §9.1, §12a).
    if (!mounted) return;
    switch (result) {
      case ExpenseSaved():
        await _cubit.reload();
      case ExpenseBinned(:final id):
        await _cubit.reload();
        if (mounted) _showMovedToBin(id);
      case ExpenseGone(:final draftKept):
        await _cubit.reload();
        if (mounted) {
          _showMessage(
            draftKept ? _l10n.draftKeptExpenseGone : _l10n.expenseGone,
            long: draftKept,
          );
        }
      case ExpenseDraftKept():
        await _cubit.reloadIfChanged();
        await _cubit.refreshDraftMark();
        if (mounted) _showMessage(_l10n.draftSaved);
      case null:
        // Back without changes: reload only if something changed data.
        await _cubit.reloadIfChanged();
        await _cubit.refreshDraftMark();
    }
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  void _showMovedToBin(int id) {
    final l10n = AppLocalizations.of(context);
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.movedToBin),
          // A snackbar with an action stays until dismissed by default;
          // Undo is only offered for a moment.
          persist: false,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () =>
                saveOrShowError(_messengerContext, () => _cubit.restore(id)),
          ),
        ),
      );
  }

  /// A plain message on Home's messenger; [long] for one with more to read.
  void _showMessage(String message, {bool long = false}) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: long
              ? const Duration(seconds: 8)
              : const Duration(seconds: 4),
          showCloseIcon: long,
        ),
      );
  }

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

  /// The chips follow the default currency, wherever it is changed.
  void _onSettings(BuildContext context, AppSettings settings) =>
      _cubit.setChipCurrency(settings.defaultCurrency);

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        isExtended: _fabExtended,
        icon: const Icon(Icons.add),
        label: Text(l10n.addExpense),
        tooltip: _fabExtended ? null : l10n.addExpense,
      ),
      body: BlocSignalListener<SettingsCubit, AppSettings>(
        listenWhen: (previous, current) =>
            previous.defaultCurrency != current.defaultCurrency,
        listener: _onSettings,
        child: BlocSignalBuilder<ExpenseListCubit, ExpenseListState>(
          bloc: _cubit,
          builder: (context, state) => switch (state) {
            ExpenseListLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            ExpenseListFailed() => LoadFailedView(onRetry: _cubit.load),
            ExpenseListLoaded() => Column(
              children: [
                // Shown on the empty state too (phase-4.md §8.1).
                AmountChipsRow(
                  chips: state.chips,
                  onTap: (amount) => _openForm(chipAmount: amount),
                ),
                Expanded(
                  child: state.expenses.isEmpty
                      ? const _EmptyState()
                      : _list(state),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }

  Widget _list(ExpenseListLoaded state) {
    // A short first page may not fill the screen, and then no scroll ever
    // asks for the next one.
    if (state.hasMore && !state.loadingMore && !state.loadMoreFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    }
    final items = homeListItems(state.expenses);
    final today = widget.dependencies.now();
    final hasFooter = state.loadingMore || state.loadMoreFailed;
    return NotificationListener<UserScrollNotification>(
      onNotification: _onUserScroll,
      child: ListView.builder(
        controller: _scroll,
        // Room for the floating button under the last row.
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: items.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return state.loadMoreFailed
                ? _LoadMoreFailedRow(onRetry: _cubit.loadMore)
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
          }
          return switch (items[index]) {
            HomeDayHeader(:final occurredOn) => _DayHeader(
              occurredOn: occurredOn,
              today: today,
            ),
            HomeExpenseRow(:final expense) => _ExpenseRow(
              key: ValueKey(expense.id),
              expense: expense,
              state: state,
              hasDraft: expense.id == state.draftExpenseId,
              onTap: () => _openForm(expenseId: expense.id),
            ),
          };
        },
      ),
    );
  }
}

/// One entry of the Home list: a day header or an expense.
sealed class HomeListItem {
  const HomeListItem();
}

final class HomeDayHeader extends HomeListItem {
  const HomeDayHeader(this.occurredOn);

  final String occurredOn;
}

final class HomeExpenseRow extends HomeListItem {
  const HomeExpenseRow(this.expense);

  final Expense expense;
}

/// [expenses] (newest first) with a header before the first expense of
/// each `occurred_on`.
List<HomeListItem> homeListItems(List<Expense> expenses) {
  final items = <HomeListItem>[];
  String? day;
  for (final expense in expenses) {
    if (expense.occurredOn != day) {
      day = expense.occurredOn;
      items.add(HomeDayHeader(day));
    }
    items.add(HomeExpenseRow(expense));
  }
  return items;
}

/// "Today", "Yesterday", else the date the way [locale] writes it ("Fri,
/// 2 Oct" for en_IN, "Fri, Oct 2" for en_US), with the year when it isn't
/// [today]'s year. [today] is the device's local date.
String dayHeaderText(
  AppLocalizations l10n,
  String locale,
  String occurredOn,
  DateTime today,
) {
  final date = DateTime.parse(occurredOn);
  final todayDate = DateTime(today.year, today.month, today.day);
  if (date == todayDate) return l10n.today;
  if (date == DateTime(today.year, today.month, today.day - 1)) {
    return l10n.yesterday;
  }
  return date.year == today.year
      ? DateFormat.MMMEd(locale).format(date)
      : DateFormat.yMMMEd(locale).format(date);
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.occurredOn, required this.today});

  final String occurredOn;

  /// The device's local now, for "Today" / "Yesterday".
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        dayHeaderText(
          AppLocalizations.of(context),
          dateLocaleOf(context),
          occurredOn,
          today.toLocal(),
        ),
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    super.key,
    required this.expense,
    required this.state,
    required this.hasDraft,
    required this.onTap,
  });

  final Expense expense;
  final ExpenseListLoaded state;

  /// The draft slot holds unsaved changes to this expense: a mark after
  /// the amount. The row still shows the stored values (P4-21).
  final bool hasDraft;
  final VoidCallback onTap;

  /// Shown when a row's category or payment method is missing. RESTRICT
  /// forbids that, but a crash would be worse than a question mark.
  static const _missing = '❓';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = dateLocaleOf(context);
    final categoryEmoji =
        state.categories[expense.categoryId]?.emoji ?? _missing;
    final methodEmoji =
        state.paymentMethods[expense.paymentMethodId]?.emoji ?? _missing;
    // The time as it was on the clock where it was recorded.
    final time = DateFormat.jm(locale).format(expense.wallClock);
    return ListTile(
      onTap: onTap,
      leading: Text(categoryEmoji, style: const TextStyle(fontSize: 28)),
      title: Text(expense.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$methodEmoji  $time'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            MoneyFormatter.of(context).format(expense.amount),
            style: theme.textTheme.titleMedium,
          ),
          if (hasDraft)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Icon(
                Icons.edit_note,
                key: const ValueKey('unsavedMark'),
                color: theme.colorScheme.tertiary,
                semanticLabel: AppLocalizations.of(context).unsavedChanges,
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadMoreFailedRow extends StatelessWidget {
  const _LoadMoreFailedRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(l10n.loadMoreFailed),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.homeEmptyTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.homeEmptyMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
