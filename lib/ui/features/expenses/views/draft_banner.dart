import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/days_ago.dart';

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
    final theme = Theme.of(context);
    final age = daysAgoText(l10n, savedAt, now);
    final onDiscard = this.onDiscard;
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4),
        child: Row(
          children: [
            Icon(
              Icons.edit_note,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  isEditing
                      ? l10n.draftRestoredEdit(age)
                      : l10n.draftRestoredAdd(age),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            if (onDiscard != null)
              TextButton(onPressed: onDiscard, child: Text(l10n.discardDraft)),
          ],
        ),
      ),
    );
  }
}
