import 'package:material_ui/material_ui.dart';

import 'confirm_dialog.dart';
import 'save_error.dart';

/// Asks [title] (with [message]) and, only if confirmed, runs [action]
/// with the "Couldn't save" handling of [saveOrShowError]. Returns true when
/// it was confirmed and succeeded, so the caller can close its screen.
///
/// One path for "are you sure?" writes (Restore default look, Restore
/// defaults, Empty bin, Delete permanently), so a confirmed write can't
/// skip the error handling.
Future<bool> confirmThenSave(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required Future<void> Function() action,
}) async {
  final confirmed = await confirmAction(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
  );
  if (!confirmed || !context.mounted) return false;
  return saveOrShowError(context, action);
}
