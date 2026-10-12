/// The trend card's points: the **current** week (7 days), month (one point per
/// day) or year (12 months).
library;

import 'periods.dart';
import 'totals.dart';

/// One point of the chart: a day, or a month in Year.
typedef TrendPoint = ({String from, String to, BigInt amountMinor});

/// The points of [range] in [currency], from [rows]. Points with no rows
/// are 0, not missing; rows outside [range] and other currencies are
/// ignored.
List<TrendPoint> trendPoints(
  PeriodRange range,
  Iterable<AmountRow> rows,
  String currency,
) {
  final slots = _slots(range);
  final sums = List<BigInt>.filled(slots.length, BigInt.zero);
  for (final (day, code, minor) in rows) {
    if (code != currency) continue;
    if (day.compareTo(range.from) < 0 || day.compareTo(range.to) > 0) continue;
    final index = range.period == Period.year
        ? int.parse(day.substring(5, 7)) - 1
        : parseDay(day).difference(parseDay(range.from)).inDays;
    sums[index] += BigInt.from(minor);
  }
  return [
    for (final (i, (from, to)) in slots.indexed)
      (from: from, to: to, amountMinor: sums[i]),
  ];
}

/// [points] as a running total: each point holds its own amount plus every
/// point before it, so the last one is the period's total (the "Running
/// total" chart, owner 2026-10-06).
List<TrendPoint> runningTotals(List<TrendPoint> points) {
  var sum = BigInt.zero;
  return [
    for (final p in points)
      (from: p.from, to: p.to, amountMinor: sum += p.amountMinor),
  ];
}

/// The whole period's total per currency: every point added, future-dated rows
/// included.
CurrencyTotals periodTotals(PeriodRange range, Iterable<AmountRow> rows) =>
    sumRowsIn(rows, range.from, range.to);

/// The currency carousel's pages: the currencies with rows in the period,
/// [defaultCurrency] first, then by code. Empty when the period has no rows.
List<String> chartCurrencies(CurrencyTotals totals, String defaultCurrency) =>
    orderedCodes(totals.keys, defaultCurrency);

/// The page the carousel starts on: the default currency if it has rows,
/// else the first of [currencies], else the default.
String initialChartCurrency(List<String> currencies, String defaultCurrency) =>
    currencies.contains(defaultCurrency)
    ? defaultCurrency
    : currencies.firstOrNull ?? defaultCurrency;

/// Each point's amount ÷ the largest, in 0..1. Geometry, not money: it sets a
/// height in pixels and is never shown, stored or added. All 0 when the largest
/// is 0.
List<double> pointFractions(List<TrendPoint> points) {
  var largest = BigInt.zero;
  for (final p in points) {
    if (p.amountMinor > largest) largest = p.amountMinor;
  }
  if (largest == BigInt.zero) return List.filled(points.length, 0);
  final max = largest.toDouble();
  return [for (final p in points) p.amountMinor.toDouble() / max];
}

/// The point that holds [day], or null when [day] isn't in [points].
int? pointIndexOf(List<TrendPoint> points, String day) {
  for (final (i, p) in points.indexed) {
    if (day.compareTo(p.from) >= 0 && day.compareTo(p.to) <= 0) return i;
  }
  return null;
}

List<(String from, String to)> _slots(PeriodRange range) {
  if (range.period != Period.year) {
    return [for (final day in daysIn(range)) (day, day)];
  }
  final year = parseDay(range.from).year;
  return [
    for (var month = 1; month <= 12; month++)
      (
        isoDay(DateTime.utc(year, month)),
        isoDay(DateTime.utc(year, month + 1, 0)),
      ),
  ];
}
