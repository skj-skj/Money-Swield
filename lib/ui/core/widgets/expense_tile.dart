import 'package:material_ui/material_ui.dart';

import '../../../domain/models/money.dart';
import '../../../l10n/app_localizations.dart';
import '../money_formatter.dart';

/// One expense in a list (Home, the bin; also a recurring item in Manage →
/// Recurring): its category's emoji, its title, a second line, and its amount,
/// with marks after the amount (the repeat mark, the photo icon, Home's
/// unsaved-changes mark).
///
/// The amount takes at most 45 % of the row and is scaled down, never cut: with
/// a large font on a 360 dp phone a long amount would otherwise leave the title
/// no room at all.
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
    this.action,
    this.muted = false,
    this.semanticsLabel,
    this.titleMaxLines = 1,
  });

  /// What TalkBack reads for the row, in place of its texts ("Netflix,
  /// ₹649, 9 November"); null reads the texts.
  final String? semanticsLabel;

  /// 1 on Home (the row keeps its height); 2 on Upcoming, whose button left
  /// "Swim…" at the largest font.
  final int titleMaxLines;

  /// The category's emoji (`missingEmoji` when the category is gone).
  final String emoji;
  final String title;
  final String subtitle;

  /// The second line's style; the list's default when null ("10 payments
  /// waiting" is in the error colour).
  final TextStyle? subtitleStyle;

  /// Null shows "—": a recurring item that can't be read has no price.
  final Money? amount;
  final VoidCallback onTap;

  /// Shown right after the amount, in order.
  final List<Widget> marks;

  /// The tile's side padding; the list's default when null.
  final EdgeInsetsGeometry? contentPadding;

  /// A button after the amount, outside its scaling (Upcoming's Skip and Bring
  /// back).
  final Widget? action;

  /// Greyed: a payment skipped once.
  final bool muted;

  /// Shown when a row's category or payment method is missing. RESTRICT
  /// forbids that, but a crash would be worse than a question mark.
  static const missingEmoji = '❓';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Half the text colour: onSurfaceVariant alone read as white in the
    // dark theme on the Oppo, so a skipped row didn't look skipped.
    final faint = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final amountView = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.45,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              switch (amount) {
                final Money amount => MoneyFormatter.of(context).format(amount),
                null => '—',
              },
              // Struck through when muted: this payment won't be made.
              style: theme.textTheme.titleMedium?.copyWith(
                color: muted ? faint : null,
                decoration: muted ? TextDecoration.lineThrough : null,
                decorationColor: muted ? faint : null,
              ),
            ),
            for (final mark in marks)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: mark,
              ),
          ],
        ),
      ),
    );
    final tile = ListTile(
      onTap: onTap,
      contentPadding: contentPadding,
      leading: Opacity(
        opacity: muted ? 0.5 : 1,
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
      title: Text(
        title,
        maxLines: titleMaxLines,
        overflow: TextOverflow.ellipsis,
        style: muted ? TextStyle(color: faint) : null,
      ),
      // No second line when there is nothing to say: an empty one only
      // made the row taller.
      subtitle: subtitle.isEmpty ? null : Text(subtitle, style: subtitleStyle),
      trailing: amountView,
    );
    final label = semanticsLabel;
    final row = label == null
        ? tile
        : Semantics(
            container: true,
            button: true,
            label: label,
            excludeSemantics: true,
            onTap: onTap,
            child: tile,
          );
    final action = this.action;
    if (action == null) return row;
    // Beside the tile, not inside it: its own button for TalkBack, and
    // outside the amount's scaling.
    return Row(
      children: [
        Expanded(child: row),
        action,
      ],
    );
  }
}

/// The repeat mark of a payment of a recurring item: first among the marks,
/// small and muted, read as "Repeats". Null for a plain expense, and for one
/// whose item was deleted for good.
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

/// The photo mark of a row with [count] photos: a small muted icon, read as "3
/// photos". Null without photos.
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
