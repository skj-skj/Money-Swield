/// Days, weeks, months and years over the stored `occurred_on` dates
/// (phase-5.md §5.1). Pure Dart.
///
/// Dates are `YYYY-MM-DD` strings. Arithmetic is on `DateTime.utc`
/// midnights, so a DST change can't move a date. The device's current zone
/// never re-dates a stored expense: only "today" ([todayOn]) uses it.
library;

/// How the Home list is grouped, and which period the trend card shows
/// (the card uses week, month and year only).
enum Period { day, week, month, year }

enum WeekStart { monday, sunday }

/// The earliest and latest dates an expense can have: the form's date
/// picker and a report's Range stop there (phase-8.md R12). Far from any
/// real date on purpose (P2-4: no real limit either way).
const firstExpenseDay = '1900-01-01';
const lastExpenseDay = '2200-01-01';

/// How weeks are named: "Oct Week 3" or "Week 41" (phase-5.md P5-10).
enum WeekLabel { month, number }

/// A period as inclusive local dates, `YYYY-MM-DD`. Its `from` is its key.
typedef PeriodRange = ({Period period, String from, String to});

/// The [period] that holds [day].
PeriodRange periodOf(String day, Period period, WeekStart weekStart) {
  final date = parseDay(day);
  final weekFrom = date.subtract(
    Duration(days: _daysIntoWeek(date, weekStart)),
  );
  final (DateTime from, DateTime to) = switch (period) {
    Period.day => (date, date),
    Period.week => (weekFrom, weekFrom.add(const Duration(days: 6))),
    Period.month => (
      DateTime.utc(date.year, date.month),
      DateTime.utc(date.year, date.month + 1, 0),
    ),
    Period.year => (DateTime.utc(date.year), DateTime.utc(date.year, 12, 31)),
  };
  return (period: period, from: isoDay(from), to: isoDay(to));
}

/// The period of the same kind just before [range].
PeriodRange previousPeriod(PeriodRange range, WeekStart weekStart) =>
    periodOf(addDays(range.from, -1), range.period, weekStart);

/// The card's next period when swiped up: week → month → year → week
/// (phase-5.md P5-29). Never [Period.day].
Period nextCardPeriod(Period p) => switch (p) {
  Period.day || Period.year => Period.week,
  Period.week => Period.month,
  Period.month => Period.year,
};

/// The other way round from [nextCardPeriod].
Period previousCardPeriod(Period p) => switch (p) {
  Period.day || Period.month => Period.week,
  Period.week => Period.year,
  Period.year => Period.month,
};

/// The card's period [steps] turns from [p]: positive up ([nextCardPeriod]),
/// negative down, wrapping, so 3 turns come back to [p] (a long or fast
/// swipe spins the card several faces, owner 2026-10-07).
Period cardPeriodAfter(Period p, int steps) {
  var period = p;
  for (var i = 0; i < steps.abs() % 3; i++) {
    period = steps > 0 ? nextCardPeriod(period) : previousCardPeriod(period);
  }
  return period;
}

/// The device-local date of [now], `YYYY-MM-DD`.
String todayOn(DateTime now) {
  final local = now.toLocal();
  return isoDay(DateTime.utc(local.year, local.month, local.day));
}

/// The local date `YYYY-MM-DD` of the moment [utc] on a clock
/// [utcOffsetMinutes] from UTC: how `occurred_on` is derived (database.md
/// §1), and how a recurring payment's moment is checked (phase-7a.md §5.6).
String localDayOf(DateTime utc, int utcOffsetMinutes) =>
    isoDay(utc.toUtc().add(Duration(minutes: utcOffsetMinutes)));

/// Every date of [range], in order.
List<String> daysIn(PeriodRange range) {
  final from = parseDay(range.from);
  final count = parseDay(range.to).difference(from).inDays + 1;
  return [for (var i = 0; i < count; i++) isoDay(from.add(Duration(days: i)))];
}

/// The year and month a week belongs to, its number in that year and in
/// that month. A week belongs to the year and month of its **4th day** (the
/// one that holds most of its days); with a Monday start this is ISO 8601
/// (phase-5.md §5.1).
({int year, int month, int number, int numberInMonth}) weekIdOf(
  PeriodRange week,
) {
  final fourth = parseDay(week.from).add(const Duration(days: 3));
  final dayOfYear = fourth.difference(DateTime.utc(fourth.year)).inDays + 1;
  return (
    year: fourth.year,
    month: fourth.month,
    number: (dayOfYear - 1) ~/ 7 + 1,
    numberInMonth: (fourth.day - 1) ~/ 7 + 1,
  );
}

/// [day] moved by [days] (negative for earlier).
String addDays(String day, int days) =>
    isoDay(parseDay(day).add(Duration(days: days)));

/// A stored date as a UTC midnight.
DateTime parseDay(String day) => DateTime.utc(
  int.parse(day.substring(0, 4)),
  int.parse(day.substring(5, 7)),
  int.parse(day.substring(8, 10)),
);

/// [date]'s year, month and day as `YYYY-MM-DD`.
String isoDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int _daysIntoWeek(DateTime date, WeekStart weekStart) => switch (weekStart) {
  // DateTime.weekday is 1 for Monday … 7 for Sunday.
  WeekStart.monday => date.weekday - 1,
  WeekStart.sunday => date.weekday % 7,
};
