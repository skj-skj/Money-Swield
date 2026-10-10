import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/recurring_repository.dart';
import 'package:my_expense_tracker_app/domain/models/recurring_item.dart';
import 'package:my_expense_tracker_app/domain/recurring_plan.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/recurring_fixture.dart';

/// Add selected and skips (phase-7b.md §6.1, §6.3; §9: "a skipped payment
/// added anyway", "Add selected adds a wrong date").
void main() {
  late RecurringFixture f;

  setUp(() async => f = await RecurringFixture.open());

  /// Netflix [frequency] from [start], saved that day; payment 0 only.
  Future<int> item({
    String start = '2026-10-09',
    Frequency frequency = Frequency.monthly,
  }) async {
    f.setToday(start);
    final (:expense, pastAdded: _) = await f.addRepeating(
      input: f.input(day: start),
      choice: RepeatChoice(frequency: frequency),
    );
    f.setToday('2026-10-09');
    return expense.recurringExpenseId!;
  }

  List<String> due(List<(String?, bool, int)> payments) => [
    for (final p in payments) p.$1!,
  ];

  Future<List<Map<String, Object?>>> skipRows() =>
      f.db.query('recurring_skips', orderBy: 'due_on');

  group('Add selected', () {
    /// Gym weekly from 3 Aug: 10 payments held (3 Aug … 5 Oct) after the
    /// first, today 9 Oct.
    Future<int> heldGym() async {
      final id = await item(start: '2026-07-27', frequency: Frequency.weekly);
      final held = (await f.recurring.byId(id))!.hold!;
      expect(held.count, 10);
      return id;
    }

    test('the subset ticked is added, the rest never later; the cursor '
        'after today', () async {
      final id = await heldGym();
      final held = (await f.recurring.heldDates(id))!;
      final days = held.days;
      expect(days.first, '2026-08-03');
      expect(days.last, '2026-10-05');
      expect(days, hasLength(10));
      final ticked = {...days}..removeAll({'2026-08-10', '2026-09-14'});
      final version = f.dataVersion.value;
      final outcome = await f.recurring.addSelected(id, ticked, held: held);
      expect(outcome.added, 8);
      expect(outcome.skipped, 2);
      expect(outcome.next, '2026-10-12');
      expect(f.dataVersion.value, version + 1);
      expect(due(await f.paymentsOf(id)), hasLength(9));
      expect(due(await f.paymentsOf(id)), isNot(contains('2026-08-10')));
      // Later runs never add the unticked ones.
      f.setToday('2026-10-12');
      await f.recurring.generateDue(confirmed: true);
      expect(due(await f.paymentsOf(id)), isNot(contains('2026-09-14')));
      expect(due(await f.paymentsOf(id)).last, '2026-10-12');
    });

    test('nothing ticked skips them all, adds nothing', () async {
      final id = await heldGym();
      final held = (await f.recurring.heldDates(id))!;
      final outcome = await f.recurring.addSelected(id, {}, held: held);
      expect(outcome.added, 0);
      expect(outcome.skipped, 10);
      expect(await f.cursorOf(id), '2026-10-12');
      expect((await f.recurring.byId(id))!.hold, isNull);
    });

    test('a foreign date ticked is ignored (a stale list can\'t add a '
        'wrong date)', () async {
      final id = await heldGym();
      final held = (await f.recurring.heldDates(id))!;
      final outcome = await f.recurring.addSelected(id, {
        '2026-08-03',
        '2026-08-04',
        '2026-07-27',
        '2026-10-12',
      }, held: held);
      expect(outcome.added, 1);
      expect(due(await f.paymentsOf(id)), ['2026-07-27', '2026-08-03']);
    });

    test('the cursor moved since the sheet was shown: refused, nothing '
        'written', () async {
      final id = await heldGym();
      final held = (await f.recurring.heldDates(id))!;
      final days = held.days;
      await f.recurring.skipBacklog(id);
      final before = await f.expenseRows();
      final version = f.dataVersion.value;
      await expectLater(
        f.recurring.addSelected(id, days.toSet(), held: held),
        throwsA(isA<RecurringChangeRefused>()),
      );
      expect(await f.expenseRows(), before);
      expect(f.dataVersion.value, version);
    });

    test('a double tap: the second is refused, one set added', () async {
      final id = await heldGym();
      final held = (await f.recurring.heldDates(id))!;
      final days = held.days;
      final results = await Future.wait([
        f.recurring.addSelected(id, days.toSet(), held: held),
        f.recurring
            .addSelected(id, days.toSet(), held: held)
            .then<Object>((o) => o, onError: (Object e) => e),
      ]);
      expect(results.whereType<RecurringChangeRefused>(), hasLength(1));
      expect(due(await f.paymentsOf(id)), hasLength(11));
    });

    test('a failure rolls the whole write back', () async {
      final id = await heldGym();
      final held = (await f.recurring.heldDates(id))!;
      final days = held.days;
      await f.db.execute(
        'CREATE TEMP TRIGGER fail BEFORE INSERT ON expenses '
        "BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      await expectLater(
        f.recurring.addSelected(id, days.toSet(), held: held),
        throwsA(isA<DatabaseException>()),
      );
      await f.db.execute('DROP TRIGGER fail');
      expect(await f.cursorOf(id), held.cursor);
      expect(due(await f.paymentsOf(id)), ['2026-07-27']);
    });

    test("past midnight between the sheet and the tap: the new day's "
        "payment, never listed, isn't skipped unseen", () async {
      final id = await heldGym();
      final held = (await f.recurring.heldDates(id))!;
      // Monday 12 Oct is a payment day; the sheet was read on the 9th.
      f.setToday('2026-10-12');
      final outcome = await f.recurring.addSelected(
        id,
        held.days.toSet(),
        held: held,
      );
      expect(outcome.added, 10);
      expect(outcome.skipped, 0);
      expect(outcome.next, '2026-10-12', reason: 'still due, not skipped');
      await f.recurring.generateDue();
      expect(due(await f.paymentsOf(id)).last, '2026-10-12');
    });

    test("a ticked date with a row already isn't added again; added + "
        'skipped is what the sheet listed', () async {
      final id = await heldGym();
      final held = (await f.recurring.heldDates(id))!;
      // A row for 10 Aug already (only a bug or a damaged file makes one).
      final row = {...(await f.db.query('expenses')).single}
        ..remove('id')
        ..['recurring_due_on'] = '2026-08-10';
      await f.db.insert('expenses', row);
      final outcome = await f.recurring.addSelected(
        id,
        held.days.toSet(),
        held: held,
      );
      expect(outcome.added, 9);
      expect(outcome.skipped, 1);
      expect(due(await f.paymentsOf(id)), hasLength(11));
    });
  });

  group('skips', () {
    test('skipOnce stores it; the generator passes over it and deletes it '
        'once its cursor is past (§9)', () async {
      final id = await item();
      await f.recurring.skipOnce(id, '2026-11-09');
      expect(await f.recurring.skips(after: '2026-10-09'), {
        (itemId: id, day: '2026-11-09'),
      });
      f.setToday('2026-11-10');
      final report = await f.recurring.generateDue();
      expect(report.added, 0);
      expect(due(await f.paymentsOf(id)), ['2026-10-09']);
      expect(await f.cursorOf(id), '2026-12-09');
      expect(await skipRows(), isEmpty);
      f.setToday('2026-12-09');
      await f.recurring.generateDue();
      expect(due(await f.paymentsOf(id)), ['2026-10-09', '2026-12-09']);
    });

    test(
      'a crash before the commit leaves the skip and adds nothing',
      () async {
        final id = await item(frequency: Frequency.weekly);
        await f.recurring.skipOnce(id, '2026-10-16');
        f.setToday('2026-10-23');
        await f.db.execute(
          'CREATE TEMP TRIGGER fail BEFORE INSERT ON expenses '
          "BEGIN SELECT RAISE(ABORT, 'boom'); END",
        );
        final report = await f.recurring.generateDue();
        expect(report.failed, {id});
        await f.db.execute('DROP TRIGGER fail');
        expect(await skipRows(), hasLength(1));
        expect(await f.cursorOf(id), '2026-10-16');
        await f.recurring.generateDue();
        expect(due(await f.paymentsOf(id)), ['2026-10-09', '2026-10-23']);
        expect(await skipRows(), isEmpty);
      },
    );

    test('every refusal of skipOnce; nothing written', () async {
      final id = await item(frequency: Frequency.weekly);
      final archived = await item();
      await f.recurring.archive(archived);
      for (final (itemId, day) in [
        (id, '2026-10-09'), // today: not upcoming
        (id, '2026-10-02'), // past
        (id, '2026-10-17'), // not a payment (a Saturday)
        (id, 'x'),
        (archived, '2026-11-09'), // archived
        (99, '2026-10-16'), // gone
      ]) {
        await expectLater(
          f.recurring.skipOnce(itemId, day),
          throwsA(
            anyOf(
              isA<RecurringChangeRefused>(),
              isA<RecurringItemUnavailable>(),
            ),
          ),
          reason: '$itemId $day',
        );
      }
      expect(await skipRows(), isEmpty);
    });

    test('a day after the end is refused', () async {
      f.setToday('2026-10-09');
      final (:expense, pastAdded: _) = await f.addRepeating(
        choice: const RepeatChoice(
          frequency: Frequency.weekly,
          end: RepeatEnd.afterCount,
          countText: '2',
        ),
      );
      await expectLater(
        f.recurring.skipOnce(expense.recurringExpenseId!, '2026-10-23'),
        throwsA(isA<RecurringChangeRefused>()),
      );
    });

    test(
      'twice → one row, one bump; unskip → back; unskip again → no-op',
      () async {
        final id = await item();
        await f.recurring.skipOnce(id, '2026-11-09');
        final version = f.dataVersion.value;
        await f.recurring.skipOnce(id, '2026-11-09');
        expect(await skipRows(), hasLength(1));
        expect(f.dataVersion.value, version);
        await f.recurring.unskip(id, '2026-11-09');
        expect(await skipRows(), isEmpty);
        expect(f.dataVersion.value, version + 1);
        await f.recurring.unskip(id, '2026-11-09');
        expect(f.dataVersion.value, version + 1);
        f.setToday('2026-11-09');
        await f.recurring.generateDue();
        expect(due(await f.paymentsOf(id)), ['2026-10-09', '2026-11-09']);
      },
    );

    test('a double tap on Skip: one row', () async {
      final id = await item();
      await Future.wait([
        f.recurring.skipOnce(id, '2026-11-09'),
        f.recurring.skipOnce(id, '2026-11-09'),
      ]);
      expect(await skipRows(), hasLength(1));
    });

    test('a stopped item\'s skip goes at the next run once it is past; '
        'a later one stays for a Restore', () async {
      final id = await item(frequency: Frequency.weekly);
      await f.recurring.skipOnce(id, '2026-10-16');
      await f.recurring.skipOnce(id, '2026-11-13');
      await f.recurring.archive(id);
      f.setToday('2026-10-20');
      await f.recurring.generateDue();
      expect([for (final r in await skipRows()) r['due_on']], ['2026-11-13']);
      await f.recurring.restore(id);
      f.setToday('2026-11-13');
      await f.recurring.generateDue();
      expect(due(await f.paymentsOf(id)), isNot(contains('2026-11-13')));
    });

    test('the hold and Add all leave a skip out: "Add all 2" adds 2', () async {
      final id = await item(start: '2026-07-09');
      // Payments 9 Aug, 9 Sep, 9 Oct waiting (held: 9 Aug is 61 days old).
      await f.db.update('recurring_expenses', {
        'next_due_on': '2026-08-09',
      }, where: 'id = $id');
      await f.db.insert('recurring_skips', {
        'recurring_expense_id': id,
        'due_on': '2026-09-09',
        'created_at': 0,
        'updated_at': 0,
      });
      final hold = (await f.recurring.byId(id))!.hold!;
      expect(hold.count, 2);
      expect((await f.recurring.heldDates(id))!.days, [
        '2026-08-09',
        '2026-10-09',
      ]);
      final report = await f.recurring.generateDue(onlyId: id, confirmed: true);
      expect(report.added, 2);
      expect(await skipRows(), isEmpty);
    });

    test('Skip them doesn\'t count a skipped date', () async {
      final id = await item(start: '2026-07-09');
      await f.db.update('recurring_expenses', {
        'next_due_on': '2026-08-09',
      }, where: 'id = $id');
      await f.db.insert('recurring_skips', {
        'recurring_expense_id': id,
        'due_on': '2026-08-09',
        'created_at': 0,
        'updated_at': 0,
      });
      final outcome = await f.recurring.skipBacklog(id);
      expect(outcome.skipped, 1, reason: 'only 9 Sep');
      expect(outcome.added, 1, reason: "today's");
      expect(await skipRows(), isEmpty);
    });

    test('cascade: deleting the item for good deletes its skips', () async {
      final id = await item();
      await f.recurring.skipOnce(id, '2026-11-09');
      await f.recurring.archive(id);
      await f.recurring.delete(id);
      expect(await skipRows(), isEmpty);
    });
  });

  test(
    'a held item\'s list row still reads (no Phase 7a regression)',
    () async {
      final id = await item();
      expect((await f.recurring.byId(id))!.archiveReason, isNull);
      expect(ArchiveReason.values, contains(ArchiveReason.replaced));
      expect(holdAfterDays, 31);
    },
  );
}
