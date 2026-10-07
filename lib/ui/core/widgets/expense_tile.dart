import 'package:material_ui/material_ui.dart';

import '../../../domain/models/money.dart';
import '../money_formatter.dart';

/// One expense in a list (Home, the bin): its category's emoji, its title,
/// a second line, and its amount, with an optional mark after the amount
/// (Home's unsaved-changes mark; later the photo and recurring badges).
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
    this.mark,
    this.contentPadding,
  });

  /// The category's emoji (`missingEmoji` when the category is gone).
  final String emoji;
  final String title;
  final String subtitle;
  final Money amount;
  final VoidCallback onTap;

  /// Shown right after the amount.
  final Widget? mark;

  /// The tile's side padding; the list's default when null.
  final EdgeInsetsGeometry? contentPadding;

  /// Shown when a row's category or payment method is missing. RESTRICT
  /// forbids that, but a crash would be worse than a question mark.
  static const missingEmoji = '❓';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = this.mark;
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
              if (mark != null)
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
