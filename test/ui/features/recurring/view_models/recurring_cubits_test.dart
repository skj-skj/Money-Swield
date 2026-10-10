import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/amount_expression.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/models/recurring_item.dart';
import 'package:my_expense_tracker_app/domain/recurring_price.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';
import 'package:my_expense_tracker_app/ui/features/expenses/view_models/expense_form_cubit.dart'
    show TitleError;
import 'package:my_expense_tracker_app/ui/features/recurring/view_models/recurring_detail_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/recurring/view_models/recurring_form_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/recurring/view_models/recurring_list_cubit.dart';

import '../../../../helpers/test_database.dart';

/// The Recurring screens' cubits (phase-7a.md §7.2–§7.5).
void main() {
  late AppDependencies deps;
  late TestClock clock;

  setUp(() async {
    clock = TestClock(DateTime(2026, 10, 9, 12));
    deps = await openTestDependencies(clock: clock);
  });

  /// Saves [title] from [start] with Repeats, today being 2026-10-09.
  Future<int> item(
    String title, {
    String start = '2026-10-09',
    RepeatChoice choice = const RepeatChoice(),
    Money amount = const Money(64900, 'INR'),
  }) async {
    final local = DateTime(
      int.parse(start.substring(0, 4)),
      int.parse(start.substring(5, 7)),
      int.parse(start.substring(8, 10)),
      10,
    );
    final (:expense, pastAdded: _) = await deps.expenses.addRepeating(
      ExpenseInput(
        title: title,
        description: null,
        amount: amount,
        occurredAt: local.toUtc(),
        utcOffsetMinutes: local.timeZoneOffset.inMinutes,
        categoryId: 17,
        paymentMethodId: 4,
        eventIds: const {},
      ),
      choice,
    );
    return expense.recurringExpenseId!;
  }

  group('list', () {
    RecurringListCubit list() {
      final cubit = RecurringListCubit(
        recurring: deps.recurring,
        categories: deps.categories,
        drafts: deps.drafts,
        dataVersion: deps.dataVersion,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('Waiting first, then Active by next date then title; no payment '
        'left last; the Archive count', () async {
      final rent = await item('Rent', start: '2026-09-01');
      await item('Netflix', start: '2026-09-15');
      await item('Gym');
      await item(
        'Phone',
        start: '2026-09-20',
        choice: const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-10-15'),
      );
      final old = await item('Old');
      await deps.recurring.archive(old);
      // A backlog: Rent's cursor back 40 days.
      await deps.database.update(
        'recurring_expenses',
        {'next_due_on': '2026-08-01'},
        where: 'id = ?',
        whereArgs: [rent],
      );
      final cubit = list();
      await cubit.load();
      final loaded = cubit.value as RecurringListLoaded;
      expect(loaded.waiting.map((i) => i.title), ['Rent']);
      expect(loaded.active.map((i) => i.title), ['Netflix', 'Gym', 'Phone']);
      expect(loaded.archived.map((i) => i.title), ['Old']);
      expect(loaded.categories[17]!.builtinKey, 'subscription');
      expect(loaded.section, RecurringSection.waiting, reason: 'Rent waits');
    });

    test('the section: Waiting while anything waits, else Active; a pick '
        'stays across reloads (owner, 2026-10-09)', () async {
      await item('Netflix');
      final cubit = list();
      await cubit.load();
      RecurringListLoaded loaded() => cubit.value as RecurringListLoaded;
      expect(loaded().section, RecurringSection.active);
      cubit.select(RecurringSection.archived);
      expect(loaded().section, RecurringSection.archived);
      expect(loaded().shown, isEmpty);
      final gym = await item('Gym', start: '2026-08-01');
      await deps.database.update(
        'recurring_expenses',
        {'next_due_on': '2026-09-01'},
        where: 'id = ?',
        whereArgs: [gym],
      );
      await cubit.load();
      expect(loaded().section, RecurringSection.archived, reason: 'picked');
      expect(loaded().waiting.map((i) => i.title), ['Gym']);
    });

    test('unpicked, the section follows: Active once nothing waits', () async {
      final gym = await item('Gym', start: '2026-08-01');
      await deps.database.update(
        'recurring_expenses',
        {'next_due_on': '2026-09-01'},
        where: 'id = ?',
        whereArgs: [gym],
      );
      final cubit = list();
      await cubit.load();
      expect(
        (cubit.value as RecurringListLoaded).section,
        RecurringSection.waiting,
      );
      await deps.recurring.generateDue(onlyId: gym, confirmed: true);
      await cubit.reloadIfChanged();
      expect(
        (cubit.value as RecurringListLoaded).section,
        RecurringSection.active,
      );
    });

    test('reloads only when something changed', () async {
      final cubit = list();
      await cubit.load();
      final first = cubit.value;
      await cubit.reloadIfChanged();
      expect(identical(cubit.value, first), isTrue);
      await item('Gym');
      await cubit.reloadIfChanged();
      expect((cubit.value as RecurringListLoaded).active, hasLength(1));
    });

    test('empty: nothing running, nothing archived', () async {
      final cubit = list();
      await cubit.load();
      expect((cubit.value as RecurringListLoaded).isEmpty, isTrue);
    });
  });

  group('archive section', () {
    test('newest archived first, with the reason', () async {
      final a = await item('A');
      final b = await item(
        'B',
        start: '2026-09-01',
        choice: const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-10-05'),
      );
      await deps.recurring.archive(a);
      clock.advance(const Duration(minutes: 1));
      await deps.recurring.generateDue();
      expect((await deps.recurring.byId(b))!.isArchived, isTrue);
      final cubit = RecurringListCubit(
        recurring: deps.recurring,
        categories: deps.categories,
        drafts: deps.drafts,
        dataVersion: deps.dataVersion,
      );
      addTearDown(cubit.close);
      await cubit.load();
      final items = (cubit.value as RecurringListLoaded).archived;
      expect(items.map((i) => i.title), ['B', 'A']);
      expect(items.first.archiveReason, ArchiveReason.expired);
      expect(items.last.archiveReason, ArchiveReason.stopped);
    });
  });

  group('detail', () {
    Future<RecurringDetailCubit> detail(
      int id, {
      String separator = '.',
    }) async {
      final cubit = RecurringDetailCubit(
        itemId: id,
        recurring: deps.recurring,
        expenses: deps.expenses,
        categories: deps.categories,
        paymentMethods: deps.paymentMethods,
        events: deps.events,
        drafts: deps.drafts,
        decimalSeparator: separator,
        now: clock.call,
      );
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    RecurringDetailLoaded loaded(RecurringDetailCubit c) =>
        c.value as RecurringDetailLoaded;

    test(
      'loads the item, prices, the last 5 payments and the lookups',
      () async {
        final id = await item(
          'Milk',
          start: '2026-10-01',
          choice: const RepeatChoice(frequency: Frequency.daily),
        );
        final cubit = await detail(id);
        final state = loaded(cubit);
        expect(state.item.paymentCount, 9);
        expect(state.payments, hasLength(5));
        expect(state.payments.first.recurringDueOn, '2026-10-09');
        expect(state.hasMorePayments, isTrue);
        expect(state.category!.builtinKey, 'subscription');
        expect(state.paymentMethod!.builtinKey, 'credit_card');
        await cubit.showAll();
        expect(loaded(cubit).payments, hasLength(9));
        expect(loaded(cubit).hasMorePayments, isFalse);
      },
    );

    test('Add all and Skip them: a double tap runs once', () async {
      // As if the app wasn't opened since 1 Sep (38 days): held.
      final id = await item('Gym', start: '2026-08-01');
      await deps.database.update('recurring_expenses', {
        'next_due_on': '2026-09-01',
      });
      await deps.database.delete(
        'expenses',
        where: "recurring_due_on > '2026-08-01'",
      );
      final cubit = await detail(id);
      expect(loaded(cubit).item.hold!.count, 2);
      final results = await Future.wait([cubit.addAll(), cubit.addAll()]);
      expect(results.whereType<int>(), [2]);
      expect(loaded(cubit).item.hold, isNull);
      expect(loaded(cubit).item.paymentCount, 3);
    });

    test('Skip them: skips the past ones, adds today\'s if due', () async {
      final id = await item('Gym', start: '2026-08-09');
      await deps.database.update('recurring_expenses', {
        'next_due_on': '2026-08-09',
      });
      await deps.database.delete(
        'expenses',
        where: "recurring_due_on > '2026-08-09'",
      );
      final cubit = await detail(id);
      final outcome = await cubit.skipAll();
      expect(outcome!.skipped, 2);
      expect(outcome.added, 1, reason: "today's is due");
      expect(outcome.next, '2026-11-09');
    });

    test('Stop returns the undo; Undo brings it back', () async {
      final id = await item('Netflix');
      final cubit = await detail(id);
      final undo = await cubit.stop();
      expect(undo, isNotNull);
      expect((await deps.recurring.byId(id))!.isArchived, isTrue);
      expect(await deps.recurring.undoArchive(undo!), isTrue);
    });

    test('the price check: 0, empty, too many decimals for JPY and KWD, '
        'an expression, before the start, in force, a replacement', () async {
      final inr = await detail(await item('Netflix', start: '2026-07-09'));
      PriceCheck check(
        RecurringDetailCubit c,
        String text, [
        String from = '2026-11-09',
      ]) => c.checkNewPrice(text, from)!;
      expect(
        (check(inr, '0') as PriceAmountInvalid).error,
        ExpressionError.notPositive,
      );
      expect(
        (check(inr, '') as PriceAmountInvalid).error,
        ExpressionError.empty,
      );
      expect((check(inr, '600+99') as PriceOk).amountMinor, 69900);
      expect(check(inr, '699', '2026-07-08'), isA<PriceDateRefused>());
      expect(
        (check(inr, '699', '2026-07-09') as PriceDateRefused).change,
        PriceChange.inForce,
      );
      await deps.recurring.changePrice(
        loaded(inr).item.id,
        amountMinor: 69900,
        from: '2027-01-09',
      );
      await inr.load();
      expect((check(inr, '799', '2027-01-09') as PriceOk).replaces, 69900);

      final yen = await detail(
        await item('Gym', amount: const Money(500, 'JPY')),
      );
      expect(
        (check(yen, '500.5') as PriceAmountInvalid).error,
        ExpressionError.tooManyDecimals,
      );
      expect((check(yen, '600') as PriceOk).amountMinor, 600);
      final dinar = await detail(
        await item('Club', amount: const Money(1250, 'KWD')),
      );
      expect((check(dinar, '1.250') as PriceOk).amountMinor, 1250);
      expect(
        (check(dinar, '1.2505') as PriceAmountInvalid).error,
        ExpressionError.tooManyDecimals,
      );
    });

    test('Spanish: a comma is the decimal separator', () async {
      final cubit = await detail(await item('Netflix'), separator: ',');
      expect(
        (cubit.checkNewPrice('6,99', '2026-11-09')! as PriceOk).amountMinor,
        699,
      );
    });

    test('changePrice saves only a valid price; the page reloads', () async {
      final cubit = await detail(await item('Netflix'));
      expect(await cubit.changePrice('0', '2026-11-09'), isFalse);
      expect(await cubit.changePrice('699', '2026-11-09'), isTrue);
      expect(loaded(cubit).prices.last, (
        from: '2026-11-09',
        amountMinor: 69900,
      ));
    });

    test('the default "from" is the next payment, never a past date', () async {
      final netflix = await item('Netflix');
      expect((await detail(netflix)).defaultPriceFrom, '2026-11-09');
      // Held: the cursor is two months back; the sheet opens on today.
      final gym = await item('Gym', start: '2026-07-09');
      await deps.database.update(
        'recurring_expenses',
        {'next_due_on': '2026-08-09'},
        where: 'id = ?',
        whereArgs: [gym],
      );
      expect((await detail(gym)).defaultPriceFrom, '2026-10-09');
      // Not started yet: its next payment (the first is already added).
      final later = await item('Later', start: '2026-12-01');
      expect((await detail(later)).defaultPriceFrom, '2027-01-01');
    });

    test('Restore preview: an expired item says its end goes; a stopped '
        'one starts from its kept cursor', () async {
      final expired = await item(
        'B',
        start: '2026-09-01',
        choice: const RepeatChoice(end: RepeatEnd.onDate, endOn: '2026-10-05'),
      );
      await deps.recurring.generateDue();
      final page = await detail(expired);
      expect(page.restorePreview, (
        next: '2026-11-01',
        endPassed: '2026-10-05',
      ));
      final stopped = await item('C');
      await deps.recurring.archive(stopped);
      final other = await detail(stopped);
      expect(other.restorePreview, (next: '2026-11-09', endPassed: null));
      final outcome = await other.restore();
      expect(outcome!.next, '2026-11-09');
    });

    test('Delete for good (archived) says it deleted; the item is Gone '
        'after', () async {
      final id = await item('Old', start: '2026-08-09');
      await deps.recurring.archive(id);
      final cubit = await detail(id);
      expect(await cubit.delete(), isTrue);
      // Not read again by the delete: the page closes with its own
      // message (a reload said Gone and closed it twice; §12a).
      expect(cubit.value, isA<RecurringDetailLoaded>());
      await cubit.load();
      expect(cubit.value, isA<RecurringDetailGone>());
    });

    test('a failed run shows on the page', () async {
      final id = await item('Netflix', start: '2026-09-09');
      await deps.database.update('recurring_expenses', {
        'next_due_on': '2026-10-09',
      });
      await deps.database.delete(
        'expenses',
        where: "recurring_due_on = '2026-10-09'",
      );
      await deps.database.delete('recurring_amounts');
      await deps.recurring.generateDue();
      expect(loaded(await detail(id)).generateFailed, isTrue);
    });
  });

  group('Edit form', () {
    Future<RecurringFormCubit> form(int id) async {
      final cubit = RecurringFormCubit(
        itemId: id,
        recurring: deps.recurring,
        categories: deps.categories,
        events: deps.events,
        paymentMethods: deps.paymentMethods,
        l10n: l10nFor('en'),
        now: clock.call,
      );
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    test('dirtiness follows the fields; an end date kept under Never is no '
        'change', () async {
      final cubit = await form(await item('Netflix'));
      expect(cubit.isDirty, isFalse);
      expect(cubit.canSave, isFalse);
      cubit.titleChanged('Netflix 4K');
      expect(cubit.isDirty, isTrue);
      cubit.titleChanged('Netflix');
      expect(cubit.isDirty, isFalse);
      cubit
        ..endChanged(RepeatEnd.onDate)
        ..endChanged(RepeatEnd.never);
      expect(cubit.isDirty, isFalse);
    });

    test('validation after a Save attempt: title, end before a payment '
        'already added', () async {
      final cubit = await form(await item('Netflix', start: '2026-08-09'));
      cubit
        ..titleChanged('  ')
        ..endDateChanged(DateTime(2026, 10, 8));
      expect(cubit.titleError, isNull);
      expect(await cubit.save(), isFalse);
      expect(cubit.titleError, TitleError.required);
      expect(cubit.endError, EndError.beforeEarliest);
      final state = cubit.value as RecurringFormReady;
      expect(state.earliestEnd, '2026-10-09');
    });

    test('save writes the item; payments added later use it', () async {
      final id = await item('Netflix');
      final cubit = await form(id);
      cubit
        ..titleChanged('Netflix 4K')
        ..timeChanged(20, 30)
        ..categorySelected(13)
        ..eventToggled(1)
        ..endDateChanged(DateTime(2027, 3, 31));
      expect(await cubit.save(), isTrue);
      final saved = (await deps.recurring.byId(id))!;
      expect(saved.title, 'Netflix 4K');
      expect(saved.timeOfDayMinutes, 20 * 60 + 30);
      expect(saved.categoryId, 13);
      expect(saved.eventIds, {1});
      expect(saved.schedule!.endOn, '2027-03-31');
      expect(cubit.isDirty, isFalse);
    });

    test('an archived item opens Gone (read-only)', () async {
      final id = await item('Old');
      await deps.recurring.archive(id);
      expect((await form(id)).value, isA<RecurringFormGone>());
    });

    test('archived meanwhile: Save says Gone, nothing written', () async {
      final id = await item('Netflix');
      final cubit = await form(id)
        ..titleChanged('x');
      await deps.recurring.archive(id);
      expect(await cubit.save(), isFalse);
      expect(cubit.value, isA<RecurringFormGone>());
      expect((await deps.recurring.byId(id))!.title, 'Netflix');
    });

    test('a double tap saves once', () async {
      final id = await item('Netflix');
      final cubit = await form(id)
        ..titleChanged('A');
      final version = deps.dataVersion.value;
      await Future.wait([cubit.save(), cubit.save()]);
      expect(deps.dataVersion.value, version + 1);
    });
  });
}
