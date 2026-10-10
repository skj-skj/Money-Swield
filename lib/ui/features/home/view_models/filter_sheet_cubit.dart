import 'package:bloc_signals/bloc_signals.dart';

import '../../../../domain/expense_filter.dart';
import '../../../../domain/periods.dart';
import '../../../core/emit_if_open.dart';

/// What the filter sheet edits: a copy of Home's filter and the list's
/// grouping. Home applies it when the sheet closes, however it closes
/// (phase-5.md §7.2, P5-18).
typedef FilterSheetValue = ({ExpenseFilter filter, Period grouping});

/// The filter sheet's own state (phase-5.md §7.2). Nothing is applied
/// while it is open: each keystroke would rebuild the list behind it.
class FilterSheetCubit extends CubitSignal<FilterSheetValue>
    with EmitIfOpen<FilterSheetValue> {
  FilterSheetCubit({required ExpenseFilter filter, required Period grouping})
    : super(initialState: (filter: filter, grouping: grouping));

  void setText(String text) =>
      _emit(value.filter.copyWith(text: text), value.grouping);

  void toggleCategory(int id) => _emit(
    value.filter.copyWith(categoryIds: _toggled(value.filter.categoryIds, id)),
    value.grouping,
  );

  void toggleEvent(int id) => _emit(
    value.filter.copyWith(eventIds: _toggled(value.filter.eventIds, id)),
    value.grouping,
  );

  void setGrouping(Period grouping) => _emit(value.filter, grouping);

  /// Only recurring (phase-7b.md §7.5).
  void setOnlyRecurring(bool on) =>
      _emit(value.filter.copyWith(onlyRecurring: on), value.grouping);

  /// Empties the text, categories, events and Only recurring; the grouping
  /// stays.
  void clear() => _emit(ExpenseFilter.none, value.grouping);

  void _emit(ExpenseFilter filter, Period grouping) {
    emitIfOpen((filter: filter, grouping: grouping));
  }

  static Set<int> _toggled(Set<int> ids, int id) =>
      ids.contains(id) ? ({...ids}..remove(id)) : {...ids, id};
}
