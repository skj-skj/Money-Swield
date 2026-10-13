import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/periods.dart';
import 'package:money_swield/domain/recurring_moment.dart';

/// A fixed-offset zone: wall-clock fields minus the offset is the instant.
ZonedMoment Function(int, int, int, int, int) fixed(int offsetMinutes) =>
    (y, m, d, h, min) => (
      occurredAt: DateTime.utc(
        y,
        m,
        d,
        h,
        min,
      ).subtract(Duration(minutes: offsetMinutes)),
      offsetMinutes: offsetMinutes,
    );

/// A zone at +60 whose clocks jump from 23:00 to 00:00 (+120) on 2026-10-09,
/// like Dart moving a time in the gap forward.
ZonedMoment lateGap(int y, int m, int d, int h, int min) {
  final wall = DateTime.utc(y, m, d, h, min);
  final gapStart = DateTime.utc(2026, 10, 9, 23);
  if (wall.isBefore(gapStart)) {
    return (
      occurredAt: wall.subtract(const Duration(minutes: 60)),
      offsetMinutes: 60,
    );
  }
  // In the gap or after: the same instant as an hour later at +120.
  return (
    occurredAt: wall.subtract(const Duration(minutes: 60)),
    offsetMinutes: 120,
  );
}

/// A zone that skips 2026-10-09 entirely (as Samoa skipped 30 Dec 2011):
/// every wall time that day is read as the same time the next day.
ZonedMoment skippedDay(int y, int m, int d, int h, int min) {
  var wall = DateTime.utc(y, m, d, h, min);
  final offset = wall.isBefore(DateTime.utc(2026, 10, 9)) ? -600 : 840;
  if (y == 2026 && m == 10 && d == 9) wall = wall.add(const Duration(days: 1));
  return (
    occurredAt: wall.subtract(Duration(minutes: offset)),
    offsetMinutes: offset,
  );
}

void main() {
  String dayOf(ZonedMoment m) => localDayOf(m.occurredAt, m.offsetMinutes);

  test('India: 10:00 on the due date', () {
    final m = paymentMoment('2026-10-09', 600, localMoment: fixed(330));
    expect(dayOf(m), '2026-10-09');
    expect(m.offsetMinutes, 330);
    expect(m.occurredAt, DateTime.utc(2026, 10, 9, 4, 30));
  });

  test('−04:00 at 23:59 stays on the day (the UTC date is the next)', () {
    final m = paymentMoment(
      '2026-10-09',
      23 * 60 + 59,
      localMoment: fixed(-240),
    );
    expect(dayOf(m), '2026-10-09');
    expect(m.offsetMinutes, -240);
    expect(m.occurredAt.day, 10);
  });

  test('Nepal at midnight: the UTC date is the day before', () {
    final m = paymentMoment('2026-10-09', 0, localMoment: fixed(345));
    expect(dayOf(m), '2026-10-09');
    expect(m.occurredAt, DateTime.utc(2026, 10, 8, 18, 15));
  });

  test('a time in a 23:00–24:00 gap pushed into the next day: 12:00 is '
      'used instead', () {
    var skipped = false;
    final m = paymentMoment(
      '2026-10-09',
      23 * 60 + 30,
      localMoment: lateGap,
      onSkippedDay: (_) => skipped = true,
    );
    expect(dayOf(m), '2026-10-09');
    expect(m.offsetMinutes, 60);
    expect(m.occurredAt, DateTime.utc(2026, 10, 9, 11));
    expect(skipped, isFalse);
  });

  test('a skipped calendar day: the moment is kept and reported', () {
    String? reported;
    final m = paymentMoment(
      '2026-10-09',
      600,
      localMoment: skippedDay,
      onSkippedDay: (day) => reported = day,
    );
    expect(dayOf(m), '2026-10-10');
    expect(m.offsetMinutes, 840);
    expect(reported, '2026-10-09');
  });

  test('minutes at the edges of the day', () {
    expect(
      dayOf(paymentMoment('2026-10-09', 0, localMoment: fixed(0))),
      '2026-10-09',
    );
    expect(
      dayOf(paymentMoment('2026-10-09', 1439, localMoment: fixed(0))),
      '2026-10-09',
    );
  });
}
