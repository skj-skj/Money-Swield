/// The Home list as a tree of groups and days (phase-5.md §5.5), so the UI
/// can build one sliver group per frame and per day and pin their headers.
library;

import 'models/expense.dart';
import 'periods.dart';

/// One frame of the list: a day, week, month or year.
final class ListGroup {
  const ListGroup({
    required this.range,
    required this.days,
    required this.open,
  });

  final PeriodRange range;

  /// Newest first.
  final List<ListDay> days;

  /// The last group while more pages may follow: the next page may add to
  /// it (and to its last day), so its frame has no bottom yet.
  final bool open;
}

/// One day inside a group.
final class ListDay {
  const ListDay({required this.day, required this.expenses});

  /// `occurred_on`.
  final String day;

  /// In list order (§4.1).
  final List<Expense> expenses;
}

/// [expenses], in list order (local date, then moment; §4.1), as groups
/// of [grouping] holding days. With that order dates never come back, so
/// each group and each day appears once.
List<ListGroup> homeGroups(
  List<Expense> expenses, {
  required Period grouping,
  required WeekStart weekStart,
  required bool hasMore,
}) {
  final groups = <ListGroup>[];
  PeriodRange? range;
  var days = <ListDay>[];
  var rows = <Expense>[];
  String? day;

  void endDay() {
    if (day != null) days.add(ListDay(day: day, expenses: rows));
    rows = [];
  }

  void endGroup({required bool open}) {
    endDay();
    if (range != null) {
      groups.add(ListGroup(range: range, days: days, open: open));
    }
    days = [];
  }

  for (final expense in expenses) {
    final on = expense.occurredOn;
    if (on != day) {
      final next = range;
      final inGroup =
          next != null &&
          on.compareTo(next.from) >= 0 &&
          on.compareTo(next.to) <= 0;
      if (inGroup) {
        endDay();
      } else {
        endGroup(open: false);
        range = periodOf(on, grouping, weekStart);
      }
      day = on;
    }
    rows.add(expense);
  }
  endGroup(open: hasMore);
  return groups;
}
