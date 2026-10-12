import 'package:material_ui/material_ui.dart';

/// One line under a form's app bar on the secondary container colour: an icon,
/// a text and an optional action. The draft banner and the "From SMS" banner
/// are this.
class FormBanner extends StatelessWidget {
  const FormBanner({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;

  /// A button at the end, e.g. Discard draft.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = this.action;
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
