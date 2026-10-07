import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'retry_row.dart';

/// "Couldn't load this list." with a Try again button, centered. Shown in
/// place of a list whose loading failed.
class LoadFailedView extends StatelessWidget {
  const LoadFailedView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RetryRow(
        message: AppLocalizations.of(context).loadFailed,
        onRetry: onRetry,
      ),
    );
  }
}
