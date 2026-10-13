import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/data/repositories/recurring_repository.dart';
import 'package:money_swield/domain/models/money.dart';
import 'package:money_swield/domain/models/recurring_item.dart';
import 'package:money_swield/domain/recurrence.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/recurring_fixture.dart';

/// Changing how often and the swap on Restore ("a new schedule loses or doubles
/// payments", "two items run for one bill").
void main() {
  late RecurringFixture f;

  setUp(() async => f = await RecurringFixture.open());

  /// Netflix monthly from [start], saved that day; payment 0 only.
  Future<int> netflix({String start = '2026-10-09'}) async {
    f.setToday(start);
    final (:expense, pastAdded: _) = await f.addRepeating(
      input: f.input(day: start),
    );
    f.setToday('2026-10-09');
    return expense.recurringExpenseId!;
  }

  RecurringEdit edit({String? endOn, String title = 'Netflix'}) =>
      RecurringEdit(
        title: title,
        description: 'Family plan',
        categoryId: 17,
        paymentMethodId: 4,
        eventIds: const {3},
        timeOfDayMinutes: 1200,
        endOn: endOn,
      );

  Schedule weekly(String start, {int interval = 1}) =>
      Schedule(frequency: Frequency.weekly, interval: interval, startOn: start);

  Future<int> count(String table) async =>
      (await f.db.rawQuery('SELECT count(*) AS n FROM $table')).single['n']!
          as int;

  group('replaceSchedule', () {
    test('a new item with the edit\'s fields, the new schedule, '
        'replaces_id; the old one archived, its cursor kept', () async {
      final old = await netflix();
      final version = f.dataVersion.value;
      final id = await f.recurring.replaceSchedule(
        old,
        edit(endOn: '2027-06-30'),
        weekly('2026-11-09'),
      );
      expect(f.dataVersion.value, version + 1);
      final row = await f.itemRow(id);
      expect(row['frequency'], 'weekly');
      expect(row['interval_count'], 1);
      expect(row['start_on'], '2026-11-09');
      expect(row['end_on'], '2027-06-30');
      expect(row['next_due_on'], '2026-11-09');
      expect(row['time_of_day_minutes'], 1200);
      expect(row['category_id'], 17);
      expect(row['payment_method_id'], 4);
      expect(row['replaces_id'], old);
      expect(row['archived_at'], isNull);
      expect((await f.recurring.byId(id))!.eventIds, {3});
      final oldRow = await f.itemRow(old);
      expect(oldRow['archived_at'], isNotNull);
      expect(oldRow['next_due_on'], '2026-11-09', reason: 'cursor kept');
      expect(oldRow['archived_at'], row['created_at'], reason: 'one write');
      // Nothing added yet: the new start is next month.
      expect(await f.paymentsOf(id), isEmpty);
      expect(await f.paymentsOf(old), hasLength(1));
    });

    test('prices: the old one\'s on the new start plus its scheduled ones '
        'after it', () async {
      final old = await netflix();
      await f.recurring.changePrice(
        old,
        amountMinor: 69900,
        from: '2026-11-09',
      );
      await f.recurring.changePrice(
        old,
        amountMinor: 79900,
        from: '2027-01-09',
      );
      final id = await f.recurring.replaceSchedule(
        old,
        edit(),
        weekly('2026-11-20'),
      );
      expect(await f.recurring.prices(id), [
        (from: '2026-11-20', amountMinor: 69900),
        (from: '2027-01-09', amountMinor: 79900),
      ]);
    });

    test(
      'a start of today adds today\'s payment once, in the same write',
      () async {
        // Monthly from 9 Sep, cursor 9 Oct... the generator ran: 9 Oct
        // added, cursor 9 Nov; today 10 Oct.
        final old = await netflix(start: '2026-09-09');
        await f.recurring.generateDue();
        f.setToday('2026-10-10');
        final id = await f.recurring.replaceSchedule(
          old,
          edit(),
          weekly('2026-10-10'),
        );
        expect(await f.paymentsOf(id), [('2026-10-10', false, 64900)]);
        expect(await f.cursorOf(id), '2026-10-17');
        // A later run adds nothing more.
        expect((await f.recurring.generateDue()).added, 0);
        expect(await f.paymentsOf(id), hasLength(1));
      },
    );

    test('a First payment on or before the old one\'s last handled date, or '
        'before today, is refused; nothing written', () async {
      // Today's payment (9 Oct) was added: 9 Oct is handled even if it is
      // deleted, so the new schedule can't start on it.
      final old = await netflix();
      final payment = (await f.recurring.payments(old)).single;
      await f.expenses.moveToBin(payment.id);
      final rows = await count('recurring_expenses');
      for (final start in ['2026-10-09', '2026-10-01', '2201-01-01', 'x']) {
        await expectLater(
          f.recurring.replaceSchedule(old, edit(), weekly(start)),
          throwsA(isA<RecurringChangeRefused>()),
          reason: start,
        );
      }
      expect(await count('recurring_expenses'), rows);
      expect((await f.itemRow(old))['archived_at'], isNull);
      // 10 Oct is fine.
      await f.recurring.replaceSchedule(old, edit(), weekly('2026-10-10'));
    });

    test("an item that hasn't started yet: a First payment before its first "
        'price takes that price, not "gone"', () async {
      // A → B from 1 Mar 2027: B has no payment and its only price is from
      // 1 Mar, yet its First payment may be any day from today.
      final b = await f.recurring.replaceSchedule(
        await netflix(),
        edit(),
        weekly('2027-03-01'),
      );
      final c = await f.recurring.replaceSchedule(
        b,
        edit(),
        weekly('2026-10-09'),
      );
      expect(await f.paymentsOf(c), [('2026-10-09', false, 64900)]);
      expect((await f.itemRow(b))['archived_at'], isNotNull);
    });

    test('an end before the start is refused', () async {
      final old = await netflix();
      await expectLater(
        f.recurring.replaceSchedule(
          old,
          edit(endOn: '2026-11-01'),
          weekly('2026-11-09'),
        ),
        throwsA(isA<RecurringChangeRefused>()),
      );
    });

    test(
      'payments waiting (held) are refused: they would be dropped',
      () async {
        final old = await netflix(start: '2026-07-09');
        // The run on 9 Jul didn't happen since: 9 Aug – 9 Oct waiting.
        await f.db.update('recurring_expenses', {
          'next_due_on': '2026-08-09',
        }, where: 'id = $old');
        await expectLater(
          f.recurring.replaceSchedule(old, edit(), weekly('2026-10-12')),
          throwsA(isA<RecurringChangeRefused>()),
        );
      },
    );

    test('an archived or gone item is unavailable', () async {
      final old = await netflix();
      await f.recurring.archive(old);
      await expectLater(
        f.recurring.replaceSchedule(old, edit(), weekly('2026-11-09')),
        throwsA(isA<RecurringItemUnavailable>()),
      );
      await expectLater(
        f.recurring.replaceSchedule(99, edit(), weekly('2026-11-09')),
        throwsA(isA<RecurringItemUnavailable>()),
      );
    });

    test('a failure after the insert rolls everything back', () async {
      final old = await netflix();
      final before = await f.db.query('recurring_expenses');
      // Fails the archive of the old item, after the new one's insert.
      await f.db.execute(
        'CREATE TEMP TRIGGER fail BEFORE UPDATE OF archived_at ON '
        "recurring_expenses BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      await expectLater(
        f.recurring.replaceSchedule(old, edit(), weekly('2026-11-09')),
        throwsA(isA<DatabaseException>()),
      );
      await f.db.execute('DROP TRIGGER fail');
      expect(await f.db.query('recurring_expenses'), before);
      expect(await count('recurring_amounts'), 1);
      expect(await count('recurring_expense_events'), 1);
    });

    test('the Archive labels the old one "replaced"; a later Stop of a '
        'restored item is "stopped"', () async {
      final old = await netflix();
      final id = await f.recurring.replaceSchedule(
        old,
        edit(),
        weekly('2026-11-09'),
      );
      final archived = (await f.recurring.archived()).single;
      expect(archived.id, old);
      expect(archived.archiveReason, ArchiveReason.replaced);
      expect((await f.recurring.byId(id))!.replacesId, old);
      // Swap back, then stop the old one: stopped, not replaced.
      await f.recurring.restore(old, swapOut: id);
      f.clock.advance(const Duration(minutes: 1));
      await f.recurring.archive(old);
      final both = await f.recurring.archived();
      expect(
        {for (final item in both) item.id: item.archiveReason},
        {old: ArchiveReason.stopped, id: ArchiveReason.stopped},
      );
    });

    test(
      'deleting the old one for good keeps the new one (SET NULL)',
      () async {
        final old = await netflix();
        final id = await f.recurring.replaceSchedule(
          old,
          edit(),
          weekly('2026-11-09'),
        );
        await f.recurring.delete(old);
        expect((await f.itemRow(id))['replaces_id'], isNull);
        expect((await f.recurring.byId(id))!.isArchived, isFalse);
      },
    );
  });

  group('the swap', () {
    test('runningRelative: direct and down a chain A → B → C', () async {
      final a = await netflix();
      final b = await f.recurring.replaceSchedule(
        a,
        edit(),
        weekly('2026-10-12'),
      );
      expect((await f.recurring.runningRelative(a))!.id, b);
      final c = await f.recurring.replaceSchedule(
        b,
        edit(),
        weekly('2026-10-20', interval: 2),
      );
      expect((await f.recurring.runningRelative(a))!.id, c);
      expect((await f.recurring.runningRelative(b))!.id, c);
      expect(await f.recurring.runningRelative(c), isNull);
    });

    test('restore(swapOut:) archives the replacement in the same write; its '
        'payments stay', () async {
      final a = await netflix();
      final b = await f.recurring.replaceSchedule(
        a,
        edit(),
        weekly('2026-10-10'),
      );
      f.setToday('2026-10-10');
      await f.recurring.generateDue();
      expect(await f.paymentsOf(b), hasLength(1));
      final outcome = await f.recurring.restore(a, swapOut: b);
      expect(outcome.next, '2026-11-09');
      expect((await f.itemRow(b))['archived_at'], isNotNull);
      expect((await f.itemRow(a))['archived_at'], isNull);
      expect(await f.paymentsOf(b), [('2026-10-10', false, 64900)]);
      final running = await f.recurring.all();
      expect([for (final i in running) i.id], [a]);
    });

    test('restoring the swapped-out one switches again', () async {
      final a = await netflix();
      final b = await f.recurring.replaceSchedule(
        a,
        edit(),
        weekly('2026-10-12'),
      );
      await f.recurring.restore(a, swapOut: b);
      expect((await f.recurring.runningRelative(b))!.id, a);
      await f.recurring.restore(b, swapOut: a);
      expect([for (final i in await f.recurring.all()) i.id], [b]);
    });

    test('Restore without the swap while a relative runs is refused; '
        'nothing written', () async {
      final a = await netflix();
      final b = await f.recurring.replaceSchedule(
        a,
        edit(),
        weekly('2026-10-12'),
      );
      final before = await f.db.query('recurring_expenses');
      await expectLater(
        f.recurring.restore(a),
        throwsA(isA<RecurringChangeRefused>()),
      );
      // A stale dialog naming another item: refused too.
      await expectLater(
        f.recurring.restore(a, swapOut: 99),
        throwsA(isA<RecurringChangeRefused>()),
      );
      expect(await f.db.query('recurring_expenses'), before);
      expect(b, isNot(a));
    });

    test('a replacement stopped meanwhile: Restore with the stale swapOut '
        'still restores', () async {
      final a = await netflix();
      final b = await f.recurring.replaceSchedule(
        a,
        edit(),
        weekly('2026-10-12'),
      );
      await f.recurring.archive(b);
      await f.recurring.restore(a, swapOut: b);
      expect([for (final i in await f.recurring.all()) i.id], [a]);
    });

    test('a failure in the swap rolls back both', () async {
      final a = await netflix();
      final b = await f.recurring.replaceSchedule(
        a,
        edit(),
        weekly('2026-10-12'),
      );
      final before = await f.db.query('recurring_expenses');
      // Fails the restore's own update, after the swap-out.
      await f.db.execute(
        'CREATE TEMP TRIGGER fail BEFORE UPDATE OF next_due_on ON '
        "recurring_expenses BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      await expectLater(
        f.recurring.restore(a, swapOut: b),
        throwsA(isA<DatabaseException>()),
      );
      await f.db.execute('DROP TRIGGER fail');
      expect(await f.db.query('recurring_expenses'), before);
    });

    test('Undo of a Stop never runs two items for one bill', () async {
      // Stop B (Undo offered), restore A (nothing to swap), then Undo.
      final a = await netflix();
      final b = await f.recurring.replaceSchedule(
        a,
        edit(),
        weekly('2026-10-12'),
      );
      final undo = await f.recurring.archive(b);
      await f.recurring.restore(a);
      expect(await f.recurring.undoArchive(undo), isFalse);
      expect([for (final i in await f.recurring.all()) i.id], [a]);
    });
  });

  test('a price stays Money in the item\'s currency', () async {
    final old = await netflix();
    final id = await f.recurring.replaceSchedule(
      old,
      edit(),
      weekly('2026-11-09'),
    );
    expect((await f.recurring.byId(id))!.price, const Money(64900, 'INR'));
  });
}
