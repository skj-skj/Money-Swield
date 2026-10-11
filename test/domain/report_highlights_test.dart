import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/report.dart';
import 'package:my_expense_tracker_app/domain/report_filter.dart';
import 'package:my_expense_tracker_app/domain/report_highlights.dart';
import 'package:my_expense_tracker_app/domain/report_range.dart';

/// The Highlights strip (owner, 2026-10-11).
void main() {
  var nextId = 1;
  ReportRow row(
    int amount, {
    String day = '2026-10-05',
    String code = 'INR',
    int method = 1,
    Set<int> events = const {},
  }) => ReportRow(
    id: nextId++,
    title: 't',
    amountMinor: amount,
    currencyCode: code,
    occurredAtMs: 0,
    utcOffsetMinutes: 0,
    day: day,
    categoryId: 1,
    paymentMethodId: method,
    eventIds: events,
  );

  const oct = ReportRange(ReportPeriod.month, '2026-10-01', '2026-10-31');
  const sep = ReportRange(ReportPeriod.month, '2026-09-01', '2026-09-30');

  Report report(List<ReportRow> rows, {ReportRange range = oct}) => buildReport(
    rows,
    range: range,
    filter: ReportFilter.none,
    grouping: ReportGrouping.byCategory,
    defaultCurrency: 'INR',
  );

  test('count, largest, top method and event; one currency only', () {
    final h = highlightsOf(
      report([
        row(100, method: 2, events: {7}),
        row(350, method: 1),
        row(300, method: 2, events: {7, 8}),
        row(9999, code: 'USD'),
      ]),
      'INR',
      '2026-10-10',
    )!;
    expect(h.count, 3);
    expect(h.largest!.amountMinor, 350);
    expect(h.topMethod, (
      key: const PaymentMethodKey(2),
      amount: BigInt.from(400),
    ));
    // A row in two events counts for both: 7 has 400, 8 has 300.
    expect(h.topEvent, (key: const EventKey(7), amount: BigInt.from(400)));
  });

  test('none in the currency → null; no events → no top event', () {
    expect(highlightsOf(report([row(1)]), 'USD', '2026-10-10'), isNull);
    expect(
      highlightsOf(report([row(1)]), 'INR', '2026-10-10')!.topEvent,
      isNull,
    );
  });

  test('per day: days up to today in a current range, integer maths', () {
    // ₹10.00 over 1–10 Oct: 10 days → ₹1.00.
    var h = highlightsOf(report([row(1000)]), 'INR', '2026-10-10')!;
    expect((h.days, h.perDay), (10, BigInt.from(100)));
    // A past month: all its days. 1000 / 30 = 33 (rounded down).
    h = highlightsOf(
      report([row(1000, day: '2026-09-02')], range: sep),
      'INR',
      '2026-10-10',
    )!;
    expect((h.days, h.perDay), (30, BigInt.from(33)));
    // A future month: all of it.
    h = highlightsOf(report([row(310)]), 'INR', '2026-09-20')!;
    expect(h.days, 31);
  });

  test('All time: first to last expense; one day → the total', () {
    final h = highlightsOf(
      report([
        row(100, day: '2026-01-01'),
        row(100, day: '2026-01-10'),
      ], range: const ReportRange.allTime()),
      'INR',
      '2026-10-10',
    )!;
    expect(h.days, 10);
    expect(h.perDay, BigInt.from(20));
    final one = highlightsOf(
      report([row(70)], range: const ReportRange.allTime()),
      'INR',
      '2026-10-10',
    )!;
    expect((one.days, one.perDay), (1, BigInt.from(70)));
  });

  test('ties: the earliest largest, the lower id', () {
    final first = row(500, method: 3);
    final h = highlightsOf(
      report([first, row(500, method: 2)]),
      'INR',
      '2026-10-10',
    )!;
    expect(h.largest!.id, first.id);
    expect(h.topMethod!.key, const PaymentMethodKey(2));
  });

  test('2⁶³ − 1 rows add up exactly', () {
    const max = 9223372036854775807;
    final h = highlightsOf(report([row(max), row(max)]), 'INR', '2026-10-01')!;
    expect(h.perDay, BigInt.from(max) * BigInt.two);
  });

  test('with events chosen, only those can be the top event (as the '
      'sections)', () {
    final r = buildReport(
      [
        row(100, events: {1, 2}),
        row(100, events: {3, 2}),
      ],
      range: oct,
      filter: const ReportFilter(base: ExpenseFilter(eventIds: {1, 3})),
      grouping: ReportGrouping.byCategory,
      defaultCurrency: 'INR',
    );
    final h = highlightsOf(r, 'INR', '2026-10-10')!;
    // Event 2 isn't chosen: it has 200, but 1 and 3 have 100 each.
    expect(h.topEvent, (key: const EventKey(1), amount: BigInt.from(100)));
  });
}
