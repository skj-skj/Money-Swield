import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'show_message.dart';

/// Runs [action] and returns true if it succeeded. If it throws, shows the
/// "Couldn't save" snackbar and returns false.
///
/// Used for writes started by a tap (a setting, a form save), where the
/// only useful reaction to a failure is telling the user and keeping the
/// screen as it was.
Future<bool> saveOrShowError(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context).saveFailed;
  try {
    await action();
    return true;
  } catch (error, stackTrace) {
    debugPrint('Save failed: $error\n$stackTrace');
    showMessage(messenger, message);
    return false;
  }
}
