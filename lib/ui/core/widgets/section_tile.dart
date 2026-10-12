import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../formatting_locale.dart';

/// A tile that picks a section and shows how many items it has: an icon, the
/// count and the label, the chosen one filled (Recurring's Waiting · Active ·
/// Archive). Read by TalkBack as "Waiting, 3", selected or not. Sized for three
/// in a 360 dp row.
class SectionTile extends StatelessWidget {
  const SectionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.alert = false,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;

  /// The icon and count in the error colour (items waiting).
  final bool alert;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final countText = NumberFormat.decimalPattern(formattingLocaleOf(context))
        .format(count);
    final accent = alert
        ? scheme.error
        : selected
        ? scheme.onSecondaryContainer
        : scheme.primary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$label, $countText',
      excludeSemantics: true,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        color: selected ? scheme.secondaryContainer : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // A low rectangle: the icon and the count on one row, the label
          // under them (owner, 2026-10-09: the square tile with the icon
          // above the count left empty space and looked too big).
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scaled down, never cut or wrapped mid-word: three tiles
                // share a 360 dp row, up to font 2.0 ("Pendientes").
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: accent, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        countText,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: alert ? scheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(label, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
