import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/recurrence.dart';

Schedule monthly(String start, {int every = 1, String? end}) => Schedule(
  frequency: Frequency.monthly,
  interval: every,
  startOn: start,
  endOn: end,
);

Schedule of(Frequency f, String start, {int every = 1, String? end}) =>
    Schedule(frequency: f, interval: every, startOn: start, endOn: end);

void main() {
  group('occurrenceAt', () {
    test('monthly × 1 from 31 Jan clamps and comes back to the 31st', () {
      final s = monthly('2026-01-31');
      expect(
        [
          for (final k in [0, 1, 2, 3, 12, 25]) occurrenceAt(s, k),
        ],
        [
          '2026-01-31',
          '2026-02-28',
          '2026-03-31',
          '2026-04-30',
          '2027-01-31',
          '2028-02-29',
        ],
      );
    });

    test('monthly × 3 from 30 Nov crosses the year', () {
      final s = monthly('2025-11-30', every: 3);
      expect(
        [for (var k = 0; k < 4; k++) occurrenceAt(s, k)],
        ['2025-11-30', '2026-02-28', '2026-05-30', '2026-08-30'],
      );
    });

    test('yearly from 29 Feb falls on 28 Feb in common years', () {
      final s = of(Frequency.yearly, '2024-02-29');
      expect(
        [
          for (final k in [1, 2, 4]) occurrenceAt(s, k),
        ],
        ['2025-02-28', '2026-02-28', '2028-02-29'],
      );
    });

    test('yearly × 2 from 31 Dec', () {
      expect(
        occurrenceAt(of(Frequency.yearly, '2026-12-31', every: 2), 1),
        '2028-12-31',
      );
    });

    test('weekly × 2 from a Monday', () {
      final s = of(Frequency.weekly, '2026-10-05', every: 2);
      expect(
        [for (var k = 0; k < 3; k++) occurrenceAt(s, k)],
        ['2026-10-05', '2026-10-19', '2026-11-02'],
      );
    });

    test('daily × 3 crosses the year', () {
      expect(
        occurrenceAt(of(Frequency.daily, '2026-12-30', every: 3), 1),
        '2027-01-02',
      );
    });

    test('a negative k is a RangeError', () {
      for (final f in Frequency.values) {
        expect(() => occurrenceAt(of(f, '2026-01-01'), -1), throwsRangeError);
      }
    });

    test('a daily item across a DST change keeps whole dates', () {
      // UTC arithmetic: 2026-03-29 is Europe's spring-forward day.
      final s = of(Frequency.daily, '2026-03-28');
      expect(occurrenceAt(s, 1), '2026-03-29');
      expect(occurrenceAt(s, 2), '2026-03-30');
    });
  });

  group('occurrenceAfter / OnOrAfter', () {
    final s = monthly('2026-01-31');

    test('the next payment strictly after a day', () {
      expect(occurrenceAfter(s, '2026-02-28'), '2026-03-31');
      expect(occurrenceAfter(s, '2026-02-27'), '2026-02-28');
      expect(occurrenceAfter(s, '2025-12-01'), '2026-01-31');
    });

    test('null past the end', () {
      expect(
        occurrenceAfter(monthly('2026-01-31', end: '2026-04-15'), '2026-03-31'),
        isNull,
      );
      expect(
        occurrenceAfter(monthly('2026-01-31', end: '2026-04-30'), '2026-03-31'),
        '2026-04-30',
      );
    });

    test('on or after includes the day itself', () {
      expect(occurrenceOnOrAfter(s, '2026-03-31'), '2026-03-31');
      expect(occurrenceOnOrAfter(s, '2026-04-01'), '2026-04-30');
      expect(occurrenceOnOrAfter(s, '1999-01-01'), '2026-01-31');
    });

    test('a schedule never runs past lastEndOn, whatever its end', () {
      final daily = of(Frequency.daily, '2200-12-30');
      expect(occurrenceAfter(daily, '2200-12-30'), '2200-12-31');
      expect(occurrenceAfter(daily, '2200-12-31'), isNull);
      expect(
        occurrenceOnOrAfter(of(Frequency.daily, lastEndOn), lastEndOn),
        lastEndOn,
      );
      // An end after lastEndOn (only a damaged row) is capped too.
      expect(
        occurrenceAfter(
          of(Frequency.daily, '2200-12-31', end: '9999-12-31'),
          '2200-12-31',
        ),
        isNull,
      );
    });

    test('a payment past year 9999 is never compared as text', () {
      // Year 10000+ would format as 5 digits and sort before "2200": the
      // bound is checked on dates, so these are null, not a payment.
      final yearly = of(Frequency.yearly, '2200-06-01', every: 99);
      expect(occurrenceAfter(yearly, '2200-06-01'), isNull);
      expect(
        occurrenceAfter(
          of(Frequency.yearly, '2150-01-01', every: 99),
          '9000-01-01',
        ),
        isNull,
      );
    });

    test('a start after lastEndOn has no payment at all', () {
      expect(
        occurrenceOnOrAfter(of(Frequency.daily, '2201-01-01'), '2201-01-01'),
        isNull,
      );
      expect(
        occurrencesThrough(of(Frequency.daily, '2201-01-01'), '2300-01-01'),
        0,
      );
    });
  });

  group('occurrencesThrough', () {
    test('counts from the start, bounded by the day and the end', () {
      final s = monthly('2026-01-31', end: '2026-04-15');
      expect(occurrencesThrough(s, '2026-01-30'), 0);
      expect(occurrencesThrough(s, '2026-01-31'), 1);
      expect(occurrencesThrough(s, '2026-02-28'), 2);
      expect(occurrencesThrough(s, '2030-01-01'), 3);
    });

    test('a daily item from 1900 is counted without walking it', () {
      final s = of(Frequency.daily, '1900-01-01');
      final watch = Stopwatch()..start();
      // 126 years with 31 leap days, then 281 days into 2026, both ends.
      expect(occurrencesThrough(s, '2026-10-09'), 126 * 365 + 31 + 281 + 1);
      expect(occurrenceAfter(s, '2026-10-09'), '2026-10-10');
      expect(watch.elapsedMilliseconds, lessThan(50));
    });
  });

  group('dueDates', () {
    final s = monthly('2026-01-31');

    test('from a payment through a day', () {
      final r = dueDates(s, from: '2026-02-28', through: '2026-05-15');
      expect(r.due, ['2026-02-28', '2026-03-31', '2026-04-30']);
      expect(r.next, '2026-05-31');
    });

    test('an end between payments: next is null', () {
      final r = dueDates(
        monthly('2026-01-31', end: '2026-04-15'),
        from: '2026-02-28',
        through: '2026-05-15',
      );
      expect(r.due, ['2026-02-28', '2026-03-31']);
      expect(r.next, isNull);
    });

    test('from after through: nothing due, from is next', () {
      final r = dueDates(s, from: '2026-06-30', through: '2026-05-15');
      expect(r.due, isEmpty);
      expect(r.next, '2026-06-30');
    });

    test('an end before from: nothing, next null', () {
      final r = dueDates(
        monthly('2026-01-31', end: '2026-02-01'),
        from: '2026-02-28',
        through: '2026-05-15',
      );
      expect(r.due, isEmpty);
      expect(r.next, isNull);
    });

    test('daily for three years stops at the limit', () {
      final r = dueDates(
        of(Frequency.daily, '2026-01-01'),
        from: '2026-01-01',
        through: '2028-12-31',
      );
      expect(r.due, hasLength(1000));
      expect(r.due.last, '2028-09-26');
      expect(r.next, '2028-09-27');
    });

    test('a from off the schedule (a damaged cursor) starts at the next '
        'payment, never adds that date', () {
      final r = dueDates(s, from: '2026-02-27', through: '2026-03-31');
      expect(r.due, ['2026-02-28', '2026-03-31']);
    });

    test('limit 0 adds nothing and keeps from as next', () {
      final r = dueDates(
        s,
        from: '2026-02-28',
        through: '2026-05-15',
        limit: 0,
      );
      expect(r.due, isEmpty);
      expect(r.next, '2026-02-28');
    });
  });

  group('against a brute-force walk', () {
    // An independent calendar: its own month lengths and leap rule.
    bool leap(int y) => y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
    int monthLength(int y, int m) =>
        const [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1] +
        (m == 2 && leap(y) ? 1 : 0);
    String fmt(int y, int m, int d) =>
        '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-'
        '${d.toString().padLeft(2, '0')}';
    (int, int, int) nextDay((int, int, int) date) {
      final (y, m, d) = date;
      if (d < monthLength(y, m)) return (y, m, d + 1);
      if (m < 12) return (y, m + 1, 1);
      return (y + 1, 1, 1);
    }

    (int, int, int) parse(String s) => (
      int.parse(s.substring(0, 4)),
      int.parse(s.substring(5, 7)),
      int.parse(s.substring(8, 10)),
    );

    /// Every payment from the start to [until], by walking.
    List<String> walk(Schedule s, String until) {
      final (sy, sm, sd) = parse(s.startOn);
      final result = <String>[];
      // Daily and weekly: the walk goes on from the previous payment.
      var d = (sy, sm, sd);
      for (var k = 0; ; k++) {
        final String date;
        switch (s.frequency) {
          case Frequency.daily || Frequency.weekly:
            final step = s.interval * (s.frequency == Frequency.weekly ? 7 : 1);
            if (k > 0) {
              for (var i = 0; i < step; i++) {
                d = nextDay(d);
              }
            }
            date = fmt(d.$1, d.$2, d.$3);
          case Frequency.monthly:
            final total = sm - 1 + k * s.interval;
            final y = sy + total ~/ 12;
            final m = total % 12 + 1;
            final len = monthLength(y, m);
            date = fmt(y, m, sd < len ? sd : len);
          case Frequency.yearly:
            final y = sy + k * s.interval;
            final len = monthLength(y, sm);
            date = fmt(y, sm, sd < len ? sd : len);
        }
        if (date.compareTo(until) > 0) return result;
        result.add(date);
      }
    }

    final starts = [
      '2024-01-28',
      '2024-01-29',
      '2024-01-30',
      '2024-01-31',
      '2024-02-29',
      '2025-08-31',
      '2023-12-31',
    ];

    for (final f in Frequency.values) {
      for (final every in [1, 2, 3]) {
        for (final start in starts) {
          test('${f.name} × $every from $start for 5 years', () {
            final s = of(f, start, every: every);
            // 5 years: from 2023–2025 starts, two leap days (2024, 2028) and
            // every month end, at a third of the cost of 10.
            final until = '${int.parse(start.substring(0, 4)) + 5}-12-31';
            final expected = walk(s, until);
            for (var k = 0; k < expected.length; k++) {
              expect(occurrenceAt(s, k), expected[k], reason: 'k = $k');
            }
            // Every day of the range: after, on-or-after and the count.
            var day = parse(addDaysFor(start, -40));
            var i = 0; // first expected index > day
            while (fmt(day.$1, day.$2, day.$3).compareTo(expected.last) < 0) {
              final text = fmt(day.$1, day.$2, day.$3);
              while (i < expected.length && expected[i].compareTo(text) <= 0) {
                i++;
              }
              expect(occurrenceAfter(s, text), expected[i], reason: text);
              expect(occurrencesThrough(s, text), i, reason: text);
              expect(
                occurrenceOnOrAfter(s, text),
                i > 0 && expected[i - 1] == text ? text : expected[i],
                reason: text,
              );
              day = nextDay(day);
            }
            // With an end on a middle payment, nothing goes past it.
            final last = expected.length ~/ 2;
            final ended = of(f, start, every: every, end: expected[last]);
            expect(occurrenceAfter(ended, expected[last]), isNull);
            final (:due, :next) = dueDates(
              ended,
              from: expected[1],
              through: until,
              limit: 100000,
            );
            expect(due, expected.sublist(1, last + 1));
            expect(next, isNull);
          });
        }
      }
    }
  });
}

/// Test-only: a date moved by whole days, by the library's own helper
/// path is avoided on purpose (UTC DateTime is independent enough here).
String addDaysFor(String day, int days) {
  final d = DateTime.utc(
    int.parse(day.substring(0, 4)),
    int.parse(day.substring(5, 7)),
    int.parse(day.substring(8, 10)) + days,
  );
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
