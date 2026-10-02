import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// "Couldn't load this list." with a Try again button, centered. Shown in
/// place of a list whose loading failed.
class LoadFailedView extends StatelessWidget {
  const LoadFailedView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.loadFailed),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
        ],
      ),
    );
  }
}
