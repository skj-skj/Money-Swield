import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/recurrence_text.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/show_message.dart';
import 'recurring_detail_screen.dart';

/// What a recurring item's page pops with, for the screen below to say
/// (phase-7a.md §8.9): on that screen's own messenger, like the expense
/// form's results.
sealed class RecurringPageResult {
  const RecurringPageResult(this.title);

  final String title;
}

/// Stop: "Netflix stopped and archived." with Undo.
final class RecurringStopped extends RecurringPageResult {
  const RecurringStopped(super.title, this.undo);

  final ArchiveUndo undo;
}

/// Restore: "Netflix restored. Next: 9 Nov".
final class RecurringRestored extends RecurringPageResult {
  const RecurringRestored(super.title, this.next);

  final String? next;
}

/// Restore with the swap (phase-7b.md §8.1 D): "Switched back to Netflix ·
/// Every month". No Undo: restoring the other one switches again. [title]
/// is the item named with its rule.
final class RecurringSwitchedBack extends RecurringPageResult {
  const RecurringSwitchedBack(super.title);
}

/// Delete for good: "Netflix deleted. Its 12 payments stay."
final class RecurringDeleted extends RecurringPageResult {
  const RecurringDeleted(super.title, this.payments);

  final int payments;
}

/// Opens item [id]'s page and waits for it to close.
Future<RecurringPageResult?> openRecurringPage(
  BuildContext context,
  AppDependencies dependencies,
  int id,
) => Navigator.push<RecurringPageResult>(
  context,
  MaterialPageRoute(
    builder: (_) =>
        RecurringDetailScreen(dependencies: dependencies, itemId: id),
  ),
);

/// A payment's Edit → its link row → the item's page (§8.1 E): what the
/// page did is said on the form, which is still open ([formContext] is
/// under its messenger). Home and the Photos screen open the form.
Future<void> openRecurringFromForm(
  BuildContext formContext,
  AppDependencies dependencies,
  int id,
) async {
  final result = await openRecurringPage(formContext, dependencies, id);
  if (!formContext.mounted) return;
  showRecurringPageResult(
    ScaffoldMessenger.maybeOf(formContext),
    AppLocalizations.of(formContext),
    dateLocaleOf(formContext),
    result,
    today: todayOn(dependencies.now()),
    onUndoStop: (undo) => undoStopOrSay(
      formContext,
      () => dependencies.recurring.undoArchive(undo),
    ),
  );
}

/// Undo of Stop from its "… stopped and archived." message: runs [undo]
/// (true when the item runs again). Refused (restored or deleted since, or
/// another item of its bill runs now: never two for one bill), it says
/// so rather than nothing; a failure says "Couldn't save".
Future<void> undoStopOrSay(
  BuildContext context,
  Future<bool> Function() undo,
) async {
  // The screen that showed the message may have closed since.
  if (!context.mounted) {
    await undo();
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  final refused = AppLocalizations.of(context).undoStopRefused;
  var done = true;
  await saveOrShowError(context, () async => done = await undo());
  if (!done) showMessage(messenger, refused);
}

/// Says what [result] did on [messenger]; Stop's Undo runs [onUndoStop].
void showRecurringPageResult(
  ScaffoldMessengerState? messenger,
  AppLocalizations l10n,
  String locale,
  RecurringPageResult? result, {
  required String today,
  required void Function(ArchiveUndo undo) onUndoStop,
}) {
  switch (result) {
    case RecurringStopped(:final title, :final undo):
      showMessage(
        messenger,
        l10n.recurringStopped(title),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => onUndoStop(undo),
        ),
      );
    case RecurringRestored(:final title, :final next?):
      showMessage(
        messenger,
        l10n.recurringRestored(title, dayText(locale, next, today: today)),
      );
    case RecurringRestored(:final title):
      showMessage(messenger, l10n.recurringRestoredNoNext(title));
    case RecurringSwitchedBack(:final title):
      showMessage(messenger, l10n.switchedBack(title));
    case RecurringDeleted(:final title, :final payments):
      showMessage(messenger, l10n.recurringDeleted(title, payments));
    case null:
      break;
  }
}
