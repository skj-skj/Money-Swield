import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/recurring_fixture.dart';

/// Save with Repeats (phase-7a.md §6.2) and what the expense side must keep
/// doing with payments (R8, R9, P7a-19).
void main() {
  late RecurringFixture f;

  setUp(() async => f = await RecurringFixture.open());

  Future<int> count(String table) async =>
      (await f.db.rawQuery('SELECT count(*) AS n FROM $table')).single['n']!
          as int;

  group('Save with Repeats', () {
    test('today: the expense is payment 0 of a new item; one price, the '
        'events, the cursor on the next payment', () async {
      final (:expense, :pastAdded) = await f.addRepeating(
        input: f.input(expression: '600+49'),
      );
      expect(pastAdded, 0);
      expect(expense.recurringDueOn, '2026-10-09');
      final itemId = expense.recurringExpenseId!;
      final item = await f.itemRow(itemId);
      expect(item['title'], 'Netflix');
      expect(item['description'], 'Family plan');
      expect(item['currency_code'], 'INR');
      expect(item['category_id'], 17);
      expect(item['payment_method_id'], 4);
      expect(item['frequency'], 'monthly');
      expect(item['interval_count'], 1);
      expect(item['start_on'], '2026-10-09');
      expect(item['end_on'], isNull);
      expect(item['time_of_day_minutes'], 600);
      expect(item['next_due_on'], '2026-11-09');
      expect(item['archived_at'], isNull);
      expect(await f.recurring.prices(itemId), [
        (from: '2026-10-09', amountMinor: 64900),
      ]);
      expect(await f.db.query('recurring_expense_events'), [
        {'recurring_expense_id': itemId, 'event_id': 2},
      ]);
      // The typed expression stays on the expense the user typed.
      expect(expense.amountExpression, '600+49');
      expect(f.dataVersion.value, 1, reason: 'bumped once');
    });

    test('from 31 Jul: three expenses with the same price and events; no '
        'photos or expression on the added ones; cursor 31 Oct', () async {
      final (:expense, :pastAdded) = await f.addRepeating(
        input: f.input(day: '2026-07-31', expression: '649'),
      );
      expect(pastAdded, 2);
      final itemId = expense.recurringExpenseId!;
      expect(await f.paymentsOf(itemId), [
        ('2026-07-31', false, 64900),
        ('2026-08-31', false, 64900),
        ('2026-09-30', false, 64900),
      ]);
      expect(await f.cursorOf(itemId), '2026-10-31');
      final rows = await f.expenseRows();
      expect(
        [for (final r in rows) r['occurred_on']],
        ['2026-07-31', '2026-08-31', '2026-09-30'],
      );
      expect(
        [for (final r in rows) r['amount_expression']],
        ['649', null, null],
      );
      expect([for (final r in rows) r['title']], everyElement('Netflix'));
      expect([
        for (final r in rows) r['description'],
      ], everyElement('Family plan'));
      // The time of the form, in the device's zone.
      for (final row in rows) {
        final local = DateTime.fromMillisecondsSinceEpoch(
          row['occurred_at']! as int,
        );
        expect((local.hour, local.minute), (10, 0));
      }
      expect(await count('expense_events'), 3);
      expect(await count('expense_photos'), 0);
    });

    test('ends on a date: no payment after it, and the cursor is null when '
        'none is left', () async {
      final (:expense, :pastAdded) = await f.addRepeating(
        input: f.input(day: '2026-08-31'),
        choice: const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-09-15'),
      );
      expect(pastAdded, 0);
      expect(await f.cursorOf(expense.recurringExpenseId!), isNull);
      expect(
        (await f.itemRow(expense.recurringExpenseId!))['end_on'],
        '2026-09-15',
      );
    });

    test('JPY and KWD keep their minor units', () async {
      final yen = await f.addRepeating(
        input: f.input(day: '2026-08-09', amount: const Money(500, 'JPY')),
      );
      final dinar = await f.addRepeating(
        input: f.input(day: '2026-08-09', amount: const Money(1250, 'KWD')),
      );
      expect(await f.paymentsOf(yen.expense.recurringExpenseId!), [
        ('2026-08-09', false, 500),
        ('2026-09-09', false, 500),
        ('2026-10-09', false, 500),
      ]);
      expect(
        [
          for (final p in await f.paymentsOf(dinar.expense.recurringExpenseId!))
            p.$3,
        ],
        [1250, 1250, 1250],
      );
      expect(
        (await f.itemRow(dinar.expense.recurringExpenseId!))['currency_code'],
        'KWD',
      );
    });

    test('the cap: 1,001 earlier payments are refused with nothing '
        'written; exactly 1,000 are saved, 1,001 rows', () async {
      await expectLater(
        f.addRepeating(
          input: f.input(day: '2024-01-12'),
          choice: const RepeatChoice(frequency: Frequency.daily),
        ),
        throwsA(
          isA<RepeatRefused>().having(
            (e) => e.error,
            'error',
            RepeatError.tooManyPast,
          ),
        ),
      );
      expect(await count('expenses'), 0);
      expect(await count('recurring_expenses'), 0);
      expect(f.dataVersion.value, 0);

      final (:expense, :pastAdded) = await f.addRepeating(
        input: f.input(day: '2024-01-13'),
        choice: const RepeatChoice(frequency: Frequency.daily),
      );
      expect(pastAdded, 1000);
      expect(await count('expenses'), 1001);
      expect(await f.cursorOf(expense.recurringExpenseId!), '2026-10-10');
    });

    test('a throw after the item insert leaves nothing, and the draft '
        'stays', () async {
      await f.db.insert('expense_draft', {
        'id': 1,
        'form_json': '{}',
        'updated_at': 0,
      });
      // A failure inside the transaction, after the item: the third row.
      await f.db.execute(
        'CREATE TEMP TRIGGER boom BEFORE INSERT ON expenses '
        "WHEN NEW.recurring_due_on = '2026-09-30' "
        "BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      await expectLater(
        f.expenses.addRepeating(
          f.input(day: '2026-07-31'),
          const RepeatChoice(),
          clearDraft: true,
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(await count('expenses'), 0);
      expect(await count('recurring_expenses'), 0);
      expect(await count('recurring_amounts'), 0);
      expect(await count('expense_draft'), 1);
    });

    test('a success clears the draft in the same transaction', () async {
      await f.db.insert('expense_draft', {
        'id': 1,
        'form_json': '{}',
        'updated_at': 0,
      });
      await f.expenses.addRepeating(
        f.input(),
        const RepeatChoice(),
        clearDraft: true,
      );
      expect(await count('expense_draft'), 0);
    });

    test('photos go to the first payment only', () async {
      final (:expense, pastAdded: _) = await f.expenses.addRepeating(
        ExpenseInput(
          title: 'Gym',
          description: null,
          amount: const Money(150000, 'INR'),
          occurredAt: f.input(day: '2026-08-09').occurredAt,
          utcOffsetMinutes: f.input(day: '2026-08-09').utcOffsetMinutes,
          categoryId: 11,
          paymentMethodId: 1,
          eventIds: const {},
          photos: const [
            LinkNewPhoto(
              relativePath: 'photos/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg',
              sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              byteSize: 10,
            ),
          ],
        ),
        const RepeatChoice(),
      );
      expect(expense.photoCount, 1);
      final links = await f.db.query('expense_photos');
      expect([for (final l in links) l['expense_id']], [expense.id]);
    });

    test('the start is the saved row\'s occurred_on, also when the zone '
        'puts the UTC moment on another day', () async {
      // 00:30 at +05:30 is the day before in UTC.
      final input = ExpenseInput(
        title: 'Milk',
        description: null,
        amount: const Money(3000, 'INR'),
        occurredAt: DateTime.utc(2026, 10, 8, 19),
        utcOffsetMinutes: 330,
        categoryId: 2,
        paymentMethodId: 1,
        eventIds: const {},
      );
      final (:expense, pastAdded: _) = await f.expenses.addRepeating(
        input,
        const RepeatChoice(frequency: Frequency.daily),
      );
      expect(expense.occurredOn, '2026-10-09');
      expect(expense.recurringDueOn, '2026-10-09');
      final item = await f.itemRow(expense.recurringExpenseId!);
      expect(item['start_on'], '2026-10-09');
      expect(item['time_of_day_minutes'], 30);
    });
  });

  group('payments are ordinary expenses', () {
    test('R8: an Edit keeps both columns, also when the date moves', () async {
      final (:expense, pastAdded: _) = await f.addRepeating();
      final moved = await f.expenses.update(
        expense.id,
        f.input(day: '2026-10-12', title: 'Netflix (shared)'),
      );
      expect(moved.occurredOn, '2026-10-12');
      expect(moved.recurringExpenseId, expense.recurringExpenseId);
      expect(moved.recurringDueOn, '2026-10-09');
    });

    test('binned and restored, a payment keeps its link', () async {
      final (:expense, pastAdded: _) = await f.addRepeating();
      await f.expenses.moveToBin(expense.id);
      expect((await f.expenses.binned()).single.recurringDueOn, '2026-10-09');
      await f.expenses.restore(expense.id);
      expect((await f.expenses.byId(expense.id))!.isRecurring, isTrue);
    });

    test('totals, search, chips and title history count payments '
        '(P7a-19)', () async {
      await f.addRepeating(input: f.input(day: '2026-08-09'));
      final rows = await f.expenses.amountsIn(
        from: '2026-08-01',
        to: '2026-10-31',
      );
      expect(rows, hasLength(3));
      expect(await f.expenses.searchEntries(), hasLength(3));
      expect(await f.expenses.amountChipStats('INR'), [64900]);
      final history = await f.expenses.titleHistory();
      expect(history.single.title, 'Netflix');
      expect(history.single.recent, 3);
    });

    test('R9: after a price change the title history\'s last amount is '
        'the newest payment\'s', () async {
      f.setToday('2026-08-20');
      final (:expense, pastAdded: _) = await f.addRepeating(
        input: f.input(day: '2026-07-09'),
      );
      final itemId = expense.recurringExpenseId!;
      await f.recurring.changePrice(
        itemId,
        amountMinor: 69900,
        from: '2026-09-01',
      );
      f.setToday('2026-10-09');
      await f.recurring.generateDue();
      expect(
        [for (final p in await f.paymentsOf(itemId)) p.$3],
        [64900, 64900, 69900, 69900],
      );
      expect((await f.expenses.titleHistory()).single.amountMinor, 69900);
    });

    test('paymentsOf: newest due first, binned left out, in pages', () async {
      final (:expense, pastAdded: _) = await f.addRepeating(
        input: f.input(day: '2022-01-01'),
        choice: const RepeatChoice(frequency: Frequency.weekly),
      );
      final itemId = expense.recurringExpenseId!;
      final all = await f.paymentsOf(itemId);
      // Bin the newest.
      final newest = (await f.recurring.payments(itemId, limit: 1)).single;
      await f.expenses.moveToBin(newest.id);
      final pages = <List<Expense>>[];
      String? before;
      do {
        final page = await f.recurring.payments(itemId, before: before);
        pages.add(page);
        before = page.isEmpty ? null : page.last.recurringDueOn;
      } while (pages.last.length == 30);
      final seen = [for (final p in pages) ...p];
      expect(seen, hasLength(all.length - 1));
      expect(seen.map((e) => e.id), isNot(contains(newest.id)));
      final days = [for (final e in seen) e.recurringDueOn!];
      expect(days, [...days]..sort((a, b) => b.compareTo(a)));
      expect([for (final p in pages) p.length].take(2), [30, 30]);
    });
  });
}
