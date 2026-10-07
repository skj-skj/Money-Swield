import 'package:material_ui/material_ui.dart';

/// What a screen shows in place of an empty list: an icon, a title, an
/// optional message and an optional button, centred. One look for every
/// empty screen (Home, the bin, the Manage lists, filters with no match).
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.scrollable = true,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// A button under the text, shown with [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  /// Centred, and scrolling when a large font needs more room than the
  /// screen has. False inside a scroll view already (Home's list), where a
  /// scroll view of its own can't be measured: then it sits at the top and
  /// is more compact (smaller icon, less space above and under it), so its
  /// button stays clear of the floating Add button at the bottom. At the
  /// largest font on the Oppo the looser spacing put it 7 dp under the
  /// button; the list's room under its end still lets it scroll clear.
  final bool scrollable;

  static const iconSize = 64.0;
  static const _compactIconSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = this.message;
    final actionLabel = this.actionLabel;
    final content = Padding(
      padding: scrollable
          ? const EdgeInsets.all(32)
          : const EdgeInsets.fromLTRB(32, 8, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: scrollable ? iconSize : _compactIconSize,
            color: theme.colorScheme.primary,
          ),
          SizedBox(height: scrollable ? 16 : 8),
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
    if (!scrollable) {
      return Align(alignment: Alignment.topCenter, child: content);
    }
    return Center(child: SingleChildScrollView(child: content));
  }
}
