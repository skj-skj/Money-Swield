import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/money.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/recurring_price.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/item_labels.dart';
import '../../../core/money_formatter.dart';
import '../../../core/period_names.dart';
import '../../../core/recurrence_text.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/expense_tile.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/show_message.dart';
import '../../expenses/expense_form_opener.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/recurring_detail_cubit.dart';
import 'add_selected_sheet.dart';
import 'change_price_sheet.dart';
import 'hold_card.dart';
import 'recurring_form_screen.dart';
import 'recurring_navigation.dart';
import 'recurring_texts.dart';

/// A recurring item's page: the hold card when held, the rule, the price
/// history and the payments added, with Change price, Stop and Edit. An
/// archived item opens read-only, with Restore and Delete for good instead.
///
/// Stop, Restore and Delete for good close the page with their result
/// ([RecurringPageResult]); the screen below says it.
class RecurringDetailScreen extends StatefulWidget {
  const RecurringDetailScreen({
    super.key,
    required this.dependencies,
    required this.itemId,
  });

  final AppDependencies dependencies;
  final int itemId;

  @override
  State<RecurringDetailScreen> createState() => _RecurringDetailScreenState();
}

class _RecurringDetailScreenState extends State<RecurringDetailScreen> {
  RecurringDetailCubit? _cubit;
  RecurringDetailCubit get _page => _cubit!;

  /// Payments open through the form opener: the draft slot's rules and its
  /// double-tap guard. From here, a payment's link row leads back to this page,
  /// so it opens nothing.
  late final _opener = ExpenseFormOpener(
    dependencies: widget.dependencies,
    // Not a tear-off: the page's cubit is replaced after a new schedule.
    pendingDraft: () => _page.pendingDraft(),
  );

  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _scaffold = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    _cubit = _cubitFor(widget.itemId);
  }

  /// The page's item: [RecurringDetailScreen.itemId] at first, then the
  /// new item after a change of how often ([_edit]).
  RecurringDetailCubit _cubitFor(int itemId) {
    final deps = widget.dependencies;
    return RecurringDetailCubit(
      itemId: itemId,
      recurring: deps.recurring,
      expenses: deps.expenses,
      categories: deps.categories,
      paymentMethods: deps.paymentMethods,
      events: deps.events,
      drafts: deps.drafts,
      decimalSeparator: decimalSeparatorOf(context),
      now: deps.now,
    )..load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _cubit?.close();
    super.dispose();
  }

  BuildContext get _messengerContext => _scaffold.currentContext ?? context;

  void _showMessage(String message) =>
      showMessage(_messenger.currentState, message);

  /// After Show all, the next page once the list nears its end.
  void _maybeLoadMore() {
    final state = _page.value;
    if (state is! RecurringDetailLoaded ||
        !state.showingAll ||
        !state.hasMorePayments) {
      return;
    }
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
      _page.loadMorePayments();
    }
  }

  Future<void> _addAll() async {
    int? added;
    await saveOrShowError(
      _messengerContext,
      () async => added = await _page.addAll(),
    );
    final count = added;
    if (count != null && mounted) {
      _showMessage(AppLocalizations.of(context).addedPayments(count));
    }
  }

  /// **Add selected**: the held dates in a sheet, all
  /// ticked; the ticked ones are added, the rest skipped for good.
  Future<void> _addSelected(RecurringItem item) async {
    final l10n = AppLocalizations.of(context);
    final locale = dateLocaleOf(context);
    final today = _page.today;
    final held = await _page.heldDates();
    if (held == null || held.days.isEmpty || !mounted) return;
    final prices = switch (_page.value) {
      RecurringDetailLoaded(:final prices) => prices,
      _ => const <PricePoint>[],
    };
    final names = PeriodNames.of(
      context,
      today: today,
      weekLabel: context.read<SettingsCubit>().value.weekLabel,
    );
    final ticked = await showAddSelectedSheet(
      context,
      days: held.days,
      priceOn: (day) => switch (priceOn(prices, day)) {
        final int minor => Money(minor, item.currencyCode),
        null => null,
      },
      dayName: names.day,
    );
    if (ticked == null || !mounted) return;
    SelectedOutcome? outcome;
    await saveOrShowError(
      _messengerContext,
      () async => outcome = await _page.addSelected(ticked, held: held),
    );
    final done = outcome;
    if (done == null || !mounted) return;
    final next = done.next;
    _showMessage(switch (next) {
      null => l10n.addedAndSkippedNoNext(done.added, done.skipped),
      // More than 1,000 were waiting: the rest are asked about next.
      _ when next.compareTo(today) <= 0 => l10n.addedAndSkippedMore(
        done.added,
        done.skipped,
      ),
      _ => l10n.addedAndSkipped(
        done.added,
        done.skipped,
        dayText(locale, next, today: today),
      ),
    });
  }

  Future<void> _skipAll() async {
    final l10n = AppLocalizations.of(context);
    final locale = dateLocaleOf(context);
    final today = _page.today;
    await saveOrShowError(_messengerContext, () async {
      final outcome = await _page.skipAll();
      if (outcome == null || !mounted) return;
      final next = outcome.next;
      _showMessage(
        next == null
            ? l10n.skippedPaymentsNoNext(outcome.skipped)
            : l10n.skippedPayments(
                outcome.skipped,
                dayText(locale, next, today: today),
              ),
      );
    });
  }

  Future<void> _stop(RecurringItem item) async {
    ArchiveUndo? undo;
    await saveOrShowError(
      _messengerContext,
      () async => undo = await _page.stop(),
    );
    final done = undo;
    if (done != null && mounted) {
      Navigator.pop(context, RecurringStopped(item.title, done));
    }
  }

  /// Restore, after its dialog; with a running relative, the swap dialog
  /// instead.
  Future<void> _restore(RecurringItem item, RecurringItem? relative) async {
    final l10n = AppLocalizations.of(context);
    final locale = dateLocaleOf(context);
    final preview = _page.restorePreview;
    if (preview == null) return;
    final today = _page.today;
    final next = preview.next;
    final endPassed = preview.endPassed;
    final name = recurringName(l10n, locale, item);
    final confirmed = await confirmAction(
      context,
      title: relative == null
          ? l10n.restoreRecurringTitle(item.title)
          : l10n.swapTitle(name),
      message: [
        if (relative != null)
          l10n.swapText(
            relative.paymentCount,
            recurringName(l10n, locale, relative),
          ),
        next == null
            ? l10n.restoreRecurringNoMore
            : l10n.restoreRecurringText(dayText(locale, next, today: today)),
        if (endPassed != null)
          l10n.restoreEndPassed(shortDateText(locale, parseDay(endPassed))),
      ].join('\n\n'),
      confirmLabel: relative == null ? l10n.restore : l10n.switchBack,
    );
    if (!confirmed || !mounted) return;
    String? restoredNext;
    var restored = false;
    await saveOrShowError(_messengerContext, () async {
      final outcome = await _page.restore();
      restored = outcome != null;
      restoredNext = outcome?.next;
    });
    if (restored && mounted) {
      Navigator.pop(
        context,
        relative == null
            ? RecurringRestored(item.title, restoredNext)
            : RecurringSwitchedBack(name),
      );
    }
  }

  Future<void> _delete(RecurringItem item) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.deleteForGoodTitle(item.title),
      message: l10n.deleteForGoodText(item.paymentCount),
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    var deleted = false;
    await saveOrShowError(
      _messengerContext,
      () async => deleted = await _page.delete() != null,
    );
    if (deleted && mounted) {
      Navigator.pop(context, RecurringDeleted(item.title, item.paymentCount));
    }
  }

  Future<void> _changePrice(RecurringItem item) async {
    final startOn = item.schedule?.startOn;
    if (startOn == null) return;
    final saved = await showChangePriceSheet(
      context,
      cubit: _page,
      currencyCode: item.currencyCode,
      startOn: startOn,
    );
    if (saved && mounted) {
      _showMessage(AppLocalizations.of(context).priceChanged);
    }
  }

  Future<void> _removePrice(String from) =>
      saveOrShowError(_messengerContext, () => _page.removePrice(from));

  Future<void> _edit() async {
    final result = await Navigator.push<RecurringFormResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringFormScreen(
          dependencies: widget.dependencies,
          itemId: _page.itemId,
        ),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case RecurringReplaced(:final newId, :final oldTitle):
        // How often changed: this item is archived, and this page shows the new
        // one, saying so (no Undo: restore the old one from the Archive). The
        // same route, so what the new page does later (Stop and its Undo) still
        // reaches the screen below; a pushReplacement would have answered that
        // screen already.
        final old = _cubit;
        setState(() => _cubit = _cubitFor(newId));
        await old?.close();
        if (mounted) {
          _showMessage(
            AppLocalizations.of(context).recurringArchivedShort(oldTitle),
          );
        }
      case RecurringEdited():
        await _page.load();
        if (mounted) {
          _showMessage(AppLocalizations.of(context).changesSaved);
        }
      case null:
        await _page.load();
    }
  }

  Future<void> _openPayment(int expenseId) async {
    final (:opened, :result) = await _opener.open(
      context,
      expenseId: expenseId,
    );
    if (!opened || !mounted) return;
    await _page.load();
    if (!mounted) return;
    showExpenseFormResult(
      _messenger.currentState,
      AppLocalizations.of(context),
      result,
      onUndoBin: (id) =>
          saveOrShowError(_messengerContext, () => _page.restoreExpense(id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalListener<RecurringDetailCubit, RecurringDetailState>(
      bloc: _page,
      listener: (context, state) {
        if (state is RecurringDetailGone) {
          // Deleted elsewhere meanwhile (a restore swapped the data, or
          // another page deleted it): nothing left to show.
          showMessage(ScaffoldMessenger.maybeOf(context), l10n.recurringGone);
          Navigator.pop(context);
        }
      },
      child: BlocSignalBuilder<RecurringDetailCubit, RecurringDetailState>(
        bloc: _page,
        builder: (context, state) => ScaffoldMessenger(
          key: _messenger,
          child: Scaffold(
            key: _scaffold,
            appBar: AppBar(
              title: Text(switch (state) {
                RecurringDetailLoaded(:final item) => item.title,
                _ => l10n.recurringTitle,
              }),
              actions: [
                if (state case RecurringDetailLoaded(:final item, :final busy)
                    when !item.isArchived && !item.isBroken)
                  IconButton(
                    key: const ValueKey('editRecurring'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.editRecurring,
                    onPressed: busy ? null : _edit,
                  ),
              ],
            ),
            body: switch (state) {
              RecurringDetailLoaded() => _loaded(state),
              RecurringDetailFailed() => LoadFailedView(onRetry: _page.load),
              RecurringDetailLoading() || RecurringDetailGone() => const Center(
                child: CircularProgressIndicator(),
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _loaded(RecurringDetailLoaded state) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = dateLocaleOf(context);
    final item = state.item;
    final schedule = item.schedule;
    final today = _page.today;
    final hold = item.hold;
    final price = item.price;
    final money = MoneyFormatter.of(context);
    final details = [
      if (state.category case final category?) categoryLabel(l10n, category),
      if (state.paymentMethod case final method?)
        paymentMethodLabel(l10n, method),
      for (final event in state.events) eventLabel(l10n, event),
    ].join(' · ');
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (item.isArchived)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Chip(
              avatar: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text(l10n.archivedBadge),
            ),
          ),
        if (state.generateFailed && !item.isArchived)
          _warning(l10n.recurringGenerateFailed),
        if (item.isBroken) _warning(l10n.recurringBroken),
        if (hold != null && !item.isArchived) ...[
          HoldCard(
            hold: hold,
            today: today,
            busy: state.busy,
            onAddAll: _addAll,
            onAddSelected: () => _addSelected(item),
            onSkip: _skipAll,
          ),
          const SizedBox(height: 16),
        ],
        Text(
          price == null ? '—' : money.format(price),
          style: theme.textTheme.headlineMedium,
        ),
        if (schedule != null) ...[
          Text(
            scheduleText(l10n, locale, schedule),
            key: const ValueKey('schedule'),
          ),
          const SizedBox(height: 4),
          Text(
            [
              // Held: the card says what is due; "Next: 9 Aug", two months
              // back, read wrong under it (Oppo).
              if (!item.isArchived && hold == null)
                nextText(l10n, locale, item.nextDueOn, today: today),
              endsText(l10n, locale, schedule.endOn),
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (details.isNotEmpty) ...[const SizedBox(height: 8), Text(details)],
        const SizedBox(height: 16),
        _actions(state),
        const SizedBox(height: 16),
        SectionHeading(l10n.recurringPrice),
        for (final point in state.prices.reversed)
          _priceRow(state, point, money, locale, today),
        const SizedBox(height: 16),
        SectionHeading(l10n.recurringPayments(item.paymentCount)),
        if (state.payments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.recurringNoPayments),
          ),
        for (final expense in state.payments) _paymentRow(state, expense),
        if (!state.showingAll && state.hasMorePayments)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('showAllPayments'),
              onPressed: _page.showAll,
              child: Text(l10n.showAll),
            ),
          ),
      ],
    );
  }

  Widget _warning(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }

  /// Change price and Stop; Restore and Delete for good when archived. A
  /// Wrap, so a large font puts them one under the other.
  Widget _actions(RecurringDetailLoaded state) {
    final l10n = AppLocalizations.of(context);
    final item = state.item;
    final busy = state.busy;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: item.isArchived
          ? [
              FilledButton.icon(
                key: const ValueKey('restoreRecurring'),
                onPressed: busy || item.isBroken
                    ? null
                    : () => _restore(item, state.relative),
                icon: const Icon(Icons.unarchive_outlined),
                label: Text(l10n.restore),
              ),
              OutlinedButton.icon(
                key: const ValueKey('deleteForGood'),
                onPressed: busy ? null : () => _delete(item),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.deleteForGood),
              ),
            ]
          : [
              FilledButton.tonalIcon(
                key: const ValueKey('changePrice'),
                onPressed: busy || item.isBroken
                    ? null
                    : () => _changePrice(item),
                icon: const Icon(Icons.sell_outlined),
                label: Text(l10n.changePrice),
              ),
              OutlinedButton.icon(
                key: const ValueKey('stopRecurring'),
                onPressed: busy ? null : () => _stop(item),
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(l10n.stop),
              ),
            ],
    );
  }

  Widget _priceRow(
    RecurringDetailLoaded state,
    PricePoint point,
    MoneyFormatter money,
    String locale,
    String today,
  ) {
    final l10n = AppLocalizations.of(context);
    final scheduled = point.from.compareTo(today) > 0;
    final removable =
        !state.item.isArchived &&
        canRemovePrice(state.prices, from: point.from, today: today);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        money.format(Money(point.amountMinor, state.item.currencyCode)),
      ),
      subtitle: Text(
        [
          l10n.priceFromDate(shortDateText(locale, parseDay(point.from))),
          if (scheduled) l10n.recurringScheduled,
        ].join(' · '),
      ),
      trailing: removable
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.removeScheduledPrice,
              onPressed: state.busy ? null : () => _removePrice(point.from),
            )
          : null,
    );
  }

  Widget _paymentRow(RecurringDetailLoaded state, Expense expense) {
    final locale = dateLocaleOf(context);
    return ExpenseTile(
      emoji: state.category?.emoji ?? ExpenseTile.missingEmoji,
      title: shortDateText(locale, parseDay(expense.occurredOn)),
      subtitle: timeText(locale, expense.wallClock),
      amount: expense.amount,
      contentPadding: EdgeInsets.zero,
      onTap: () => _openPayment(expense.id),
      marks: [?photoMark(context, expense.photoCount)],
    );
  }
}
