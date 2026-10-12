import 'dart:math' as math;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/expense_draft_repository.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../../../domain/amount_expression.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/currency.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/expense_draft.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/recurring_plan.dart';
import '../../../../domain/recurring_price.dart';
import '../../../core/emit_if_open.dart';

sealed class RecurringDetailState {
  const RecurringDetailState();
}

final class RecurringDetailLoading extends RecurringDetailState {
  const RecurringDetailLoading();
}

final class RecurringDetailFailed extends RecurringDetailState {
  const RecurringDetailFailed(this.error);

  final Object error;
}

/// The item was deleted meanwhile: the page says so and closes.
final class RecurringDetailGone extends RecurringDetailState {
  const RecurringDetailGone();
}

final class RecurringDetailLoaded extends RecurringDetailState {
  const RecurringDetailLoaded({
    required this.item,
    required this.prices,
    required this.payments,
    required this.hasMorePayments,
    required this.category,
    required this.paymentMethod,
    required this.events,
    this.showingAll = false,
    this.busy = false,
    this.generateFailed = false,
    this.relative,
  });

  final RecurringItem item;

  /// Oldest first.
  final List<PricePoint> prices;

  /// Active payments, newest due first: the last 5, or every page read so
  /// far after Show all.
  final List<Expense> payments;
  final bool hasMorePayments;
  final Category? category;
  final PaymentMethod? paymentMethod;
  final List<Event> events;
  final bool showingAll;

  /// Add all, Skip them, Stop, Restore or Delete is running: their buttons
  /// are off (a double tap does it once).
  final bool busy;

  /// The last generator run couldn't add its payments.
  final bool generateFailed;

  /// An archived item's running relative: Restore swaps it out, after the swap
  /// dialog. Null for a running item.
  final RecurringItem? relative;

  RecurringDetailLoaded copyWith({
    List<Expense>? payments,
    bool? hasMorePayments,
    bool? showingAll,
    bool? busy,
  }) => RecurringDetailLoaded(
    item: item,
    prices: prices,
    payments: payments ?? this.payments,
    hasMorePayments: hasMorePayments ?? this.hasMorePayments,
    category: category,
    paymentMethod: paymentMethod,
    events: events,
    showingAll: showingAll ?? this.showingAll,
    busy: busy ?? this.busy,
    generateFailed: generateFailed,
    relative: relative,
  );
}

/// What a new price typed in the Change price sheet would do.
sealed class PriceCheck {
  const PriceCheck();
}

/// The amount can't be saved yet.
final class PriceAmountInvalid extends PriceCheck {
  const PriceAmountInvalid(this.error);

  final ExpressionError error;
}

/// The date is refused: before the start, or a price there is in force.
final class PriceDateRefused extends PriceCheck {
  const PriceDateRefused(this.change);

  final PriceChange change;
}

/// Saving is fine: a new price, or [replaces] the scheduled one there.
final class PriceOk extends PriceCheck {
  const PriceOk(this.amountMinor, {this.replaces});

  final int amountMinor;
  final int? replaces;
}

/// [text] (the amount field as typed) from [from], for an item with [prices]
/// starting on [startOn] in [currencyCode], on [today]: the form's evaluator,
/// the currency's digits, above 0.
PriceCheck checkPrice({
  required String text,
  required String from,
  required List<PricePoint> prices,
  required String startOn,
  required String currencyCode,
  required String today,
  required String decimalSeparator,
}) {
  final result = evaluateField(
    text,
    minorDigits: findCurrency(currencyCode)?.minorDigits ?? 2,
    decimalSeparator: decimalSeparator,
  );
  switch (result) {
    case ExpressionRejected(:final error):
      return PriceAmountInvalid(error);
    case ExpressionValue(:final amountMinor):
      final change = priceChangeFor(
        prices,
        startOn: startOn,
        from: from,
        today: today,
      );
      return switch (change) {
        PriceChange.beforeStart ||
        PriceChange.inForce => PriceDateRefused(change),
        PriceChange.add => PriceOk(amountMinor),
        PriceChange.replace => PriceOk(
          amountMinor,
          replaces: prices.firstWhere((p) => p.from == from).amountMinor,
        ),
      };
  }
}

/// A recurring item's page.
class RecurringDetailCubit extends CubitSignal<RecurringDetailState>
    with EmitIfOpen<RecurringDetailState> {
  RecurringDetailCubit({
    required this.itemId,
    required this._recurring,
    required this._expenses,
    required this._categories,
    required this._paymentMethods,
    required this._events,
    required this._drafts,
    this.decimalSeparator = '.',
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(initialState: const RecurringDetailLoading());

  final int itemId;
  final RecurringRepository _recurring;
  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final PaymentMethodRepository _paymentMethods;
  final EventRepository _events;
  final ExpenseDraftRepository _drafts;
  final String decimalSeparator;
  final DateTime Function() _now;

  /// How many payments the page lists before Show all.
  static const firstPayments = 5;
  static const pageSize = 30;

  String get today => todayOn(_now());

  RecurringDetailLoaded? get _loaded => switch (value) {
    final RecurringDetailLoaded loaded => loaded,
    _ => null,
  };

  Future<void> load() async {
    try {
      final item = await _recurring.byId(itemId);
      if (item == null) {
        emitIfOpen(const RecurringDetailGone());
        return;
      }
      final showingAll = _loaded?.showingAll ?? false;
      final limit = showingAll
          ? math.max(pageSize, _loaded?.payments.length ?? 0)
          : firstPayments;
      final payments = await _recurring.payments(itemId, limit: limit);
      final events = {for (final e in await _events.all()) e.id: e};
      emitIfOpen(
        RecurringDetailLoaded(
          item: item,
          prices: await _recurring.prices(itemId),
          payments: payments,
          hasMorePayments: showingAll
              ? payments.length == limit
              : item.paymentCount > payments.length,
          category: (await _categories.all())
              .where((c) => c.id == item.categoryId)
              .firstOrNull,
          paymentMethod: (await _paymentMethods.all())
              .where((m) => m.id == item.paymentMethodId)
              .firstOrNull,
          events: [for (final id in item.eventIds) ?events[id]],
          showingAll: showingAll,
          generateFailed: _recurring.lastFailed.contains(itemId),
          relative: item.isArchived
              ? await _recurring.runningRelative(itemId)
              : null,
        ),
      );
    } catch (error) {
      if (_loaded == null) emitIfOpen(RecurringDetailFailed(error));
    }
  }

  /// Show all: every payment, a page at a time.
  Future<void> showAll() async {
    final loaded = _loaded;
    if (loaded == null || loaded.showingAll) return;
    emitIfOpen(loaded.copyWith(showingAll: true));
    await loadMorePayments();
  }

  bool _loadingMore = false;

  /// The next page after the payments shown (after Show all).
  Future<void> loadMorePayments() async {
    final loaded = _loaded;
    if (loaded == null || _loadingMore) return;
    _loadingMore = true;
    try {
      final before = loaded.payments.lastOrNull?.recurringDueOn;
      final page = await _recurring.payments(
        itemId,
        before: before,
        limit: pageSize,
      );
      final current = _loaded;
      if (current == null) return;
      emitIfOpen(
        current.copyWith(
          payments: [...current.payments, ...page],
          hasMorePayments: page.length == pageSize,
        ),
      );
    } catch (error) {
      debugPrint('Reading more payments failed: $error');
    } finally {
      _loadingMore = false;
    }
  }

  /// Runs [action] once at a time (a double tap does it once), then reads
  /// the page again unless [reload] is false. Null when one was already
  /// running. Rethrows a failed write; the screen says "Couldn't save".
  Future<T?> _busy<T>(Future<T> Function() action, {bool reload = true}) async {
    final loaded = _loaded;
    if (loaded == null || loaded.busy) return null;
    emitIfOpen(loaded.copyWith(busy: true));
    var done = false;
    try {
      final result = await action();
      done = true;
      return result;
    } finally {
      final current = _loaded;
      if (current != null) emitIfOpen(current.copyWith(busy: false));
      if (reload || !done) await load();
    }
  }

  /// **Add all** on the hold card: up to 1,000 now. Returns how many
  /// were added.
  Future<int?> addAll() async => (await _busy(
    () => _recurring.generateDue(onlyId: itemId, confirmed: true),
  ))?.added;

  /// The held dates for the Add selected sheet: skips left out, at most 1,000,
  /// with the cursor and day they were read at. Null when nothing is held any
  /// more.
  Future<HeldDates?> heldDates() => _recurring.heldDates(itemId);

  /// **Add selected**: the [ticked] dates added, the other listed ones
  /// skipped for good. [held] is [heldDates]'s: refused if the item moved on
  /// meanwhile (the page reloads). Busy-guarded.
  Future<SelectedOutcome?> addSelected(
    Set<String> ticked, {
    required HeldDates held,
  }) => _busy(() => _recurring.addSelected(itemId, ticked, held: held));

  /// **Skip them**: every payment before today is skipped.
  Future<SkipOutcome?> skipAll() => _busy(() => _recurring.skipBacklog(itemId));

  /// **Stop**: to the Archive; the page closes with Undo.
  Future<ArchiveUndo?> stop() => _busy(() => _recurring.archive(itemId));

  /// The archived item back in the list, from the Archive. With a running
  /// relative, it is swapped out in the same write (always, after the screen's
  /// dialog). A relative that changed since the page read it is refused by the
  /// repository; the page reads again.
  Future<RestoreOutcome?> restore() {
    final swapOut = _loaded?.relative?.id;
    return _busy(() => _recurring.restore(itemId, swapOut: swapOut));
  }

  /// Delete for good (archived only). True when deleted. Not read again after:
  /// the item is gone and the page closes with its own message; a reload would
  /// say "no longer exists" and close the page a second time.
  Future<bool?> delete() => _busy(() async {
    await _recurring.delete(itemId);
    return true;
  }, reload: false);

  /// What Restore will do, for its dialog: the first payment it adds, and the
  /// end that passed and is cleared. The rule [RecurringRepository.restore]
  /// writes ([planRestore]).
  ({String? next, String? endPassed})? get restorePreview {
    final item = _loaded?.item;
    final schedule = item?.schedule;
    if (item == null || schedule == null) return null;
    final (schedule: _, :endPassed, :next) = planRestore(
      schedule,
      cursor: item.nextDueOn,
      today: today,
    );
    return (next: next, endPassed: endPassed);
  }

  /// What a new price would do, live, for the sheet.
  PriceCheck? checkNewPrice(String text, String from) {
    final loaded = _loaded;
    if (loaded == null) return null;
    return checkPrice(
      text: text,
      from: from,
      prices: loaded.prices,
      startOn: loaded.item.schedule?.startOn ?? from,
      currencyCode: loaded.item.currencyCode,
      today: today,
      decimalSeparator: decimalSeparator,
    );
  }

  /// Saves a new price. Returns false when it isn't valid (the sheet shows
  /// why); rethrows a failed write.
  Future<bool> changePrice(String text, String from) async {
    final check = checkNewPrice(text, from);
    if (check is! PriceOk) return false;
    await _recurring.changePrice(
      itemId,
      amountMinor: check.amountMinor,
      from: from,
    );
    await load();
    return true;
  }

  /// The date a price change starts from by default: the next payment; never a
  /// past date (a held item's cursor can be months back), nor before the start.
  String get defaultPriceFrom {
    final item = _loaded?.item;
    final today = this.today;
    final start = item?.schedule?.startOn;
    return [
      today,
      ?item?.nextDueOn,
      ?start,
    ].reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
  }

  Future<void> removePrice(String from) async {
    await _recurring.removePrice(itemId, from);
    await load();
  }

  /// Undo of "Moved to bin" for a payment opened from this page.
  Future<void> restoreExpense(int expenseId) async {
    await _expenses.restore(expenseId);
    await load();
  }

  /// The draft slot, for opening a payment.
  Future<ExpenseDraft?> pendingDraft() => _drafts.read();
}
