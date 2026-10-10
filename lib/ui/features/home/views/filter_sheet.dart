import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/picker_order.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/back_guard.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/tile_picker.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/filter_sheet_cubit.dart';
import 'filter_bar.dart';

/// Opens the filter sheet over Home and returns what it holds when it
/// closes, however it closes: Show results, back, a swipe down or a tap
/// outside (phase-5.md §8.4, P5-18), so nothing typed is lost.
Future<FilterSheetValue> showFilterSheet(
  BuildContext context, {
  required ExpenseFilter filter,
  required Period grouping,
  required Map<int, Category> categories,
  required Map<int, Event> events,
}) async {
  // Closed by the sheet itself once it is gone: the future below
  // completes when the sheet starts closing, while it still shows.
  final cubit = FilterSheetCubit(filter: filter, grouping: grouping);
  await showAppSheet<void>(
    context,
    builder: (_) =>
        FilterSheet(cubit: cubit, categories: categories, events: events),
  );
  return cubit.value;
}

/// Which picker is in search mode, if any.
enum _Searching { none, categories, events }

/// The grouping first, then the search, then categories and events in the
/// same tile pickers as the Add expense form, here both multi-select, each
/// with its own search and without New (owner, 2026-10-06; phase-5.md
/// §8.4).
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.cubit,
    required this.categories,
    required this.events,
  });

  /// Closed by this widget when it goes away.
  final FilterSheetCubit cubit;
  final Map<int, Category> categories;
  final Map<int, Event> events;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final _search = TextEditingController(
    text: widget.cubit.value.filter.text,
  );

  var _searching = _Searching.none;

  @override
  void dispose() {
    _search.dispose();
    widget.cubit.close();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    widget.cubit.clear();
  }

  void _setSearching(_Searching searching) =>
      setState(() => _searching = searching);

  /// Name order, like Manage.
  List<PickerItem> _categoryItems(AppLocalizations l10n) {
    final categories = widget.categories.values.toList()
      ..sort(
        (a, b) => compareNames(categoryName(l10n, a), categoryName(l10n, b)),
      );
    return [
      for (final c in categories)
        PickerItem(id: c.id, emoji: c.emoji, name: categoryName(l10n, c)),
    ];
  }

  /// Name order, archived events after the others (reports still count
  /// them, A10).
  List<PickerItem> _eventItems(AppLocalizations l10n) {
    final events = widget.events.values.toList()
      ..sort((a, b) {
        if (a.isArchived != b.isArchived) return a.isArchived ? 1 : -1;
        return compareNames(eventName(l10n, a), eventName(l10n, b));
      });
    return [
      for (final e in events)
        PickerItem(id: e.id, emoji: e.emoji, name: eventName(l10n, e)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<SettingsCubit>().value;
    final categoryItems = _categoryItems(l10n);
    final eventItems = _eventItems(l10n);
    return BackGuard(
      // Back closes a picker's search first, then the sheet.
      intercept: _searching != _Searching.none,
      onBack: () => _setSearching(_Searching.none),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: BlocSignalBuilder<FilterSheetCubit, FilterSheetValue>(
          bloc: widget.cubit,
          builder: (context, value) {
            final filter = value.filter;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      SectionHeading(l10n.groupBy),
                      _groupBy(l10n, value.grouping),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('filterSearch'),
                        controller: _search,
                        maxLength: maxSearchLength,
                        textInputAction: TextInputAction.search,
                        onChanged: widget.cubit.setText,
                        decoration: InputDecoration(
                          hintText: l10n.filterSearchHint,
                          prefixIcon: const Icon(Icons.search),
                          // No counter: the limit is generous (P5-19).
                          counterText: '',
                          border: const OutlineInputBorder(),
                          suffixIcon: filter.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: l10n.clear,
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _search.clear();
                                    widget.cubit.setText('');
                                  },
                                ),
                        ),
                      ),
                      // Under the search (phase-7b.md §8.4); shown even
                      // with no recurring item.
                      SwitchListTile(
                        key: const ValueKey('filterOnlyRecurring'),
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.repeat),
                        title: Text(l10n.onlyRecurring),
                        value: filter.onlyRecurring,
                        onChanged: widget.cubit.setOnlyRecurring,
                      ),
                      const SizedBox(height: 8),
                      SectionHeading(l10n.filterCategories),
                      TilePicker(
                        key: const ValueKey('filterCategories'),
                        items: categoryItems,
                        selectedIds: filter.categoryIds,
                        multiSelect: true,
                        tileShape: settings.tileShape,
                        buttonShape: settings.buttonShape,
                        searching: _searching == _Searching.categories,
                        onSearchingChanged: (on) => _setSearching(
                          on ? _Searching.categories : _Searching.none,
                        ),
                        onTap: widget.cubit.toggleCategory,
                        searchHint: l10n.searchCategories,
                        allTitle: l10n.allCategories,
                        emptyText: l10n.noCategoriesYet,
                      ),
                      const SizedBox(height: 16),
                      SectionHeading(l10n.filterEvents),
                      TilePicker(
                        key: const ValueKey('filterEvents'),
                        items: eventItems,
                        selectedIds: filter.eventIds,
                        multiSelect: true,
                        tileShape: settings.tileShape,
                        buttonShape: settings.buttonShape,
                        searching: _searching == _Searching.events,
                        onSearchingChanged: (on) => _setSearching(
                          on ? _Searching.events : _Searching.none,
                        ),
                        onTap: widget.cubit.toggleEvent,
                        searchHint: l10n.searchEvents,
                        allTitle: l10n.allEvents,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: filter.isEmpty && filter.text.isEmpty
                            ? null
                            : _clear,
                        child: Text(l10n.clear),
                      ),
                      FilledButton(
                        key: const ValueKey('showResults'),
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.showResults),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _groupBy(AppLocalizations l10n, Period grouping) =>
      SegmentedButton<Period>(
        key: const ValueKey('groupBy'),
        showSelectedIcon: false,
        segments: [
          for (final p in Period.values)
            ButtonSegment(
              value: p,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(periodName(l10n, p)),
              ),
            ),
        ],
        selected: {grouping},
        onSelectionChanged: (selection) =>
            widget.cubit.setGrouping(selection.single),
      );
}
