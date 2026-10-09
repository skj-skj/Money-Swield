import 'package:material_ui/material_ui.dart';

import '../../../app/app_dependencies.dart';
import '../../../domain/models/expense_draft.dart';
import '../../../domain/models/money.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/widgets/show_message.dart';
import 'view_models/expense_form_cubit.dart';
import 'views/expense_form_screen.dart';

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
/// The slot is read through [pendingDraft], the screen's cubit: a widget
/// doesn't read a repository.
class ExpenseFormOpener {
  ExpenseFormOpener({required this.dependencies, required this.pendingDraft});

  final AppDependencies dependencies;
  final Future<ExpenseDraft?> Function() pendingDraft;

  bool _opening = false;

  /// Opens Add (no [expenseId]; [chipAmount] from a chip) or Edit, and
  /// waits for the form to close. `opened` is false when the tap was
  /// ignored (another form is being opened).
  Future<({bool opened, ExpenseFormResult? result})> open(
    BuildContext context, {
    int? expenseId,
    Money? chipAmount,
  }) async {
    if (_opening) return (opened: false, result: null);
    _opening = true;
    final Future<ExpenseFormResult?> closed;
    try {
      final slot = await pendingDraft();
      if (!context.mounted) return (opened: false, result: null);
      final draft = slot?.editingExpenseId == expenseId ? slot : null;
      closed = Navigator.push<ExpenseFormResult>(
        context,
        MaterialPageRoute(
          builder: (_) => ExpenseFormScreen(
            dependencies: dependencies,
            expenseId: expenseId,
            draft: draft,
            chipAmount: chipAmount,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
    return (opened: true, result: await closed);
  }
}

/// What a closed form says, on the screen that opened it (after the pop,
/// on that screen's own messenger: phase-2.md §9.1): "Moved to bin" with
/// [onUndoBin], "This expense no longer exists", "Draft saved", or that a
/// save couldn't keep a photo. Nothing for a plain save or back.
void showExpenseFormResult(
  ScaffoldMessengerState? messenger,
  AppLocalizations l10n,
  ExpenseFormResult? result, {
  required void Function(int id) onUndoBin,
}) {
  switch (result) {
    case ExpenseSaved(:final photosNotKept) when photosNotKept > 0:
      showMessage(messenger, l10n.photosNotKept(photosNotKept), long: true);
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
