import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/money.dart';
import '../../../../domain/models/recurring_item.dart' show ArchiveUndo;
import '../../../../domain/periods.dart';
import '../../../../domain/upcoming.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/money_formatter.dart';
import '../../../core/period_names.dart';
import '../../../core/scroll_paging.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/expense_tile.dart';
import '../../../core/widgets/filtered_chip.dart';
import '../../../core/widgets/list_frames.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/show_message.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/upcoming_cubit.dart';
import 'recurring_navigation.dart';
import 'skip_dialog.dart';

/// **Upcoming payments**: every payment of the next 12
/// months, nearest first, in month frames with sticky day headers like the
/// Photos screen; no subtotals. Like the Photos screen it follows Home's
/// filters, with a Filtered mark (owner, 2026-10-10; it
/// ignored them before). A row opens its item's page; ⊘ skips it once or stops the item; a
/// skipped row stays, greyed, with ↺ to bring it back.
class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({
    super.key,
    required this.dependencies,
    this.filter = ExpenseFilter.none,
  });

  final AppDependencies dependencies;

  /// Home's filter, fixed while this screen is open.
  final ExpenseFilter filter;

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen>
    with ScrollPaging<UpcomingScreen> {
  late final UpcomingCubit _cubit = UpcomingCubit(
    recurring: widget.dependencies.recurring,
    categories: widget.dependencies.categories,
    dataVersion: widget.dependencies.dataVersion,
    filter: widget.filter,
    now: widget.dependencies.now,
  )..load();

  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The next month once less than about two screens of rows are left
  /// below (the Photos screen's lead).
  @override
  double get loadMoreLead => 400.0;

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  void loadMore() => _cubit.loadMore();

  /// Home's filter narrows the list (Only recurring alone doesn't).
  bool get _filtered => upcomingFiltered(widget.filter);

  BuildContext get _messengerContext => _scaffoldKey.currentContext ?? context;

  void _showMessage(String message, {SnackBarAction? action}) =>
      showMessage(_messenger.currentState, message, action: action);

  /// The item's page; back here, the list reads again if anything changed,
  /// and what the page did is said here.
  Future<void> _open(UpcomingPayment payment) async {
    final result = await openRecurringPage(
      context,
      widget.dependencies,
      payment.itemId,
    );
    if (!mounted) return;
    await _cubit.reloadIfChanged();
    if (!mounted) return;
    showRecurringPageResult(
      _messenger.currentState,
      AppLocalizations.of(context),
      dateLocaleOf(context),
      result,
      today: todayOn(widget.dependencies.now()),
      onUndoStop: (undo) =>
          undoStopOrSay(_messengerContext, () => _cubit.undoStop(undo)),
    );
  }

  /// ⊘: the dialog, then Skip once (with Undo) or Stop (with Undo).
  Future<void> _skip(UpcomingPayment payment, String date) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showSkipDialog(
      context,
      title: payment.title,
      date: date,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case SkipChoice.once:
        var skipped = false;
        await saveOrShowError(
          _messengerContext,
          () async => skipped = await _cubit.skipOnce(payment),
        );
        if (!skipped || !mounted) return;
        _showMessage(
          l10n.skippedOn(payment.title, date),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => saveOrShowError(
              _messengerContext,
              () => _cubit.unskip(payment),
            ),
          ),
        );
      case SkipChoice.stop:
        ArchiveUndo? undo;
        await saveOrShowError(
          _messengerContext,
          () async => undo = await _cubit.stopItem(payment.itemId),
        );
        final done = undo;
        if (done == null || !mounted) return;
        _showMessage(
          l10n.recurringStopped(payment.title),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () =>
                undoStopOrSay(_messengerContext, () => _cubit.undoStop(done)),
          ),
        );
    }
  }

  /// ↺: no dialog.
  Future<void> _bringBack(UpcomingPayment payment, String date) async {
    final l10n = AppLocalizations.of(context);
    var back = false;
    await saveOrShowError(
      _messengerContext,
      () async => back = await _cubit.unskip(payment),
    );
    if (back && mounted) _showMessage(l10n.paymentBack(payment.title, date));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(l10n.upcomingTitle),
          actions: [
            if (_filtered)
              const FilteredChip(key: ValueKey('upcomingFiltered')),
          ],
        ),
        body: BlocSignalBuilder<UpcomingCubit, UpcomingState>(
          bloc: _cubit,
          builder: (context, state) => AsyncBody(
            phase: switch (state) {
              UpcomingLoading() => LoadPhase.loading,
              UpcomingFailed() => LoadPhase.failed,
              UpcomingLoaded() when state.isEmpty => LoadPhase.empty,
              UpcomingLoaded() => LoadPhase.loaded,
            },
            onRetry: _cubit.load,
            empty: EmptyStateView(
              icon: Icons.event_repeat_outlined,
              title: _filtered
                  ? l10n.noUpcomingMatchFilters
                  : l10n.upcomingEmpty,
            ),
            builder: (context) => _list(context, state as UpcomingLoaded),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, UpcomingLoaded state) {
    final l10n = AppLocalizations.of(context);
    final names = _names(context, context.read<SettingsCubit>().value);
    final outline = Theme.of(context).colorScheme.outlineVariant;
    // A short first month may not fill the screen: no scroll would ever ask
    // for the next one.
    if (state.hasMore) {
      loadMoreAfterFrame();
    }
    return CustomScrollView(
      controller: pagingScroll,
      slivers: [
        for (final (i, month) in state.months.indexed)
          DecoratedSliver(
            key: ValueKey('month ${month.month}'),
            decoration: FrameDecoration(
              color: outline,
              // The last month stays open while more may follow.
              open: state.hasMore && i == state.months.length - 1,
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                PinnedHeaderSliver(
                  child: FrameTop(name: names.monthWithYear(month.month)),
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
                      SliverList.list(
                        children: [
                          for (final payment in day.payments)
                            _row(context, state, payment, names),
                        ],
                      ),
                    ],
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            // No spinner while more may follow: a month is computed in
            // memory the moment the list nears its end.
            child: state.hasMore
                ? const SizedBox(height: 48)
                : Text(
                    l10n.upcomingEnd,
                    key: const ValueKey('upcomingEnd'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    UpcomingLoaded state,
    UpcomingPayment payment,
    PeriodNames names,
  ) {
    final l10n = AppLocalizations.of(context);
    final amount = Money(payment.amountMinor, payment.currencyCode);
    final date = names.day(payment.day);
    final busy = state.isBusy(payment);
    final skipped = payment.skipped;
    return ExpenseTile(
      key: ValueKey('upcoming ${payment.itemId} ${payment.day}'),
      emoji:
          state.categories[payment.categoryId]?.emoji ??
          ExpenseTile.missingEmoji,
      title: payment.title,
      subtitle: skipped ? l10n.skipped : '',
      amount: amount,
      muted: skipped,
      titleMaxLines: 2,
      onTap: () => _open(payment),
      contentPadding: const EdgeInsetsDirectional.only(
        start: frameMargin + frameInset,
        end: 0,
      ),
      // No repeat mark: every row here repeats, and the mark cut titles short
      // at 360 dp ("Swimming c…" on the Oppo). "Netflix, ₹649, Monday 9
      // November" (+ ", Skipped").
      semanticsLabel: [
        l10n.upcomingRowSemantics(
          payment.title,
          MoneyFormatter.of(context).format(amount),
          names.spokenDay(payment.day),
        ),
        if (skipped) l10n.skipped,
      ].join(', '),
      action: Padding(
        // The icon's own 12 dp padding puts it inside the frame line.
        padding: const EdgeInsetsDirectional.only(end: frameMargin - 8),
        child: skipped
            ? IconButton(
                key: ValueKey('bringBack ${payment.itemId} ${payment.day}'),
                icon: const Icon(Icons.undo),
                tooltip: l10n.bringBack,
                onPressed: busy ? null : () => _bringBack(payment, date),
              )
            : IconButton(
                key: ValueKey('skip ${payment.itemId} ${payment.day}'),
                icon: const Icon(Icons.event_busy_outlined),
                tooltip: l10n.skip,
                onPressed: busy ? null : () => _skip(payment, date),
              ),
      ),
    );
  }

  PeriodNames _names(BuildContext context, AppSettings settings) =>
      PeriodNames.of(
        context,
        today: todayOn(widget.dependencies.now()),
        weekLabel: settings.weekLabel,
      );
}
