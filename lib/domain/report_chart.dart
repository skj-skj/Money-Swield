/// The report card's slices: the first level's largest groups in one currency,
/// the rest in Other. The donut and the bars draw the same slices, in the same
/// colours (by position).
library;

import 'dart:math' as math;

import 'report.dart';

/// 5 groups and Other at most (dataviz: ≤ 6 segments).
const maxSlices = 6;

/// No slice is drawn thinner than this, in degrees, so a tiny group still
/// shows. Geometry only: its label keeps its real share.
const minSweepDegrees = 2.0;

/// One slice of a chart.
final class ChartSlice {
  const ChartSlice({
    required this.group,
    required this.amount,
    required this.count,
    required this.sharePermille,
    required this.ringFraction,
    this.others = const [],
  });

  /// The group, or null for Other.
  final ReportGroup? group;

  bool get isOther => group == null;

  final BigInt amount;

  /// Its rows in the currency (Other: of its groups, a row in two of them
  /// counted in each).
  final int count;

  /// Of the whole the chart shows (with overlap, shares can add up past 100 %).
  /// Null when that whole is 0 (only ₹0 payments).
  final int? sharePermille;

  /// Of the slices' sum, 0..1, for the ring's geometry only.
  final double ringFraction;

  /// The groups Other holds, largest first (the card's Other dialog);
  /// empty for a group's slice.
  final List<ReportGroup> others;
}

/// The card's slices in [currency]: the report's first-level groups,
/// shares of its total ([slicesOf]).
List<ChartSlice> chartSlices(Report report, String currency) => slicesOf(
  report.groupsIn(currency),
  currency,
  report.totals[currency]?.amount ?? BigInt.zero,
);

/// [groups] (in order, largest first) as slices in [currency], shares of
/// [total]: all of them when they are [maxSlices] or fewer or when
/// [groupOthers] is off (owner, 2026-10-10: the export's "Group small
/// items as Others" toggle), else the 5 largest and Other with the rest.
List<ChartSlice> slicesOf(
  List<ReportGroup> groups,
  String currency,
  BigInt total, {
  bool groupOthers = true,
}) {
  if (groups.isEmpty) return const [];
  final shown = !groupOthers || groups.length <= maxSlices
      ? groups
      : groups.sublist(0, maxSlices - 1);
  final rest = groups.sublist(shown.length);
  var restAmount = BigInt.zero;
  var restCount = 0;
  for (final g in rest) {
    restAmount += g.byCurrency[currency]!.amount;
    restCount += g.byCurrency[currency]!.count;
  }
  var ringSum = restAmount;
  for (final g in shown) {
    ringSum += g.byCurrency[currency]!.amount;
  }
  return [
    for (final g in shown)
      ChartSlice(
        group: g,
        amount: g.byCurrency[currency]!.amount,
        count: g.byCurrency[currency]!.count,
        sharePermille: sharePermille(g.byCurrency[currency]!.amount, total),
        ringFraction: geometryRatio(g.byCurrency[currency]!.amount, ringSum),
      ),
    if (rest.isNotEmpty)
      ChartSlice(
        group: null,
        amount: restAmount,
        count: restCount,
        sharePermille: sharePermille(restAmount, total),
        ringFraction: geometryRatio(restAmount, ringSum),
        others: rest,
      ),
  ];
}

/// [part] / [whole] as a `double` (0..1 for a part of it), for geometry
/// only (a slice, a bar's length): exact enough for pixels even when both
/// are beyond 2⁵³ (scaled down together first). 0 when [whole] is 0.
double geometryRatio(BigInt part, BigInt whole) {
  if (whole == BigInt.zero) return 0;
  final shift = math.max(0, whole.bitLength - 52);
  return (part >> shift).toDouble() / (whole >> shift).toDouble();
}

/// The gap after each of [count] slices of a ring: [gapDegrees], less
/// when that many gaps would take more than half of it (a chart of every
/// item, "Group small items as Others" off); none for a single slice.
double ringGap(int count, double gapDegrees) =>
    count < 2 ? 0 : math.min(gapDegrees, 180 / count);

/// Each slice's sweep in degrees around a ring with a [ringGap] after each
/// slice: proportional to [fractions], none under [minSweepDegrees] (less
/// when there are so many slices that it can't fit), adding up to 360 with
/// the gaps. One slice is the full ring. The card's donut and the PDF's
/// charts both draw these, so a small slice shows on both.
List<double> ringSweeps(List<double> fractions, {double gapDegrees = 0}) {
  if (fractions.isEmpty) return const [];
  if (fractions.length == 1) return const [360];
  final room = 360 - ringGap(fractions.length, gapDegrees) * fractions.length;
  final minSweep = math.min(minSweepDegrees, room / fractions.length);
  // The thin slices get the minimum; the others share what's left, in
  // proportion. Repeated, since shrinking the others can push one more
  // under the minimum.
  final small = <int>{};
  var sweeps = <double>[];
  while (true) {
    var bigSum = 0.0;
    for (var i = 0; i < fractions.length; i++) {
      if (!small.contains(i)) bigSum += fractions[i];
    }
    final bigRoom = room - minSweep * small.length;
    sweeps = [
      for (var i = 0; i < fractions.length; i++)
        small.contains(i)
            ? minSweep
            : bigSum == 0
            ? bigRoom / (fractions.length - small.length)
            : fractions[i] / bigSum * bigRoom,
    ];
    final newlySmall = [
      for (var i = 0; i < sweeps.length; i++)
        if (!small.contains(i) && sweeps[i] < minSweep) i,
    ];
    if (newlySmall.isEmpty) return sweeps;
    small.addAll(newlySmall);
  }
}
