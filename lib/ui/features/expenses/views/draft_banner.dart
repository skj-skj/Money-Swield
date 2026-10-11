import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/days_ago.dart';
import '../../../core/widgets/form_banner.dart';

/// One line under the app bar when the form opened from the draft slot
/// (phase-4.md §7.4): "Unsaved expense restored (yesterday)". An Edit
/// draft also offers Discard draft.
class DraftBanner extends StatelessWidget {
  const DraftBanner({
    super.key,
    required this.isEditing,
    required this.savedAt,
    required this.now,
    this.onDiscard,
  });

  final bool isEditing;

  /// When the draft was last written.
  final DateTime savedAt;
  final DateTime now;

  /// Discard draft; only for an Edit draft.
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final age = daysAgoText(l10n, savedAt, now);
    final onDiscard = this.onDiscard;
    return FormBanner(
      icon: Icons.edit_note,
      text: isEditing
          ? l10n.draftRestoredEdit(age)
          : l10n.draftRestoredAdd(age),
      action: onDiscard == null
          ? null
          : TextButton(onPressed: onDiscard, child: Text(l10n.discardDraft)),
    );
  }
}
