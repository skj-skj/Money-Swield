import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// A full-screen error with a copyable report and a retry button. Used when
/// the app can't start: a failed migration or a database that won't open.
class ErrorReportView extends StatelessWidget {
  const ErrorReportView({
    super.key,
    required this.title,
    required this.message,
    this.detail,
    required this.report,
    required this.onRetry,
  });

  final String title;
  final String message;

  /// A short line above the report, e.g. which migration failed.
  final String? detail;

  /// The plain-text report the user copies into a bug report.
  final String report;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final detail = this.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (detail != null) ...[
          const SizedBox(height: 16),
          Text(detail, style: theme.textTheme.titleSmall),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                report,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: report));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.reportCopied)));
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: Text(l10n.copyErrorReport),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
      ],
    );
  }
}
