import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/data/repositories/expense_draft_repository.dart';
import 'package:money_swield/data/repositories/expense_repository.dart';
import 'package:money_swield/domain/amount_expression.dart';
import 'package:money_swield/domain/models/expense.dart';
import 'package:money_swield/domain/models/expense_draft.dart';
import 'package:money_swield/domain/models/money.dart';
import 'package:money_swield/domain/title_suggestions.dart';
import 'package:money_swield/ui/features/expenses/view_models/expense_form_cubit.dart';

import '../../../../helpers/fake_timers.dart';
import '../../../../helpers/test_database.dart';

/// The Add/Edit form's smart entry behaviour.
void main() {
  late AppDependencies deps;
  late TestClock clock;
  late FakeTimers timers;
  late ExpenseDraftRepository drafts;

  setUp(() async {
    clock = TestClock();
    deps = await openTestDependencies(clock: clock);
    timers = FakeTimers();
    drafts = ExpenseDraftRepository(deps.database, timer: timers.call);
  });

  Future<ExpenseFormCubit> openForm({
    int? expenseId,
    ExpenseDraft? draft,
    Money? chip,
    String separator = '.',
    ExpenseDraftRepository? using,
  }) async {
    final cubit = ExpenseFormCubit(
      expenses: deps.expenses,
      categories: deps.categories,
      events: deps.events,
      paymentMethods: deps.paymentMethods,
      drafts: using ?? drafts,
      l10n: l10nFor('en'),
      defaultCurrency: 'INR',
      defaultPaymentMethodId: 1,
      decimalSeparator: separator,
      expenseId: expenseId,
      openingDraft: draft,
      chipAmount: chip,
      now: clock.call,
    );
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  ExpenseFormReady ready(ExpenseFormCubit cubit) =>
      cubit.value as ExpenseFormReady;
  ExpenseFields fieldsOf(ExpenseFormCubit cubit) => ready(cubit).fields;

  Future<Expense> seed({
    String title = 'Lunch',
    String? description = 'With rice',
    Money amount = const Money(11050, 'INR'),
    String? expression,
    int categoryId = 3,
    int paymentMethodId = 2,
    Set<int> eventIds = const {1},
    int daysAgo = 1,
  }) => deps.expenses.add(
    ExpenseInput(
      title: title,
      description: description,
      amount: amount,
      amountExpression: expression,
      occurredAt: clock.now.subtract(Duration(days: daysAgo)),
      utcOffsetMinutes: 330,
      categoryId: categoryId,
      paymentMethodId: paymentMethodId,
      eventIds: eventIds,
    ),
  );

  /// The suggestion for [typed] once the history is loaded.
  TitleSuggestion suggestionFor(ExpenseFormCubit cubit, String typed) {
    cubit.titleChanged(typed);
    return ready(cubit).suggestions.first;
  }

  Future<ExpenseDraft?> slot() => drafts.read();

  Future<int> draftRows() async =>
      (await deps.database.query('expense_draft')).length;

  group('suggestions', () {
    test('computed for the title typed before the history arrived', () async {
      await seed();
      final cubit = ExpenseFormCubit(
        expenses: deps.expenses,
        categories: deps.categories,
        events: deps.events,
        paymentMethods: deps.paymentMethods,
        drafts: drafts,
        l10n: l10nFor('en'),
        defaultCurrency: 'INR',
        defaultPaymentMethodId: 1,
        now: clock.call,
      );
      addTearDown(cubit.close);
      final loading = cubit.load();
      // The form shows before the history query finishes.
      await pumpEventQueueUntil(() => cubit.value is ExpenseFormReady);
      cubit.titleChanged('lu');
      await loading;
      expect(ready(cubit).suggestions.map((s) => s.title), ['Lunch']);
    });

    test(
      'a failing history read means no suggestions, the form works',
      () async {
        await seed();
        final cubit = ExpenseFormCubit(
          expenses: _NoHistory(deps),
          categories: deps.categories,
          events: deps.events,
          paymentMethods: deps.paymentMethods,
          drafts: drafts,
          l10n: l10nFor('en'),
          defaultCurrency: 'INR',
          defaultPaymentMethodId: 1,
          now: clock.call,
        );
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.value, isA<ExpenseFormReady>());
        cubit.titleChanged('lu');
        expect(ready(cubit).suggestions, isEmpty);
      },
    );

    test(
      'not shown for an Edit title or a resumed draft until typed',
      () async {
        final lunch = await seed();
        final edit = await openForm(expenseId: lunch.id);
        expect(ready(edit).suggestions, isEmpty);
        edit.titleChanged('Lunc');
        expect(ready(edit).suggestions, isNotEmpty);
      },
    );

    test('hidden after a pick and on dismiss', () async {
      await seed();
      final cubit = await openForm();
      await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
      expect(ready(cubit).suggestions, isEmpty);
      cubit.titleChanged('Lun');
      expect(ready(cubit).suggestions, isNotEmpty);
      cubit.dismissSuggestions();
      expect(ready(cubit).suggestions, isEmpty);
    });
  });

  group('prefill', () {
    test('fills every untouched field from the newest expense', () async {
      await seed(daysAgo: 3, amount: const Money(100, 'INR'));
      await seed(
        title: 'lunch',
        expression: '50+60*2',
        amount: const Money(17000, 'INR'),
        eventIds: {1, 2},
      );
      final cubit = await openForm();
      await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));

      final fields = fieldsOf(cubit);
      expect(fields.title, 'lunch', reason: 'the newest spelling');
      expect(fields.expression, '50+60×2');
      expect(fields.description, 'With rice');
      expect(fields.categoryId, 3);
      expect(fields.paymentMethodId, 2);
      expect(fields.eventIds, {1, 2});
      expect(fields.currencyCode, 'INR');
      expect(ready(cubit).touched, {
        DraftField.title,
      }, reason: 'prefilled fields stay untouched');
    });

    test('the date and time are never copied', () async {
      await seed(daysAgo: 30);
      final cubit = await openForm();
      final before = fieldsOf(cubit).wallClock;
      await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
      expect(fieldsOf(cubit).wallClock, before);
    });

    test('only untouched fields', () async {
      await seed();
      final cubit = await openForm()
        ..categorySelected(5)
        ..descriptionChanged('mine')
        ..eventsCleared()
        ..paymentMethodSelected(4);
      await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
      final fields = fieldsOf(cubit);
      expect(fields.categoryId, 5);
      expect(fields.description, 'mine');
      expect(fields.eventIds, isEmpty);
      expect(fields.paymentMethodId, 4);
      expect(fields.expression, '110.50', reason: 'amount was untouched');
    });

    test('a second pick replaces the first pick\'s values', () async {
      await seed(title: 'Lunch', categoryId: 3);
      await seed(
        title: 'Taxi',
        description: null,
        categoryId: 6,
        amount: const Money(30000, 'INR'),
        eventIds: {},
      );
      final cubit = await openForm();
      await cubit.pickSuggestion(suggestionFor(cubit, 'Lu'));
      await cubit.pickSuggestion(suggestionFor(cubit, 'Ta'));
      final fields = fieldsOf(cubit);
      expect(fields.title, 'Taxi');
      expect(fields.categoryId, 6);
      expect(fields.description, '', reason: 'Taxi had none');
      expect(fields.eventIds, isEmpty);
      expect(fields.expression, '300.00');
    });

    group('after a prefill (owner, 2026-10-04)', () {
      setUp(() async {
        await seed(title: 'Lunch', amount: const Money(11050, 'INR'));
        await seed(title: 'Taxi', amount: const Money(30000, 'INR'));
      });

      Future<ExpenseFormCubit> prefilled() async {
        final cubit = await openForm();
        await cubit.pickSuggestion(suggestionFor(cubit, 'Lu'));
        return cubit;
      }

      test("only a suggestion's values → no draft; back keeps none", () async {
        final cubit = await openForm()
          ..titleChanged('Lu');
        expect(cubit.ownsDraft, isTrue, reason: 'a typed title is input');
        await cubit.pickSuggestion(ready(cubit).suggestions.first);
        expect(cubit.ownsDraft, isFalse);
        expect(await slot(), isNull);
      });

      test(
        'a second pick, or the title typed again, keeps it draft-free',
        () async {
          final cubit = await prefilled();
          await cubit.pickSuggestion(suggestionFor(cubit, 'Ta'));
          cubit.titleChanged('Taxi-');
          expect(await slot(), isNull);
        },
      );

      group('a title typed after the pick', () {
        test('is a search while the title has focus; left without a pick, '
            'it is a change: draft, no more suggestions', () async {
          final cubit = await prefilled()
            ..titleChanged('Lunch at office');
          expect(await slot(), isNull, reason: 'still typing: a search');
          cubit.titleLeft();
          final draft = (await slot())!;
          expect(draft.title, 'Lunch at office');
          expect(draft.amountExpression, '110.50');
          expect(draft.suggestionsBlocked, isTrue);
          expect(cubit.ownsDraft, isTrue);
          cubit.titleChanged('Ta');
          expect(ready(cubit).suggestions, isEmpty);
        });

        test(
          'left as the picked title (spaces aside) → still no draft',
          () async {
            final cubit = await prefilled()
              ..titleChanged('Lunch-')
              ..titleChanged('Lunch ')
              ..titleLeft();
            expect(await slot(), isNull);
            expect(suggestionFor(cubit, 'Ta').title, 'Taxi');
          },
        );

        test('picked instead → no draft', () async {
          final cubit = await prefilled();
          await cubit.pickSuggestion(suggestionFor(cubit, 'Ta'));
          cubit.titleLeft();
          expect(await slot(), isNull);
        });

        test('Clear brings the suggestions back', () async {
          final cubit = await prefilled()
            ..titleChanged('Lunch at office')
            ..titleLeft();
          await cubit.clear();
          expect(suggestionFor(cubit, 'Ta').title, 'Taxi');
        });

        test('the app going to the background keeps it in the slot without '
            'blocking; a pick on return removes it', () async {
          final cubit = await prefilled()
            ..titleChanged('Ta');
          await cubit.flushDraftInBackground();
          final draft = (await slot())!;
          expect(draft.title, 'Ta');
          expect(draft.suggestionsBlocked, isFalse);
          await cubit.pickSuggestion(ready(cubit).suggestions.first);
          expect(await slot(), isNull);
        });

        test('Edit: a renamed title left without a pick → draft', () async {
          final e = await seed(title: 'Dinner', daysAgo: 2);
          final cubit = await openForm(expenseId: e.id);
          await cubit.pickSuggestion(suggestionFor(cubit, 'Ta'));
          cubit
            ..titleChanged('Taxi home')
            ..titleLeft();
          expect((await slot())!.title, 'Taxi home');
          expect((await slot())!.editingExpenseId, e.id);
        });
      });

      test('a change after the pick saves the whole form; changed back → '
          'the draft goes', () async {
        final cubit = await prefilled();
        final shown = fieldsOf(cubit).wallClock;
        cubit.dateChanged(DateTime(2026, 9, 1));
        final draft = (await slot())!;
        expect(draft.title, 'Lunch');
        expect(draft.amountExpression, '110.50');
        expect(draft.description, 'With rice');
        expect(draft.suggestionsBlocked, isTrue);
        cubit.dateChanged(DateTime(shown.year, shown.month, shown.day));
        expect(await slot(), isNull);
      });

      test('input from before the pick is kept as a draft', () async {
        final cubit = await openForm()
          ..categorySelected(5);
        await cubit.pickSuggestion(suggestionFor(cubit, 'Lu'));
        final draft = (await slot())!;
        expect(draft.categoryId, 5);
        expect(
          draft.suggestionsBlocked,
          isFalse,
          reason: 'nothing changed since the pick',
        );
      });

      test('a chip and a pick → no draft', () async {
        final cubit = await openForm(chip: const Money(5000, 'INR'));
        await cubit.pickSuggestion(suggestionFor(cubit, 'Lu'));
        expect(fieldsOf(cubit).expression, '50.00');
        expect(await slot(), isNull);
      });

      test('Edit: a pick only changes the title → no draft', () async {
        final e = await seed(title: 'Dinner', daysAgo: 2);
        final cubit = await openForm(expenseId: e.id);
        await cubit.pickSuggestion(suggestionFor(cubit, 'Ta'));
        expect(fieldsOf(cubit).title, 'Taxi');
        expect(cubit.canSave, isTrue);
        expect(await slot(), isNull);
      });

      test('a resumed draft changed after a pick: still no suggestions; '
          'Clear → back', () async {
        final first = await prefilled()
          ..descriptionChanged('mine');
        final draft = (await slot())!;
        await first.close();
        final cubit = await openForm(draft: draft)
          ..titleChanged('Ta');
        expect(ready(cubit).suggestions, isEmpty);
        await cubit.clear();
        expect(suggestionFor(cubit, 'Ta').title, 'Taxi');
      });

      test('a resumed draft picked into keeps its draft', () async {
        final cubit = await openForm(
          draft: _addDraft(title: 'x', amount: '80'),
        );
        await cubit.pickSuggestion(suggestionFor(cubit, 'Ta'));
        expect(cubit.ownsDraft, isTrue);
        expect((await slot())!.title, 'Taxi');
      });

      test('a field changed → no suggestions, a pick does nothing', () async {
        final cubit = await prefilled();
        final taxi = suggestionFor(cubit, 'Ta');
        cubit
          ..amountChanged('')
          ..titleChanged('Ta');
        expect(ready(cubit).suggestions, isEmpty);
        await cubit.pickSuggestion(taxi);
        expect(fieldsOf(cubit).title, 'Ta');
        expect(fieldsOf(cubit).expression, '');
      });

      test('changed back to the prefilled value → suggestions again', () async {
        final cubit = await prefilled()
          ..categorySelected(5)
          ..categorySelected(3);
        cubit.titleChanged('Ta');
        expect(ready(cubit).suggestions.map((s) => s.title), ['Taxi']);
      });

      test('Clear → suggestions again, the pick fills the form; Undo → the '
          'prefill rule back', () async {
        final cubit = await prefilled()
          ..amountChanged('1');
        await cubit.clear();
        await cubit.pickSuggestion(suggestionFor(cubit, 'Ta'));
        expect(fieldsOf(cubit).expression, '300.00');
        cubit.undoReset();
        expect(fieldsOf(cubit).expression, '1');
        cubit.titleChanged('Ta');
        expect(ready(cubit).suggestions, isEmpty);
      });
    });

    group('amount and currency go together', () {
      Future<ExpenseFormCubit> pickUsd({
        bool amountTouched = false,
        String? amountTyped,
        String? currency,
      }) async {
        await seed(amount: const Money(1250, 'USD'));
        final cubit = await openForm();
        if (amountTouched) cubit.amountChanged('99');
        if (amountTyped != null) cubit.amountChanged(amountTyped);
        if (currency != null) cubit.currencyChanged(currency);
        await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
        return cubit;
      }

      test('both untouched → both copied', () async {
        final f = fieldsOf(await pickUsd());
        expect((f.expression, f.currencyCode), ('12.50', 'USD'));
      });

      test(
        'amount typed then cleared → both copied (owner, 2026-10-04)',
        () async {
          await seed(amount: const Money(1250, 'USD'));
          final cubit = await openForm()
            ..amountChanged('99')
            ..amountChanged('');
          await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
          final f = fieldsOf(cubit);
          expect((f.expression, f.currencyCode), ('12.50', 'USD'));
        },
      );

      test('a second pick replaces an amount the first pick filled into an '
          'emptied field', () async {
        await seed(title: 'Lunch', amount: const Money(11050, 'INR'));
        await seed(title: 'Taxi', amount: const Money(30000, 'INR'));
        final cubit = await openForm()
          ..amountChanged('5')
          ..amountChanged('');
        await cubit.pickSuggestion(suggestionFor(cubit, 'Lu'));
        expect(fieldsOf(cubit).expression, '110.50');
        await cubit.pickSuggestion(suggestionFor(cubit, 'Ta'));
        expect(fieldsOf(cubit).expression, '300.00');
        expect(ready(cubit).touched, contains(DraftField.amount));
      });

      test('blank (spaces only) counts as empty', () async {
        final f = fieldsOf(await pickUsd(amountTyped: '  '));
        expect(f.expression, '12.50');
      });

      test('amount touched → neither', () async {
        final f = fieldsOf(await pickUsd(amountTouched: true));
        expect((f.expression, f.currencyCode), ('99', 'INR'));
      });

      test('currency touched to another → neither', () async {
        final f = fieldsOf(await pickUsd(currency: 'EUR'));
        expect((f.expression, f.currencyCode), ('', 'EUR'));
      });

      test('currency touched to the same → amount copied', () async {
        final f = fieldsOf(await pickUsd(currency: 'USD'));
        expect((f.expression, f.currencyCode), ('12.50', 'USD'));
      });
    });

    test('archived events are not copied', () async {
      await seed(eventIds: {1, 2});
      await deps.events.setArchived(2, true);
      final cubit = await openForm();
      await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
      expect(fieldsOf(cubit).eventIds, {1});
    });

    test('a stored expression that doesn\'t match the amount → the plain '
        'amount, and Save keeps the same minor units', () async {
      await seed(expression: '50+60', amount: const Money(12345, 'INR'));
      final cubit = await openForm();
      await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
      expect(fieldsOf(cubit).expression, '123.45');
      final saved = await cubit.save();
      expect(saved!.amount.amountMinor, 12345);
      expect(saved.amountExpression, isNull);
    });

    test(
      'a prefilled expression saves the same minor units and expression',
      () async {
        await seed(expression: '1/3*3', amount: const Money(100, 'INR'));
        final cubit = await openForm();
        await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
        final saved = await cubit.save();
        expect(saved!.amount.amountMinor, 100);
        expect(saved.amountExpression, '1/3*3');
      },
    );

    test('in es the prefilled expression uses `,`', () async {
      await seed(expression: '1.5*2', amount: const Money(300, 'INR'));
      final cubit = await openForm(separator: ',');
      await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
      expect(fieldsOf(cubit).expression, '1,5×2');
      expect(cubit.isDirty, isTrue);
      expect((await cubit.save())!.amountExpression, '1.5*2');
    });

    test('on Edit a pick changes only the title', () async {
      await seed(title: 'Dinner', categoryId: 9, description: 'x');
      final mine = await seed(title: 'Mine', categoryId: 1);
      final cubit = await openForm(expenseId: mine.id);
      await cubit.pickSuggestion(suggestionFor(cubit, 'Din'));
      final fields = fieldsOf(cubit);
      expect(fields.title, 'Dinner');
      expect(fields.categoryId, 1);
      expect(fields.description, 'With rice');
    });

    test('a source binned after the history was read fills nothing', () async {
      final lunch = await seed();
      final cubit = await openForm();
      final suggestion = suggestionFor(cubit, 'lu');
      await deps.expenses.moveToBin(lunch.id);
      await cubit.pickSuggestion(suggestion);
      expect(fieldsOf(cubit).title, 'Lunch');
      expect(fieldsOf(cubit).categoryId, isNull);
    });

    test(
      'an itemized description is recognised: Itemize replaces it',
      () async {
        await seed(
          expression: '50+60',
          amount: const Money(11000, 'INR'),
          description: '50 (potato) + 60 (onion)\nfrom the market',
        );
        final cubit = await openForm();
        await cubit.pickSuggestion(suggestionFor(cubit, 'lu'));
        expect(cubit.itemizeLabels, ['potato', 'onion']);
        cubit.itemize(['potatoes', 'onion']);
        expect(
          fieldsOf(cubit).description,
          '50 (potatoes) + 60 (onion)\nfrom the market',
        );
      },
    );
  });

  group('itemize', () {
    test('first time, then replaced while unchanged, added above once '
        'edited', () async {
      final cubit = await openForm()
        ..amountChanged('50+60×2')
        ..descriptionChanged('notes');
      expect(cubit.itemizeTerms, ['50', '+60*2']);
      cubit.itemize(['potato', 'onion']);
      expect(
        fieldsOf(cubit).description,
        '50 (potato) + 60 × 2 (onion)\nnotes',
      );

      cubit.itemize(['', 'onions']);
      expect(fieldsOf(cubit).description, '50 + 60 × 2 (onions)\nnotes');

      cubit.descriptionChanged('50 + 60 × 2 (onions) edited\nnotes');
      cubit.itemize(['a', 'b']);
      expect(
        fieldsOf(cubit).description,
        '50 (a) + 60 × 2 (b)\n50 + 60 × 2 (onions) edited\nnotes',
      );
    });

    test('offered only for ≥ 2 terms that evaluate', () async {
      final cubit = await openForm()
        ..amountChanged('50');
      expect(cubit.itemizeTerms, isNull);
      cubit.amountChanged('50+60÷0');
      expect(cubit.itemizeTerms, isNull);
      cubit.amountChanged('2×3');
      expect(cubit.itemizeTerms, isNull, reason: 'one product is one term');
      cubit.amountChanged('50+');
      expect(cubit.itemizeTerms, isNull, reason: 'one term after the drop');
    });

    test('labels come back for the same terms, not for others', () async {
      final cubit = await openForm()
        ..amountChanged('50+60');
      cubit.itemize(['a', 'b']);
      expect(cubit.itemizeLabels, ['a', 'b']);
      cubit.amountChanged('50+70');
      expect(cubit.itemizeLabels, ['', '']);
      cubit.amountChanged('50,0+60');
      expect(cubit.itemizeLabels, [
        '',
        '',
      ], reason: '50.0 is another canonical term than 50');
    });

    test('an Edit recognises its saved line and recovers labels', () async {
      final e = await seed(
        expression: '50+60',
        amount: const Money(11000, 'INR'),
        description: '50 (potato) + 60 (onion)',
      );
      final cubit = await openForm(expenseId: e.id);
      expect(cubit.itemizeLabels, ['potato', 'onion']);
      cubit.itemize(['p', 'o']);
      expect(fieldsOf(cubit).description, '50 (p) + 60 (o)');
    });
  });

  group('draft slot ownership', () {
    test('a change writes the draft; changing back clears it', () async {
      final cubit = await openForm()
        ..titleChanged('Tea');
      expect(cubit.ownsDraft, isTrue);
      expect((await slot())?.title, 'Tea');
      cubit.titleChanged('');
      expect(cubit.ownsDraft, isFalse);
      expect(await slot(), isNull);
      await drafts.flush();
      expect(await draftRows(), 0);
    });

    test('opening Edit #9 while #7 has a draft and closing it untouched '
        'keeps #7\'s draft', () async {
      final seven = await seed(title: 'Seven');
      final nine = await seed(title: 'Nine');
      final first = await openForm(expenseId: seven.id)
        ..titleChanged('7!');
      await first.flushDraft();
      await first.close();

      final second = await openForm(expenseId: nine.id);
      await second.flushDraft();
      await second.close();
      expect((await slot())?.editingExpenseId, seven.id);
      expect(await draftRows(), 1);
    });

    test('a change in #9 takes the slot; changing back empties it', () async {
      final seven = await seed(title: 'Seven');
      final nine = await seed(title: 'Nine');
      (await openForm(expenseId: seven.id)).titleChanged('7!');

      final second = await openForm(expenseId: nine.id)
        ..titleChanged('9!');
      expect((await slot())?.editingExpenseId, nine.id);
      second.titleChanged('Nine');
      expect(await slot(), isNull);
    });

    test('resume, change, change back: the draft is still there', () async {
      final resumed = await openForm(
        draft: _addDraft(title: 'Tea', touched: {DraftField.title}),
      );
      expect(resumed.isDirty, isTrue, reason: 'against a new form');
      resumed.titleChanged('Teas');
      resumed.titleChanged('Tea');
      expect((await slot())?.title, 'Tea');
    });

    test('nothing is written while loading or after close', () async {
      final cubit = ExpenseFormCubit(
        expenses: deps.expenses,
        categories: deps.categories,
        events: deps.events,
        paymentMethods: deps.paymentMethods,
        drafts: drafts,
        l10n: l10nFor('en'),
        defaultCurrency: 'INR',
        defaultPaymentMethodId: 1,
        now: clock.call,
      );
      cubit.titleChanged('while loading');
      await cubit.load();
      expect(await slot(), isNull);
      await cubit.close();
      cubit.titleChanged('after close');
      expect(await slot(), isNull);
    });

    test('the draft holds canonical text and the touched set', () async {
      (await openForm(separator: ','))
        ..amountChanged('1,5×2')
        ..categorySelected(4);
      final draft = (await slot())!;
      expect(draft.amountExpression, '1.5*2');
      expect(draft.touched, {DraftField.amount, DraftField.category});
      expect(draft.pickedWallClock, isNull, reason: 'date untouched');
      expect(draft.editingExpenseId, isNull);
    });

    test('a touched date is kept in the draft', () async {
      (await openForm()).dateChanged(DateTime(2026, 9, 1));
      final draft = (await slot())!;
      expect(draft.pickedWallClock!.day, 1);
      expect(draft.pickedWallClock!.month, 9);
    });
  });

  group('save and the draft', () {
    test(
      'Save deletes the draft row with the expense: no row, no memory',
      () async {
        final cubit = await openForm()
          ..titleChanged('Tea')
          ..amountChanged('20')
          ..categorySelected(2);
        await drafts.flush();
        expect(await draftRows(), 1);

        expect(await cubit.save(), isNotNull);
        expect(await draftRows(), 0);
        expect(await slot(), isNull);
        expect(cubit.ownsDraft, isFalse);
      },
    );

    test('a write still queued when Save starts can\'t bring the row back '
        '(no duplicate on the next Add)', () async {
      final cubit = await openForm()
        ..titleChanged('Tea')
        ..amountChanged('20')
        ..categorySelected(2);
      // Hold the database, so the first draft write waits for it and a
      // second one is chained behind it. sqflite runs a statement issued
      // during a transaction after its commit (probed), so without the
      // form waiting for the draft writes, the second write would land
      // after Save's commit and bring the draft back.
      final release = Completer<void>();
      final held = deps.database.transaction((_) => release.future);
      timers.elapse();
      // The first write starts (it reads the draft) and waits for the
      // database; the next change makes a second write due.
      await Future<void>.delayed(Duration.zero);
      cubit.descriptionChanged('more');
      timers.elapse();
      final saving = cubit.save();
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await held;
      expect(await saving, isNotNull);
      await drafts.flush();
      expect(await draftRows(), 0);

      final restarted = ExpenseDraftRepository(deps.database);
      expect(await restarted.read(), isNull, reason: 'app killed now');
    });

    test(
      'a chip alone isn\'t a change: back leaves another draft alone',
      () async {
        final seven = await seed(title: 'Seven');
        (await openForm(expenseId: seven.id)).titleChanged('7!');
        await drafts.flush();

        final chip = await openForm(chip: const Money(5000, 'INR'));
        expect(chip.ownsDraft, isFalse);
        await chip.flushDraft();
        expect((await slot())?.editingExpenseId, seven.id);
      },
    );

    test('an untouched Edit can\'t save, so it never clears another '
        'draft', () async {
      final seven = await seed(title: 'Seven');
      final nine = await seed(title: 'Nine');
      (await openForm(expenseId: seven.id)).titleChanged('7!');
      final edit = await openForm(expenseId: nine.id);
      expect(await edit.save(), isNotNull, reason: 'save() itself works');
      expect((await slot())?.editingExpenseId, seven.id);
      await drafts.flush();
      expect(await draftRows(), 1);
    });

    test('a failing save keeps the draft', () async {
      final cubit = await openForm()
        ..titleChanged('Tea')
        ..amountChanged('20')
        ..categorySelected(2)
        ..paymentMethodSelected(4);
      await deps.database.delete('payment_methods', where: 'id = 4');
      await expectLater(cubit.save(), throwsA(anything));
      await drafts.flush();
      expect((await slot())?.title, 'Tea');
      expect(await draftRows(), 1);
    });

    test('Update of an expense binned meanwhile keeps the edits as an Add '
        'draft', () async {
      final e = await seed();
      final cubit = await openForm(expenseId: e.id)
        ..titleChanged('Edited');
      await deps.expenses.moveToBin(e.id);
      expect(await cubit.save(), isNull);
      expect(cubit.value, isA<ExpenseFormGone>());
      expect((cubit.value as ExpenseFormGone).draftKept, isTrue);
      final draft = (await slot())!;
      expect(draft.editingExpenseId, isNull);
      expect(draft.title, 'Edited');
    });

    test('Delete takes the draft with it', () async {
      final e = await seed();
      final cubit = await openForm(expenseId: e.id)
        ..titleChanged('x');
      await drafts.flush();
      expect(await cubit.moveToBin(), e.id);
      expect(await draftRows(), 0);
      expect(await slot(), isNull);
    });

    test('Delete of an already binned expense says gone', () async {
      final e = await seed();
      final cubit = await openForm(expenseId: e.id);
      await deps.expenses.moveToBin(e.id);
      expect(await cubit.moveToBin(), isNull);
      expect(cubit.value, isA<ExpenseFormGone>());
    });

    test(
      'Update is disabled until a change; Save on Add is always on',
      () async {
        final e = await seed();
        final edit = await openForm(expenseId: e.id);
        expect(edit.canSave, isFalse);
        edit.titleChanged('x');
        expect(edit.canSave, isTrue);
        expect((await openForm()).canSave, isTrue);
      },
    );

    test('the expression is saved and shown again on Edit', () async {
      final cubit = await openForm()
        ..titleChanged('Veg')
        ..amountChanged('50+60×2+')
        ..categorySelected(3);
      final saved = (await cubit.save())!;
      expect(saved.amount.amountMinor, 17000);
      expect(saved.amountExpression, '50+60*2', reason: 'normalized');
      final edit = await openForm(expenseId: saved.id);
      expect(fieldsOf(edit).expression, '50+60×2');
      expect(edit.isDirty, isFalse);
    });

    test('`,` vs `.` for the same number isn\'t a change', () async {
      final e = await seed(amount: const Money(150, 'INR'));
      final cubit = await openForm(expenseId: e.id);
      expect(fieldsOf(cubit).expression, '1.50');
      cubit.amountChanged('1,50');
      expect(cubit.isDirty, isFalse);
    });
  });

  group('resume', () {
    test('an Add draft with an untouched date opens at now', () async {
      final cubit = await openForm(draft: _addDraft(title: 'Tea'));
      final local = clock.now.toLocal();
      expect(fieldsOf(cubit).wallClock.hour, local.hour);
      expect(ready(cubit).restoredAt, isNotNull, reason: 'the banner');
      clock.advance(const Duration(days: 1));
      final next = await openForm(draft: _addDraft(title: 'Tea'));
      expect(fieldsOf(next).wallClock.day, clock.now.toLocal().day);
    });

    test('a touched date keeps the picked wall-clock time', () async {
      final picked = DateTime(2026, 9, 20, 13, 5);
      final cubit =
          await openForm(
              draft: _addDraft(
                title: 'Tea',
                picked: picked,
                touched: {DraftField.dateTime},
              ),
            )
            ..amountChanged('5')
            ..categorySelected(1);
      expect(fieldsOf(cubit).wallClock, DateTime.utc(2026, 9, 20, 13, 5));
      final saved = await cubit.save();
      expect(saved!.wallClock, DateTime.utc(2026, 9, 20, 13, 5));
    });

    test('an Edit draft with an untouched date keeps occurred_at and the '
        'offset', () async {
      final e = await seed();
      final cubit = await openForm(
        expenseId: e.id,
        draft: _editDraft(e.id, title: 'Changed'),
      );
      expect(fieldsOf(cubit).title, 'Changed');
      expect(cubit.isDirty, isTrue);
      final saved = (await cubit.save())!;
      expect(saved.occurredAt, e.occurredAt);
      expect(saved.utcOffsetMinutes, e.utcOffsetMinutes);
    });

    test('the banner goes on the first change', () async {
      final cubit = await openForm(draft: _addDraft(title: 'Tea'));
      expect(ready(cubit).restoredAt, isNotNull);
      cubit.amountChanged('1');
      expect(ready(cubit).restoredAt, isNull);
    });

    group('cleaning', () {
      test('a deleted category: Add → none, Edit → the expense\'s', () async {
        final category = await deps.categories.add(name: 'Temp', emoji: '🧪');
        await deps.categories.delete(category.id);
        final add = await openForm(
          draft: _addDraft(title: 'x', categoryId: category.id),
        );
        expect(fieldsOf(add).categoryId, isNull);

        final e = await seed(categoryId: 3);
        final edit = await openForm(
          expenseId: e.id,
          draft: _editDraft(e.id, categoryId: category.id),
        );
        expect(fieldsOf(edit).categoryId, 3);
      });

      test('a deleted payment method: Add → the default, Edit → the '
          'expense\'s', () async {
        final add = await openForm(
          draft: _addDraft(title: 'x', paymentMethodId: 999),
        );
        expect(fieldsOf(add).paymentMethodId, 1);
        final e = await seed(paymentMethodId: 2);
        final edit = await openForm(
          expenseId: e.id,
          draft: _editDraft(e.id, paymentMethodId: 999),
        );
        expect(fieldsOf(edit).paymentMethodId, 2);
      });

      test('deleted events are dropped (else the save fails on the FK); '
          'archived ones are kept and listed', () async {
        await deps.events.setArchived(2, true);
        final cubit =
            await openForm(
                draft: _addDraft(title: 'x', eventIds: {1, 2, 999}),
              )
              ..amountChanged('5')
              ..categorySelected(1);
        expect(fieldsOf(cubit).eventIds, {1, 2});
        expect(ready(cubit).events.map((e) => e.id), contains(2));
        expect((await cubit.save())!.eventIds, {1, 2});
      });

      test('an unknown currency and over-long texts are kept', () async {
        final long = 'x' * 150;
        final cubit = await openForm(
          draft: _addDraft(title: long, currency: 'XYZ'),
        );
        expect(fieldsOf(cubit).title, long);
        expect(fieldsOf(cubit).currencyCode, 'XYZ');
        await cubit.save();
        expect(cubit.titleError, TitleError.tooLong);
      });

      test('an unreadable currency falls back to the default', () async {
        final cubit = await openForm(
          draft: _addDraft(title: 'x', currency: ''),
        );
        expect(fieldsOf(cubit).currencyCode, 'INR');
      });

      test('missing touched: fields differing from a new form count', () async {
        final cubit = await openForm(
          draft: _addDraft(title: 'x', categoryId: 3, touched: null),
        );
        expect(ready(cubit).touched, {DraftField.title, DraftField.category});
      });
    });
  });

  group('chip', () {
    test('a chip fills the amount and marks it touched', () async {
      final cubit = await openForm(chip: const Money(5000, 'INR'));
      expect(fieldsOf(cubit).expression, '50.00');
      expect(ready(cubit).touched, contains(DraftField.amount));
    });

    // Owner, 2026-10-04: the chip is an explicit choice and always wins.
    test('with an Add draft whose amount is set, the chip replaces it; the '
        'rest of the draft stays', () async {
      final cubit = await openForm(
        chip: const Money(5000, 'INR'),
        draft: _addDraft(
          title: 'x',
          amount: '70',
          categoryId: 3,
          touched: {DraftField.title, DraftField.amount, DraftField.category},
        ),
      );
      expect(fieldsOf(cubit).expression, '50.00');
      expect(fieldsOf(cubit).title, 'x');
      expect(fieldsOf(cubit).categoryId, 3);
      expect(cubit.ownsDraft, isTrue, reason: 'still the same draft');
    });

    test(
      'with an Add draft whose amount is untouched, the chip fills it',
      () async {
        final cubit = await openForm(
          chip: const Money(5000, 'INR'),
          draft: _addDraft(title: 'x'),
        );
        expect(fieldsOf(cubit).expression, '50.00');
        expect(fieldsOf(cubit).title, 'x');
      },
    );

    test('a draft in another currency gets the chip\'s amount and '
        'currency, never ₹50 as \$50', () async {
      final cubit = await openForm(
        chip: const Money(5000, 'INR'),
        draft: _addDraft(
          title: 'x',
          amount: '12',
          currency: 'USD',
          touched: {DraftField.amount, DraftField.currency},
        ),
      );
      expect(fieldsOf(cubit).expression, '50.00');
      expect(fieldsOf(cubit).currencyCode, 'INR');
      cubit.categorySelected(1);
      expect((await cubit.save())!.amount, const Money(5000, 'INR'));
    });
  });

  group('Itemize follows the description live', () {
    test('a label edited in the brackets shows in the sheet at once', () async {
      final cubit = await openForm()
        ..amountChanged('50+60');
      cubit
        ..itemize(['potato', 'onion'])
        ..descriptionChanged('50 (potatoes) + 60 (onion)\nnotes');
      expect(cubit.itemizeLabels, ['potatoes', 'onion']);
      cubit.itemize(['potatoes', 'red onion']);
      expect(
        fieldsOf(cubit).description,
        '50 (potatoes) + 60 (red onion)\nnotes',
        reason: 'the edited line is still the Itemize line: replaced',
      );
    });

    test('an amount changed to match the edited line picks it up', () async {
      final cubit = await openForm()
        ..amountChanged('50+60');
      cubit
        ..itemize(['a', 'b'])
        ..descriptionChanged('50 (a) + 70 (c)')
        ..amountChanged('50+70');
      expect(cubit.itemizeLabels, ['a', 'c']);
    });

    test('a line that no longer reads as one keeps the last labels', () async {
      final cubit = await openForm()
        ..amountChanged('50+60');
      cubit
        ..itemize(['a', 'b'])
        ..descriptionChanged('potatoes and onions');
      expect(cubit.itemizeLabels, ['a', 'b']);
    });

    test('a prefilled Itemize line, then back → no draft for it', () async {
      await seed(
        expression: '50+60',
        amount: const Money(11000, 'INR'),
        description: '50 (potato) + 60 (onion)',
      );
      final cubit = await openForm();
      await cubit.pickSuggestion(suggestionFor(cubit, 'Lu'));
      expect(cubit.itemizeLabels, ['potato', 'onion']);
      expect(await slot(), isNull);
    });
  });

  group('the amount is read with the locale\'s separator', () {
    // The rule itself (grouping vs decimal, both separators):
    // amount_expression_test. Here: the form reads with the locale's.
    test('en reads `.` as the decimal, es reads `,`', () async {
      for (final (separator, decimal, grouping) in [
        ('.', '1.000×2', '1,000×2'),
        (',', '1,000×2', '1.000×2'),
      ]) {
        final cubit = await openForm(separator: separator)
          ..amountChanged(grouping);
        expect(
          cubit.amountResult,
          const ExpressionRejected(ExpressionError.tooManyDecimals),
          reason: separator,
        );
        cubit.amountChanged(decimal);
        expect(
          (cubit.amountResult! as ExpressionValue).amountMinor,
          200,
          reason: separator,
        );
      }
    });
  });

  group('Clear and Discard draft', () {
    test('Undo lists again an archived event only the undone fields had '
        '(else it is saved without being shown)', () async {
      await deps.events.setArchived(2, true);
      final cubit = await openForm(
        draft: _addDraft(title: 'x', eventIds: {1, 2}),
      );
      await cubit.clear();
      expect(ready(cubit).events.map((e) => e.id), isNot(contains(2)));
      cubit.undoReset();
      expect(fieldsOf(cubit).eventIds, {1, 2});
      expect(ready(cubit).events.map((e) => e.id), contains(2));
    });

    test('Clear → a new form, the slot cleared; Undo → fields and slot '
        'back', () async {
      final cubit = await openForm(draft: _addDraft(title: 'Tea'))
        ..amountChanged('5');
      expect(cubit.canClear, isTrue);
      await cubit.clear();
      expect(fieldsOf(cubit).title, '');
      expect(fieldsOf(cubit).expression, '');
      expect(cubit.isDirty, isFalse);
      expect(cubit.canClear, isFalse);
      expect(await slot(), isNull);
      await drafts.flush();
      expect(await draftRows(), 0);

      cubit.undoReset();
      expect(fieldsOf(cubit).title, 'Tea');
      expect(fieldsOf(cubit).expression, '5');
      expect((await slot())?.title, 'Tea');
    });

    test('Clear resets the date to now', () async {
      final cubit = await openForm()
        ..dateChanged(DateTime(2020));
      clock.advance(const Duration(hours: 3));
      await cubit.clear();
      expect(fieldsOf(cubit).wallClock.hour, clock.now.toLocal().hour);
      expect(cubit.isDirty, isFalse);
    });

    test('Discard draft → stored values, Update disabled, Undo', () async {
      final e = await seed();
      final cubit = await openForm(
        expenseId: e.id,
        draft: _editDraft(e.id, title: 'Changed'),
      );
      expect(cubit.canSave, isTrue);
      await cubit.discardDraft();
      expect(fieldsOf(cubit).title, 'Lunch');
      expect(cubit.canSave, isFalse);
      expect(await slot(), isNull);

      cubit.undoReset();
      expect(fieldsOf(cubit).title, 'Changed');
      expect((await slot())?.editingExpenseId, e.id);
    });

    test(
      'each programmatic text change bumps textRevision; typing doesn\'t',
      () async {
        final cubit = await openForm();
        final start = ready(cubit).textRevision;
        cubit.titleChanged('Tea');
        expect(ready(cubit).textRevision, start);
        await cubit.clear();
        expect(ready(cubit).textRevision, start + 1);
      },
    );
  });
}

/// An expense repository whose title history can't be read.
class _NoHistory extends ExpenseRepository {
  _NoHistory(AppDependencies deps)
    : super(deps.database, dataVersion: deps.dataVersion);

  @override
  Future<List<TitleHistoryRow>> titleHistory() async =>
      throw StateError('no history');
}

ExpenseDraft _addDraft({
  required String title,
  String amount = '',
  int? categoryId,
  Set<int> eventIds = const {},
  int? paymentMethodId = 1,
  String currency = 'INR',
  DateTime? picked,
  Set<DraftField>? touched = const {DraftField.title},
}) => ExpenseDraft(
  editingExpenseId: null,
  title: title,
  amountExpression: amount,
  description: '',
  categoryId: categoryId,
  eventIds: eventIds,
  paymentMethodId: paymentMethodId,
  currencyCode: currency,
  pickedWallClock: picked,
  touched: touched,
  itemizeLine: null,
  itemizeLabels: const [],
  itemizeTerms: const [],
  updatedAt: DateTime.utc(2026, 10, 1),
);

ExpenseDraft _editDraft(
  int id, {
  String title = 'Lunch',
  int categoryId = 3,
  int paymentMethodId = 2,
}) => ExpenseDraft(
  editingExpenseId: id,
  title: title,
  amountExpression: '110.50',
  description: 'With rice',
  categoryId: categoryId,
  eventIds: const {1},
  paymentMethodId: paymentMethodId,
  currencyCode: 'INR',
  pickedWallClock: null,
  touched: DraftField.values.toSet(),
  itemizeLine: null,
  itemizeLabels: const [],
  itemizeTerms: const [],
  updatedAt: DateTime.utc(2026, 10, 1),
);

/// Lets queued futures run until [condition] holds (at most 1000 turns).
Future<void> pumpEventQueueUntil(bool Function() condition) async {
  for (var i = 0; i < 1000 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
