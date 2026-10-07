import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/home_list.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';

/// phase-5.md §5.5. Moved from test/ui/features/home/views/home_list_test.
void main() {
  var nextId = 100;
  Expense on(String day, [String? title]) {
    final id = nextId--;
    return Expense(
      id: id,
      title: title ?? 'E$id',
      description: null,
      amount: const Money(100, 'INR'),
      amountExpression: null,
      occurredAt: DateTime.utc(2026),
      utcOffsetMinutes: 0,
      occurredOn: day,
      categoryId: 1,
      paymentMethodId: 1,
      eventIds: const {},
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      deletedAt: null,
    );
  }

  /// [expenses] as `from: day day …` per group.
  List<String> shape(
    List<Expense> expenses,
    Period grouping, {
    WeekStart start = WeekStart.monday,
    bool hasMore = false,
  }) => [
    for (final g in homeGroups(
      expenses,
      grouping: grouping,
      weekStart: start,
      hasMore: hasMore,
    ))
      '${g.range.from}:${[for (final d in g.days) '${d.day.substring(5)}×${d.expenses.length}'].join(' ')}${g.open ? ' open' : ''}',
  ];

  final rows = [
    on('2026-10-12'), // a future-dated row first, in its own week
    on('2026-10-05'),
    on('2026-10-05'),
    on('2026-10-04'),
    on('2026-09-28'),
    on('2026-09-27'),
    on('2025-12-31'),
  ];

  test('day groups: one per date, each once, in order', () {
    expect(shape(rows, Period.day), [
      '2026-10-12:10-12×1',
      '2026-10-05:10-05×2',
      '2026-10-04:10-04×1',
      '2026-09-28:09-28×1',
      '2026-09-27:09-27×1',
      '2025-12-31:12-31×1',
    ]);
  });

  test('week groups with their days, Monday and Sunday starts', () {
    expect(shape(rows, Period.week), [
      '2026-10-12:10-12×1',
      '2026-10-05:10-05×2',
      '2026-09-28:10-04×1 09-28×1',
      '2026-09-21:09-27×1',
      '2025-12-29:12-31×1',
    ]);
    expect(shape(rows, Period.week, start: WeekStart.sunday), [
      '2026-10-11:10-12×1',
      '2026-10-04:10-05×2 10-04×1',
      '2026-09-27:09-28×1 09-27×1',
      '2025-12-28:12-31×1',
    ]);
  });

  test('month and year groups', () {
    expect(shape(rows, Period.month), [
      '2026-10-01:10-12×1 10-05×2 10-04×1',
      '2026-09-01:09-28×1 09-27×1',
      '2025-12-01:12-31×1',
    ]);
    expect(shape(rows, Period.year), [
      '2026-01-01:10-12×1 10-05×2 10-04×1 09-28×1 09-27×1',
      '2025-01-01:12-31×1',
    ]);
  });

  test('the last group is open while more pages may follow', () {
    expect(
      shape(rows.take(3).toList(), Period.week, hasMore: true).last,
      '2026-10-05:10-05×2 open',
    );
    // The next page shows it ended: closed, and nothing is repeated.
    expect(shape(rows, Period.week, hasMore: false)[1], '2026-10-05:10-05×2');
  });

  test('no rows, no groups', () {
    expect(shape([], Period.week), isEmpty);
  });
}
