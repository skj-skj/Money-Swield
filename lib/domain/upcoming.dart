/// Upcoming payments (phase-7b.md §5.3): every payment of the running
/// items over the next 12 months, nearest first, computed, never stored.
/// Pure Dart.
library;

import 'expense_filter.dart';
import 'models/recurring_item.dart';
import 'periods.dart';
import 'recurrence.dart';
import 'recurring_price.dart';

/// An upcoming payment skipped once (`recurring_skips`, §4.1).
typedef SkipKey = ({int itemId, String day});

/// How far Upcoming looks: the next 12 months (P7b-10).
const upcomingMonths = 12;

/// One payment to come.
final class UpcomingPayment {
  const UpcomingPayment({
    required this.itemId,
    required this.title,
    required this.day,
    required this.amountMinor,
    required this.currencyCode,
    required this.categoryId,
    required this.skipped,
  });

  final int itemId;
  final String title;

  /// Its due date, `YYYY-MM-DD`.
  final String day;

  /// The item's price on [day], in minor units of [currencyCode].
  final int amountMinor;
  final String currencyCode;
  final int categoryId;

  /// Skipped once: listed greyed, with Bring back (P7b-8).
  final bool skipped;

  SkipKey get key => (itemId: itemId, day: day);

  @override
  bool operator ==(Object other) =>
      other is UpcomingPayment &&
      other.itemId == itemId &&
      other.title == title &&
      other.day == day &&
      other.amountMinor == amountMinor &&
      other.currencyCode == currencyCode &&
      other.categoryId == categoryId &&
      other.skipped == skipped;

  @override
  int get hashCode => Object.hash(
    itemId,
    title,
    day,
    amountMinor,
    currencyCode,
    categoryId,
    skipped,
  );

  @override
  String toString() =>
      'UpcomingPayment($itemId $title $day $amountMinor $currencyCode'
      '${skipped ? ', skipped' : ''})';
}

/// Whether [item]'s payments pass Home's [filter] (owner, 2026-10-10:
/// Upcoming follows the filters, like the Photos screen): its category is
/// one chosen, it has one of the chosen events, and every word of the
/// text is in its title or description, as an expense it adds would be
/// matched (phase-5.md §5.6, P5-32). Only recurring lets every item
/// through: they all repeat.
bool upcomingItemMatches(RecurringItem item, ExpenseFilter filter) {
  if (filter.categoryIds.isNotEmpty &&
      !filter.categoryIds.contains(item.categoryId)) {
    return false;
  }
  if (filter.eventIds.isNotEmpty &&
      !filter.eventIds.any(item.eventIds.contains)) {
    return false;
  }
  final words = searchWords(filter.text);
  if (words.isEmpty) return true;
  final folded = foldForSearch(item.title, item.description);
  return words.every(folded.contains);
}

/// Whether [filter] narrows Upcoming: categories, events or text. Only
/// recurring alone doesn't (every item repeats), so the screen then says
/// neither "Filtered" nor "match the filters", and its Home icon has no
/// dot.
bool upcomingFiltered(ExpenseFilter filter) =>
    !filter.copyWith(onlyRecurring: false).isEmpty;

/// Whether [item] has a payment Upcoming lists on [today]: running,
/// readable, and one due after today (and on or after its cursor) through
/// [upcomingThrough]. Home shows its icon only then: an item starting in
/// two years, or held with its end passed, lists nothing.
bool hasUpcomingPayment(RecurringItem item, {required String today}) {
  final schedule = item.schedule;
  final cursor = item.nextDueOn;
  if (item.isArchived || schedule == null || cursor == null) return false;
  final first = occurrenceOnOrAfter(
    schedule,
    _later(cursor, addDays(today, 1)),
  );
  return first != null && first.compareTo(upcomingThrough(today)) <= 0;
}

String _later(String a, String b) => a.compareTo(b) > 0 ? a : b;

/// The last day Upcoming shows on [today]: 12 months on, clamped to the
/// month's end (31 Jan → 31 Jan; 29 Feb → 28 Feb). `periods.dart` has no
/// month arithmetic: it is the 12th payment of "monthly from today".
String upcomingThrough(String today) => occurrenceAt(
  Schedule(frequency: Frequency.monthly, interval: 1, startOn: today),
  upcomingMonths,
);

/// Every payment of [items] after [today] (from [from] when that is later:
/// a page) through [through], nearest first, then by title, then by item
/// id; with the price on its date and whether it is in [skips].
///
/// Only running, readable items; each from the day after today or its
/// cursor when later, so a held item's waiting dates aren't listed (they
/// are on its hold card) and nothing already handled is. An item with no
/// price on a date (only a damaged one) leaves that date out.
List<UpcomingPayment> upcomingPayments(
  List<RecurringItem> items,
  Set<SkipKey> skips, {
  required String today,
  required String through,
  String? from,
}) {
  final tomorrow = addDays(today, 1);
  final start = from == null ? tomorrow : _later(from, tomorrow);
  final throughDate = parseDay(through);
  final payments = <UpcomingPayment>[];
  for (final item in items) {
    final schedule = item.schedule;
    final cursor = item.nextDueOn;
    if (item.isArchived || schedule == null || cursor == null) continue;
    var day = occurrenceOnOrAfter(schedule, _later(cursor, start));
    while (day != null && !parseDay(day).isAfter(throughDate)) {
      final price = priceOn(item.prices, day);
      if (price != null) {
        payments.add(
          UpcomingPayment(
            itemId: item.id,
            title: item.title,
            day: day,
            amountMinor: price,
            currencyCode: item.currencyCode,
            categoryId: item.categoryId,
            skipped: skips.contains((itemId: item.id, day: day)),
          ),
        );
      }
      day = occurrenceAfter(schedule, day);
    }
  }
  return payments..sort(_byDayThenTitle);
}

int _byDayThenTitle(UpcomingPayment a, UpcomingPayment b) {
  final byDay = a.day.compareTo(b.day);
  if (byDay != 0) return byDay;
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  return byTitle != 0 ? byTitle : a.itemId.compareTo(b.itemId);
}

/// A month frame of Upcoming: "Nov 2026".
final class UpcomingMonth {
  const UpcomingMonth({required this.month, required this.days});

  /// Its first day, `YYYY-MM-01`.
  final String month;

  /// Nearest first.
  final List<UpcomingDay> days;
}

/// A day header and its payments.
final class UpcomingDay {
  const UpcomingDay({required this.day, required this.payments});

  final String day;

  /// By title, then item id.
  final List<UpcomingPayment> payments;
}

/// [payments] (in [upcomingPayments]' order) as month frames holding days,
/// nearest first: the other way round from `photoGroups` (R4).
List<UpcomingMonth> upcomingGroups(List<UpcomingPayment> payments) {
  final months = <UpcomingMonth>[];
  for (final payment in payments) {
    final month = '${payment.day.substring(0, 7)}-01';
    if (months.isEmpty || months.last.month != month) {
      months.add(UpcomingMonth(month: month, days: []));
    }
    final days = months.last.days;
    if (days.isEmpty || days.last.day != payment.day) {
      days.add(UpcomingDay(day: payment.day, payments: []));
    }
    days.last.payments.add(payment);
  }
  return months;
}

/// The calendar months Upcoming pages through on [today], a page each
/// (P7b-10): the rest of this month (tomorrow on), then each month up to
/// [upcomingThrough]'s. 13 of them: the first and last are part months.
/// Today the last day of a month: the first page is next month.
List<PeriodRange> upcomingPages(String today) {
  final start = addDays(today, 1);
  final through = upcomingThrough(today);
  final pages = <PeriodRange>[];
  var month = periodOf(start, Period.month, WeekStart.monday);
  while (month.from.compareTo(through) <= 0) {
    pages.add((
      period: Period.month,
      from: month.from.compareTo(start) < 0 ? start : month.from,
      to: month.to.compareTo(through) > 0 ? through : month.to,
    ));
    month = periodOf(addDays(month.to, 1), Period.month, WeekStart.monday);
  }
  return pages;
}
