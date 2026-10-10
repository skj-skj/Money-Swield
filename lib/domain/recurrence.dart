/// When a recurring item's payments fall (phase-7a.md §5.1). Pure Dart.
///
/// Dates are `YYYY-MM-DD` strings; arithmetic is on `DateTime.utc`
/// midnights ([parseDay]), so a DST change can't move a date (F9). Every
/// payment is computed from the start, never from the previous payment,
/// and clamped to the month's last day: a monthly item from 31 Jan falls on
/// 28 Feb, then on 31 Mar again (database.md §3.8).
library;

import 'dart:math' as math;

import 'periods.dart';

enum Frequency { daily, weekly, monthly, yearly }

/// The latest date anything repeats to: the date pickers' limit (F11).
/// Keeps every stored date a 4-digit year, which [parseDay] and comparing
/// dates as strings need. Payments after it are never computed.
const lastEndOn = '2200-12-31';

final DateTime _lastEnd = parseDay(lastEndOn);

/// A recurring item's rule. Dates are `YYYY-MM-DD`.
final class Schedule {
  const Schedule({
    required this.frequency,
    required this.interval,
    required this.startOn,
    this.endOn,
  });

  final Frequency frequency;

  /// Every [interval] days, weeks, months or years: 1 to 99.
  final int interval;

  /// The first payment, and the anchor day: the 31st stays the 31st.
  final String startOn;

  /// The last day a payment may fall on; null = no end (then [lastEndOn]).
  final String? endOn;

  @override
  bool operator ==(Object other) =>
      other is Schedule &&
      other.frequency == frequency &&
      other.interval == interval &&
      other.startOn == startOn &&
      other.endOn == endOn;

  @override
  int get hashCode => Object.hash(frequency, interval, startOn, endOn);

  @override
  String toString() =>
      'Schedule(${frequency.name} × $interval from $startOn'
      '${endOn == null ? '' : ' to $endOn'})';
}

/// The [k]-th payment (k = 0 is the start), computed from the start and
/// clamped to the month's last day. Not bounded by the end: callers that
/// need that use [occurrenceAfter] and friends.
String occurrenceAt(Schedule s, int k) => isoDay(_dateAt(s, k));

/// The [k]-th payment, or null when it falls after [lastEndOn]: "after 999
/// payments" yearly × 99 would be year 100828, which [parseDay] can't read
/// and which sorts before "2200" as text (phase-7b.md §5.1). Compared as
/// dates, never as strings. The end is not applied.
String? occurrenceWithinLimit(Schedule s, int k) {
  final date = _dateAt(s, k);
  return date.isAfter(_lastEnd) ? null : isoDay(date);
}

/// The last payment before the end, or null when [s] has no end (it runs to
/// [lastEndOn]) or none falls before it.
String? lastOccurrence(Schedule s) {
  final endOn = s.endOn;
  if (endOn == null) return null;
  final count = occurrencesThrough(s, endOn);
  return count == 0 ? null : occurrenceAt(s, count - 1);
}

/// The first payment strictly after [day], or null when it would fall
/// after the end (or after [lastEndOn]).
String? occurrenceAfter(Schedule s, String day) {
  final date = _dateAt(s, _indexAfter(s, parseDay(day)));
  return date.isAfter(_end(s)) ? null : isoDay(date);
}

/// The first payment on or after [day], or null past the end.
String? occurrenceOnOrAfter(Schedule s, String day) =>
    occurrenceAfter(s, addDays(day, -1));

/// How many payments fall from the start through [day] (and the end): 0
/// before the start.
int occurrencesThrough(Schedule s, String day) {
  final through = parseDay(day);
  final end = _end(s);
  return _indexAfter(s, through.isAfter(end) ? end : through);
}

/// The payments from [from] through [through], at most [limit], and the
/// payment after them (null past the end).
///
/// [from] should be a payment; one that isn't (a damaged cursor) is
/// moved to the first payment on or after it, so a date off the schedule
/// is never added. [from] after [through]: none due, and [from] is next.
({List<String> due, String? next}) dueDates(
  Schedule s, {
  required String from,
  required String through,
  int limit = 1000,
}) {
  final throughDate = parseDay(through);
  final due = <String>[];
  var next = occurrenceOnOrAfter(s, from);
  while (next != null &&
      due.length < limit &&
      !parseDay(next).isAfter(throughDate)) {
    due.add(next);
    next = occurrenceAfter(s, next);
  }
  return (due: due, next: next);
}

/// The last day a payment may fall on: the end, or [lastEndOn].
DateTime _end(Schedule s) {
  final endOn = s.endOn;
  if (endOn == null) return _lastEnd;
  final end = parseDay(endOn);
  return end.isAfter(_lastEnd) ? _lastEnd : end;
}

/// The smallest k with payment k after [day], from an estimate corrected
/// upwards, so a daily item from 1900 costs as little as one from today.
/// Payments strictly increase with k (the interval is at least 1).
int _indexAfter(Schedule s, DateTime day) {
  final start = parseDay(s.startOn);
  if (day.isBefore(start)) return 0;
  final n = s.interval;
  var k = switch (s.frequency) {
    // Exact: start + k·n days > day ⇔ k > (day − start) / n.
    Frequency.daily => day.difference(start).inDays ~/ n + 1,
    Frequency.weekly => day.difference(start).inDays ~/ (7 * n) + 1,
    // Payment k − 2 is in an earlier month (year) than [day], so no
    // smaller k can be after it.
    Frequency.monthly => math.max(
      0,
      ((day.year - start.year) * 12 + day.month - start.month) ~/ n - 1,
    ),
    Frequency.yearly => math.max(0, (day.year - start.year) ~/ n - 1),
  };
  while (!_dateAt(s, k).isAfter(day)) {
    k++;
  }
  return k;
}

DateTime _dateAt(Schedule s, int k) {
  if (k < 0) throw RangeError.value(k, 'k', 'must not be negative');
  final start = parseDay(s.startOn);
  final n = s.interval;
  return switch (s.frequency) {
    Frequency.daily => _plusDays(start, k * n),
    Frequency.weekly => _plusDays(start, 7 * k * n),
    Frequency.monthly => _clamped(start.year, start.month + k * n, start.day),
    Frequency.yearly => _clamped(start.year + k * n, start.month, start.day),
  };
}

/// UTC midnights have no DST, so adding whole days is exact.
DateTime _plusDays(DateTime date, int days) =>
    DateTime.utc(date.year, date.month, date.day + days);

/// [day] of [month] (which may run past 12) in [year], or that month's last
/// day when it is shorter: 31 → 30 or 28/29, 29 Feb → 28 Feb.
DateTime _clamped(int year, int month, int day) {
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, math.min(day, lastDay));
}
