/// The Repeats section of the Add form as typed, and its checks. Pure Dart.
library;

import 'periods.dart';
import 'recurrence.dart';

export 'recurrence.dart' show Frequency, lastEndOn;

/// How Repeats ends: never, on a date, or after N payments (offered where an
/// item is created, not in its Edit screen).
enum RepeatEnd { never, onDate, afterCount }

/// What the Repeats section holds. Kept **as typed**: a half-typed interval
/// ("", "0") or count stays as it is, in the form and the draft, and is checked
/// at Save only.
final class RepeatChoice {
  const RepeatChoice({
    this.frequency = Frequency.monthly,
    this.intervalText = '1',
    this.end = RepeatEnd.never,
    this.endOn,
    this.countText = '',
  });

  /// What switching Repeats on starts with: every 1 month, never ends.
  static const defaults = RepeatChoice();

  final Frequency frequency;

  /// The "Every" field as typed.
  final String intervalText;

  final RepeatEnd end;

  /// The "On" date; kept while [end] is something else, so switching back
  /// finds it.
  final String? endOn;

  /// The "After N payments" field as typed: payments in all, the first one
  /// included. Kept while [end] is something else.
  final String countText;

  RepeatChoice copyWith({
    Frequency? frequency,
    String? intervalText,
    RepeatEnd? end,
    String? endOn,
    String? countText,
  }) => RepeatChoice(
    frequency: frequency ?? this.frequency,
    intervalText: intervalText ?? this.intervalText,
    end: end ?? this.end,
    endOn: endOn ?? this.endOn,
    countText: countText ?? this.countText,
  );

  /// The interval when [intervalText] is 1 to [maxRepeatInterval], else
  /// null. Leading zeros are read ("007" from a draft is 7): the field
  /// itself takes two digits.
  int? get interval => intervalOf(intervalText);

  /// The payment count when [countText] is 2 to [maxRepeatCount], else
  /// null. 1 isn't a repeat: the expense alone is that.
  int? get count => _number(countText, 2, maxRepeatCount);

  @override
  bool operator ==(Object other) =>
      other is RepeatChoice &&
      other.frequency == frequency &&
      other.intervalText == intervalText &&
      other.end == end &&
      other.endOn == endOn &&
      other.countText == countText;

  @override
  int get hashCode =>
      Object.hash(frequency, intervalText, end, endOn, countText);

  @override
  String toString() =>
      'RepeatChoice(${frequency.name} × "$intervalText", ${end.name}'
      '${endOn == null ? '' : ' $endOn'}'
      '${countText.isEmpty ? '' : ' count "$countText"'})';
}

/// The Every field's [text] as an interval, 1 to [maxRepeatInterval], or
/// null: the Add form's and the Edit screen's.
int? intervalOf(String text) => _number(text, 1, maxRepeatInterval);

/// [text] as a number from [min] to [max], or null. At most 3 digits, so a
/// damaged draft can't hold a number too long to parse.
int? _number(String text, int min, int max) {
  if (text.isEmpty || text.length > 3 || !_digits.hasMatch(text)) return null;
  final value = int.parse(text);
  return value >= min && value <= max ? value : null;
}

final _digits = RegExp(r'^[0-9]+$');

const maxRepeatInterval = 99;

/// The most payments "After N payments" takes.
const maxRepeatCount = 999;

/// What the After field holds when After is picked with nothing typed: the
/// flow's example, so the row always says what it means, as "On" shows a date.
const defaultRepeatCountText = '12';

/// The most earlier payments a Save adds, and the most one generator run adds
/// per item.
const maxPastPayments = 1000;

enum RepeatError {
  /// Every isn't 1 to 99.
  intervalRange,

  /// Ends on a date, but none is set (only from a damaged draft: picking
  /// "On" sets one).
  endMissing,

  endBeforeStart,

  /// After [lastEndOn] (from a draft).
  endTooLate,

  /// More than [maxPastPayments] earlier payments.
  tooManyPast,

  /// After N payments, N not 2 to [maxRepeatCount].
  countRange,
}

/// The schedule a Save stores for a first payment on [startOn]. "After N
/// payments" is stored as the N-th payment's date. Only for a choice
/// [validateRepeat] accepts.
Schedule scheduleFor(RepeatChoice c, String startOn) {
  final interval = c.interval;
  if (interval == null) {
    throw ArgumentError.value(c.intervalText, 'interval', 'not 1 to 99');
  }
  final String? endOn;
  switch (c.end) {
    case RepeatEnd.never:
      endOn = null;
    case RepeatEnd.onDate:
      endOn = c.endOn;
    case RepeatEnd.afterCount:
      endOn = _afterCountEnd(c, interval, startOn);
      if (endOn == null) {
        throw ArgumentError.value(c.countText, 'count', 'not 2 to 999 by 2200');
      }
  }
  return Schedule(
    frequency: c.frequency,
    interval: interval,
    startOn: startOn,
    endOn: endOn,
  );
}

/// Why [c] can't be saved for a first payment on [startOn] when it is
/// [today], or null.
RepeatError? validateRepeat(
  RepeatChoice c, {
  required String startOn,
  required String today,
}) {
  final interval = c.interval;
  if (interval == null) return RepeatError.intervalRange;
  switch (c.end) {
    case RepeatEnd.never:
      break;
    case RepeatEnd.onDate:
      final endOn = c.endOn;
      if (endOn == null || !isValidDay(endOn)) return RepeatError.endMissing;
      if (endOn.compareTo(startOn) < 0) return RepeatError.endBeforeStart;
      if (endOn.compareTo(lastEndOn) > 0) return RepeatError.endTooLate;
    case RepeatEnd.afterCount:
      if (c.count == null) return RepeatError.countRange;
      // The N-th payment past 2200-12-31 (yearly × 99, after 999): an end
      // nothing could read back.
      if (_afterCountEnd(c, interval, startOn) == null) {
        return RepeatError.endTooLate;
      }
  }
  if (pastPaymentCount(c, startOn: startOn, today: today) > maxPastPayments) {
    return RepeatError.tooManyPast;
  }
  return null;
}

/// What the Repeats section says under the rule: the earlier payments a Save
/// adds, how many in all, the next payment after them and, when it ends, its
/// last payment.
typedef RepeatSummary = ({
  List<String> past,
  int pastCount,
  String? next,
  String? last,
});

/// [scheduleFor], or null while Every or After N isn't valid yet: what the
/// section's live texts are computed from, before any Save attempt.
Schedule? scheduleOrNull(RepeatChoice c, String startOn) {
  final interval = c.interval;
  if (interval == null) return null;
  if (c.end == RepeatEnd.afterCount &&
      _afterCountEnd(c, interval, startOn) == null) {
    return null;
  }
  return scheduleFor(c, startOn);
}

/// The end "After N payments" stores: the N-th payment's date. Null when N
/// isn't 2 to [maxRepeatCount] or that payment falls after [lastEndOn].
String? _afterCountEnd(RepeatChoice c, int interval, String startOn) {
  final count = c.count;
  if (count == null) return null;
  return occurrenceWithinLimit(
    Schedule(frequency: c.frequency, interval: interval, startOn: startOn),
    count - 1,
  );
}

/// How many payments a Save would add besides the first: those after
/// [startOn] up to [today] (and the end). Only for a choice
/// [scheduleOrNull] accepts.
int pastPaymentCount(
  RepeatChoice c, {
  required String startOn,
  required String today,
}) {
  final schedule = scheduleFor(c, startOn);
  // The first payment itself counts once it is due; it is the form's.
  final through = occurrencesThrough(schedule, today);
  return through == 0 ? 0 : through - 1;
}

/// What the section shows: the payments Save would also add (after the
/// first, up to [today], at most [maxPastPayments]) and the next one after
/// those; null when none is left before the end. Only for a choice
/// [scheduleOrNull] accepts.
({List<String> past, String? next}) repeatPreview(
  RepeatChoice c, {
  required String startOn,
  required String today,
}) {
  final schedule = scheduleFor(c, startOn);
  final second = occurrenceAfter(schedule, startOn);
  if (second == null) return (past: const [], next: null);
  final (:due, :next) = dueDates(
    schedule,
    from: second,
    through: today,
    limit: maxPastPayments,
  );
  return (past: due, next: next);
}

/// Whether [day] is a real `YYYY-MM-DD` date (not 2026-02-30).
bool isValidDay(String day) {
  if (!_dayPattern.hasMatch(day)) return false;
  return isoDay(parseDay(day)) == day;
}

final _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
