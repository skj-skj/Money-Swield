import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/expense_filter.dart';
import 'package:money_swield/domain/report.dart';
import 'package:money_swield/domain/report_chart.dart';
import 'package:money_swield/domain/report_filter.dart';
import 'package:money_swield/domain/report_range.dart';

void main() {
  var nextId = 1;

  ReportRow row(int category, int amount, {Set<int> events = const {}}) =>
      ReportRow(
        id: nextId++,
        title: 't',
        amountMinor: amount,
        currencyCode: 'INR',
        occurredAtMs: 0,
        utcOffsetMinutes: 0,
        day: '2026-10-05',
        categoryId: category,
        paymentMethodId: 1,
        eventIds: events,
      );

  Report report(
    List<ReportRow> rows, {
    ReportFilter filter = ReportFilter.none,
    ReportGrouping grouping = ReportGrouping.byCategory,
  }) => buildReport(
    rows,
    range: const ReportRange.allTime(),
    filter: filter,
    grouping: grouping,
    defaultCurrency: 'INR',
  );

  List<ReportRow> groups(int n, {int Function(int i)? amount}) => [
    for (var i = 1; i <= n; i++) row(i, amount?.call(i) ?? i * 10),
  ];

  void fractionsAddUp(List<ChartSlice> slices) {
    final sum = slices.fold(0.0, (s, x) => s + x.ringFraction);
    expect(sum, closeTo(1, 1e-9));
  }

  test('0 groups → none; another currency → none', () {
    expect(chartSlices(report([]), 'INR'), isEmpty);
    expect(chartSlices(report(groups(3)), 'USD'), isEmpty);
  });

  test('1 group → one full ring at 100 %', () {
    final slices = chartSlices(report(groups(1)), 'INR');
    expect(slices.single.ringFraction, 1);
    expect(slices.single.sharePermille, 1000);
  });

  test('6 groups → 6 slices, no Other', () {
    final slices = chartSlices(report(groups(6)), 'INR');
    expect(slices.length, 6);
    expect(slices.any((s) => s.isOther), isFalse);
    fractionsAddUp(slices);
  });

  test('7 groups → 5 + Other with the 2 smallest', () {
    final slices = chartSlices(report(groups(7)), 'INR');
    expect(slices.length, 6);
    expect(slices.last.isOther, isTrue);
    expect(slices.last.others.length, 2);
    // Largest first: 20 then 10.
    expect(
      [for (final g in slices.last.others) g.byCurrency['INR']!.amount.toInt()],
      [20, 10],
    );
    expect(slices.last.amount, BigInt.from(30)); // 10 + 20
    expect(slices.first.amount, BigInt.from(70));
    fractionsAddUp(slices);
    // Shares of the total 280: 70 → 25.0 %.
    expect(slices.first.sharePermille, 250);
  });

  test('ringSweeps: 20 groups, 15 tiny → 5 + Other, none under 2°; '
      'every item of 200 still fits the ring', () {
    final rows = groups(20, amount: (i) => i <= 15 ? 1 : 1000000);
    final slices = chartSlices(report(rows), 'INR');
    expect(slices.length, 6);
    expect(slices.last.others.length, 15);
    fractionsAddUp(slices);
    final sweeps = ringSweeps([
      for (final s in slices) s.ringFraction,
    ], gapDegrees: 2);
    // Other (15 / 5,000,015 of the ring: 0.001°) gets the minimum.
    expect(sweeps.last, minSweepDegrees);
    expect(sweeps.fold(0.0, (a, b) => a + b) + 6 * 2, closeTo(360, 1e-9));
    // Others off with 200 items: 2° gaps and minimums can't all fit, so
    // both shrink; nothing negative, the ring still closes.
    final many = ringSweeps([
      0.9,
      for (var i = 0; i < 199; i++) 0.1 / 199,
    ], gapDegrees: 2);
    final gap = ringGap(200, 2);
    expect(gap, lessThan(2));
    expect(many.every((d) => d > 0), isTrue);
    expect(many.fold(0.0, (a, b) => a + b) + 200 * gap, closeTo(360, 1e-6));
    expect(ringSweeps([]), isEmpty);
    expect(ringSweeps([1]), [360]);
    // All zero (can't come from a report, but never NaN).
    expect(ringSweeps([0, 0]), [180, 180]);
  });

  test('events with overlap: ring 2 : 1, labels of the total', () {
    // Wedding ₹100, Birthday ₹50, one ₹30 row in both; total ₹120.
    final rows = [
      row(1, 70, events: {1}),
      row(1, 20, events: {2}),
      row(1, 30, events: {1, 2}),
    ];
    final r = report(
      rows,
      filter: const ReportFilter(base: ExpenseFilter(eventIds: {1, 2})),
      grouping: const ReportGrouping(
        GroupDimension.event,
        then: GroupDimension.category,
      ),
    );
    final slices = chartSlices(r, 'INR');
    expect(slices[0].ringFraction, closeTo(2 / 3, 1e-12));
    expect(slices[1].ringFraction, closeTo(1 / 3, 1e-12));
    expect(slices[0].sharePermille, 833);
    expect(slices[1].sharePermille, 417);
  });

  test('amounts past 2⁵³ still give exact-enough fractions', () {
    const big = 9223372036854775807;
    final slices = chartSlices(report([row(1, big), row(2, big)]), 'INR');
    expect(slices[0].ringFraction, closeTo(0.5, 1e-12));
    fractionsAddUp(slices);
  });

  test('regression: a currency whose total is 0 (only ₹0 payments) gives '
      'slices without shares instead of crashing', () {
    final slices = chartSlices(report([row(1, 0), row(2, 0)]), 'INR');
    expect(slices.length, 2);
    expect(slices.every((s) => s.sharePermille == null), isTrue);
    expect(slices.every((s) => s.ringFraction == 0), isTrue);
  });

  test('groupOthers off: every group its own slice', () {
    final r = report(groups(9));
    final all = slicesOf(
      r.groupsIn('INR'),
      'INR',
      r.totals['INR']!.amount,
      groupOthers: false,
    );
    expect(all.length, 9);
    expect(all.any((s) => s.isOther), isFalse);
    fractionsAddUp(all);
  });
}
