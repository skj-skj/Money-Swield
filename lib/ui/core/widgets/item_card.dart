import 'package:material_ui/material_ui.dart';

/// A category, event or payment method as a card in a `TwoColumnMasonry`
/// grid: emoji, name (up to 2 lines) and description (up to 3 lines), each
/// cut with "…" when longer. Its height follows its content.
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.emoji,
    required this.title,
    this.description,
    this.badge,
    this.selected = false,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String? description;

  /// A short label in the top corner, e.g. "Default".
  final String? badge;

  /// Shows a check mark, for cards picked in a multi-select list.
  final bool selected;

  final VoidCallback onTap;

  static const titleMaxLines = 2;
  static const descriptionMaxLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = this.description;
    final badge = this.badge;
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? theme.colorScheme.secondaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const Spacer(),
                  if (badge != null) _Badge(label: badge),
                  if (selected)
                    Icon(Icons.check_circle, color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: descriptionMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain label, deliberately not a Chip: it isn't tappable, so it
/// shouldn't look like a button.
class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: colors.onSecondaryContainer),
        ),
      ),
    );
  }
}
