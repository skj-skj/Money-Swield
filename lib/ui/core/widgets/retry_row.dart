import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// "Couldn't load …" and a Try again button, stacked and centred: shown
/// where something failed to load (a page of the list, the trend card's
/// totals, a whole list in `LoadFailedView`).
class RetryRow extends StatelessWidget {
  const RetryRow({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
        ],
      ),
    );
  }
}
