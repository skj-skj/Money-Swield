import 'package:material_ui/material_ui.dart';

import '../../../domain/models/money.dart';
import '../../../l10n/app_localizations.dart';
import '../money_formatter.dart';

/// One expense in a list (Home, the bin): its category's emoji, its title,
/// a second line, and its amount, with marks after the amount (the photo
/// icon, Home's unsaved-changes mark; later the recurring badge).
///
/// The amount takes at most 45 % of the row and is scaled down, never cut:
/// with a large font on a 360 dp phone a long amount would otherwise leave
/// the title no room at all (phase-5.md §12a).
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
    this.marks = const [],
    this.contentPadding,
  });

  /// The category's emoji (`missingEmoji` when the category is gone).
  final String emoji;
  final String title;
  final String subtitle;
  final Money amount;
  final VoidCallback onTap;

  /// Shown right after the amount, in order (phase-6.md R7).
  final List<Widget> marks;

  /// The tile's side padding; the list's default when null.
  final EdgeInsetsGeometry? contentPadding;

  /// Shown when a row's category or payment method is missing. RESTRICT
  /// forbids that, but a crash would be worse than a question mark.
  static const missingEmoji = '❓';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: contentPadding,
      leading: Text(emoji, style: const TextStyle(fontSize: 28)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.45,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                MoneyFormatter.of(context).format(amount),
                style: theme.textTheme.titleMedium,
              ),
              for (final mark in marks)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: mark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo mark of a row with [count] photos (phase-6.md §8.5): a small
/// muted icon, read as "3 photos". Null without photos.
Widget? photoMark(BuildContext context, int count) {
  if (count == 0) return null;
  return Icon(
    Icons.photo_outlined,
    key: const ValueKey('photoMark'),
    size: 16,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    semanticLabel: AppLocalizations.of(context).photosCount(count),
  );
}
