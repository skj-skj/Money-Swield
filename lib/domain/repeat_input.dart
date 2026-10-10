/// The Repeats section of the Add form as typed, and its checks
/// (phase-7a.md §5.2). Pure Dart.
library;

import 'periods.dart';
import 'recurrence.dart';

export 'recurrence.dart' show Frequency, lastEndOn;

enum RepeatEnd { never, onDate }

/// What the Repeats section holds. Kept **as typed** (P7a-26): a half-typed
/// interval ("", "0") stays as it is, in the form and the draft, and is
/// checked at Save only.
final class RepeatChoice {
  const RepeatChoice({
    this.frequency = Frequency.monthly,
    this.intervalText = '1',
    this.end = RepeatEnd.never,
    this.endOn,
  });

  /// What switching Repeats on starts with: every 1 month, never ends.
  static const defaults = RepeatChoice();

  final Frequency frequency;

  /// The "Every" field as typed.
  final String intervalText;

  final RepeatEnd end;

  /// The "On" date; kept while [end] is never, so switching back finds it.
  final String? endOn;

  RepeatChoice copyWith({
    Frequency? frequency,
    String? intervalText,
    RepeatEnd? end,
    String? endOn,
  }) => RepeatChoice(
    frequency: frequency ?? this.frequency,
    intervalText: intervalText ?? this.intervalText,
    end: end ?? this.end,
    endOn: endOn ?? this.endOn,
  );

  /// The interval when [intervalText] is 1 to [maxRepeatInterval], else
  /// null. Leading zeros are read ("007" from a draft is 7): the field
  /// itself takes two digits.
  int? get interval {
    final text = intervalText;
    if (text.isEmpty || text.length > 3 || !_digits.hasMatch(text)) {
      return null;
    }
    final value = int.parse(text);
    return value >= 1 && value <= maxRepeatInterval ? value : null;
  }

  /// The end date that applies: [endOn] when it ends on a date.
  String? get effectiveEndOn => end == RepeatEnd.onDate ? endOn : null;

  @override
  bool operator ==(Object other) =>
      other is RepeatChoice &&
      other.frequency == frequency &&
      other.intervalText == intervalText &&
      other.end == end &&
      other.endOn == endOn;

  @override
  int get hashCode => Object.hash(frequency, intervalText, end, endOn);

  @override
  String toString() =>
      'RepeatChoice(${frequency.name} × "$intervalText", ${end.name}'
      '${endOn == null ? '' : ' $endOn'})';
}

final _digits = RegExp(r'^[0-9]+$');

const maxRepeatInterval = 99;

/// The most earlier payments a Save adds, and the most one generator run
/// adds per item (P7a-13).
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
}

/// The schedule a Save stores for a first payment on [startOn]. Only for a
/// choice [validateRepeat] accepts.
Schedule scheduleFor(RepeatChoice c, String startOn) {
  final interval = c.interval;
  if (interval == null) {
    throw ArgumentError.value(c.intervalText, 'interval', 'not 1 to 99');
  }
  return Schedule(
    frequency: c.frequency,
    interval: interval,
    startOn: startOn,
    endOn: c.effectiveEndOn,
  );
}

/// Why [c] can't be saved for a first payment on [startOn] when it is
/// [today], or null.
RepeatError? validateRepeat(
  RepeatChoice c, {
  required String startOn,
  required String today,
}) {
  if (c.interval == null) return RepeatError.intervalRange;
  if (c.end == RepeatEnd.onDate) {
    final endOn = c.endOn;
    if (endOn == null || !isValidDay(endOn)) return RepeatError.endMissing;
    if (endOn.compareTo(startOn) < 0) return RepeatError.endBeforeStart;
    if (endOn.compareTo(lastEndOn) > 0) return RepeatError.endTooLate;
  }
  if (pastPaymentCount(c, startOn: startOn, today: today) > maxPastPayments) {
    return RepeatError.tooManyPast;
  }
  return null;
}

/// How many payments a Save would add besides the first: those after
/// [startOn] up to [today] (and the end). Only for a valid interval.
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
/// those; null when none is left before the end. Only for a choice with a
/// valid interval.
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
