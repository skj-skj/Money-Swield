import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/recurrence.dart';
import 'package:my_expense_tracker_app/domain/recurring_plan.dart';

const today = '2026-10-09';

Schedule monthlyFrom(String start, {String? end}) => Schedule(
  frequency: Frequency.monthly,
  interval: 1,
  startOn: start,
  endOn: end,
);

TemplatePlan plan(
  Schedule s,
  String? cursor, {
  String on = today,
  bool confirmed = false,
}) => planTemplate(s, cursor: cursor, today: on, confirmed: confirmed);

void main() {
  test('no cursor: nothing due', () {
    expect(plan(monthlyFrom('2026-01-08'), null), isA<NothingDue>());
    expect(
      plan(monthlyFrom('2026-01-08'), null, confirmed: true),
      isA<NothingDue>(),
    );
  });

  test('a cursor after today: nothing due', () {
    expect(plan(monthlyFrom('2026-10-09'), '2026-11-09'), isA<NothingDue>());
  });

  test('due today: added', () {
    final p = plan(monthlyFrom('2026-09-09'), today) as AddPayments;
    expect(p.due, [today]);
    expect(p.next, '2026-11-09');
  });

  test('31 days old: added, not held', () {
    final p = plan(monthlyFrom('2026-08-08'), '2026-09-08') as AddPayments;
    expect(p.due, ['2026-09-08', '2026-10-08']);
    expect(p.next, '2026-11-08');
  });

  test('32 days old: held with the count and the dates', () {
    final p = plan(monthlyFrom('2026-08-07'), '2026-09-07') as HoldPayments;
    expect((p.count, p.from, p.to), (2, '2026-09-07', '2026-10-07'));
  });

  test('confirmed: the same backlog is added', () {
    final p = plan(
      monthlyFrom('2026-08-07'),
      '2026-09-07',
      confirmed: true,
    ) as AddPayments;
    expect(p.due, ['2026-09-07', '2026-10-07']);
  });

  test('daily for three years, confirmed: 1,000 now, the rest next run', () {
    final s = const Schedule(
      frequency: Frequency.daily,
      interval: 1,
      startOn: '2026-01-01',
    );
    final p =
        plan(s, '2026-01-01', on: '2028-12-31', confirmed: true) as AddPayments;
    expect(p.due, hasLength(1000));
    expect(p.next, '2028-09-27');
    final held = plan(s, '2026-01-01', on: '2028-12-31') as HoldPayments;
    expect(held.count, 1096);
    expect(held.to, '2028-12-31');
  });

  test('an end inside the backlog: the hold counts only up to it, and '
      'adding leaves no next', () {
    final s = monthlyFrom('2026-05-07', end: '2026-08-20');
    final held = plan(s, '2026-06-07') as HoldPayments;
    expect((held.count, held.to), (3, '2026-08-07'));
    final added = plan(s, '2026-06-07', confirmed: true) as AddPayments;
    expect(added.due, ['2026-06-07', '2026-07-07', '2026-08-07']);
    expect(added.next, isNull);
  });

  test('a damaged cursor off the schedule is moved, not added as is', () {
    final p = plan(monthlyFrom('2026-01-31'), '2026-09-29') as AddPayments;
    expect(p.due, ['2026-09-30']);
  });

  group('cursorAfterEndChange', () {
    test('a cursor within the new end stays; past it, null', () {
      expect(
        cursorAfterEndChange(
          monthlyFrom('2026-01-31', end: '2026-12-31'),
          cursor: '2026-10-31',
          oldEnd: null,
        ),
        '2026-10-31',
      );
      expect(
        cursorAfterEndChange(
          monthlyFrom('2026-01-31', end: '2026-10-30'),
          cursor: '2026-10-31',
          oldEnd: null,
        ),
        isNull,
      );
    });

    test('no payment was left: the first after the old end, never one '
        'before it', () {
      expect(
        cursorAfterEndChange(
          monthlyFrom('2026-01-31'),
          cursor: null,
          oldEnd: '2026-10-15',
        ),
        '2026-10-31',
      );
      expect(
        cursorAfterEndChange(
          monthlyFrom('2026-01-31', end: '2026-10-20'),
          cursor: null,
          oldEnd: '2026-10-15',
        ),
        isNull,
      );
      expect(
        cursorAfterEndChange(
          monthlyFrom('2026-01-31'),
          cursor: null,
          oldEnd: null,
        ),
        isNull,
      );
    });
  });

  group('planRestore', () {
    test('an end that passed is cleared and named; payments from today', () {
      final r = planRestore(
        monthlyFrom('2026-01-09', end: '2026-09-15'),
        cursor: null,
        today: today,
      );
      expect(r.endPassed, '2026-09-15');
      expect(r.schedule.endOn, isNull);
      expect(r.next, today);
    });

    test(
      'an end still ahead stays; the kept cursor or the next from today',
      () {
        final s = monthlyFrom('2026-01-31', end: '2027-03-31');
        final r = planRestore(s, cursor: '2026-03-31', today: today);
        expect(r.endPassed, isNull);
        expect(r.schedule, s);
        expect(r.next, '2026-10-31');
      },
    );
  });

  group('cursorAfterRestore', () {
    test('a kept cursor: the later of it and today\'s next payment', () {
      final s = monthlyFrom('2026-01-31');
      expect(
        cursorAfterRestore(
          s,
          cursor: '2026-11-30',
          endCleared: false,
          today: today,
        ),
        '2026-11-30',
      );
      expect(
        cursorAfterRestore(
          s,
          cursor: '2026-03-31',
          endCleared: false,
          today: today,
        ),
        '2026-10-31',
      );
      expect(
        cursorAfterRestore(
          monthlyFrom('2026-01-31', end: '2026-10-01'),
          cursor: '2026-09-30',
          endCleared: false,
          today: today,
        ),
        isNull,
      );
    });

    test('no cursor: from today only when the end passed and was cleared', () {
      final s = monthlyFrom('2026-01-09');
      expect(
        cursorAfterRestore(s, cursor: null, endCleared: true, today: today),
        today,
      );
      expect(
        cursorAfterRestore(s, cursor: null, endCleared: false, today: today),
        isNull,
      );
    });
  });

  test('earliestEndFor: the latest of start, today and the newest payment', () {
    expect(
      earliestEndFor(startOn: '2026-01-01', newestPayment: null, today: today),
      today,
    );
    expect(
      earliestEndFor(startOn: '2026-12-25', newestPayment: null, today: today),
      '2026-12-25',
    );
    expect(
      earliestEndFor(
        startOn: '2026-01-01',
        newestPayment: '2026-11-01',
        today: today,
      ),
      '2026-11-01',
    );
  });

  test('dueCount', () {
    final s = monthlyFrom('2026-01-31');
    expect(dueCount(s, cursor: '2026-02-28', today: '2026-05-15'), 3);
    expect(dueCount(s, cursor: '2026-06-30', today: '2026-05-15'), 0);
  });
}
