import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/models/recurring_item.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';

import '../../helpers/recurring_fixture.dart';

/// The generator (phase-7a.md §6.3) and "a deleted payment never comes
/// back" (§6.7).
void main() {
  late RecurringFixture f;

  setUp(() async => f = await RecurringFixture.open());

  /// Netflix, monthly from [start] (saved that day), payment 0 only.
  Future<int> monthlyFrom(
    String start, {
    RepeatChoice choice = const RepeatChoice(),
    Money amount = const Money(64900, 'INR'),
  }) async {
    f.setToday(start);
    final (:expense, pastAdded: _) = await f.addRepeating(
      input: f.input(day: start, amount: amount),
      choice: choice,
    );
    return expense.recurringExpenseId!;
  }

  List<String> due(List<(String?, bool, int)> payments) => [
    for (final p in payments) p.$1!,
  ];

  test('nothing due: nothing added, no bump', () async {
    final id = await monthlyFrom('2026-10-09');
    final version = f.dataVersion.value;
    final report = await f.recurring.generateDue();
    expect(report.added, 0);
    expect(due(await f.paymentsOf(id)), ['2026-10-09']);
    expect(f.dataVersion.value, version);
  });

  test(
    'one due: added with the item\'s fields and events, cursor moved',
    () async {
      final id = await monthlyFrom('2026-09-09');
      f.setToday('2026-10-09');
      final version = f.dataVersion.value;
      final report = await f.recurring.generateDue();
      expect(report.added, 1);
      expect(f.dataVersion.value, version + 1);
      expect(due(await f.paymentsOf(id)), ['2026-09-09', '2026-10-09']);
      expect(await f.cursorOf(id), '2026-11-09');
      final added = (await f.recurring.payments(id, limit: 1)).single;
      expect(added.title, 'Netflix');
      expect(added.description, 'Family plan');
      expect(added.categoryId, 17);
      expect(added.paymentMethodId, 4);
      expect(added.eventIds, {2});
      expect(added.amountExpression, isNull);
      expect(added.occurredOn, '2026-10-09');
      expect(added.createdAt, f.clock.now.toUtc());
      // The item's updated_at is untouched: Undo of a Stop compares it.
      expect(
        (await f.itemRow(id))['updated_at'],
        isNot(f.clock.now.millisecondsSinceEpoch),
      );
    },
  );

  test('three due, clamped to the months\' last days', () async {
    final id = await monthlyFrom('2026-01-31');
    f.setToday('2026-04-30');
    // 61 days old: held unless confirmed.
    expect((await f.recurring.generateDue()).added, 0);
    expect((await f.recurring.generateDue(confirmed: true)).added, 3);
    expect(due(await f.paymentsOf(id)), [
      '2026-01-31',
      '2026-02-28',
      '2026-03-31',
      '2026-04-30',
    ]);
    expect(await f.cursorOf(id), '2026-05-31');
  });

  test('run twice, and two runs at once: each payment once', () async {
    final id = await monthlyFrom('2026-07-09');
    f.setToday('2026-09-09');
    final reports = await Future.wait([
      f.recurring.generateDue(),
      f.recurring.generateDue(),
    ]);
    expect(reports.map((r) => r.added).reduce((a, b) => a + b), 2);
    expect((await f.recurring.generateDue()).added, 0);
    expect(due(await f.paymentsOf(id)), [
      '2026-07-09',
      '2026-08-09',
      '2026-09-09',
    ]);
  });

  test('a throw after the second insert rolls the item back; the rerun '
      'adds each payment once', () async {
    final id = await monthlyFrom('2026-06-09');
    final other = await monthlyFrom('2026-06-10');
    f.setToday('2026-09-10');
    await f.db.execute(
      'CREATE TEMP TRIGGER boom BEFORE INSERT ON expenses '
      "WHEN NEW.recurring_due_on = '2026-09-09' "
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );
    final failedRun = await f.recurring.generateDue(confirmed: true);
    expect(failedRun.failed, {id});
    expect(f.recurring.lastFailed, {id});
    expect(due(await f.paymentsOf(id)), ['2026-06-09'], reason: 'rolled back');
    expect(await f.cursorOf(id), '2026-07-09');
    expect(due(await f.paymentsOf(other)), hasLength(4), reason: 'went on');
    await f.db.execute('DROP TRIGGER boom');
    final rerun = await f.recurring.generateDue(confirmed: true);
    expect(rerun.added, 3);
    expect(f.recurring.lastFailed, isEmpty);
    expect(due(await f.paymentsOf(id)), [
      '2026-06-09',
      '2026-07-09',
      '2026-08-09',
      '2026-09-09',
    ]);
  });

  test(
    'the unique index refuses a duplicate even if the check missed it',
    () async {
      final id = await monthlyFrom('2026-09-09');
      // A row the check can't see (another item's id), then moved under it.
      final stray = await f.db.insert('expenses', {
        'title': 'x',
        'amount_minor': 1,
        'currency_code': 'INR',
        'occurred_at': 0,
        'utc_offset_minutes': 0,
        'occurred_on': '2026-10-09',
        'category_id': 1,
        'payment_method_id': 1,
        'recurring_expense_id': id,
        'recurring_due_on': '2026-10-09',
        'created_at': 0,
        'updated_at': 0,
      });
      expect(stray, isPositive);
      f.setToday('2026-10-09');
      final report = await f.recurring.generateDue();
      // The check finds it, so nothing is added and the cursor moves: the
      // payment counts as handled.
      expect(report.added, 0);
      expect(await f.cursorOf(id), '2026-11-09');
      await expectLater(
        f.db.insert('expenses', {
          'title': 'x',
          'amount_minor': 1,
          'currency_code': 'INR',
          'occurred_at': 0,
          'utc_offset_minutes': 0,
          'occurred_on': '2026-10-09',
          'category_id': 1,
          'payment_method_id': 1,
          'recurring_expense_id': id,
          'recurring_due_on': '2026-10-09',
          'created_at': 0,
          'updated_at': 0,
        }),
        throwsA(anything),
      );
    },
  );

  test('an end between payments: cursor null, still running until the '
      'end passes, then archived as expired', () async {
    final id = await monthlyFrom(
      '2026-08-09',
      choice: const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-10-15'),
    );
    f.setToday('2026-10-09');
    await f.recurring.generateDue();
    expect(await f.cursorOf(id), isNull);
    expect((await f.recurring.all()).single.nextDueOn, isNull);
    f.setToday('2026-10-15');
    expect((await f.recurring.generateDue()).expired, 0);
    expect(await f.recurring.all(), hasLength(1));
    f.setToday('2026-10-16');
    final report = await f.recurring.generateDue();
    expect(report.expired, 1);
    expect(await f.recurring.all(), isEmpty);
    final archived = (await f.recurring.archived()).single;
    expect(archived.archiveReason, isNotNull);
    expect(archived.archiveReason!.name, 'expired');
  });

  test('the last payment added after the end passed: archived as expired '
      'in the same run', () async {
    final id = await monthlyFrom(
      '2026-08-09',
      choice: const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-09-15'),
    );
    // Not opened between the last payment (9 Sep) and its end.
    f.setToday('2026-09-20');
    final report = await f.recurring.generateDue();
    expect(report.added, 1);
    expect(report.expired, 1);
    expect(due(await f.paymentsOf(id)), ['2026-08-09', '2026-09-09']);
    expect(await f.recurring.all(), isEmpty);
    expect(
      (await f.recurring.archived()).single.archiveReason!.name,
      'expired',
    );
  });

  test('a backlog of 32 days is held, 31 days is added', () async {
    final held = await monthlyFrom('2026-08-07');
    final added = await monthlyFrom('2026-08-08');
    f.setToday('2026-10-09');
    final report = await f.recurring.generateDue();
    expect(report.held, [
      (
        id: held,
        title: 'Netflix',
        count: 2,
        from: '2026-09-07',
        to: '2026-10-07',
      ),
    ]);
    expect(due(await f.paymentsOf(held)), ['2026-08-07']);
    expect(due(await f.paymentsOf(added)), [
      '2026-08-08',
      '2026-09-08',
      '2026-10-08',
    ]);
    expect((await f.recurring.byId(held))!.hold?.count, 2);
    // Confirmed (Add all) overrides the hold.
    final all = await f.recurring.generateDue(onlyId: held, confirmed: true);
    expect(all.added, 2);
    expect((await f.recurring.byId(held))!.hold, isNull);
  });

  test('1,000 at most per run; the rest is held again next time', () async {
    final id = await monthlyFrom(
      '2026-01-01',
      choice: const RepeatChoice(frequency: Frequency.daily),
    );
    f.setToday('2028-12-31');
    final first = await f.recurring.generateDue(onlyId: id, confirmed: true);
    // Payment 0 is 1 Jan: the 1,000 are 2 Jan 2026 to 27 Sep 2028.
    expect(first.added, 1000);
    // The item's event is on every one, across the 500-date chunks of the
    // batched event copy (plus payment 0's).
    final links = await f.db.rawQuery(
      'SELECT count(*) AS n FROM expense_events WHERE event_id = 2',
    );
    expect(links.single['n'], 1001);
    expect(await f.cursorOf(id), '2028-09-28');
    final next = await f.recurring.generateDue();
    expect(next.held.single.count, 95);
    final rest = await f.recurring.generateDue(onlyId: id, confirmed: true);
    expect(rest.added, 95);
    expect(await f.cursorOf(id), '2029-01-01');
  });

  test(
    'an item with no price is skipped and logged; the others go on',
    () async {
      final broken = await monthlyFrom('2026-09-09');
      final fine = await monthlyFrom('2026-09-10');
      await f.db.delete(
        'recurring_amounts',
        where: 'recurring_expense_id = ?',
        whereArgs: [broken],
      );
      f.setToday('2026-10-10');
      final report = await f.recurring.generateDue();
      expect(report.failed, {broken});
      expect(report.added, 1);
      expect(await f.cursorOf(broken), '2026-10-09', reason: 'untouched');
      expect(due(await f.paymentsOf(fine)), hasLength(2));
      final all = await f.recurring.all();
      expect(all.firstWhere((i) => i.id == broken).isBroken, isTrue);
      expect(all.firstWhere((i) => i.id == fine).isBroken, isFalse);
    },
  );

  test('an unreadable rule makes the item broken, never thrown', () async {
    final id = await monthlyFrom('2026-09-09');
    await f.db.update(
      'recurring_expenses',
      {'frequency': 'fortnightly'},
      where: 'id = ?',
      whereArgs: [id],
    );
    f.setToday('2026-10-09');
    expect((await f.recurring.generateDue()).failed, {id});
    expect((await f.recurring.all()).single.isBroken, isTrue);
    for (final bad in [
      {'frequency': 'monthly', 'interval_count': 0},
      {'interval_count': 1, 'start_on': '2026-02-30'},
      {'start_on': '2026-09-09', 'next_due_on': '9 Oct'},
    ]) {
      await f.db.update(
        'recurring_expenses',
        bad,
        where: 'id = ?',
        whereArgs: [id],
      );
      expect((await f.recurring.all()).single.isBroken, isTrue, reason: '$bad');
    }
  });

  test('an archived event is copied; a deleted one is gone', () async {
    final id = await monthlyFrom('2026-09-09');
    await f.db.insert('recurring_expense_events', {
      'recurring_expense_id': id,
      'event_id': 3,
    });
    await f.db.update('events', {'archived_at': 1}, where: 'id = 2');
    await f.db.delete('events', where: 'id = 3');
    f.setToday('2026-10-09');
    await f.recurring.generateDue();
    expect((await f.recurring.payments(id, limit: 1)).single.eventIds, {2});
  });

  test('a run that only moves a cursor (the payments had rows) still '
      'bumps DataVersion: screens that reload "if changed" kept showing a '
      'gone backlog', () async {
    final id = await monthlyFrom('2026-08-09');
    f.setToday('2026-10-09');
    await f.recurring.generateDue(confirmed: true);
    // As if the cursor were behind rows that exist (e.g. a restored copy).
    await f.db.update(
      'recurring_expenses',
      {'next_due_on': '2026-09-09'},
      where: 'id = ?',
      whereArgs: [id],
    );
    final version = f.dataVersion.value;
    final report = await f.recurring.generateDue();
    expect(report.added, 0);
    expect(await f.cursorOf(id), '2026-11-09');
    expect(f.dataVersion.value, version + 1);
  });

  test('an archived item is never due', () async {
    final id = await monthlyFrom('2026-08-09');
    await f.recurring.archive(id);
    f.setToday('2026-10-09');
    expect((await f.recurring.generateDue()).added, 0);
    expect(due(await f.paymentsOf(id)), ['2026-08-09']);
  });

  test(
    'the price on each date is used; payments already added keep theirs',
    () async {
      final id = await monthlyFrom('2026-08-09');
      await f.recurring.changePrice(id, amountMinor: 69900, from: '2026-09-15');
      f.setToday('2026-10-09');
      await f.recurring.generateDue();
      expect(
        [for (final p in await f.paymentsOf(id)) p.$3],
        [64900, 64900, 69900],
      );
      await f.recurring.changePrice(id, amountMinor: 79900, from: '2026-10-09');
      expect(
        [for (final p in await f.paymentsOf(id)) p.$3],
        [64900, 64900, 69900],
        reason: 'history is never edited',
      );
    },
  );

  group('moments in a fake zone', () {
    test('occurred_on is the due date; occurred_at is the item\'s time '
        'there', () async {
      final fake = await RecurringFixture.open(
        localMoment: (y, m, d, h, min) => (
          occurredAt: DateTime.utc(
            y,
            m,
            d,
            h,
            min,
          ).subtract(const Duration(minutes: -240)),
          offsetMinutes: -240,
        ),
      );
      fake.setToday('2026-09-09');
      final (:expense, pastAdded: _) = await fake.addRepeating(
        input: fake.input(day: '2026-09-09'),
      );
      // Saved at 23:59 the item's time of day would cross into the next UTC
      // day at -04:00; make it 23:59.
      await fake.db.update('recurring_expenses', {
        'time_of_day_minutes': 23 * 60 + 59,
      });
      fake.setToday('2026-10-09');
      await fake.recurring.generateDue();
      final added = (await fake.recurring.payments(
        expense.recurringExpenseId!,
        limit: 1,
      )).single;
      expect(added.occurredOn, '2026-10-09');
      expect(added.utcOffsetMinutes, -240);
      expect(added.occurredAt, DateTime.utc(2026, 10, 10, 3, 59));
      expect(
        localDayOf(added.occurredAt, added.utcOffsetMinutes),
        '2026-10-09',
      );
    });
  });

  group('§6.7: a deleted payment never comes back', () {
    Future<(int, int)> todaysPayment() async {
      final id = await monthlyFrom('2026-09-09');
      f.setToday('2026-10-09');
      await f.recurring.generateDue();
      final payment = (await f.recurring.payments(id, limit: 1)).single;
      expect(payment.recurringDueOn, '2026-10-09');
      return (id, payment.id);
    }

    test('deleted (binned), app reopened', () async {
      final (id, payment) = await todaysPayment();
      await f.expenses.moveToBin(payment);
      expect((await f.recurring.generateDue()).added, 0);
      expect(await f.paymentsOf(id), [
        ('2026-09-09', false, 64900),
        ('2026-10-09', true, 64900),
      ]);
    });

    test('deleted, then Empty bin', () async {
      final (id, payment) = await todaysPayment();
      await f.expenses.moveToBin(payment);
      await f.expenses.emptyBin();
      expect((await f.recurring.generateDue()).added, 0);
      expect(due(await f.paymentsOf(id)), ['2026-09-09']);
    });

    test('deleted, then purged 30 days later', () async {
      final (id, payment) = await todaysPayment();
      await f.expenses.moveToBin(payment);
      f.clock.advance(const Duration(days: 31));
      await f.expenses.purgeBin();
      f.setToday('2026-10-09');
      expect((await f.recurring.generateDue()).added, 0);
      expect(due(await f.paymentsOf(id)), ['2026-09-09']);
    });

    test('deleted, item stopped and restored the same day', () async {
      final (id, payment) = await todaysPayment();
      await f.expenses.moveToBin(payment);
      await f.recurring.archive(id);
      final restored = await f.recurring.restore(id);
      expect(restored.added, 0);
      expect(restored.next, '2026-11-09');
      expect(
        due([
          for (final p in await f.paymentsOf(id))
            if (!p.$2) p,
        ]),
        ['2026-09-09'],
      );
    });

    test('deleted + Empty bin + Stop + Restore', () async {
      final (id, payment) = await todaysPayment();
      await f.expenses.moveToBin(payment);
      await f.expenses.emptyBin();
      await f.recurring.archive(id);
      expect((await f.recurring.restore(id)).added, 0);
      expect(due(await f.paymentsOf(id)), ['2026-09-09']);
    });

    test('deleted, item expired and restored', () async {
      final id = await monthlyFrom(
        '2026-09-09',
        choice: const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-10-09'),
      );
      f.setToday('2026-10-09');
      await f.recurring.generateDue();
      final payment = (await f.recurring.payments(id, limit: 1)).single;
      await f.expenses.moveToBin(payment.id);
      await f.expenses.emptyBin();
      f.setToday('2026-10-10');
      await f.recurring.generateDue();
      expect(
        (await f.recurring.archived()).single.archiveReason!.name,
        'expired',
      );
      final restored = await f.recurring.restore(id);
      expect(restored.endCleared, isTrue);
      expect(restored.added, 0);
      expect(restored.next, '2026-11-09');
      expect(due(await f.paymentsOf(id)), ['2026-09-09']);
    });

    test('stopped with no payment left and an end still ahead: Restore '
        'keeps it so (no payment comes back; §12a)', () async {
      final id = await monthlyFrom(
        '2026-09-09',
        choice: const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-10-20'),
      );
      f.setToday('2026-10-09');
      await f.recurring.generateDue();
      expect(await f.cursorOf(id), isNull);
      final payment = (await f.recurring.payments(id, limit: 1)).single;
      await f.expenses.moveToBin(payment.id);
      await f.expenses.emptyBin();
      await f.recurring.archive(id);
      expect(
        (await f.recurring.archived()).single.archiveReason!.name,
        'stopped',
      );
      final restored = await f.recurring.restore(id);
      expect(restored.endCleared, isFalse);
      expect(
        restored.added,
        0,
        reason: "today's deleted payment stays deleted",
      );
      expect(restored.next, isNull);
      expect(due(await f.paymentsOf(id)), ['2026-09-09']);
    });

    test('two app starts at once', () async {
      final id = await monthlyFrom('2026-09-09');
      f.setToday('2026-10-09');
      await Future.wait([f.recurring.generateDue(), f.recurring.generateDue()]);
      expect(due(await f.paymentsOf(id)), ['2026-09-09', '2026-10-09']);
    });

    test('property: over random sequences the cursor never moves back and '
        'no due date gets two rows or comes back once deleted', () async {
      // One database for every seed, emptied in between: a fresh migrated
      // one per seed was most of this test's time.
      for (var seed = 0; seed < 40; seed++) {
        final random = Random(seed);
        await f.db.delete('expenses');
        await f.db.delete('recurring_expenses');
        f.setToday('2026-01-05');
        final (:expense, pastAdded: _) = await f.addRepeating(
          input: f.input(day: '2026-01-05'),
          choice: RepeatChoice(
            frequency: Frequency.values[random.nextInt(4)],
            intervalText: '${1 + random.nextInt(3)}',
          ),
        );
        final id = expense.recurringExpenseId!;
        var day = '2026-01-05';
        var lastCursor = await f.cursorOf(id);
        final deleted = <String>{};
        ArchiveUndo? undo;
        for (var step = 0; step < 30; step++) {
          switch (random.nextInt(8)) {
            case 0 || 1:
              day = addDays(day, 1 + random.nextInt(20));
              f.setToday(day);
              await f.recurring.generateDue();
            case 2:
              await f.recurring.generateDue(confirmed: true);
            case 3:
              final payments = await f.recurring.payments(id, limit: 3);
              if (payments.isNotEmpty) {
                final p = payments[random.nextInt(payments.length)];
                await f.expenses.moveToBin(p.id);
                deleted.add(p.recurringDueOn!);
              }
            case 4:
              await f.expenses.emptyBin();
            case 5:
              final item = await f.recurring.byId(id);
              if (item != null && !item.isArchived) {
                undo = await f.recurring.archive(id);
              }
            case 6:
              if (undo != null) await f.recurring.undoArchive(undo);
              undo = null;
            case 7:
              final item = await f.recurring.byId(id);
              if (item != null && item.isArchived) {
                await f.recurring.restore(id);
              }
              final held = await f.recurring.byId(id);
              if (held?.hold != null && random.nextBool()) {
                await f.recurring.skipBacklog(id);
              }
          }
          final cursor = await f.cursorOf(id);
          if (lastCursor != null && cursor != null) {
            expect(
              cursor.compareTo(lastCursor),
              greaterThanOrEqualTo(0),
              reason: 'seed $seed step $step',
            );
          }
          if (cursor != null) lastCursor = cursor;
          final rows = await f.db.query(
            'expenses',
            columns: ['recurring_due_on', 'deleted_at'],
            where: 'recurring_expense_id = ?',
            whereArgs: [id],
          );
          final dues = [for (final r in rows) r['recurring_due_on']! as String];
          expect(dues.toSet(), hasLength(dues.length), reason: 'seed $seed');
          for (final r in rows) {
            if (r['deleted_at'] == null) {
              expect(
                deleted,
                isNot(contains(r['recurring_due_on'])),
                reason: 'seed $seed step $step: a deleted payment came back',
              );
            }
          }
        }
      }
    });
  });

  group('a payment re-dated by the user (owner\'s question, 2026-10-10)', () {
    /// Re-dates payment [id] to [day] through the form's path, as an Edit
    /// that only changes the date does.
    Future<void> redate(int id, String day) async {
      final e = (await f.expenses.byId(id))!;
      final moved = f.input(day: day, amount: e.amount, eventIds: e.eventIds);
      await f.expenses.update(id, moved);
    }

    test('paid 5 days late: moved from 9 Nov to 14 Nov → nothing re-added '
        'for 9 Nov, next month on schedule', () async {
      final id = await monthlyFrom('2026-10-09');
      f.setToday('2026-11-09');
      await f.recurring.generateDue();
      final nov = (await f.recurring.payments(id, limit: 1)).single;
      expect(nov.recurringDueOn, '2026-11-09');
      await redate(nov.id, '2026-11-14');
      for (final day in ['2026-11-10', '2026-11-14', '2026-12-09']) {
        f.setToday(day);
        await f.recurring.generateDue();
      }
      final payments = await f.recurring.payments(id);
      expect(
        [for (final p in payments) p.recurringDueOn],
        ['2026-12-09', '2026-11-09', '2026-10-09'],
      );
      // The moved one keeps which payment it is; only its date changed.
      final moved = payments.singleWhere((p) => p.id == nov.id);
      expect(moved.occurredOn, '2026-11-14');
      expect(moved.recurringDueOn, '2026-11-09');
      expect(await f.cursorOf(id), '2027-01-09');
    });

    test('moved into another month (9 Nov paid on 2 Dec) or earlier (paid '
        'on 1 Nov): never a second November payment', () async {
      final id = await monthlyFrom('2026-10-09');
      f.setToday('2026-11-09');
      await f.recurring.generateDue();
      final nov = (await f.recurring.payments(id, limit: 1)).single;
      await redate(nov.id, '2026-12-02');
      f.setToday('2026-12-09');
      await f.recurring.generateDue();
      await redate(nov.id, '2026-11-01');
      f.setToday('2027-01-09');
      await f.recurring.generateDue();
      expect(
        [for (final p in await f.recurring.payments(id)) p.recurringDueOn],
        ['2027-01-09', '2026-12-09', '2026-11-09', '2026-10-09'],
      );
    });

    test(
      'a held backlog doesn\'t count a re-dated payment as missing',
      () async {
        final id = await monthlyFrom('2026-10-09');
        f.setToday('2026-11-09');
        await f.recurring.generateDue();
        final nov = (await f.recurring.payments(id, limit: 1)).single;
        await redate(nov.id, '2026-11-20');
        f.setToday('2027-01-20');
        final item = (await f.recurring.byId(id))!;
        expect(item.hold!.from, '2026-12-09', reason: 'not 9 Nov');
        expect(item.hold!.count, 2);
      },
    );
  });
}
