/// The Highlights strip under the report card (owner, 2026-10-11): a few
/// facts of the report in the card's currency. No comparisons with other
/// periods (P8-23). Pure Dart, `BigInt` sums of `int` minor units.
library;

import 'periods.dart';
import 'report.dart';

/// A group and its sum in the currency.
typedef TopGroup = ({GroupKey key, BigInt amount});

final class ReportHighlights {
  const ReportHighlights({
    required this.count,
    required this.days,
    required this.perDay,
    required this.largest,
    required this.topMethod,
    required this.topEvent,
  });

  /// Expenses in the currency.
  final int count;

  /// The days the average is over (see [highlightsOf]).
  final int days;

  /// The total ÷ [days], rounded down to a minor unit: integer maths.
  final BigInt perDay;

  /// The single largest expense (ties: the earliest).
  final ReportRow? largest;

  /// The payment method with the largest sum (ties: the lower id).
  final TopGroup? topMethod;

  /// The event with the largest sum (ties: the lower id); null when no
  /// expense has an event. A row in two events counts for both. With
  /// events chosen in the filter, only those count (as the sections,
  /// `keysOf`): another event a row also has isn't "top" of this report.
  final TopGroup? topEvent;
}

/// The highlights of [report] in [currency], [today] being the device's
/// date. The average counts the days of the range up to today (a current
/// month on the 10th: 10 days, not 31: future days would dilute it), the
/// whole range when it's over or all in the future, and for All time the
/// days from the first to the last expense. Null without rows in
/// [currency].
ReportHighlights? highlightsOf(Report report, String currency, String today) {
  final rows = [
    for (final row in report.rows)
      if (row.currencyCode == currency) row,
  ];
  if (rows.isEmpty) return null;
  var total = BigInt.zero;
  ReportRow? largest;
  final methods = <int, BigInt>{};
  final events = <int, BigInt>{};
  final chosen = report.filter.base.eventIds;
  for (final row in rows) {
    final amount = BigInt.from(row.amountMinor);
    total += amount;
    if (largest == null || row.amountMinor > largest.amountMinor) {
      largest = row;
    }
    methods[row.paymentMethodId] =
        (methods[row.paymentMethodId] ?? BigInt.zero) + amount;
    for (final key in keysOf(row, GroupDimension.event, chosen)) {
      if (key case EventKey(:final id)) {
        events[id] = (events[id] ?? BigInt.zero) + amount;
      }
    }
  }
  final days = averageDays(report, today);
  return ReportHighlights(
    count: rows.length,
    days: days,
    perDay: total ~/ BigInt.from(days),
    largest: largest,
    topMethod: _top(methods, PaymentMethodKey.new),
    topEvent: _top(events, EventKey.new),
  );
}

/// The days [highlightsOf]'s average is over; at least 1.
int averageDays(Report report, String today) {
  final range = report.range;
  final String from;
  final String to;
  if (range.isAllTime) {
    final span = report.span;
    if (span == null) return 1;
    (from, to) = (span.first, span.last);
  } else {
    from = range.from!;
    to = range.contains(today) ? today : range.to!;
  }
  final days = parseDay(to).difference(parseDay(from)).inDays + 1;
  return days < 1 ? 1 : days;
}

TopGroup? _top(Map<int, BigInt> sums, GroupKey Function(int) key) {
  int? best;
  for (final MapEntry(key: id, value: amount) in sums.entries) {
    if (best == null ||
        amount > sums[best]! ||
        (amount == sums[best]! && id < best)) {
      best = id;
    }
  }
  return best == null ? null : (key: key(best), amount: sums[best]!);
}
