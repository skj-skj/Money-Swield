import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/expense_draft.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/confirm_dialog.dart';

/// Asks before an SMS card's form dismisses [draft]: **Cancel** (the default;
/// back is Cancel too) or
/// **Dismiss draft**, which deletes it for good (no Undo). An Edit
/// draft's message names the expense by the title it has in the draft;
/// the stored expense stays as it was. True when the user chose Dismiss
/// draft.
Future<bool> askDismissDraft(BuildContext context, ExpenseDraft draft) {
  final l10n = AppLocalizations.of(context);
  final title = draft.title.trim();
  return confirmAction(
    context,
    title: l10n.smsDraftTitle,
    message: draft.isAdd || title.isEmpty
        ? l10n.smsDraftMessage
        : l10n.smsEditDraftMessage(title),
    confirmLabel: l10n.smsDismissDraft,
  );
}
