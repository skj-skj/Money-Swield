/// What the generator does for one recurring item (phase-7a.md §5.3).
/// Pure Dart.
library;

import 'dart:math' as math;

import 'periods.dart';
import 'recurrence.dart';
import 'repeat_input.dart' show maxPastPayments;

/// A backlog whose oldest payment is more than this many days old is held:
/// nothing is added until the user chooses Add all or Skip them (P7a-3).
const holdAfterDays = 31;

sealed class TemplatePlan {
  const TemplatePlan();
}

final class NothingDue extends TemplatePlan {
  const NothingDue();
}

/// Add [due] (at most [maxPastPayments]) and move the cursor to [next]
/// (null: no payment is left before the end).
final class AddPayments extends TemplatePlan {
  const AddPayments(this.due, this.next);

  final List<String> due;
  final String? next;
}

/// The oldest payment due is more than [holdAfterDays] old: nothing is
/// added until the user chooses (§8.6). [count] payments are due, [from]
/// (the cursor) to [to].
final class HoldPayments extends TemplatePlan {
  const HoldPayments({
    required this.count,
    required this.from,
    required this.to,
  });

  final int count;
  final String from;
  final String to;
}

/// The plan for an item with [s] and [cursor] (`next_due_on`) on [today].
/// [confirmed]: the user already said yes (Save with Repeats, Add all), so
/// no hold. [skipped]: dates skipped once from Upcoming (phase-7b.md §5.2):
/// neither added nor counted, so "Add all 10" adds 10, and the hold looks
/// at the oldest date it would really add. The cursor still moves past
/// them.
TemplatePlan planTemplate(
  Schedule s, {
  required String? cursor,
  required String today,
  required bool confirmed,
  Set<String> skipped = const {},
}) {
  if (cursor == null || cursor.compareTo(today) > 0) return const NothingDue();
  final oldest = _firstNotSkipped(s, cursor, today, skipped);
  if (!confirmed &&
      oldest != null &&
      parseDay(today).difference(parseDay(oldest)).inDays > holdAfterDays) {
    final count =
        dueCount(s, cursor: cursor, today: today) -
        skippedBetween(s, skipped, cursor, today);
    return HoldPayments(
      count: count,
      from: oldest,
      to: _lastNotSkipped(s, today, skipped),
    );
  }
  final (:due, :next) = dueDatesSkipping(
    s,
    from: cursor,
    through: today,
    skipped: skipped,
  );
  if (due.isEmpty && next == cursor) return const NothingDue();
  return AddPayments(due, next);
}

/// [dueDates] with the [skipped] dates passed over: at most [limit] dates
/// to add, and the payment after the last date looked at (added or
/// skipped). The cursor goes there, past the skips.
({List<String> due, String? next}) dueDatesSkipping(
  Schedule s, {
  required String from,
  required String through,
  Set<String> skipped = const {},
  int limit = maxPastPayments,
}) {
  if (skipped.isEmpty) {
    return dueDates(s, from: from, through: through, limit: limit);
  }
  final throughDate = parseDay(through);
  final due = <String>[];
  var next = occurrenceOnOrAfter(s, from);
  while (next != null &&
      due.length < limit &&
      !parseDay(next).isAfter(throughDate)) {
    if (!skipped.contains(next)) due.add(next);
    next = occurrenceAfter(s, next);
  }
  return (due: due, next: next);
}

/// **Add selected** (phase-7b.md §5.2, P7b-6): the dates to add are the
/// [ticked] ones that are really due (the held dates: from [cursor]
/// through [today], [skipped] left out, at most [maxPastPayments]);
/// anything else ticked is ignored, so a stale list can't add a wrong
/// date. `listed`: how many dates the sheet listed. The cursor goes after
/// them: after [today], so the unticked ones are skipped for good; with
/// more than 1,000 waiting, to the first one not listed, which is asked
/// about again (phase-7b.md §12a: never skipped unseen).
///
/// [today] is the day the sheet was read on, not the day of the tap: past
/// midnight, the new day's payment wasn't listed and must not be skipped
/// unseen either.
({List<String> add, int listed, String? next}) selectedPlan(
  Schedule s, {
  required String cursor,
  required String today,
  required Set<String> ticked,
  Set<String> skipped = const {},
}) {
  final (:due, :next) = dueDatesSkipping(
    s,
    from: cursor,
    through: today,
    skipped: skipped,
  );
  return (
    add: [
      for (final day in due)
        if (ticked.contains(day)) day,
    ],
    listed: due.length,
    next: next,
  );
}

/// The first payment from [cursor] through [today] that isn't skipped.
String? _firstNotSkipped(
  Schedule s,
  String cursor,
  String today,
  Set<String> skipped,
) {
  var day = occurrenceOnOrAfter(s, cursor);
  while (day != null && day.compareTo(today) <= 0 && skipped.contains(day)) {
    day = occurrenceAfter(s, day);
  }
  return day == null || day.compareTo(today) > 0 ? null : day;
}

/// The last payment through [today] that isn't skipped (one exists: the
/// hold found one).
String _lastNotSkipped(Schedule s, String today, Set<String> skipped) {
  var k = occurrencesThrough(s, today) - 1;
  while (k > 0 && skipped.contains(occurrenceAt(s, k))) {
    k--;
  }
  return occurrenceAt(s, k);
}

/// How many of [skipped] are payments from [from] through [to].
int skippedBetween(Schedule s, Set<String> skipped, String from, String to) =>
    skipped
        .where(
          (d) =>
              d.compareTo(from) >= 0 &&
              d.compareTo(to) <= 0 &&
              occurrenceOnOrAfter(s, d) == d,
        )
        .length;

/// The cursor after an Edit changed the end (the schedule [s] has the new
/// one). Every date up to the old cursor, or up to [oldEnd] when no
/// payment was left ([cursor] null), was handled: the cursor never moves
/// back onto one of them (§6.7, P7a-17).
///
/// - A cursor past the new end: null (no payment left).
/// - No payment was left and the end moves later (or goes): the first
///   payment after the old end. Without this an item whose end was
///   extended would never add a payment again (phase-7a.md §12a).
String? cursorAfterEndChange(
  Schedule s, {
  required String? cursor,
  required String? oldEnd,
}) {
  if (cursor != null) return occurrenceOnOrAfter(s, cursor);
  return oldEnd == null ? null : occurrenceAfter(s, oldEnd);
}

/// The cursor when an archived item is restored on [today]: payments start
/// again from today, the archived gap isn't caught up, and no date already
/// handled is looked at again (§6.7). [s] is the schedule as restored (an
/// end that passed is cleared: [endCleared]).
///
/// - A kept cursor: the later of it and the first payment from today; null
///   when none is left before the end.
/// - No cursor and the end passed (expired, now without an end): the first
///   payment from today.
/// - No cursor and the end still ahead (stopped with no payment left):
///   stays null. Taking "the first payment from today" here could hand
///   back a payment already added and since deleted (phase-7a.md §12a).
String? cursorAfterRestore(
  Schedule s, {
  required String? cursor,
  required bool endCleared,
  required String today,
}) {
  if (cursor == null) return endCleared ? occurrenceOnOrAfter(s, today) : null;
  return occurrenceOnOrAfter(s, cursor.compareTo(today) > 0 ? cursor : today);
}

/// What Restore does to an archived item with [s] and [cursor] on [today]
/// (§6.1): the schedule it restores with (an end before today cleared,
/// `endPassed` says which), and its cursor ([cursorAfterRestore]). The
/// Restore dialog shows it and the repository writes it, so they can't
/// disagree.
({Schedule schedule, String? endPassed, String? next}) planRestore(
  Schedule s, {
  required String? cursor,
  required String today,
}) {
  final endOn = s.endOn;
  final endPassed = endOn != null && endOn.compareTo(today) < 0 ? endOn : null;
  final schedule = endPassed == null
      ? s
      : Schedule(
          frequency: s.frequency,
          interval: s.interval,
          startOn: s.startOn,
        );
  return (
    schedule: schedule,
    endPassed: endPassed,
    next: cursorAfterRestore(
      schedule,
      cursor: cursor,
      endCleared: endPassed != null,
      today: today,
    ),
  );
}

/// The earliest end an Edit may set (P7a-27): not before today, the start,
/// or a payment already added ([newestPayment], binned ones included).
String earliestEndFor({
  required String startOn,
  required String? newestPayment,
  required String today,
}) => [
  startOn,
  today,
  ?newestPayment,
].reduce((a, b) => a.compareTo(b) >= 0 ? a : b);

/// The last payment date item [s] has handled (added, deleted or skipped):
/// the payment before its [cursor]; with no cursor (no payment left), its
/// last payment before the end. Null when none was handled.
String? lastHandledOn(Schedule s, {required String? cursor}) {
  if (cursor == null) {
    return lastOccurrence(
      Schedule(
        frequency: s.frequency,
        interval: s.interval,
        startOn: s.startOn,
        endOn: s.endOn ?? lastEndOn,
      ),
    );
  }
  final before = occurrencesThrough(s, addDays(cursor, -1));
  return before == 0 ? null : occurrenceAt(s, before - 1);
}

/// The earliest First payment a new schedule may start on (phase-7b.md
/// §7.3, P7b-4): after the old item's last handled date, so no date it
/// added, deleted or skipped is paid again (§6.5), and not before [today].
String earliestFirstPayment(
  Schedule old, {
  required String? cursor,
  required String today,
}) {
  final handled = lastHandledOn(old, cursor: cursor);
  final after = handled == null ? today : addDays(handled, 1);
  return after.compareTo(today) > 0 ? after : today;
}

/// An item as [runningRelatives] sees it: what it was made from, and
/// whether it runs.
typedef FamilyLink = ({int? replacesId, bool running});

/// The running items of [id]'s family, itself left out: every item joined
/// to it through `replaces_id`, up or down, any number of steps (A → B →
/// C: restoring A finds C; restoring B, swapped out for A, finds A).
/// Restoring one of them swaps these out (P7b-3), so one bill never has two
/// items running. Newest first. [items] is every item, by id.
List<int> runningRelatives(int id, Map<int, FamilyLink> items) {
  final children = <int, List<int>>{};
  for (final MapEntry(key: child, value: link) in items.entries) {
    final parent = link.replacesId;
    if (parent != null) children.putIfAbsent(parent, () => []).add(child);
  }
  // Up to the first item, then every item below it. The seen set keeps a
  // damaged loop from running forever.
  var root = id;
  final up = <int>{root};
  while (true) {
    final parent = items[root]?.replacesId;
    if (parent == null || !items.containsKey(parent) || !up.add(parent)) {
      break;
    }
    root = parent;
  }
  final family = <int>{};
  final queue = [root];
  while (queue.isNotEmpty) {
    final next = queue.removeLast();
    if (!family.add(next)) continue;
    queue.addAll(children[next] ?? const []);
  }
  return [
    for (final member in family)
      if (member != id && items[member]?.running == true) member,
  ]..sort((a, b) => b.compareTo(a));
}

/// Whether an item's payments are waiting to be added ([cursor] on or
/// before [today]: held, or a run that failed): changing how often would
/// drop them, so the Edit screen asks to add or skip them first
/// (phase-7b.md §12a).
bool paymentsWaiting({required String? cursor, required String today}) =>
    cursor != null && cursor.compareTo(today) <= 0;

/// How many payments are due from [cursor] through [today]; 0 when the
/// cursor is after today.
int dueCount(Schedule s, {required String cursor, required String today}) =>
    math.max(
      0,
      occurrencesThrough(s, today) - occurrencesThrough(s, addDays(cursor, -1)),
    );
