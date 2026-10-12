import 'package:bloc_signals/bloc_signals.dart';

import '../../../../domain/expense_filter.dart';
import '../../emit_if_open.dart';

/// What the filter sheet edits (Home's, Reports' and Reports' Generate sheet
/// share it): a copy of the screen's filter and its payment methods (Reports
/// only; Home never sets them). The screen applies it when the sheet closes,
/// however it closes. What a screen adds above the fields (Home's grouping, the
/// Generate options) is that screen's own.
typedef FilterSheetValue = ({ExpenseFilter filter, Set<int> paymentMethodIds});

/// The filter sheet's own state. Nothing is applied while it is open: each
/// keystroke would rebuild the list behind it.
class FilterSheetCubit extends CubitSignal<FilterSheetValue>
    with EmitIfOpen<FilterSheetValue> {
  FilterSheetCubit({
    required ExpenseFilter filter,
    Set<int> paymentMethodIds = const {},
  }) : super(
         initialState: (filter: filter, paymentMethodIds: paymentMethodIds),
       );

  void setText(String text) => _emit(filter: value.filter.copyWith(text: text));

  void toggleCategory(int id) => _emit(
    filter: value.filter.copyWith(
      categoryIds: _toggled(value.filter.categoryIds, id),
    ),
  );

  void toggleEvent(int id) => _emit(
    filter: value.filter.copyWith(
      eventIds: _toggled(value.filter.eventIds, id),
    ),
  );

  /// A payment method (Reports' sheet).
  void togglePaymentMethod(int id) =>
      _emit(paymentMethodIds: _toggled(value.paymentMethodIds, id));

  /// Only recurring.
  void setOnlyRecurring(bool on) =>
      _emit(filter: value.filter.copyWith(onlyRecurring: on));

  /// Empties the text, categories, events, payment methods and Only
  /// recurring.
  void clear() => _emit(filter: ExpenseFilter.none, paymentMethodIds: const {});

  void _emit({ExpenseFilter? filter, Set<int>? paymentMethodIds}) {
    emitIfOpen((
      filter: filter ?? value.filter,
      paymentMethodIds: paymentMethodIds ?? value.paymentMethodIds,
    ));
  }

  static Set<int> _toggled(Set<int> ids, int id) =>
      ids.contains(id) ? ({...ids}..remove(id)) : {...ids, id};
}
