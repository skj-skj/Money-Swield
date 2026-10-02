import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Asks "Delete '[name]'?" and returns true if the user confirmed.
Future<bool> confirmDelete(BuildContext context, String name) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteConfirmTitle(name)),
      content: Text(l10n.deleteConfirmMessage),
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
