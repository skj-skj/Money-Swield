import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'retry_row.dart';

/// The end of a paged list while its next page loads (a spinner) or after
/// that failed (Try again): Home's list, the Photos screen and the SMS
/// screen.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({
    super.key,
    required this.failed,
    required this.onRetry,
  });

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => failed
      ? RetryRow(
          message: AppLocalizations.of(context).loadMoreFailed,
          onRetry: onRetry,
        )
      : const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
}
