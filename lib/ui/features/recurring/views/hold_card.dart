import 'package:material_ui/material_ui.dart';

import '../../../../domain/recurring_plan.dart';
import '../../../../domain/repeat_input.dart' show maxPastPayments;
import '../../../../l10n/app_localizations.dart';
import '../../../core/formatting_locale.dart';
import 'recurring_texts.dart';

/// The question a held backlog asks on its page (phase-7a.md §8.6): "⚠ 10
/// payments are due, 3 Aug – 5 Oct." with **Add all 10**, **Add selected**
/// (phase-7b.md §8.1 E) and **Skip them**. No confirm: the card is the
/// question. While one runs, a progress ring and the buttons off.
class HoldCard extends StatelessWidget {
  const HoldCard({
    super.key,
    required this.hold,
    required this.today,
    required this.busy,
    required this.onAddAll,
    required this.onAddSelected,
    required this.onSkip,
  });

  final HoldPayments hold;
  final String today;
  final bool busy;
  final VoidCallback onAddAll;

  /// Opens the sheet to tick the ones to add.
  final VoidCallback onAddSelected;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tooMany = hold.count > maxPastPayments;
    return Card(
      key: const ValueKey('holdCard'),
      // Not errorContainer: dark red with pink buttons was loud and hard to
      // read in the dark theme (Oppo, §12a). The icon carries the warning.
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    holdText(l10n, dateLocaleOf(context), hold, today: today),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // A Wrap: three buttons take two lines at 360 dp (phase-7b.md
            // §8.2), and at a large font they go one under the other.
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (busy)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                OutlinedButton(
                  key: const ValueKey('skipThem'),
                  onPressed: busy ? null : onSkip,
                  child: Text(l10n.skipThem),
                ),
                OutlinedButton(
                  key: const ValueKey('addSelected'),
                  onPressed: busy ? null : onAddSelected,
                  child: Text(l10n.addSelected),
                ),
                FilledButton(
                  key: const ValueKey('addAll'),
                  onPressed: busy ? null : onAddAll,
                  child: Text(
                    tooMany
                        ? l10n.addFirstN(maxPastPayments)
                        : l10n.addAllN(hold.count),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
