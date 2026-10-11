/// The dates a report covers (phase-8.md §5.1): a week, month or year
/// stepped with ‹ ›, or a custom Range (From, To, or All time). Pure Dart,
/// on `YYYY-MM-DD` strings like the rest of the domain (`periods.dart`).
library;

import 'periods.dart';

/// The period row's four choices.
enum ReportPeriod { week, month, year, range }

/// Why a From / To pair can't be shown. Not `RangeError`: dart:core has
/// one.
enum CustomRangeProblem { fromAfterTo, outOfBounds, malformed }

/// The dates a report covers, inclusive. [from] and [to] are null for All
/// time (a [ReportPeriod.range] only).
final class ReportRange {
  const ReportRange(this.period, String this.from, String this.to);

  const ReportRange.allTime()
    : period = ReportPeriod.range,
      from = null,
      to = null;

  final ReportPeriod period;
  final String? from;
  final String? to;

  bool get isAllTime => from == null;

  /// Whether [day] is inside: always for All time.
  bool contains(String day) =>
      isAllTime || (day.compareTo(from!) >= 0 && day.compareTo(to!) <= 0);

  @override
  bool operator ==(Object other) =>
      other is ReportRange &&
      other.period == period &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(period, from, to);

  @override
  String toString() => isAllTime
      ? 'ReportRange(all time)'
      : 'ReportRange(${period.name} $from..$to)';
}

/// The current week, month or year: the one that holds [today]. Future
/// days in it count (phase-5.md P5-13). Not for [ReportPeriod.range].
ReportRange currentRange(ReportPeriod period, String today, WeekStart ws) {
  final range = periodOf(today, _calendarPeriod(period), ws);
  return ReportRange(period, range.from, range.to);
}

/// [range] moved by [steps] weeks, months or years (negative: earlier).
/// Months and years are calendar ones (29 Feb in a leap year). A custom
/// range doesn't step: it comes back as it is.
ReportRange stepRange(ReportRange range, int steps, WeekStart ws) {
  if (range.period == ReportPeriod.range) return range;
  final from = parseDay(range.from!);
  final DateTime day = switch (range.period) {
    ReportPeriod.week => from.add(Duration(days: 7 * steps)),
    ReportPeriod.month => DateTime.utc(from.year, from.month + steps),
    _ => DateTime.utc(from.year + steps),
  };
  return currentRange(range.period, isoDay(day), ws);
}

/// Whether ‹ (negative) or › (positive) can move [range]: the stepped
/// range must still touch the days an expense can have
/// ([firstExpenseDay] … [lastExpenseDay], R12). False for a custom range.
bool canStep(ReportRange range, int steps, WeekStart ws) {
  if (range.period == ReportPeriod.range || steps == 0) return false;
  final next = stepRange(range, steps, ws);
  return next.to!.compareTo(firstExpenseDay) >= 0 &&
      next.from!.compareTo(lastExpenseDay) <= 0;
}

/// The Range dialog's first From / To: the last 12 whole months, this one
/// included (P8-4): on 10 Oct 2026, 1 Nov 2025 – 31 Oct 2026.
ReportRange defaultCustomRange(String today) {
  final date = parseDay(today);
  return ReportRange(
    ReportPeriod.range,
    isoDay(DateTime.utc(date.year, date.month - 11)),
    isoDay(DateTime.utc(date.year, date.month + 1, 0)),
  );
}

/// Null when [from] … [to] can be shown: both real dates inside the
/// bounds, [from] not after [to] (the same day is one day).
CustomRangeProblem? checkCustomRange(String from, String to) {
  if (!isValidDay(from) || !isValidDay(to)) return CustomRangeProblem.malformed;
  if (from.compareTo(firstExpenseDay) < 0 || to.compareTo(lastExpenseDay) > 0) {
    return CustomRangeProblem.outOfBounds;
  }
  if (from.compareTo(to) > 0) return CustomRangeProblem.fromAfterTo;
  return null;
}

/// Whether [range] holds [today]: a current week, month or year, which
/// follows today when the day changes (P8-25). Never All time.
bool holdsToday(ReportRange range, String today) =>
    !range.isAllTime && range.contains(today);

/// [range] as stored in `report_range` (§4): `all`, or `from..to`.
String encodeCustomRange(ReportRange range) =>
    range.isAllTime ? 'all' : '${range.from}..${range.to}';

/// A stored `report_range`, or null when it is missing or not a valid
/// range (malformed, From after To, out of bounds): the caller then uses
/// [defaultCustomRange].
ReportRange? decodeCustomRange(String? stored) {
  if (stored == null) return null;
  if (stored == 'all') return const ReportRange.allTime();
  final parts = stored.split('..');
  if (parts.length != 2) return null;
  final [from, to] = parts;
  if (checkCustomRange(from, to) != null) return null;
  return ReportRange(ReportPeriod.range, from, to);
}

/// Whether [day] is a real date written `YYYY-MM-DD` (not 2026-02-30).
bool isValidDay(String day) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return false;
  final month = int.parse(day.substring(5, 7));
  final date = int.parse(day.substring(8, 10));
  if (month < 1 || month > 12 || date < 1) return false;
  // parseDay rolls a day past the month's end over: it must come back.
  return isoDay(parseDay(day)) == day;
}

Period _calendarPeriod(ReportPeriod period) => switch (period) {
  ReportPeriod.week => Period.week,
  ReportPeriod.month => Period.month,
  ReportPeriod.year => Period.year,
  ReportPeriod.range => throw ArgumentError.value(
    period,
    'period',
    'a custom range has no current one',
  ),
};
