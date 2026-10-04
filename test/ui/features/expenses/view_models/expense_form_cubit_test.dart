import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/amount_expression.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/ui/core/picker_order.dart';
import 'package:my_expense_tracker_app/ui/features/expenses/view_models/expense_form_cubit.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDependencies deps;
  late TestClock clock;

  setUp(() async {
    clock = TestClock();
    deps = await openTestDependencies(clock: clock);
  });

  Future<ExpenseFormCubit> openForm({int? expenseId}) async {
    final cubit = ExpenseFormCubit(
      expenses: deps.expenses,
      categories: deps.categories,
      events: deps.events,
      paymentMethods: deps.paymentMethods,
      drafts: deps.drafts,
      l10n: l10nFor('en'),
      defaultCurrency: 'INR',
      defaultPaymentMethodId: 1,
      expenseId: expenseId,
      now: clock.call,
    );
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  ExpenseFields fieldsOf(ExpenseFormCubit cubit) =>
      (cubit.value as ExpenseFormReady).fields;

  /// A valid new expense: "Lunch", 110.50, Food.
  Future<ExpenseFormCubit> validForm() async => (await openForm())
    ..titleChanged('Lunch')
    ..amountChanged('110.50')
    ..categorySelected(1);

  Future<Expense> seed({
    DateTime? occurredAt,
    int utcOffsetMinutes = 330,
    int categoryId = 1,
    Set<int> eventIds = const {},
  }) => deps.expenses.add(
    ExpenseInput(
      title: 'Seeded',
      description: 'Note',
      amount: const Money(11050, 'INR'),
      occurredAt: occurredAt ?? clock.now.subtract(const Duration(days: 1)),
      utcOffsetMinutes: utcOffsetMinutes,
      categoryId: categoryId,
      paymentMethodId: 2,
      eventIds: eventIds,
    ),
  );

  group('a new form', () {
    test('starts with the defaults and now, and has no changes', () async {
      final cubit = await openForm();
      final fields = fieldsOf(cubit);
      expect(fields.title, '');
      expect(fields.currencyCode, 'INR');
      expect(fields.paymentMethodId, 1);
      expect(fields.categoryId, isNull);
      final local = clock.now.toLocal();
      expect(fields.wallClock.hour, local.hour);
      expect(fields.wallClock.day, local.day);
      expect(cubit.isDirty, isFalse);
    });

    test(
      'lists payment methods with the default first, then by name',
      () async {
        await deps.settings.setDefaultPaymentMethodId(3);
        final cubit = ExpenseFormCubit(
          expenses: deps.expenses,
          categories: deps.categories,
          events: deps.events,
          paymentMethods: deps.paymentMethods,
          drafts: deps.drafts,
          l10n: l10nFor('en'),
          defaultCurrency: 'INR',
          defaultPaymentMethodId: 3,
        );
        addTearDown(cubit.close);
        await cubit.load();
        final ready = cubit.value as ExpenseFormReady;
        expect(
          [for (final m in ready.paymentMethods) m.builtinKey],
          ['debit_card', 'cash', 'credit_card', 'upi'],
        );
        expect(ready.fields.paymentMethodId, 3);
      },
    );

    test('any change makes it dirty', () async {
      final cubit = await openForm();
      cubit.titleChanged('x');
      expect(cubit.isDirty, isTrue);
      cubit.titleChanged('');
      expect(cubit.isDirty, isFalse, reason: 'back to how it opened');
      cubit.eventToggled(1);
      expect(cubit.isDirty, isTrue);
    });
  });

  group('validation', () {
    test(
      'an empty form shows every required error and saves nothing',
      () async {
        final cubit = await openForm();
        expect(cubit.titleError, isNull, reason: 'not before the first save');

        expect(await cubit.save(), isNull);
        expect(cubit.titleError, TitleError.required);
        expect(cubit.amountError, ExpressionError.empty);
        expect(cubit.categoryMissing, isTrue);
        expect(await deps.expenses.page(), isEmpty);
      },
    );

    test('the category is required', () async {
      final cubit = await openForm()
        ..titleChanged('Lunch')
        ..amountChanged('10');
      expect(await cubit.save(), isNull);
      expect(cubit.categoryMissing, isTrue);
      expect(cubit.titleError, isNull);
      expect(cubit.amountError, isNull);
    });

    test('title up to 100 characters, description up to 1000', () async {
      final cubit = await validForm()
        ..titleChanged('a' * 101)
        ..descriptionChanged('b' * 1001);
      expect(await cubit.save(), isNull);
      expect(cubit.titleError, TitleError.tooLong);
      expect(cubit.descriptionTooLong, isTrue);

      cubit
        ..titleChanged('a' * 100)
        ..descriptionChanged('b' * 1000);
      expect(await cubit.save(), isNotNull);
    });

    test(
      'changing the currency re-validates the decimals, never rounds',
      () async {
        // No category: the save fails and errors show from now on.
        final cubit = await openForm()
          ..titleChanged('Lunch')
          ..amountChanged('10.50');
        await cubit.save();
        expect(cubit.amountError, isNull);
        cubit.currencyChanged('JPY');
        expect(cubit.amountError, ExpressionError.tooManyDecimals);
        expect(fieldsOf(cubit).expression, '10.50', reason: 'text untouched');

        cubit.currencyChanged('USD');
        expect(cubit.amountError, isNull);
      },
    );

    test('errors update as the user types once shown', () async {
      final cubit = await openForm();
      await cubit.save();
      cubit.titleChanged('Lunch');
      expect(cubit.titleError, isNull);
      expect(cubit.amountError, ExpressionError.empty);
    });
  });

  group('amount result line', () {
    int? valueOf(ExpressionResult? result) => switch (result) {
      ExpressionValue(:final amountMinor) => amountMinor,
      _ => null,
    };

    test('shows only for an operator, a , or more than one .', () async {
      final cubit = await openForm();
      cubit.amountChanged('110.50');
      expect(cubit.amountResult, isNull);
      cubit.amountChanged('10,5');
      expect(valueOf(cubit.amountResult), 1050);
      cubit.amountChanged('50+60×2');
      expect(valueOf(cubit.amountResult), 17000);
      cubit.amountChanged('1.000.000');
      expect(
        cubit.amountResult,
        const ExpressionRejected(ExpressionError.invalid),
        reason: 'shown before the first save too',
      );
    });

    test('follows the currency', () async {
      final cubit = await openForm()
        ..amountChanged('1,000');
      expect(
        cubit.amountResult,
        const ExpressionRejected(ExpressionError.tooManyDecimals),
      );
      cubit.currencyChanged('KWD');
      expect(valueOf(cubit.amountResult), 1000);
    });
  });

  group('save', () {
    test(
      'trims title and description and stores an empty description as NULL',
      () async {
        final cubit = await validForm()
          ..titleChanged('  Lunch  ')
          ..descriptionChanged('   ');
        final saved = await cubit.save();
        expect(saved!.title, 'Lunch');
        expect(saved.description, isNull);
        expect(saved.amount, const Money(11050, 'INR'));
        expect(saved.paymentMethodId, 1);
      },
    );

    test('a new expense is saved at the moment the form opened, with the device offset', () async {
      final saved = await (await validForm()).save();
      expect(saved!.occurredAt, clock.now);
      expect(
        saved.utcOffsetMinutes,
        clock.now.toLocal().timeZoneOffset.inMinutes,
      );
    });

    test('saves what the date and time buttons show', () async {
      final cubit = await validForm()
        ..dateChanged(DateTime(2026, 3, 29))
        ..timeChanged(2, 30);
      final shown = fieldsOf(cubit).wallClock;
      final saved = await cubit.save();
      // Whatever the device's zone does with 02:30 on that day (a DST gap
      // in Spain), the saved wall-clock time is what the button showed.
      expect(saved!.wallClock, shown);
      expect(saved.occurredOn.substring(0, 7), '2026-03');
    });

    test('a second save while the first runs is ignored', () async {
      final cubit = await validForm();
      final first = cubit.save();
      expect(await cubit.save(), isNull);
      expect(await first, isNotNull);
      expect(await deps.expenses.page(), hasLength(1));
    });
  });

  group('edit', () {
    test('opens with the saved values and no changes', () async {
      final expense = await seed(eventIds: {2});
      final cubit = await openForm(expenseId: expense.id);
      final fields = fieldsOf(cubit);
      expect(fields.title, 'Seeded');
      expect(fields.expression, '110.50');
      expect(fields.description, 'Note');
      expect(fields.eventIds, {2});
      expect(fields.paymentMethodId, 2);
      expect(fields.wallClock, expense.wallClock);
      expect(cubit.isDirty, isFalse);
    });

    test('an untouched date keeps the original moment and offset', () async {
      // Recorded in New York (UTC−5), edited on a device elsewhere.
      final expense = await seed(
        occurredAt: DateTime.utc(2026, 9, 1, 4),
        utcOffsetMinutes: -300,
      );
      final cubit = await openForm(expenseId: expense.id);
      expect(fieldsOf(cubit).wallClock, DateTime.utc(2026, 8, 31, 23));
      cubit.titleChanged('Renamed');

      final saved = await cubit.save();
      expect(saved!.occurredAt, expense.occurredAt);
      expect(saved.utcOffsetMinutes, -300);
      expect(saved.occurredOn, '2026-08-31');
    });

    test(
      'a changed time is read as device time with the device offset',
      () async {
        final expense = await seed(
          occurredAt: DateTime.utc(2026, 9, 1, 4),
          utcOffsetMinutes: -300,
        );
        final cubit = await openForm(expenseId: expense.id)
          ..timeChanged(9, 15);
        final saved = await cubit.save();
        final expectedLocal = DateTime(2026, 8, 31, 9, 15);
        expect(saved!.occurredAt, expectedLocal.toUtc());
        expect(saved.utcOffsetMinutes, expectedLocal.timeZoneOffset.inMinutes);
        expect(saved.wallClock, DateTime.utc(2026, 8, 31, 9, 15));
      },
    );

    test('an expense binned before opening shows as gone', () async {
      final expense = await seed();
      await deps.expenses.moveToBin(expense.id);
      final cubit = await openForm(expenseId: expense.id);
      expect(cubit.value, isA<ExpenseFormGone>());
    });

    test('an expense binned while editing: save reports it gone', () async {
      final expense = await seed();
      final cubit = await openForm(expenseId: expense.id)
        ..titleChanged('New');
      await deps.expenses.moveToBin(expense.id);

      expect(await cubit.save(), isNull);
      expect(cubit.value, isA<ExpenseFormGone>());
      expect((await deps.expenses.binned()).single.title, 'Seeded');
    });

    test('moveToBin bins the edited expense', () async {
      final expense = await seed();
      final cubit = await openForm(expenseId: expense.id);
      expect(await cubit.moveToBin(), expense.id);
      expect(await deps.expenses.byId(expense.id), isNull);
    });
  });

  group('pickers', () {
    List<String> names(List<PickerItem> items) => [
      for (final item in items) item.name,
    ];

    test('order by popularity; a new install by name', () async {
      final fresh = await openForm();
      expect(names(fresh.categoryTiles), [
        'Bills',
        'Clothes',
        'Drinks',
        'Education',
        'Entertainment',
        'Food',
        'Fuel',
        'Gifts',
      ]);

      // Two uses of Other (20), one of Rent (8) more recently.
      await seed(categoryId: 20);
      await seed(categoryId: 20);
      clock.advance(const Duration(hours: 1));
      await seed(categoryId: 8, occurredAt: clock.now);
      final used = await openForm();
      expect(names(used.categoryTiles).take(3), ['Other', 'Rent', 'Bills']);
    });

    test('a selected category outside the top 8 takes the 8th slot', () async {
      final cubit = await openForm()
        ..categorySelected(19); // Investment
      final tiles = names(cubit.categoryTiles);
      expect(tiles, hasLength(8));
      expect(tiles.last, 'Investment');
      expect(tiles.take(7), [
        'Bills',
        'Clothes',
        'Drinks',
        'Education',
        'Entertainment',
        'Food',
        'Fuel',
      ]);
    });

    test('selected events outside the top 8 take slots from the end', () async {
      for (final name in ['A1', 'A2', 'A3', 'A4', 'Z1', 'Z2']) {
        await deps.events.add(name: name, emoji: '🔹');
      }
      final cubit = await openForm();
      final z2 = (await deps.events.all()).singleWhere((e) => e.name == 'Z2');
      final z1 = (await deps.events.all()).singleWhere((e) => e.name == 'Z1');
      cubit
        ..eventToggled(z2.id)
        ..eventToggled(z1.id);
      final tiles = names(cubit.eventTiles);
      // 7 tiles: "None" takes the first slot of the grid. The most popular
      // of them (by name here: Z1) takes the last slot.
      expect(tiles, hasLength(7));
      expect(tiles.sublist(5), ['Z2', 'Z1']);
    });

    test(
      'archived events are hidden, except the ones on the edited expense',
      () async {
        final events = await deps.events.all();
        final trip = events.singleWhere((e) => e.builtinKey == 'trip');
        final party = events.singleWhere((e) => e.builtinKey == 'party');
        final expense = await seed(eventIds: {trip.id});
        await deps.events.setArchived(trip.id, true);
        await deps.events.setArchived(party.id, true);

        expect(names((await openForm()).eventItems), isNot(contains('Trip')));
        final edit = await openForm(expenseId: expense.id);
        expect(names(edit.eventItems), contains('Trip'));
        expect(names(edit.eventItems), isNot(contains('Party')));

        final saved = await (edit..titleChanged('Kept')).save();
        expect(saved!.eventIds, {trip.id}, reason: 'not dropped silently');
      },
    );

    test('a category made from the picker is added and selected', () async {
      final cubit = await openForm();
      final pets = await deps.categories.add(name: 'Pets', emoji: '🐶');
      cubit.categoryAdded(pets);
      expect(fieldsOf(cubit).categoryId, pets.id);
      expect(names(cubit.categoryTiles), contains('Pets'));
    });

    test('None clears the events', () async {
      final cubit = await openForm()
        ..eventToggled(1)
        ..eventToggled(2);
      cubit.eventsCleared();
      expect(fieldsOf(cubit).eventIds, isEmpty);
    });

    test('an event made from the picker is added and selected', () async {
      final cubit = await openForm();
      final chai = await deps.events.add(name: 'chai', emoji: '☕');
      cubit.eventAdded(chai);
      expect(fieldsOf(cubit).eventIds, {chai.id});
      expect(cubit.allEvents.map((e) => e.id), contains(chai.id));
    });
  });
}
