/// The moment an added recurring payment gets. Pure Dart.
library;

import 'periods.dart';

/// A local wall-clock time as the device's zone reads it: the instant
/// (UTC) and the zone's offset then.
typedef ZonedMoment = ({DateTime occurredAt, int offsetMinutes});

/// The device's zone: Dart's local `DateTime`, which moves a time inside a DST
/// gap forward. Tests pass a fake zone instead.
ZonedMoment deviceMoment(int year, int month, int day, int hour, int minute) {
  final local = DateTime(year, month, day, hour, minute);
  return (
    occurredAt: local.toUtc(),
    offsetMinutes: local.timeZoneOffset.inMinutes,
  );
}

/// `occurred_at` (UTC) and offset for a payment due on [day] at [minutes] past
/// midnight, in the device's zone when it is added.
///
/// A DST gap can push the time into the next day (a gap from 23:00 moves
/// 23:30 to after midnight): then 12:00 that day is used, so the payment
/// stays on its due date. If 12:00 isn't on [day] either (a calendar day
/// the zone skipped), the moment is kept and [onSkippedDay] is told:
/// `occurred_on` is derived as always and is the next day, while the
/// payment's `recurring_due_on` keeps the due date.
ZonedMoment paymentMoment(
  String day,
  int minutes, {
  ZonedMoment Function(int year, int month, int day, int hour, int minute)
      localMoment =
      deviceMoment,
  void Function(String day)? onSkippedDay,
}) {
  final date = parseDay(day);
  bool onDay(ZonedMoment m) => localDayOf(m.occurredAt, m.offsetMinutes) == day;
  final atTime = localMoment(
    date.year,
    date.month,
    date.day,
    minutes ~/ 60,
    minutes % 60,
  );
  if (onDay(atTime)) return atTime;
  final noon = localMoment(date.year, date.month, date.day, 12, 0);
  if (onDay(noon)) return noon;
  onSkippedDay?.call(day);
  return atTime;
}
