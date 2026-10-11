import 'package:material_ui/material_ui.dart';

import '../../../app/app_dependencies.dart';
import '../../../domain/models/expense_draft.dart';
import '../../../domain/models/money.dart';
import '../../../domain/models/sms_suggestion.dart';
import '../../../domain/sms/sms_draft_rule.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/formatting_locale.dart';
import '../../core/recurrence_text.dart';
import '../../core/widgets/show_message.dart';
import 'view_models/expense_form_cubit.dart';
import 'views/expense_form_screen.dart';
import 'views/sms_draft_dialog.dart';

/// Opens the Add / Edit form the way every screen does (phase-6.md §8.9,
/// P6-39): Home and the Photos screen share it.
///
/// - The form starts from the draft slot when the slot holds a draft for
///   it (an Add draft for Add, this expense's Edit draft for Edit);
///   otherwise the slot is left alone until the form gets a change
///   (phase-4.md §7.4).
/// - Reading the slot is async, and taps in that gap would open a second
///   form (R12): every open is ignored until the current one is pushed.
///
/// - An SMS draft (phase-9a.md §7.3) is resumed only by its own card
///   ([openSms]) or a plain Add: a chip or Recurring → New opens a fresh
///   form instead, or a chip's amount or a Repeats Save would mark the SMS
///   with values it never had (P9a-43).
///
/// The slot is read through [pendingDraft], the screen's cubit: a widget
/// doesn't read a repository; [dismissDraft] empties it ([openSms]'s
/// Dismiss draft).
class ExpenseFormOpener {
  ExpenseFormOpener({
    required this.dependencies,
    required this.pendingDraft,
    this.dismissDraft,
    this.onOpenRecurring,
  });

  final AppDependencies dependencies;
  final Future<ExpenseDraft?> Function() pendingDraft;
  final Future<void> Function()? dismissDraft;

  /// Opens a recurring item's page from a payment's Edit (phase-7a.md
  /// §8.1 E).
  final void Function(BuildContext context, int itemId)? onOpenRecurring;

  bool _opening = false;

  /// Opens Add (no [expenseId]; [chipAmount] from a chip; Repeats on with
  /// [startRepeating]) or Edit, and waits for the form to close. `opened`
  /// is false when the tap was ignored (another form is being opened).
  Future<({bool opened, ExpenseFormResult? result})> open(
    BuildContext context, {
    int? expenseId,
    Money? chipAmount,
    bool startRepeating = false,
  }) async {
    if (_opening) return (opened: false, result: null);
    _opening = true;
    final Future<ExpenseFormResult?> closed;
    try {
      final slot = await pendingDraft();
      if (!context.mounted) return (opened: false, result: null);
      final ownDraft = slot?.editingExpenseId == expenseId ? slot : null;
      final fromSms = ownDraft?.sms != null;
      final draft = fromSms && (chipAmount != null || startRepeating)
          ? null
          : ownDraft;
      closed = _push(
        context,
        expenseId: expenseId,
        draft: draft,
        chipAmount: chipAmount,
        startRepeating: startRepeating,
      );
    } finally {
      _opening = false;
    }
    return (opened: true, result: await closed);
  }

  /// Opens the Add form from the SMS suggestion [sms] (phase-9a.md §7.3,
  /// §5.9, P9a-3): its own draft is resumed; with no draft a new form is
  /// filled from it; **any other draft is asked about first** (Cancel /
  /// Dismiss draft), so a draft is never replaced silently. Cancel (or
  /// back) leaves everything as it was: `opened` false.
  Future<({bool opened, ExpenseFormResult? result})> openSms(
    BuildContext context,
    SmsSuggestion sms,
  ) async {
    if (_opening) return (opened: false, result: null);
    _opening = true;
    final Future<ExpenseFormResult?> closed;
    try {
      final slot = await pendingDraft();
      if (!context.mounted) return (opened: false, result: null);
      switch (smsOpenRule(slot, sms.link)) {
        case SmsOpen.resume:
          closed = _push(context, draft: slot);
        case SmsOpen.fresh:
          closed = _push(context, sms: sms);
        case SmsOpen.ask:
          if (!await askDismissDraft(context, slot!) || !context.mounted) {
            return (opened: false, result: null);
          }
          await dismissDraft?.call();
          if (!context.mounted) return (opened: false, result: null);
          closed = _push(context, sms: sms);
      }
    } finally {
      _opening = false;
    }
    return (opened: true, result: await closed);
  }

  Future<ExpenseFormResult?> _push(
    BuildContext context, {
    int? expenseId,
    ExpenseDraft? draft,
    Money? chipAmount,
    bool startRepeating = false,
    SmsSuggestion? sms,
  }) => Navigator.push<ExpenseFormResult>(
    context,
    MaterialPageRoute(
      builder: (_) => ExpenseFormScreen(
        dependencies: dependencies,
        expenseId: expenseId,
        draft: draft,
        chipAmount: chipAmount,
        startRepeating: startRepeating,
        sms: sms,
        onOpenRecurring: onOpenRecurring,
      ),
    ),
  );
}

/// What a closed form says, on the screen that opened it (after the pop,
/// on that screen's own messenger: phase-2.md §9.1): "Moved to bin" with
/// [onUndoBin], "This expense no longer exists", "Draft saved", that a
/// save couldn't keep a photo, or what a Save with Repeats did
/// (phase-7a.md §8.9). Nothing for a plain save or back.
void showExpenseFormResult(
  ScaffoldMessengerState? messenger,
  AppLocalizations l10n,
  ExpenseFormResult? result, {
  required void Function(int id) onUndoBin,
}) {
  switch (result) {
    case ExpenseSaved(:final photosNotKept) when photosNotKept > 0:
      showMessage(messenger, l10n.photosNotKept(photosNotKept), long: true);
    case ExpenseSaved(:final pastAdded, :final updated) when pastAdded > 0:
      showMessage(
        messenger,
        updated
            ? l10n.updatedWithEarlier(pastAdded)
            : l10n.savedWithEarlier(pastAdded),
      );
    case ExpenseSaved(repeating: true, :final schedule?, :final updated)
        when messenger != null:
      final rule = scheduleText(
        l10n,
        dateLocaleOf(messenger.context),
        schedule,
      );
      showMessage(
        messenger,
        updated ? l10n.updatedRepeats(rule) : l10n.savedRepeats(rule),
      );
    case ExpenseBinned(:final id):
      showMessage(
        messenger,
        l10n.movedToBin,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => onUndoBin(id),
        ),
      );
    case ExpenseGone(:final draftKept):
      showMessage(
        messenger,
        draftKept ? l10n.draftKeptExpenseGone : l10n.expenseGone,
        long: draftKept,
      );
    case ExpenseDraftKept():
      showMessage(messenger, l10n.draftSaved);
    case ExpenseSaved() || null:
      break;
  }
}
