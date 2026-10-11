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
}) => [
  for (final group in framesByDay(
    expenses,
    dayOf: (e) => e.occurredOn,
    grouping: grouping,
    weekStart: weekStart,
    hasMore: hasMore,
  ))
    ListGroup(
      range: group.range,
      open: group.open,
      days: [
        for (final day in group.days)
          ListDay(day: day.day, expenses: day.items),
      ],
    ),
];

/// A frame of any dated rows: its period, its days (newest first, each
/// with its rows in the order given) and whether more pages may add to it.
typedef DayFrame<T> = ({
  PeriodRange range,
  List<({String day, List<T> items})> days,
  bool open,
});

/// [items], sorted newest day first ([dayOf] gives a row's `YYYY-MM-DD`),
/// cut into frames of [grouping] holding days: Home's list
/// ([homeGroups]), the Photos screen and the SMS screen share this cut.
/// The last frame (and its last day) stays `open` while
/// [hasMore].
List<DayFrame<T>> framesByDay<T>(
  List<T> items, {
  required String Function(T) dayOf,
  required Period grouping,
  required WeekStart weekStart,
  required bool hasMore,
}) {
  final frames = <DayFrame<T>>[];
  PeriodRange? range;
  var days = <({String day, List<T> items})>[];
  var rows = <T>[];
  String? day;

  void endDay() {
    if (day != null) days.add((day: day, items: rows));
    rows = [];
  }

  void endFrame({required bool open}) {
    endDay();
    if (range != null) frames.add((range: range, days: days, open: open));
    days = [];
  }

  for (final item in items) {
    final on = dayOf(item);
    if (on != day) {
      final current = range;
      final inFrame =
          current != null &&
          on.compareTo(current.from) >= 0 &&
          on.compareTo(current.to) <= 0;
      if (inFrame) {
        endDay();
      } else {
        endFrame(open: false);
        range = periodOf(on, grouping, weekStart);
      }
      day = on;
    }
    rows.add(item);
  }
  endFrame(open: hasMore);
  return frames;
}
