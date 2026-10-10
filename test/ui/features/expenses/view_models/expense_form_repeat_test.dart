import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_draft_repository.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';
import 'package:my_expense_tracker_app/domain/title_suggestions.dart';
import 'package:my_expense_tracker_app/ui/features/expenses/view_models/expense_form_cubit.dart';

import '../../../../helpers/fake_timers.dart';
import '../../../../helpers/test_database.dart';

/// The Add form's Repeats (phase-7a.md §7.1).
void main() {
  late AppDependencies deps;
  late TestClock clock;
  late FakeTimers timers;
  late ExpenseDraftRepository drafts;

  setUp(() async {
    // Noon on 2026-10-09, device time.
    clock = TestClock(DateTime(2026, 10, 9, 12));
    deps = await openTestDependencies(clock: clock);
    timers = FakeTimers();
    drafts = ExpenseDraftRepository(deps.database, timer: timers.call);
  });

  Future<ExpenseFormCubit> openForm({
    int? expenseId,
    ExpenseDraft? draft,
    bool startRepeating = false,
  }) async {
    final cubit = ExpenseFormCubit(
      expenses: deps.expenses,
      categories: deps.categories,
      events: deps.events,
      paymentMethods: deps.paymentMethods,
      drafts: drafts,
      recurring: deps.recurring,
      startRepeating: startRepeating,
      l10n: l10nFor('en'),
      defaultCurrency: 'INR',
      defaultPaymentMethodId: 1,
      expenseId: expenseId,
      openingDraft: draft,
      now: clock.call,
    );
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  ExpenseFormReady ready(ExpenseFormCubit cubit) =>
      cubit.value as ExpenseFormReady;
  RepeatChoice? repeatOf(ExpenseFormCubit cubit) => ready(cubit).fields.repeat;

  /// "Netflix", 649, Subscription.
  Future<ExpenseFormCubit> validForm({bool startRepeating = false}) async =>
      (await openForm(startRepeating: startRepeating))
        ..titleChanged('Netflix')
        ..amountChanged('649')
        ..categorySelected(17);

  group('the switch', () {
    test('on: every 1 month, never ending; off keeps the settings for '
        'switching on again', () async {
      final cubit = await openForm();
      expect(repeatOf(cubit), isNull);
      cubit.repeatToggled(true);
      expect(repeatOf(cubit), RepeatChoice.defaults);
      cubit
        ..repeatIntervalChanged('3')
        ..repeatFrequencyChanged(Frequency.weekly)
        ..repeatToggled(false);
      expect(repeatOf(cubit), isNull);
      cubit.repeatToggled(true);
      expect(
        repeatOf(cubit),
        const RepeatChoice(frequency: Frequency.weekly, intervalText: '3'),
      );
    });

    test('a change of each field', () async {
      final cubit = await openForm()
        ..repeatToggled(true);
      cubit.repeatFrequencyChanged(Frequency.yearly);
      expect(repeatOf(cubit)!.frequency, Frequency.yearly);
      cubit.repeatIntervalChanged('');
      expect(repeatOf(cubit)!.intervalText, '', reason: 'as typed');
      cubit.repeatEndChanged(RepeatEnd.onDate);
      expect(repeatOf(cubit)!.end, RepeatEnd.onDate);
      expect(repeatOf(cubit)!.endOn, '2027-04-09', reason: '6 months on');
      cubit.repeatEndDateChanged(DateTime(2027, 1, 31));
      expect(repeatOf(cubit)!.endOn, '2027-01-31');
      cubit.repeatEndChanged(RepeatEnd.never);
      expect(repeatOf(cubit)!.end, RepeatEnd.never);
      expect(repeatOf(cubit)!.endOn, '2027-01-31', reason: 'kept');
    });

    test('the default end is clamped: 31 Aug + 6 months is 28 Feb', () async {
      final cubit = await openForm()
        ..dateChanged(DateTime(2026, 8, 31))
        ..repeatToggled(true)
        ..repeatEndChanged(RepeatEnd.onDate);
      expect(repeatOf(cubit)!.endOn, '2027-02-28');
    });

    test('changes do nothing while Repeats is off', () async {
      final cubit = await openForm()
        ..repeatIntervalChanged('5');
      expect(repeatOf(cubit), isNull);
      expect(cubit.isDirty, isFalse);
    });

    test('on makes the form dirty and writes a draft with it', () async {
      final cubit = await openForm()
        ..repeatToggled(true);
      expect(cubit.isDirty, isTrue);
      await drafts.flush();
      expect((await drafts.read())!.repeat, RepeatChoice.defaults);
    });
  });

  group('preview and errors', () {
    test('the preview follows the form\'s date', () async {
      final cubit = await openForm()
        ..repeatToggled(true);
      expect(cubit.repeatSummary!.past, isEmpty);
      expect(cubit.repeatSummary!.next, '2026-11-09');
      cubit.dateChanged(DateTime(2026, 7, 31));
      expect(cubit.repeatSummary!.past, ['2026-08-31', '2026-09-30']);
      expect(cubit.repeatSummary!.pastCount, 2);
      expect(cubit.repeatSummary!.next, '2026-10-31');
    });

    test('no preview for an Every that isn\'t 1 to 99', () async {
      final cubit = await openForm()
        ..repeatToggled(true)
        ..repeatIntervalChanged('0');
      expect(cubit.repeatSummary, isNull);
    });

    test('errors show only after a Save attempt, and block it', () async {
      final cubit = await validForm()
        ..repeatToggled(true)
        ..repeatIntervalChanged('');
      expect(cubit.repeatError, isNull);
      expect(await cubit.save(), isNull);
      expect(cubit.repeatError, RepeatError.intervalRange);
      expect(await deps.database.query('expenses'), isEmpty);
      cubit.repeatIntervalChanged('2');
      expect(cubit.repeatError, isNull, reason: 'live after the attempt');
    });

    test('an end before the start blocks Save', () async {
      final cubit = await validForm()
        ..repeatToggled(true)
        ..repeatEndDateChanged(DateTime(2026, 10, 1));
      expect(await cubit.save(), isNull);
      expect(cubit.repeatError, RepeatError.endBeforeStart);
    });

    test('too many earlier payments: counted live, Save blocked', () async {
      final cubit = await validForm()
        ..repeatToggled(true)
        ..repeatFrequencyChanged(Frequency.daily)
        ..dateChanged(DateTime(2023, 1, 1));
      expect(cubit.repeatSummary!.pastCount, 1377);
      expect(cubit.repeatSummary!.past, hasLength(1000));
      expect(await cubit.save(), isNull);
      expect(cubit.repeatError, RepeatError.tooManyPast);
      expect(await deps.database.query('expenses'), isEmpty);
    });
  });

  group('save', () {
    test('with Repeats: the expense is the first payment, earlier ones '
        'added', () async {
      final cubit = await validForm()
        ..repeatToggled(true)
        ..dateChanged(DateTime(2026, 7, 31));
      final saved = await cubit.save();
      expect(saved!.isRecurring, isTrue);
      expect(saved.recurringDueOn, '2026-07-31');
      expect(cubit.lastSaveRepeating, isTrue);
      expect(cubit.lastPastAdded, 2);
      expect(cubit.lastSavedSchedule!.startOn, '2026-07-31');
      expect(await deps.database.query('expenses'), hasLength(3));
    });

    test('off: a plain expense', () async {
      final cubit = await validForm()
        ..repeatToggled(true)
        ..repeatToggled(false);
      final saved = await cubit.save();
      expect(saved!.isRecurring, isFalse);
      expect(cubit.lastSaveRepeating, isFalse);
      expect(await deps.database.query('recurring_expenses'), isEmpty);
    });

    test('a double tap saves once', () async {
      final cubit = await validForm()
        ..repeatToggled(true);
      final results = await Future.wait([cubit.save(), cubit.save()]);
      expect(results.whereType<Expense>(), hasLength(1));
      expect(await deps.database.query('recurring_expenses'), hasLength(1));
      expect(await deps.database.query('expenses'), hasLength(1));
    });

    test('Save with Repeats deletes the draft it owns (that it is in the '
        'same transaction is the repository test)', () async {
      final cubit = await validForm()
        ..repeatToggled(true);
      await drafts.flush();
      expect(await drafts.read(), isNotNull);
      await cubit.save();
      expect(await deps.database.query('expense_draft'), isEmpty);
    });
  });

  group('draft, Clear and Undo', () {
    test('a resumed Add draft brings Repeats back as it was', () async {
      final first = await validForm()
        ..repeatToggled(true)
        ..repeatIntervalChanged('0')
        ..repeatEndChanged(RepeatEnd.onDate);
      await drafts.flush();
      await first.close();
      final draft = await drafts.read();
      final again = await openForm(draft: draft);
      expect(
        repeatOf(again),
        const RepeatChoice(
          intervalText: '0',
          end: RepeatEnd.onDate,
          endOn: '2027-04-09',
        ),
      );
    });

    test('Clear turns Repeats off; Undo brings it back', () async {
      final cubit = await validForm()
        ..repeatToggled(true)
        ..repeatIntervalChanged('2');
      await cubit.clear();
      expect(repeatOf(cubit), isNull);
      cubit.undoReset();
      expect(repeatOf(cubit)!.intervalText, '2');
    });

    test('an Edit draft never brings Repeats into the Edit form', () async {
      final saved = await deps.expenses.add(
        ExpenseInput(
          title: 'Lunch',
          description: null,
          amount: const Money(100, 'INR'),
          occurredAt: clock.now.toUtc(),
          utcOffsetMinutes: clock.now.timeZoneOffset.inMinutes,
          categoryId: 1,
          paymentMethodId: 1,
          eventIds: const {},
        ),
      );
      final draft = ExpenseDraft(
        editingExpenseId: saved.id,
        title: 'Lunch!',
        amountExpression: '1',
        description: '',
        categoryId: 1,
        eventIds: const {},
        paymentMethodId: 1,
        currencyCode: 'INR',
        pickedWallClock: null,
        touched: const {DraftField.title},
        itemizeLine: null,
        itemizeLabels: const [],
        itemizeTerms: const [],
        updatedAt: clock.now.toUtc(),
        repeat: RepeatChoice.defaults,
      );
      final cubit = await openForm(expenseId: saved.id, draft: draft);
      expect(repeatOf(cubit), isNull);
      cubit.repeatToggled(true);
      expect(repeatOf(cubit), isNull, reason: 'Add only (P7a-6)');
    });
  });

  group('title suggestions', () {
    setUp(() async {
      await deps.expenses.add(
        ExpenseInput(
          title: 'Netflix',
          description: 'plan',
          amount: const Money(64900, 'INR'),
          occurredAt: clock.now.subtract(const Duration(days: 2)).toUtc(),
          utcOffsetMinutes: 330,
          categoryId: 17,
          paymentMethodId: 4,
          eventIds: const {},
        ),
      );
    });

    TitleSuggestion suggestionFor(ExpenseFormCubit cubit, String typed) {
      cubit.titleChanged(typed);
      return ready(cubit).suggestions.first;
    }

    test('a pick never switches Repeats on', () async {
      final cubit = await openForm();
      await cubit.pickSuggestion(suggestionFor(cubit, 'Ne'));
      expect(repeatOf(cubit), isNull);
    });

    test('Repeats on after a pick still allows a second pick, which keeps '
        'it on (like photos, phase-6.md §12a)', () async {
      final cubit = await openForm();
      await cubit.pickSuggestion(suggestionFor(cubit, 'Ne'));
      cubit.repeatToggled(true);
      expect(ready(cubit).suggestions, isEmpty);
      cubit.titleChanged('Netf');
      expect(
        ready(cubit).suggestions,
        isNotEmpty,
        reason: 'Repeats is not a change a pick would overwrite',
      );
      await cubit.pickSuggestion(ready(cubit).suggestions.first);
      expect(repeatOf(cubit), RepeatChoice.defaults);
    });
  });

  group('Edit', () {
    test('a payment: its item is linked; there is no switch', () async {
      final (:expense, pastAdded: _) = await deps.expenses.addRepeating(
        ExpenseInput(
          title: 'Gym',
          description: null,
          amount: const Money(150000, 'INR'),
          occurredAt: clock.now.toUtc(),
          utcOffsetMinutes: clock.now.timeZoneOffset.inMinutes,
          categoryId: 11,
          paymentMethodId: 1,
          eventIds: const {},
        ),
        RepeatChoice.defaults,
      );
      final cubit = await openForm(expenseId: expense.id);
      expect(cubit.linkedItem!.id, expense.recurringExpenseId);
      expect(cubit.linkedItem!.title, 'Gym');
      cubit.repeatToggled(true);
      expect(repeatOf(cubit), isNull);
    });

    test('a plain expense: no link', () async {
      final saved = await deps.expenses.add(
        ExpenseInput(
          title: 'Lunch',
          description: null,
          amount: const Money(100, 'INR'),
          occurredAt: clock.now.toUtc(),
          utcOffsetMinutes: 0,
          categoryId: 1,
          paymentMethodId: 1,
          eventIds: const {},
        ),
      );
      expect((await openForm(expenseId: saved.id)).linkedItem, isNull);
    });
  });

  group('Recurring → New (startRepeating)', () {
    test('a new form opens with Repeats on and no changes', () async {
      final cubit = await openForm(startRepeating: true);
      expect(repeatOf(cubit), RepeatChoice.defaults);
      expect(cubit.isDirty, isFalse);
      await drafts.flush();
      expect(await drafts.read(), isNull, reason: 'nothing typed: no draft');
    });

    test('an Add draft without Repeats opens as it was, Repeats on', () async {
      final first = await validForm();
      await drafts.flush();
      await first.close();
      final cubit = await openForm(
        draft: await drafts.read(),
        startRepeating: true,
      );
      expect(ready(cubit).fields.title, 'Netflix');
      expect(repeatOf(cubit), RepeatChoice.defaults);
    });

    test('an Add draft with Repeats opens exactly as it was', () async {
      final first = await validForm()
        ..repeatToggled(true)
        ..repeatFrequencyChanged(Frequency.weekly);
      await drafts.flush();
      await first.close();
      final cubit = await openForm(
        draft: await drafts.read(),
        startRepeating: true,
      );
      expect(repeatOf(cubit)!.frequency, Frequency.weekly);
    });
  });
}
