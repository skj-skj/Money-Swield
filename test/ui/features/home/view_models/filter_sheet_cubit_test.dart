import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/ui/features/home/view_models/filter_sheet_cubit.dart';

void main() {
  FilterSheetCubit cubitFor(ExpenseFilter filter) {
    final cubit = FilterSheetCubit(filter: filter, grouping: Period.week);
    addTearDown(cubit.close);
    return cubit;
  }

  test('edits a copy: the filter it started from is unchanged', () {
    const start = ExpenseFilter(categoryIds: {1});
    final cubit = cubitFor(start)
      ..setText('lun')
      ..toggleCategory(2)
      ..toggleCategory(1)
      ..toggleEvent(7)
      ..setGrouping(Period.month);
    expect(
      cubit.value.filter,
      const ExpenseFilter(text: 'lun', categoryIds: {2}, eventIds: {7}),
    );
    expect(cubit.value.grouping, Period.month);
    expect(start.categoryIds, {1});
  });

  test('setOnlyRecurring (phase-7b.md §7.5); Clear empties text, '
      'categories, events and Only recurring; grouping stays', () {
    const filter = ExpenseFilter(text: 'x', categoryIds: {1}, eventIds: {2});
    final cubit = cubitFor(filter)
      ..setGrouping(Period.year)
      ..setOnlyRecurring(true);
    expect(cubit.value.filter, filter.copyWith(onlyRecurring: true));
    cubit.clear();
    expect(cubit.value.filter, ExpenseFilter.none);
    expect(cubit.value.grouping, Period.year);
  });
}
