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

  group('a new schedule (phase-7b.md §7.3)', () {
    test('lastHandledOn: the payment before the cursor; none left: the '
        'last before the end', () {
      final s = monthlyFrom('2026-01-31');
      expect(lastHandledOn(s, cursor: '2026-03-31'), '2026-02-28');
      expect(lastHandledOn(s, cursor: '2026-01-31'), isNull);
      // A damaged cursor between payments: the one before it.
      expect(lastHandledOn(s, cursor: '2026-03-15'), '2026-02-28');
      final ends = monthlyFrom('2026-01-31', end: '2026-04-15');
      expect(lastHandledOn(ends, cursor: null), '2026-03-31');
    });

    test('earliestFirstPayment: the day after the last handled date, never '
        'before today', () {
      final s = monthlyFrom('2026-09-09');
      // Netflix: 9 Oct handled (today), cursor 9 Nov: from 10 Oct.
      expect(
        earliestFirstPayment(s, cursor: '2026-11-09', today: today),
        '2026-10-10',
      );
      // Last handled long ago (no payment left, the end ahead): today.
      expect(
        earliestFirstPayment(
          monthlyFrom('2026-01-09', end: '2027-01-01'),
          cursor: null,
          today: '2027-01-05',
        ),
        '2027-01-05',
      );
      // Nothing handled yet can't happen (payment 0 is saved), but reads
      // as today.
      expect(
        earliestFirstPayment(
          monthlyFrom('2026-12-01'),
          cursor: '2026-12-01',
          today: today,
        ),
        today,
      );
    });

    test('paymentsWaiting: a cursor on or before today', () {
      expect(paymentsWaiting(cursor: today, today: today), isTrue);
      expect(paymentsWaiting(cursor: '2026-08-09', today: today), isTrue);
      expect(paymentsWaiting(cursor: '2026-10-10', today: today), isFalse);
      expect(paymentsWaiting(cursor: null, today: today), isFalse);
    });
  });

  group('Add selected (phase-7b.md §5.2: held monthly 09-07, 10-07; today '
      '10-09)', () {
    final s = monthlyFrom('2026-08-07');
    ({List<String> add, int listed, String? next}) select(
      Set<String> ticked, {
      String cursor = '2026-09-07',
      Set<String> skipped = const {},
    }) => selectedPlan(
      s,
      cursor: cursor,
      today: today,
      ticked: ticked,
      skipped: skipped,
    );

    test('{10-07} → adds 10-07, cursor 11-07', () {
      final p = select({'2026-10-07'});
      expect(p.add, ['2026-10-07']);
      expect(p.next, '2026-11-07');
    });

    test('nothing ticked → adds nothing, cursor 11-07 (skipped for good)', () {
      final p = select({});
      expect(p.add, isEmpty);
      expect(p.listed, 2);
      expect(p.next, '2026-11-07');
    });

    test('a date that isn\'t held (08-07, already handled) is ignored', () {
      final p = select({'2026-09-07', '2026-08-07', '2026-09-08', 'x'});
      expect(p.add, ['2026-09-07']);
      expect(p.next, '2026-11-07');
    });

    test('a skipped date ticked (a stale list) is not added', () {
      final p = select({'2026-09-07', '2026-10-07'}, skipped: {'2026-10-07'});
      expect(p.add, ['2026-09-07']);
    });

    test('over 1,000 waiting: the cursor goes to the first not listed, '
        'still waiting (never skipped unseen)', () {
      final daily = Schedule(
        frequency: Frequency.daily,
        interval: 1,
        startOn: '2023-01-01',
      );
      final p = selectedPlan(
        daily,
        cursor: '2023-01-02',
        today: today,
        ticked: {'2023-01-02'},
      );
      expect(p.add, ['2023-01-02']);
      expect(p.next, '2025-09-28', reason: 'the 1,001st date');
      expect(p.next!.compareTo(today) < 0, isTrue);
    });
  });

  group('planTemplate with skips (phase-7b.md §5.2)', () {
    test('cursor 09-07 (monthly), 09-07 skipped, today 10-09: Add [10-07] '
        '(2 days old: not held)', () {
      final p = planTemplate(
        monthlyFrom('2026-08-07'),
        cursor: '2026-09-07',
        today: today,
        confirmed: false,
        skipped: {'2026-09-07'},
      );
      expect(p, isA<AddPayments>());
      expect((p as AddPayments).due, ['2026-10-07']);
      expect(p.next, '2026-11-07');
    });

    test('cursor 10-09, 10-09 skipped: Add [], next 11-09 (the cursor still '
        'moves)', () {
      final p = planTemplate(
        monthlyFrom('2026-09-09'),
        cursor: today,
        today: today,
        confirmed: false,
        skipped: {today},
      );
      expect(p, isA<AddPayments>());
      expect((p as AddPayments).due, isEmpty);
      expect(p.next, '2026-11-09');
    });

    test('a hold counts without the skips, from the oldest real one', () {
      final p = planTemplate(
        monthlyFrom('2026-01-09'),
        cursor: '2026-05-09',
        today: today,
        confirmed: false,
        skipped: {'2026-05-09', '2026-10-09', '2026-07-15'},
      );
      expect(p, isA<HoldPayments>());
      final hold = p as HoldPayments;
      // 05-09 … 10-09 is 6; two of them skipped (07-15 isn't a payment).
      expect(hold.count, 4);
      expect(hold.from, '2026-06-09');
      expect(hold.to, '2026-09-09');
    });

    test('confirmed (Add all) adds every one but the skipped', () {
      final p = planTemplate(
        monthlyFrom('2026-01-09'),
        cursor: '2026-05-09',
        today: today,
        confirmed: true,
        skipped: {'2026-05-09'},
      );
      expect((p as AddPayments).due, [
        '2026-06-09',
        '2026-07-09',
        '2026-08-09',
        '2026-09-09',
        '2026-10-09',
      ]);
      expect(p.next, '2026-11-09');
    });
  });

  group('runningRelatives (P7b-3)', () {
    Map<int, FamilyLink> family(Map<int, (int?, bool)> rows) => {
      for (final MapEntry(key: id, value: (parent, running)) in rows.entries)
        id: (replacesId: parent, running: running),
    };

    test('A → B: restoring A finds B; restoring B (swapped out) finds A', () {
      final items = family({1: (null, false), 2: (1, true)});
      expect(runningRelatives(1, items), [2]);
      final swapped = family({1: (null, true), 2: (1, false)});
      expect(runningRelatives(2, swapped), [1]);
    });

    test('a chain A → B → C: restoring A finds C, B is archived', () {
      final items = family({1: (null, false), 2: (1, false), 3: (2, true)});
      expect(runningRelatives(1, items), [3]);
      expect(runningRelatives(2, items), [3]);
    });

    test('A replaced twice (A → B, swap back, A → C): restoring B finds C '
        'through A', () {
      final items = family({1: (null, false), 2: (1, false), 3: (1, true)});
      expect(runningRelatives(2, items), [3]);
    });

    test('nothing running, other families and itself left out', () {
      final items = family({
        1: (null, false),
        2: (1, false),
        3: (null, true),
        4: (null, false),
      });
      expect(runningRelatives(1, items), isEmpty);
      expect(runningRelatives(4, items), isEmpty);
      expect(runningRelatives(3, items), isEmpty);
    });

    test('a damaged loop or a missing parent ends', () {
      final loop = family({1: (2, false), 2: (1, true)});
      expect(runningRelatives(1, loop), [2]);
      final orphan = family({2: (99, false), 3: (2, true)});
      expect(runningRelatives(2, orphan), [3]);
    });
  });
}
