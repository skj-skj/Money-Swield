import 'package:material_ui/material_ui.dart';

/// A small heading above a section of a screen or sheet ("Categories",
/// "Group by", "Recent"), with an optional error under it (a required
/// picker left empty).
class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.text, {
    super.key,
    this.error,
    this.padding = const EdgeInsets.only(bottom: 8),
    this.accent = false,
  });

  final String text;
  final String? error;
  final EdgeInsetsGeometry padding;

  /// In the theme's primary colour, for headings inside a list (the
  /// currency sheet's Recent / All currencies).
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = this.error;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              color: accent ? theme.colorScheme.primary : null,
            ),
          ),
          if (error != null)
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
