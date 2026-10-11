/// A report: the expenses of a range that pass a filter, grouped by one
/// or two dimensions, with totals per currency (phase-8.md §5.2). The
/// screen, the PDF and the Excel file are all built from one [Report], so
/// an export can't differ from the screen (§9).
///
/// Every sum is a `BigInt` of `int` minor units, never a `double`;
/// currencies never mix (D2); the report's totals count each row once,
/// while a row in two events is in each of their groups.
library;

import 'expense_filter.dart';
import 'report_filter.dart';
import 'report_range.dart';
import 'totals.dart';

/// What a level of the report groups by.
enum GroupDimension { category, event, paymentMethod }

/// A first dimension, and an optional different second one.
final class ReportGrouping {
  const ReportGrouping(this.first, {this.then})
    : assert(then != first, 'the second dimension must differ');

  final GroupDimension first;
  final GroupDimension? then;

  /// The card's grouping: an overview by category (owner, 2026-10-10).
  static const byCategory = ReportGrouping(GroupDimension.category);

  bool get hasEvent =>
      first == GroupDimension.event || then == GroupDimension.event;

  @override
  bool operator ==(Object other) =>
      other is ReportGrouping && other.first == first && other.then == then;

  @override
  int get hashCode => Object.hash(first, then);

  @override
  String toString() => 'ReportGrouping(${first.name}, then: ${then?.name})';
}

/// What a group is: a category, an event, "no event" or a payment method.
sealed class GroupKey {
  const GroupKey();
}

final class CategoryKey extends GroupKey {
  const CategoryKey(this.id);
  final int id;

  @override
  bool operator ==(Object other) => other is CategoryKey && other.id == id;
  @override
  int get hashCode => Object.hash(CategoryKey, id);
  @override
  String toString() => 'CategoryKey($id)';
}

final class EventKey extends GroupKey {
  const EventKey(this.id);
  final int id;

  @override
  bool operator ==(Object other) => other is EventKey && other.id == id;
  @override
  int get hashCode => Object.hash(EventKey, id);
  @override
  String toString() => 'EventKey($id)';
}

/// The rows with no event, when grouping by Event with no events chosen.
final class NoEventKey extends GroupKey {
  const NoEventKey();

  @override
  bool operator ==(Object other) => other is NoEventKey;
  @override
  int get hashCode => (NoEventKey).hashCode;
  @override
  String toString() => 'NoEventKey()';
}

final class PaymentMethodKey extends GroupKey {
  const PaymentMethodKey(this.id);
  final int id;

  @override
  bool operator ==(Object other) => other is PaymentMethodKey && other.id == id;
  @override
  int get hashCode => Object.hash(PaymentMethodKey, id);
  @override
  String toString() => 'PaymentMethodKey($id)';
}

/// Ties between groups of equal totals: by id, and "No event" last. Keys of one level are of one kind (or events and No event),
/// so any other mix only needs to be stable.
int compareGroupKeys(GroupKey a, GroupKey b) => switch ((a, b)) {
  (NoEventKey(), NoEventKey()) => 0,
  (NoEventKey(), _) => 1,
  (_, NoEventKey()) => -1,
  (CategoryKey(id: final x), CategoryKey(id: final y)) ||
  (EventKey(id: final x), EventKey(id: final y)) ||
  (
    PaymentMethodKey(id: final x),
    PaymentMethodKey(id: final y),
  ) => x.compareTo(y),
  _ => a.runtimeType.toString().compareTo(b.runtimeType.toString()),
};

/// One expense as a report sees it (§6.1's row).
final class ReportRow {
  const ReportRow({
    required this.id,
    required this.title,
    this.description,
    required this.amountMinor,
    required this.currencyCode,
    required this.occurredAtMs,
    required this.utcOffsetMinutes,
    required this.day,
    required this.categoryId,
    required this.paymentMethodId,
    this.eventIds = const {},
    this.recurring = false,
  });

  final int id;
  final String title;
  final String? description;
  final int amountMinor;
  final String currencyCode;
  final int occurredAtMs;
  final int utcOffsetMinutes;

  /// `occurred_on`: the local date where it was recorded.
  final String day;
  final int categoryId;
  final int paymentMethodId;
  final Set<int> eventIds;

  /// A payment of a recurring item.
  final bool recurring;

  @override
  String toString() => 'ReportRow($id, $title, $amountMinor $currencyCode)';
}

/// Report order: date, then moment, then id, ascending (a report reads
/// forward in time).
int compareReportRows(ReportRow a, ReportRow b) {
  final byDay = a.day.compareTo(b.day);
  if (byDay != 0) return byDay;
  final byMoment = a.occurredAtMs.compareTo(b.occurredAtMs);
  return byMoment != 0 ? byMoment : a.id.compareTo(b.id);
}

/// A group's sums in one currency.
final class GroupTotal {
  const GroupTotal(this.amount, this.count);

  final BigInt amount;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is GroupTotal && other.amount == amount && other.count == count;

  @override
  int get hashCode => Object.hash(amount, count);

  @override
  String toString() => 'GroupTotal($amount, $count)';
}

final class ReportGroup {
  ReportGroup._({
    required this.key,
    required this.byCurrency,
    required this.rows,
    required this._children,
  });

  final GroupKey key;

  /// Per currency, the group's sum and count.
  final Map<String, GroupTotal> byCurrency;

  final List<ReportGroup> _children;

  /// Every row of the group, in report order ([compareReportRows]).
  final List<ReportRow> rows;

  /// The second level's groups that have rows in [currency], in that
  /// currency's order (total descending, ties by key). Empty without a
  /// second dimension.
  List<ReportGroup> childrenIn(String currency) =>
      _ordered(_children, currency);

  /// The group's rows in [currency], in report order.
  List<ReportRow> rowsIn(String currency) => [
    for (final row in rows)
      if (row.currencyCode == currency) row,
  ];

  @override
  String toString() => 'ReportGroup($key, $byCurrency)';
}

final class Report {
  Report._({
    required this.range,
    required this.filter,
    required this.grouping,
    required this.rows,
    required this.totals,
    required this.currencies,
    required this._groups,
    required this.span,
  });

  final ReportRange range;
  final ReportFilter filter;
  final ReportGrouping grouping;

  /// Every row the report covers, once, in report order.
  final List<ReportRow> rows;

  /// Per currency: each row counted once.
  final Map<String, GroupTotal> totals;

  /// The currencies with rows: the default first, then by code.
  final List<String> currencies;

  final List<ReportGroup> _groups;

  /// The first and last day of the rows; null without rows.
  final ({String first, String last})? span;

  bool get isEmpty => rows.isEmpty;

  /// The first level's groups with rows in [currency], largest first,
  /// ties by key ([compareGroupKeys]).
  List<ReportGroup> groupsIn(String currency) => _ordered(_groups, currency);

  /// The overlap in [currency] only: rows of that currency in two or more
  /// groups of one level.
  int overlapIn(String currency) {
    if (!grouping.hasEvent) return 0;
    var count = 0;
    for (final row in rows) {
      if (row.currencyCode == currency && _inSeveralEvents(row, filter)) {
        count++;
      }
    }
    return count;
  }
}

/// Whether [row] is in two or more event groups.
bool _inSeveralEvents(ReportRow row, ReportFilter filter) =>
    keysOf(row, GroupDimension.event, filter.base.eventIds).length > 1;

List<ReportGroup> _ordered(List<ReportGroup> groups, String currency) {
  final shown = [
    for (final g in groups)
      if (g.byCurrency.containsKey(currency)) g,
  ];
  return shown..sort((a, b) {
    final byAmount = b.byCurrency[currency]!.amount.compareTo(
      a.byCurrency[currency]!.amount,
    );
    return byAmount != 0 ? byAmount : compareGroupKeys(a.key, b.key);
  });
}

/// The groups [row] is in for [dimension]. Only Event can give more than
/// one: with events chosen in the filter, the chosen ones it has (a
/// not-chosen event is ignored); without, each event it has, or No event.
List<GroupKey> keysOf(
  ReportRow row,
  GroupDimension dimension,
  Set<int> chosenEvents,
) => switch (dimension) {
  GroupDimension.category => [CategoryKey(row.categoryId)],
  GroupDimension.paymentMethod => [PaymentMethodKey(row.paymentMethodId)],
  GroupDimension.event => _eventKeys(row, chosenEvents),
};

List<GroupKey> _eventKeys(ReportRow row, Set<int> chosen) {
  final ids =
      (chosen.isEmpty ? row.eventIds : row.eventIds.intersection(chosen))
          .toList()
        ..sort();
  // A row reaching here without a chosen event only if the filter didn't
  // narrow it (never, through buildReport): No event rather than lost.
  return ids.isEmpty
      ? const [NoEventKey()]
      : [for (final id in ids) EventKey(id)];
}

/// Whether [row] passes [filter]: any chosen category, at least one chosen
/// event, any chosen payment method, Only recurring, every word of the
/// text in its title or description (Home's rules, phase-5.md §5.6).
/// [words] is `searchWords(filter.base.text)`, computed once.
bool rowPasses(ReportRow row, ReportFilter filter, List<String> words) {
  final base = filter.base;
  if (base.categoryIds.isNotEmpty &&
      !base.categoryIds.contains(row.categoryId)) {
    return false;
  }
  if (base.eventIds.isNotEmpty && !row.eventIds.any(base.eventIds.contains)) {
    return false;
  }
  if (filter.paymentMethodIds.isNotEmpty &&
      !filter.paymentMethodIds.contains(row.paymentMethodId)) {
    return false;
  }
  if (base.onlyRecurring && !row.recurring) return false;
  return words.isEmpty ||
      matchesWords(foldForSearch(row.title, row.description), words);
}

/// Builds the report from [rows] (as read for [range] and [filter]'s SQL
/// part): the range and the whole filter are applied again here, so the
/// result never depends on what the read let through.
Report buildReport(
  List<ReportRow> rows, {
  required ReportRange range,
  required ReportFilter filter,
  required ReportGrouping grouping,
  required String defaultCurrency,
}) {
  final words = searchWords(filter.base.text);
  final kept = [
    for (final row in rows)
      if (range.contains(row.day) && rowPasses(row, filter, words)) row,
  ]..sort(compareReportRows);
  final chosen = filter.base.eventIds;
  final totals = _sum(kept);
  return Report._(
    range: range,
    filter: filter,
    grouping: grouping,
    rows: kept,
    totals: totals,
    currencies: orderedCodes(totals.keys, defaultCurrency),
    groups: _group(kept, grouping.first, grouping.then, chosen),
    span: kept.isEmpty ? null : (first: kept.first.day, last: kept.last.day),
  );
}

/// [rows] grouped by [dimension], each group split by [then] when set.
/// [rows] are in report order, so each group's rows stay in it.
List<ReportGroup> _group(
  List<ReportRow> rows,
  GroupDimension dimension,
  GroupDimension? then,
  Set<int> chosenEvents,
) {
  final members = <GroupKey, List<ReportRow>>{};
  for (final row in rows) {
    for (final key in keysOf(row, dimension, chosenEvents)) {
      members.putIfAbsent(key, () => []).add(row);
    }
  }
  return [
    for (final MapEntry(:key, value: groupRows) in members.entries)
      ReportGroup._(
        key: key,
        byCurrency: _sum(groupRows),
        rows: groupRows,
        children: then == null
            ? const []
            : _group(groupRows, then, null, chosenEvents),
      ),
  ];
}

Map<String, GroupTotal> _sum(List<ReportRow> rows) {
  final amounts = <String, BigInt>{};
  final counts = <String, int>{};
  for (final row in rows) {
    final code = row.currencyCode;
    amounts[code] =
        (amounts[code] ?? BigInt.zero) + BigInt.from(row.amountMinor);
    counts[code] = (counts[code] ?? 0) + 1;
  }
  return {
    for (final code in amounts.keys)
      code: GroupTotal(amounts[code]!, counts[code]!),
  };
}

/// [part] / [whole] in tenths of a percent, rounded half up; integers
/// only (P8-11). Null when [whole] is 0.
int? sharePermille(BigInt part, BigInt whole) {
  if (whole == BigInt.zero) return null;
  return ((part * BigInt.from(2000) + whole) ~/ (whole * BigInt.two)).toInt();
}
