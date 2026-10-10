import 'package:material_ui/material_ui.dart';

import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/upcoming.dart' show upcomingFiltered;
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/item_labels.dart';
import '../view_models/expense_list_cubit.dart';

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
    this.photosIcon = FilteredScreenIcon.hidden,
    this.onPhotos,
    this.upcomingIcon = FilteredScreenIcon.hidden,
    this.onUpcoming,
  });

  final ExpenseFilter filter;
  final Period grouping;
  final Map<int, Category> categories;
  final Map<int, Event> events;

  /// Opens the filter sheet.
  final VoidCallback onOpen;

  /// A chip's ✕ removed part of the filter.
  final ValueChanged<ExpenseFilter> onChange;

  /// The photos icon left of the filter icon (phase-6.md §8.9, P6-36):
  /// hidden without photos, greyed out when the filters hide every one
  /// (P6-45).
  final FilteredScreenIcon photosIcon;

  /// Opens the Photos screen.
  final VoidCallback? onPhotos;

  /// The Upcoming payments icon left of the photos icon (phase-7b.md
  /// §8.3, P7b-7): hidden while no item runs, greyed when the filters hide
  /// every upcoming payment, with the filter dot, like the photos icon
  /// (owner, 2026-10-10: Upcoming follows the filters).
  final FilteredScreenIcon upcomingIcon;
  final VoidCallback? onUpcoming;

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
                    // First after the text chip (phase-7b.md §8.4).
                    if (filter.onlyRecurring)
                      _chip(
                        context,
                        key: const ValueKey('filterChipRecurring'),
                        label: l10n.filterChipRecurring,
                        onDeleted: () =>
                            onChange(filter.copyWith(onlyRecurring: false)),
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
            ?_screenIcon(
              key: const ValueKey('upcomingButton'),
              state: upcomingIcon,
              tooltip: l10n.upcomingTooltip,
              noneTooltip: l10n.noUpcomingMatchTooltip,
              icon: Icons.event_repeat_outlined,
              onPressed: onUpcoming,
              // Only recurring alone narrows nothing there.
              filtered: upcomingFiltered(filter),
            ),
            ?_screenIcon(
              key: const ValueKey('photosButton'),
              state: photosIcon,
              tooltip: l10n.photos,
              noneTooltip: l10n.noPhotosMatchTooltip,
              icon: Icons.photo_library_outlined,
              onPressed: onPhotos,
              filtered: !filter.isEmpty,
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

  /// An icon opening a screen that follows the filters: null when
  /// [state] is hidden, greyed (with [noneTooltip]) when the filters hide
  /// everything, and the filter icon's dot while [filtered] (a filter
  /// narrows that screen), since it shows only what the filters let
  /// through (owner, after the Oppo run; Upcoming too, owner 2026-10-10).
  IconButton? _screenIcon({
    required Key key,
    required FilteredScreenIcon state,
    required String tooltip,
    required String noneTooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool filtered,
  }) => switch (state) {
    FilteredScreenIcon.hidden => null,
    _ => IconButton(
      key: key,
      tooltip: state == FilteredScreenIcon.enabled ? tooltip : noneTooltip,
      onPressed: state == FilteredScreenIcon.enabled ? onPressed : null,
      icon: Badge(isLabelVisible: filtered, smallSize: 8, child: Icon(icon)),
    ),
  };

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
