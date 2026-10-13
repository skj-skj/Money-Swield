import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/expense_filter.dart';
import 'package:money_swield/ui/core/widgets/filter/filter_sheet_cubit.dart';

void main() {
  FilterSheetCubit cubitFor(ExpenseFilter filter) {
    final cubit = FilterSheetCubit(filter: filter);
    addTearDown(cubit.close);
    return cubit;
  }

  test('edits a copy: the filter it started from is unchanged', () {
    const start = ExpenseFilter(categoryIds: {1});
    final cubit = cubitFor(start)
      ..setText('lun')
      ..toggleCategory(2)
      ..toggleCategory(1)
      ..toggleEvent(7);
    expect(
      cubit.value.filter,
      const ExpenseFilter(text: 'lun', categoryIds: {2}, eventIds: {7}),
    );
    expect(start.categoryIds, {1});
  });

  test('setOnlyRecurring; Clear empties text, '
      'categories, events and Only recurring', () {
    const filter = ExpenseFilter(text: 'x', categoryIds: {1}, eventIds: {2});
    final cubit = cubitFor(filter)..setOnlyRecurring(true);
    expect(cubit.value.filter, filter.copyWith(onlyRecurring: true));
    cubit.clear();
    expect(cubit.value.filter, ExpenseFilter.none);
  });

  test('payment methods (Reports): toggled; Clear empties '
      'them too; Home never sets them', () {
    final cubit = cubitFor(ExpenseFilter.none)
      ..togglePaymentMethod(2)
      ..togglePaymentMethod(3)
      ..togglePaymentMethod(2);
    expect(cubit.value.paymentMethodIds, {3});
    cubit.clear();
    expect(cubit.value.paymentMethodIds, isEmpty);
    expect(cubitFor(ExpenseFilter.none).value.paymentMethodIds, isEmpty);
  });
}
