import 'package:material_ui/material_ui.dart';

import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/item_labels.dart';

/// The bar above Home's list (phase-5.md §8.4): one chip per active filter,
/// each with ✕, then the grouping; on the right the filter icon, with a
/// dot while any filter is active. The chips scroll sideways when they
/// don't fit. Pinned in both card positions (P5-11).
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.filter,
    required this.grouping,
    required this.categories,
    required this.events,
    required this.onOpen,
    required this.onChange,
  });

  final ExpenseFilter filter;
  final Period grouping;
  final Map<int, Category> categories;
  final Map<int, Event> events;

  /// Opens the filter sheet.
  final VoidCallback onOpen;

  /// A chip's ✕ removed part of the filter.
  final ValueChanged<ExpenseFilter> onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = searchWords(filter.text).isEmpty ? null : filter.text.trim();
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (text != null)
                      _chip(
                        context,
                        key: const ValueKey('filterChipText'),
                        label: l10n.filterSearchChip(text),
                        onDeleted: () => onChange(filter.copyWith(text: '')),
                      ),
                    if (_namesOf(
                          filter.categoryIds,
                          categories,
                          (c) => (c.emoji, categoryName(l10n, c)),
                        )
                        case final names?)
                      _chip(
                        context,
                        key: const ValueKey('filterChipCategories'),
                        label: _label(l10n, names),
                        onDeleted: () =>
                            onChange(filter.copyWith(categoryIds: const {})),
                      ),
                    if (_namesOf(
                          filter.eventIds,
                          events,
                          (e) => (e.emoji, eventName(l10n, e)),
                        )
                        case final names?)
                      _chip(
                        context,
                        key: const ValueKey('filterChipEvents'),
                        label: _label(l10n, names),
                        onDeleted: () =>
                            onChange(filter.copyWith(eventIds: const {})),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        key: const ValueKey('groupingChip'),
                        label: Text(groupedByName(l10n, grouping)),
                        onPressed: onOpen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('filterButton'),
              tooltip: l10n.filters,
              onPressed: onOpen,
              icon: Badge(
                isLabelVisible: !filter.isEmpty,
                smallSize: 8,
                child: const Icon(Icons.tune),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required Key key,
    required String label,
    required VoidCallback onDeleted,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: InputChip(
      key: key,
      // Long names (a user's category) are cut, so the bar stays one row.
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      onDeleted: onDeleted,
      deleteButtonTooltipMessage: AppLocalizations.of(context).removeFilter,
      onPressed: onOpen,
    ),
  );

  /// The first name in name order and how many more: `🍽️ Food +2`.
  static String _label(AppLocalizations l10n, List<String> names) =>
      names.length == 1
      ? names.first
      : l10n.filterMore(names.first, names.length - 1);

  /// `🍽️ Food` for each of [ids] that still exists, in name order; null
  /// when none does.
  static List<String>? _namesOf<T>(
    Set<int> ids,
    Map<int, T> items,
    (String emoji, String name) Function(T) describe,
  ) {
    final found = [
      for (final id in ids)
        if (items[id] case final item?) describe(item),
    ]..sort((a, b) => compareNames(a.$2, b.$2));
    return found.isEmpty
        ? null
        : [for (final (emoji, name) in found) emojiLabel(emoji, name)];
  }
}

/// "By week" and the like, for the grouping chip.
String groupedByName(AppLocalizations l10n, Period grouping) =>
    switch (grouping) {
      Period.day => l10n.groupedByDay,
      Period.week => l10n.groupedByWeek,
      Period.month => l10n.groupedByMonth,
      Period.year => l10n.groupedByYear,
    };

/// "Day", "Week" and the like.
String periodName(AppLocalizations l10n, Period period) => switch (period) {
  Period.day => l10n.periodDay,
  Period.week => l10n.periodWeek,
  Period.month => l10n.periodMonth,
  Period.year => l10n.periodYear,
};
