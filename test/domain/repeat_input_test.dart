import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/recurrence.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';

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
  group('repeatPreview (§5.2 table, today 2026-10-09)', () {
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
      const c = RepeatChoice(endOn: '2000-01-01');
      expect(c.effectiveEndOn, isNull);
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
  });
}
