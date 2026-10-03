import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Asks "Delete '[name]'?" and returns true if the user confirmed.
/// [message] replaces the default "This can't be undone.".
Future<bool> confirmDelete(
  BuildContext context,
  String name, {
  String? message,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteConfirmTitle(name)),
      content: Text(message ?? l10n.deleteConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Asks [title] (with an optional [message]) and returns true if the user
/// tapped [confirmLabel]. Cancelling or dismissing returns false.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel ?? l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// "Discard changes?" with Discard / Keep editing. True means discard.
Future<bool> confirmDiscard(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return confirmAction(
    context,
    title: l10n.discardChangesTitle,
    confirmLabel: l10n.discard,
    cancelLabel: l10n.keepEditing,
  );
}
