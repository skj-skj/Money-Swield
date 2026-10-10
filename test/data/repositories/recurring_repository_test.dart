import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/recurring_repository.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/models/recurring_item.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';

import '../../helpers/recurring_fixture.dart';
import '../../helpers/test_database.dart';

/// `RecurringRepository` (phase-7a.md §6.1) apart from the generator.
void main() {
  late RecurringFixture f;

  setUp(() async => f = await RecurringFixture.open());

  Future<int> item({
    String start = '2026-10-09',
    RepeatChoice choice = const RepeatChoice(),
    Money amount = const Money(64900, 'INR'),
    String title = 'Netflix',
  }) async {
    // Saved today (2026-10-09): a start before it adds the earlier payments.
    final (:expense, pastAdded: _) = await f.addRepeating(
      input: f.input(day: start, amount: amount, title: title),
      choice: choice,
    );
    return expense.recurringExpenseId!;
  }

  RecurringEdit edit({
    String title = 'Netflix 4K',
    String? endOn,
    Set<int> eventIds = const {3},
    int time = 1200,
  }) => RecurringEdit(
    title: title,
    description: null,
    categoryId: 13,
    paymentMethodId: 2,
    eventIds: eventIds,
    timeOfDayMinutes: time,
    endOn: endOn,
  );

  group('reads', () {
    test(
      'all(): running items with price today, events, payments, hold',
      () async {
        final id = await item(start: '2026-08-09');
        final archivedId = await item(title: 'Old');
        await f.recurring.archive(archivedId);
        final all = await f.recurring.all();
        expect(all, hasLength(1));
        final netflix = all.single;
        expect(netflix.id, id);
        expect(netflix.price, const Money(64900, 'INR'));
        expect(netflix.eventIds, {2});
        expect(netflix.paymentCount, 3);
        expect(netflix.nextDueOn, '2026-11-09');
        expect(netflix.hold, isNull);
        expect(netflix.isBroken, isFalse);
        expect(netflix.isArchived, isFalse);
      },
    );

    test('an item that has not started shows its first price', () async {
      await item(
        start: '2026-12-25',
        choice: const RepeatChoice(frequency: Frequency.yearly),
      );
      expect((await f.recurring.all()).single.priceMinor, 64900);
    });

    test('a binned payment is not counted', () async {
      final id = await item(start: '2026-08-09');
      final latest = (await f.recurring.payments(id, limit: 1)).single;
      await f.expenses.moveToBin(latest.id);
      expect((await f.recurring.byId(id))!.paymentCount, 2);
    });

    test('archived(): newest archived first, labelled', () async {
      final first = await item(title: 'A');
      final second = await item(title: 'B');
      await f.recurring.archive(first);
      f.clock.advance(const Duration(minutes: 1));
      await f.recurring.archive(second);
      final archived = await f.recurring.archived();
      expect(archived.map((i) => i.id), [second, first]);
      expect(archived.first.archiveReason, ArchiveReason.stopped);
      expect(archived.first.archivedOn, '2026-10-09');
    });

    test('archived() and all() with nothing to list: empty, never a throw '
        '(an empty archive threw, so the Archive kept its last row)', () async {
      expect(await f.recurring.archived(), isEmpty);
      expect(await f.recurring.all(), isEmpty);
      final id = await item();
      await f.recurring.archive(id);
      await f.recurring.restore(id);
      expect(await f.recurring.archived(), isEmpty);
    });

    test('counts', () async {
      await item(title: 'A');
      final b = await item(title: 'B');
      await f.recurring.archive(b);
      expect(await f.recurring.counts(), (running: 1, archived: 1));
    });

    test('byId: running or archived; null once gone', () async {
      final id = await item();
      await f.recurring.archive(id);
      expect((await f.recurring.byId(id))!.isArchived, isTrue);
      await f.recurring.delete(id);
      expect(await f.recurring.byId(id), isNull);
    });

    test('the probe passes with a broken item (R4)', () async {
      final id = await item();
      await f.db.delete(
        'recurring_amounts',
        where: 'recurring_expense_id = ?',
        whereArgs: [id],
      );
      await f.db.update('recurring_expenses', {'frequency': '?'});
      await RecurringRepository.probe(f.db);
      expect((await f.recurring.all()).single.isBroken, isTrue);
    });
  });

  group('update', () {
    test('saves the editable fields and replaces the events; the schedule, '
        'currency and cursor stay', () async {
      final id = await item(amount: const Money(1250, 'KWD'));
      final before = await f.itemRow(id);
      f.clock.advance(const Duration(minutes: 5));
      await f.recurring.update(id, edit());
      final after = await f.itemRow(id);
      expect(after['title'], 'Netflix 4K');
      expect(after['description'], isNull);
      expect(after['category_id'], 13);
      expect(after['payment_method_id'], 2);
      expect(after['time_of_day_minutes'], 1200);
      for (final kept in [
        'currency_code',
        'frequency',
        'interval_count',
        'start_on',
        'next_due_on',
        'created_at',
      ]) {
        expect(after[kept], before[kept], reason: kept);
      }
      expect(after['updated_at'], f.clock.now.millisecondsSinceEpoch);
      expect((await f.recurring.byId(id))!.eventIds, {3});
    });

    test('an end before today, before a payment already added (binned '
        'too), or after 2200-12-31 is refused', () async {
      final id = await item(start: '2026-08-09');
      // Today's payment, binned: still counts.
      final today = (await f.recurring.payments(id, limit: 1)).single;
      await f.expenses.moveToBin(today.id);
      expect(await f.recurring.newestPaymentOn(id), '2026-10-09');
      for (final bad in [
        '2026-10-08',
        '2026-09-30',
        '2201-01-01',
        '2026-02-30',
      ]) {
        await expectLater(
          f.recurring.update(id, edit(endOn: bad)),
          throwsA(isA<RecurringChangeRefused>()),
          reason: bad,
        );
      }
      await f.recurring.update(id, edit(endOn: '2026-10-09'));
      await f.recurring.update(id, edit(endOn: lastEndOn));
    });

    test('a future payment already added holds the end back too', () async {
      // Save a payment dated after today: the first payment is 25 Dec.
      final id = await item(start: '2026-12-25');
      await expectLater(
        f.recurring.update(id, edit(endOn: '2026-12-24')),
        throwsA(isA<RecurringChangeRefused>()),
      );
    });

    test('an end with no payment left after the cursor sets it null', () async {
      final id = await item();
      await f.recurring.update(id, edit(endOn: '2026-11-01'));
      expect(await f.cursorOf(id), isNull);
      expect(
        (await f.recurring.byId(id))!.isArchived,
        isFalse,
        reason: 'still running until the end passes',
      );
    });

    test(
      'an end extended on an item with no payment left: payments start '
      'again after the old end (§12a: it would add nothing ever again)',
      () async {
        final id = await item(
          choice: const RepeatChoice(
            end: RepeatEnd.onDate,
            endOn: '2026-10-20',
          ),
        );
        expect(await f.cursorOf(id), isNull);
        await f.recurring.update(id, edit(endOn: '2027-03-31'));
        expect(await f.cursorOf(id), '2026-11-09');
        await f.recurring.update(id, edit(endOn: '2026-10-20'));
        expect(await f.cursorOf(id), isNull);
        await f.recurring.update(id, edit());
        expect(await f.cursorOf(id), '2026-11-09');
      },
    );

    test('an archived item opens read-only: update refused', () async {
      final id = await item();
      await f.recurring.archive(id);
      await expectLater(
        f.recurring.update(id, edit()),
        throwsA(isA<RecurringItemUnavailable>()),
      );
      await expectLater(
        f.recurring.update(999, edit()),
        throwsA(isA<RecurringItemUnavailable>()),
      );
    });
  });

  group('prices (§5.4)', () {
    test('every row of the table', () async {
      final id = await item(start: '2026-07-09');
      Future<List<PricePointView>> prices() async => [
        for (final p in await f.recurring.prices(id)) (p.from, p.amountMinor),
      ];
      // Before the start.
      await expectLater(
        f.recurring.changePrice(id, amountMinor: 1, from: '2026-07-08'),
        throwsA(isA<RecurringChangeRefused>()),
      );
      // Up to today, free: a new price.
      await f.recurring.changePrice(id, amountMinor: 59900, from: '2026-09-01');
      // Up to today, taken (and the first): in force.
      for (final taken in ['2026-09-01', '2026-07-09']) {
        await expectLater(
          f.recurring.changePrice(id, amountMinor: 1, from: taken),
          throwsA(isA<RecurringChangeRefused>()),
        );
      }
      // After today: scheduled, then replaced.
      await f.recurring.changePrice(id, amountMinor: 69900, from: '2027-01-09');
      await f.recurring.changePrice(id, amountMinor: 79900, from: '2027-01-09');
      expect(await prices(), [
        ('2026-07-09', 64900),
        ('2026-09-01', 59900),
        ('2027-01-09', 79900),
      ]);
      // Payments already added keep theirs.
      expect([
        for (final p in await f.paymentsOf(id)) p.$3,
      ], everyElement(64900));
    });

    test('an amount not above 0 or a bad date is refused', () async {
      final id = await item();
      for (final amount in [0, -5]) {
        await expectLater(
          f.recurring.changePrice(id, amountMinor: amount, from: '2026-11-09'),
          throwsA(isA<RecurringChangeRefused>()),
        );
      }
      await expectLater(
        f.recurring.changePrice(id, amountMinor: 5, from: '9-11-2026'),
        throwsA(isA<RecurringChangeRefused>()),
      );
    });

    test('KWD: 1.250 stays 1250 minor units', () async {
      final id = await item(amount: const Money(1250, 'KWD'));
      await f.recurring.changePrice(id, amountMinor: 1500, from: '2026-11-09');
      expect((await f.recurring.prices(id)).last.amountMinor, 1500);
    });

    test(
      'removePrice: a scheduled one goes; in force and the first stay',
      () async {
        final id = await item(start: '2026-07-09');
        await f.recurring.changePrice(
          id,
          amountMinor: 59900,
          from: '2026-09-01',
        );
        await f.recurring.changePrice(
          id,
          amountMinor: 69900,
          from: '2027-01-09',
        );
        await f.recurring.removePrice(id, '2027-01-09');
        for (final kept in ['2026-09-01', '2026-07-09', '2027-05-05']) {
          await expectLater(
            f.recurring.removePrice(id, kept),
            throwsA(isA<RecurringChangeRefused>()),
          );
        }
        expect(await f.recurring.prices(id), hasLength(2));
      },
    );

    test('archived: prices are read-only', () async {
      final id = await item();
      await f.recurring.archive(id);
      await expectLater(
        f.recurring.changePrice(id, amountMinor: 5, from: '2026-11-09'),
        throwsA(isA<RecurringItemUnavailable>()),
      );
    });
  });

  group('Stop, Undo, Restore', () {
    test('Stop of an item that has not started keeps its cursor', () async {
      final id = await item(
        start: '2026-12-25',
        choice: const RepeatChoice(frequency: Frequency.yearly),
      );
      final cursor = await f.cursorOf(id);
      await f.recurring.archive(id);
      expect(await f.cursorOf(id), cursor);
      expect(
        (await f.recurring.archived()).single.archiveReason,
        ArchiveReason.stopped,
      );
    });

    test('Stop twice: the second is refused', () async {
      final id = await item();
      await f.recurring.archive(id);
      await expectLater(
        f.recurring.archive(id),
        throwsA(isA<RecurringItemUnavailable>()),
      );
    });

    test('Stop of a held item: archived, no hold; Undo: held again', () async {
      final id = await item(start: '2026-08-01');
      f.setToday('2026-10-09');
      await f.db.update('recurring_expenses', {'next_due_on': '2026-08-01'});
      await f.db.delete('expenses', where: "recurring_due_on > '2026-08-01'");
      expect((await f.recurring.byId(id))!.hold, isNotNull);
      final undo = await f.recurring.archive(id);
      expect((await f.recurring.byId(id))!.hold, isNull);
      expect(await f.recurring.undoArchive(undo), isTrue);
      expect((await f.recurring.byId(id))!.hold?.count, 3);
    });

    test('Undo after the item changed (restored and stopped again) does '
        'nothing', () async {
      final id = await item();
      final undo = await f.recurring.archive(id);
      await f.recurring.restore(id);
      f.clock.advance(const Duration(seconds: 1));
      await f.recurring.archive(id);
      expect(await f.recurring.undoArchive(undo), isFalse);
      expect((await f.recurring.byId(id))!.isArchived, isTrue);
    });

    test('Restore: from today, the archived gap is not caught up', () async {
      final id = await item(start: '2026-07-09');
      await f.recurring.archive(id);
      f.setToday('2027-01-20');
      final outcome = await f.recurring.restore(id);
      expect(outcome.added, 0);
      expect(outcome.next, '2027-02-09');
      expect(outcome.endCleared, isFalse);
      expect(
        [for (final p in await f.paymentsOf(id)) p.$1],
        ['2026-07-09', '2026-08-09', '2026-09-09', '2026-10-09'],
      );
    });

    test('Restore on a due day adds that day\'s payment', () async {
      final id = await item(start: '2026-07-09');
      await f.recurring.archive(id);
      f.setToday('2027-01-09');
      final outcome = await f.recurring.restore(id);
      expect(outcome.added, 1);
      expect(outcome.next, '2027-02-09');
    });

    test('Restore of an expired item clears its end', () async {
      final id = await item(
        choice: const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-10-20'),
      );
      f.setToday('2026-10-21');
      await f.recurring.generateDue();
      final archived = (await f.recurring.archived()).single;
      expect(archived.archiveReason, ArchiveReason.expired);
      f.setToday('2026-12-01');
      final outcome = await f.recurring.restore(id);
      expect(outcome.endCleared, isTrue);
      expect((await f.itemRow(id))['end_on'], isNull);
      expect(outcome.next, '2026-12-09');
    });

    test('Restore of a running item is refused', () async {
      final id = await item();
      await expectLater(
        f.recurring.restore(id),
        throwsA(isA<RecurringItemUnavailable>()),
      );
    });
  });

  test('byIds: the items that exist, by id, in one read', () async {
    final a = await item();
    final b = await item(start: '2026-08-09');
    final read = await f.recurring.byIds({a, b, 999});
    expect(read.keys, unorderedEquals([a, b]));
    expect(read[b]!.paymentCount, 3);
    expect(await f.recurring.byIds({}), isEmpty);
  });

  group('delete for good', () {
    test('a running item is refused', () async {
      final id = await item();
      await expectLater(
        f.recurring.delete(id),
        throwsA(isA<RecurringItemUnavailable>()),
      );
      expect(await f.recurring.byId(id), isNotNull);
    });

    test('an archived one: payments, active and binned, stay unmarked; '
        'prices and events go', () async {
      final id = await item(start: '2026-08-09');
      final latest = (await f.recurring.payments(id, limit: 1)).single;
      await f.expenses.moveToBin(latest.id);
      await f.recurring.archive(id);
      await f.recurring.delete(id);
      final rows = await f.expenseRows();
      expect(rows, hasLength(3));
      for (final row in rows) {
        expect(row['recurring_expense_id'], isNull);
        expect(row['recurring_due_on'], isNull);
      }
      expect(await f.db.query('recurring_amounts'), isEmpty);
      expect(await f.db.query('recurring_expense_events'), isEmpty);
      expect((await f.expenses.binned()).single.isRecurring, isFalse);
    });
  });

  test('every write bumps DataVersion once', () async {
    final id = await item(start: '2026-07-09');
    var version = f.dataVersion.value;
    Future<void> bumps(Future<Object?> Function() write) async {
      await write();
      expect(f.dataVersion.value, version + 1);
      version = f.dataVersion.value;
    }

    await bumps(() => f.recurring.update(id, edit()));
    await bumps(
      () => f.recurring.changePrice(id, amountMinor: 5, from: '2026-12-09'),
    );
    await bumps(() => f.recurring.removePrice(id, '2026-12-09'));
    await bumps(() => f.recurring.archive(id));
    // Restore bumps for the restore; a payment added today would add one.
    await f.recurring.restore(id);
    expect(f.dataVersion.value, greaterThan(version));
  });

  test('insertRecurringRow helper and the repository agree', () async {
    final id = await insertRecurringRow(f.db);
    final read = (await f.recurring.byId(id))!;
    expect(read.schedule!.startOn, '2026-01-31');
    expect(read.isBroken, isFalse);
  });
}

typedef PricePointView = (String, int);
