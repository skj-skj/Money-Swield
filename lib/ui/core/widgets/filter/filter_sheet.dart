import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../features/settings/view_models/settings_cubit.dart';
import '../../builtin_names.dart';
import '../../picker_order.dart';
import '../app_sheet.dart';
import '../back_guard.dart';
import '../section_heading.dart';
import '../tile_picker.dart';
import 'filter_sheet_cubit.dart';

/// Opens [FilterSheet] over a screen and returns what it holds when it closes,
/// however it closes: Show results, back, a swipe down or a tap outside, so
/// nothing typed is lost. Home adds its list grouping as [leading]; Reports
/// adds payment methods ([paymentMethods] not null), and its Generate sheet its
/// options and buttons ([leading], [actions]).
Future<FilterSheetValue> showFilterSheet(
  BuildContext context, {
  required ExpenseFilter filter,
  required Map<int, Category> categories,
  required Map<int, Event> events,
  Map<int, PaymentMethod>? paymentMethods,
  Set<int> paymentMethodIds = const {},
  WidgetBuilder? leading,
  List<Widget> Function(
    BuildContext context,
    FilterSheetValue value,
    VoidCallback? clear,
  )?
  actions,
}) async {
  // Closed by the sheet itself once it is gone: the future below
  // completes when the sheet starts closing, while it still shows.
  final cubit = FilterSheetCubit(
    filter: filter,
    paymentMethodIds: paymentMethodIds,
  );
  await showAppSheet<void>(
    context,
    builder: (_) => FilterSheet(
      cubit: cubit,
      categories: categories,
      events: events,
      paymentMethods: paymentMethods,
      leading: leading,
      actions: actions,
    ),
  );
  return cubit.value;
}

/// Which picker is in search mode, if any.
enum _Searching { none, categories, events, paymentMethods }

/// The filter's fields: the search, Only recurring, then categories and events
/// in the same tile pickers as the Add expense form, here both multi-select,
/// each with its own search and without New (owner, 2026-10-06), and on Reports
/// payment methods. One component for Home's filter sheet, Reports' and its
/// Generate sheet (owner, 2026-10-10): [leading] goes above the fields (Home's
/// grouping, the Generate options), [actions] at the bottom (by default Clear
/// and Show results).
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.cubit,
    required this.categories,
    required this.events,
    this.paymentMethods,
    this.leading,
    this.actions,
  });

  /// Closed by this widget when it goes away.
  final FilterSheetCubit cubit;
  final Map<int, Category> categories;
  final Map<int, Event> events;

  /// Reports' payment-method picker; null for none (Home).
  final Map<int, PaymentMethod>? paymentMethods;

  /// Above the fields: a screen's own options.
  final WidgetBuilder? leading;

  /// The buttons at the bottom; `clear` empties the fields. Null: Clear
  /// and Show results.
  final List<Widget> Function(
    BuildContext context,
    FilterSheetValue value,
    VoidCallback? clear,
  )?
  actions;

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

  /// Name order, archived events after the others (reports still count them).
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

  /// Name order, like the categories.
  List<PickerItem> _methodItems(
    AppLocalizations l10n,
    Map<int, PaymentMethod> methods,
  ) {
    final sorted = methods.values.toList()
      ..sort(
        (a, b) => compareNames(
          paymentMethodName(l10n, a),
          paymentMethodName(l10n, b),
        ),
      );
    return [
      for (final m in sorted)
        PickerItem(id: m.id, emoji: m.emoji, name: paymentMethodName(l10n, m)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<SettingsCubit>().value;
    final categoryItems = _categoryItems(l10n);
    final eventItems = _eventItems(l10n);
    final methods = widget.paymentMethods;
    final methodItems = methods == null ? null : _methodItems(l10n, methods);
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
            final clear =
                filter.isEmpty &&
                    filter.text.isEmpty &&
                    value.paymentMethodIds.isEmpty
                ? null
                : _clear;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (widget.leading case final leading?)
                        leading(context)
                      else
                        const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('filterSearch'),
                        controller: _search,
                        maxLength: maxSearchLength,
                        textInputAction: TextInputAction.search,
                        onChanged: widget.cubit.setText,
                        decoration: InputDecoration(
                          hintText: l10n.filterSearchHint,
                          prefixIcon: const Icon(Icons.search),
                          // No counter: the limit is generous.
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
                      // Under the search; shown even with no recurring item.
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
                      if (methodItems != null) ...[
                        const SizedBox(height: 16),
                        SectionHeading(l10n.reportFilterPaymentMethods),
                        TilePicker(
                          key: const ValueKey('filterPaymentMethods'),
                          items: methodItems,
                          selectedIds: value.paymentMethodIds,
                          multiSelect: true,
                          tileShape: settings.tileShape,
                          buttonShape: settings.buttonShape,
                          searching: _searching == _Searching.paymentMethods,
                          onSearchingChanged: (on) => _setSearching(
                            on ? _Searching.paymentMethods : _Searching.none,
                          ),
                          onTap: widget.cubit.togglePaymentMethod,
                          searchHint: l10n.searchPaymentMethods,
                          allTitle: l10n.allPaymentMethods,
                        ),
                      ],
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
                    children:
                        widget.actions?.call(context, value, clear) ??
                        [
                          TextButton(onPressed: clear, child: Text(l10n.clear)),
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
}
