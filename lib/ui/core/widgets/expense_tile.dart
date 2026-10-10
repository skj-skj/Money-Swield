import 'package:material_ui/material_ui.dart';

import '../../../domain/models/money.dart';
import '../../../l10n/app_localizations.dart';
import '../money_formatter.dart';

/// One expense in a list (Home, the bin; also a recurring item in Manage →
/// Recurring): its category's emoji, its title, a second line, and its
/// amount, with marks after the amount (the repeat mark, the photo icon,
/// Home's unsaved-changes mark; phase-7a.md P7a-23).
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
    this.subtitleStyle,
  });

  /// The category's emoji (`missingEmoji` when the category is gone).
  final String emoji;
  final String title;
  final String subtitle;

  /// The second line's style; the list's default when null ("10 payments
  /// waiting" is in the error colour, phase-7a.md §8.3).
  final TextStyle? subtitleStyle;

  /// Null shows "—": a recurring item that can't be read has no price.
  final Money? amount;
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
      subtitle: Text(subtitle, style: subtitleStyle),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.45,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(switch (amount) {
                final Money amount => MoneyFormatter.of(context).format(amount),
                null => '—',
              }, style: theme.textTheme.titleMedium),
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

/// The repeat mark of a payment of a recurring item (phase-7a.md §8.7):
/// first among the marks (P7a-23), small and muted, read as "Repeats".
/// Null for a plain expense, and for one whose item was deleted for good.
Widget? repeatMark(BuildContext context, bool isRecurring) {
  if (!isRecurring) return null;
  return Icon(
    Icons.repeat,
    key: const ValueKey('repeatMark'),
    size: 16,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    semanticLabel: AppLocalizations.of(context).repeatsMark,
  );
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
