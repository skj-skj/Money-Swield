import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/recurrence.dart';
import 'package:money_swield/domain/repeat_input.dart';

const today = '2026-10-09';

RepeatChoice choice({
  Frequency frequency = Frequency.monthly,
  String every = '1',
  String? endOn,
}) => RepeatChoice(
  frequency: frequency,
  intervalText: every,
  end: endOn == null ? RepeatEnd.never : RepeatEnd.onDate,
  endOn: endOn,
);

RepeatError? check(RepeatChoice c, String start) =>
    validateRepeat(c, startOn: start, today: today);

({List<String> past, String? next}) preview(RepeatChoice c, String start) =>
    repeatPreview(c, startOn: start, today: today);

void main() {
  group('repeatPreview (today 2026-10-09)', () {
    test('monthly from today: nothing earlier, next month', () {
      final p = preview(choice(), today);
      expect(p.past, isEmpty);
      expect(p.next, '2026-11-09');
    });

    test('monthly from 31 Jul: 31 Aug and 30 Sep earlier, next 31 Oct', () {
      final p = preview(choice(), '2026-07-31');
      expect(p.past, ['2026-08-31', '2026-09-30']);
      expect(p.next, '2026-10-31');
    });

    test('yearly from a future date: nothing earlier, the year after', () {
      final p = preview(choice(frequency: Frequency.yearly), '2026-12-25');
      expect(p.past, isEmpty);
      expect(p.next, '2027-12-25');
    });

    test('ends before the second payment: no more payments', () {
      final p = preview(choice(endOn: '2026-09-15'), '2026-08-31');
      expect(p.past, isEmpty);
      expect(p.next, isNull);
      expect(check(choice(endOn: '2026-09-15'), '2026-08-31'), isNull);
    });

    test('ends on the start: this payment only', () {
      final p = preview(choice(endOn: today), today);
      expect(p.past, isEmpty);
      expect(p.next, isNull);
      expect(check(choice(endOn: today), today), isNull);
    });

    test('today is a payment: it is among the earlier ones', () {
      final p = preview(choice(frequency: Frequency.daily), '2026-10-07');
      expect(p.past, ['2026-10-08', '2026-10-09']);
      expect(p.next, '2026-10-10');
    });

    test('never ending from lastEndOn: valid, no next', () {
      expect(check(choice(), lastEndOn), isNull);
      expect(preview(choice(), lastEndOn).next, isNull);
    });
  });

  group('validateRepeat', () {
    test('Every must be 1 to 99', () {
      for (final text in [
        '',
        '0',
        '00',
        '100',
        '-1',
        '1.5',
        ' 1',
        'a',
        '1000',
      ]) {
        expect(
          check(choice(every: text), today),
          RepeatError.intervalRange,
          reason: '"$text"',
        );
      }
      for (final text in ['1', '99', '07', '007']) {
        expect(check(choice(every: text), today), isNull, reason: '"$text"');
      }
      expect(choice(every: '007').interval, 7);
    });

    test('the interval is checked first', () {
      expect(
        check(choice(every: '0', endOn: '2000-01-01'), today),
        RepeatError.intervalRange,
      );
    });

    test('an end before the start, after lastEndOn, or missing', () {
      expect(
        check(choice(endOn: '2026-10-08'), today),
        RepeatError.endBeforeStart,
      );
      expect(check(choice(endOn: '2201-01-01'), today), RepeatError.endTooLate);
      expect(check(choice(endOn: lastEndOn), today), isNull);
      expect(
        check(const RepeatChoice(end: RepeatEnd.onDate), today),
        RepeatError.endMissing,
      );
      expect(
        check(
          const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-02-30'),
          today,
        ),
        RepeatError.endMissing,
      );
    });

    test('an end kept while Never is chosen is not checked', () {
      const c = RepeatChoice(endOn: '2000-01-01', countText: '0');
      expect(scheduleFor(c, today).endOn, isNull);
      expect(check(c, today), isNull);
    });

    test('at most 1,000 earlier payments', () {
      expect(
        pastPaymentCount(
          choice(frequency: Frequency.daily),
          startOn: '2023-01-01',
          today: today,
        ),
        1377,
      );
      expect(
        check(choice(frequency: Frequency.daily), '2023-01-01'),
        RepeatError.tooManyPast,
      );
      expect(check(choice(frequency: Frequency.daily), '2024-01-13'), isNull);
      expect(
        preview(choice(frequency: Frequency.daily), '2024-01-13').past,
        hasLength(1000),
      );
      expect(
        check(choice(frequency: Frequency.daily), '2024-01-12'),
        RepeatError.tooManyPast,
      );
      expect(
        pastPaymentCount(choice(), startOn: '1900-01-31', today: today),
        1520,
      );
      expect(check(choice(), '1900-01-31'), RepeatError.tooManyPast);
    });

    test('an end limits the count: a long backlog that ends early is fine', () {
      expect(
        check(
          choice(frequency: Frequency.daily, endOn: '2023-06-30'),
          '2023-01-01',
        ),
        isNull,
      );
    });
  });

  group('scheduleFor', () {
    test('the stored rule: interval read, the end only when chosen', () {
      expect(
        scheduleFor(choice(every: '3', endOn: '2027-04-09'), '2026-10-09'),
        const Schedule(
          frequency: Frequency.monthly,
          interval: 3,
          startOn: '2026-10-09',
          endOn: '2027-04-09',
        ),
      );
      expect(
        scheduleFor(const RepeatChoice(endOn: '2027-04-09'), today).endOn,
        isNull,
      );
    });

    test('an invalid interval is an error, never a guess', () {
      expect(() => scheduleFor(choice(every: ''), today), throwsArgumentError);
    });
  });

  test('isValidDay', () {
    expect(isValidDay('2026-02-28'), isTrue);
    expect(isValidDay('2028-02-29'), isTrue);
    for (final bad in [
      '2026-02-29',
      '2026-13-01',
      '2026-1-1',
      '31-12-2026',
      '',
      '2026-10-09T00:00',
    ]) {
      expect(isValidDay(bad), isFalse, reason: bad);
    }
  });

  test('RepeatChoice equality covers every field', () {
    const a = RepeatChoice();
    expect(a, const RepeatChoice());
    expect(a == a.copyWith(frequency: Frequency.weekly), isFalse);
    expect(a == a.copyWith(intervalText: '2'), isFalse);
    expect(a == a.copyWith(end: RepeatEnd.onDate), isFalse);
    expect(a == a.copyWith(endOn: '2027-01-01'), isFalse);
    expect(a == a.copyWith(countText: '3'), isFalse);
    expect(a.hashCode == a.copyWith(countText: '3').hashCode, isFalse);
  });

  group('after N payments (today 2026-10-09)', () {
    RepeatChoice after(
      String count, {
      Frequency frequency = Frequency.monthly,
      String every = '1',
    }) => RepeatChoice(
      frequency: frequency,
      intervalText: every,
      end: RepeatEnd.afterCount,
      countText: count,
    );

    test('weekly from today, after 3: ends on the third payment', () {
      final c = after('3', frequency: Frequency.weekly);
      expect(check(c, today), isNull);
      expect(scheduleFor(c, today).endOn, '2026-10-23');
      expect(lastOccurrence(scheduleFor(c, today)), '2026-10-23');
      // Payments: 10-09, 10-16, 10-23: three in all, this one included.
      expect(occurrencesThrough(scheduleFor(c, today), '2200-12-31'), 3);
    });

    test('count texts: 2 and 999 pass; empty, 0, 1, 1000, abc refused', () {
      for (final ok in ['2', '999', '02']) {
        expect(check(after(ok), today), isNull, reason: ok);
      }
      for (final bad in ['', '0', '1', '1000', 'abc', '-2', '9999']) {
        expect(check(after(bad), today), RepeatError.countRange, reason: bad);
        expect(scheduleOrNull(after(bad), today), isNull, reason: bad);
      }
    });

    test('an N-th payment past 2200-12-31 is endTooLate, never stored', () {
      // Yearly × 99 after 999 would end in year 100828; monthly × 99 in
      // 10260: both read wrong as text ("100828" < "2200").
      expect(
        check(after('999', frequency: Frequency.yearly, every: '99'), today),
        RepeatError.endTooLate,
      );
      expect(check(after('999', every: '99'), today), RepeatError.endTooLate);
      expect(
        check(
          after('2', frequency: Frequency.yearly, every: '10'),
          '2200-12-31',
        ),
        RepeatError.endTooLate,
      );
      expect(
        scheduleOrNull(
          after('999', frequency: Frequency.yearly, every: '99'),
          today,
        ),
        isNull,
      );
      expect(
        () => scheduleFor(
          after('999', frequency: Frequency.yearly, every: '99'),
          today,
        ),
        throwsArgumentError,
      );
    });

    test('yearly from today, after 175: ends 2200-10-09, valid', () {
      final c = after('175', frequency: Frequency.yearly);
      expect(check(c, today), isNull);
      expect(scheduleFor(c, today).endOn, '2200-10-09');
    });

    test('the end of a back-dated start counts the earlier payments', () {
      // Monthly from 9 Aug, after 3: 9 Aug, 9 Sep, 9 Oct; nothing next.
      final c = after('3');
      final p = preview(c, '2026-08-09');
      expect(p.past, ['2026-09-09', '2026-10-09']);
      expect(p.next, isNull);
    });

    test('property: no accepted choice stores a year past 2200', () {
      // Every frequency × interval 1–99 × count 2–999 from 2026-10-09 (and
      // from the last day allowed): an accepted end is a 4-digit date on
      // or before 2200-12-31; a refused one is endTooLate.
      for (final start in [today, '2200-12-01']) {
        for (final f in Frequency.values) {
          for (var every = 1; every <= 99; every += 7) {
            for (final count in [2, 3, 12, 100, 175, 500, 998, 999]) {
              final c = after('$count', frequency: f, every: '$every');
              final error = check(c, start);
              if (error == null) {
                final endOn = scheduleFor(c, start).endOn!;
                expect(isValidDay(endOn), isTrue, reason: '$c $endOn');
                expect(endOn.compareTo(lastEndOn) <= 0, isTrue, reason: '$c');
              } else {
                expect(
                  error,
                  anyOf(RepeatError.endTooLate, RepeatError.tooManyPast),
                  reason: '$c',
                );
              }
            }
          }
        }
      }
    });
  });

  group('lastOccurrence', () {
    test('no end: none; an end between payments: the payment before', () {
      const s = Schedule(
        frequency: Frequency.monthly,
        interval: 1,
        startOn: '2026-01-31',
      );
      expect(lastOccurrence(s), isNull);
      const ends = Schedule(
        frequency: Frequency.monthly,
        interval: 1,
        startOn: '2026-01-31',
        endOn: '2026-03-15',
      );
      expect(lastOccurrence(ends), '2026-02-28');
      const beforeStart = Schedule(
        frequency: Frequency.monthly,
        interval: 1,
        startOn: '2026-01-31',
        endOn: '2026-01-01',
      );
      expect(lastOccurrence(beforeStart), isNull);
    });
  });
}
