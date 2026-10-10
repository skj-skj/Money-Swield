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
/// no hold.
TemplatePlan planTemplate(
  Schedule s, {
  required String? cursor,
  required String today,
  required bool confirmed,
}) {
  if (cursor == null || cursor.compareTo(today) > 0) return const NothingDue();
  final age = parseDay(today).difference(parseDay(cursor)).inDays;
  if (!confirmed && age > holdAfterDays) {
    final count = dueCount(s, cursor: cursor, today: today);
    if (count > 0) {
      return HoldPayments(
        count: count,
        from: cursor,
        to: occurrenceAt(s, occurrencesThrough(s, today) - 1),
      );
    }
  }
  final (:due, :next) = dueDates(
    s,
    from: cursor,
    through: today,
    limit: maxPastPayments,
  );
  if (due.isEmpty && next == cursor) return const NothingDue();
  return AddPayments(due, next);
}

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

/// How many payments are due from [cursor] through [today]; 0 when the
/// cursor is after today.
int dueCount(Schedule s, {required String cursor, required String today}) =>
    math.max(
      0,
      occurrencesThrough(s, today) - occurrencesThrough(s, addDays(cursor, -1)),
    );
