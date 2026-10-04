import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/item_shape.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/emoji_picker_field.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/home_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// The main Phase 2 flows, driven through the real app (phase-2.md §13).
void main() {
  late AppDependencies deps;

  setUp(() async {
    deps = await openTestDependencies();
    await deps.settings.setOnboardingCompleted();
  });

  /// A phone-sized screen, so the whole form fits without scrolling much.
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
  }

  Future<void> openAddForm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add expense'));
    await tester.pumpAndSettle();
  }

  Future<Expense> seedExpense({
    String title = 'Lunch',
    Money amount = const Money(11050, 'INR'),
    int categoryId = 1,
  }) => deps.expenses.add(
    ExpenseInput(
      title: title,
      description: null,
      amount: amount,
      occurredAt: DateTime.now().toUtc(),
      utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      categoryId: categoryId,
      paymentMethodId: 1,
      eventIds: const {},
    ),
  );

  group('add / edit', () {
    testWidgets('a new expense appears at the top of Home, formatted', (
      tester,
    ) async {
      usePhoneSize(tester);
      await seedExpense(title: 'Older');
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);

      await tester.enterText(field('Title'), '  Chai ');
      await tester.enterText(field('Amount'), '20,5');
      await tester.tap(find.text('Bills'));
      await tester.pump();
      await tapSave(tester);

      expect(find.text('Add expense'), findsOneWidget, reason: 'back on Home');
      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(titles, ['Chai', 'Older']);
      expect(find.text('₹20.50'), findsOneWidget);
      expect(find.text('🧾'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      final saved = (await deps.expenses.page()).first;
      expect(saved.title, 'Chai');
      expect(saved.amount, const Money(2050, 'INR'));
      expect(saved.description, isNull);
    });

    testWidgets('saving shows the errors and keeps the form open', (
      tester,
    ) async {
      usePhoneSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      await tapSave(tester);

      expect(find.text('Enter a title'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(find.text('Pick a category'), findsOneWidget);
      expect(await deps.expenses.page(), isEmpty);
    });

    testWidgets('editing an expense updates its row', (tester) async {
      usePhoneSize(tester);
      await seedExpense();
      await pumpApp(tester, dependencies: deps);
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      expect(find.text('Edit expense'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Amount')).controller!.text,
        '110.50',
      );
      await tester.enterText(field('Title'), 'Dinner');
      await tester.enterText(field('Amount'), '250');
      // On an existing expense the save button says Update (P4-18).
      expect(find.widgetWithText(TextButton, 'Save'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Update'));
      await tester.pumpAndSettle();

      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Lunch'), findsNothing);
      expect(find.text('₹250.00'), findsOneWidget);
    });

    // Phase 4 (D9, P4-13): no "Discard changes?" prompt any more; back
    // keeps the changes as a draft. The draft flows are in
    // expense_draft_flows_test.dart.
    testWidgets('back on a changed form keeps a draft, without a prompt', (
      tester,
    ) async {
      usePhoneSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      await tester.enterText(field('Title'), 'Chai');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(field('Title'), findsNothing);
      expect(find.text('Draft saved'), findsOneWidget);
      expect(find.text('No expenses yet'), findsOneWidget);
      expect((await deps.drafts.read())?.title, 'Chai');
    });

    testWidgets('back on an untouched form just closes it', (tester) async {
      usePhoneSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Draft saved'), findsNothing);
      expect(find.text('No expenses yet'), findsOneWidget);
    });
  });

  Future<void> openExpense(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> deleteFromForm(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await tester.pumpAndSettle();
  }

  group('bin', () {
    testWidgets('delete → snackbar → Undo brings it back', (tester) async {
      usePhoneSize(tester);
      await seedExpense();
      await pumpApp(tester, dependencies: deps);
      await openExpense(tester, 'Lunch');
      await deleteFromForm(tester);

      expect(find.text('Lunch'), findsNothing);
      expect(find.text('Moved to bin'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsOneWidget);
      expect(await deps.expenses.binned(), isEmpty);
    });

    testWidgets('delete → bin → restore → back on Home', (tester) async {
      usePhoneSize(tester);
      await seedExpense();
      await pumpApp(tester, dependencies: deps);
      await openExpense(tester, 'Lunch');
      await deleteFromForm(tester);

      await openTab(tester, 'Settings');
      await tester.tap(find.text('Bin'));
      await tester.pumpAndSettle();
      expect(find.text('Deleted today · removed in 30 days'), findsOneWidget);
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(
        find.text('Deleted expenses stay here for 30 days.'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, 'Home');
      expect(find.text('Lunch'), findsOneWidget);
    });

    testWidgets('empty bin asks for confirmation first', (tester) async {
      usePhoneSize(tester);
      final expense = await seedExpense();
      await deps.expenses.moveToBin(expense.id);
      await pumpApp(tester, dependencies: deps);
      await openTab(tester, 'Settings');
      await tester.tap(find.text('Bin'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Empty bin'));
      await tester.pumpAndSettle();
      expect(find.text('Empty the bin?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await deps.expenses.binned(), hasLength(1));

      await tester.tap(find.byTooltip('Empty bin'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Empty bin'));
      await tester.pumpAndSettle();
      expect(await deps.expenses.binned(), isEmpty);
      expect(
        find.text('Deleted expenses stay here for 30 days.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('deleting a used category moves its expenses to the picked one', (
    tester,
  ) async {
    usePhoneSize(tester);
    await seedExpense(); // Food 🍽️
    final binned = await seedExpense(title: 'Binned');
    await deps.expenses.moveToBin(binned.id);
    await pumpApp(tester, dependencies: deps);
    expect(find.text('🍽️'), findsOneWidget);

    await openTab(tester, 'Manage');
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('"Food" is used by 2 expenses (1 in the bin).'),
      findsOneWidget,
    );
    final moveButton = find.widgetWithText(TextButton, 'Move and delete');
    expect(tester.widget<TextButton>(moveButton).onPressed, isNull);
    await tester.tap(find.text('Groceries'));
    await tester.pump();
    await tester.tap(moveButton);
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsNothing, reason: 'deleted');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTab(tester, 'Home');
    expect(find.text('🛒'), findsOneWidget);
    expect(find.text('🍽️'), findsNothing);
    expect((await deps.expenses.binned()).single.categoryId, 3);
  });

  testWidgets('deleting a used payment method moves its expenses too', (
    tester,
  ) async {
    usePhoneSize(tester);
    final upi = await deps.expenses.add(
      ExpenseInput(
        title: 'Metro',
        description: null,
        amount: const Money(4000, 'INR'),
        occurredAt: DateTime.now().toUtc(),
        utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
        categoryId: 1,
        paymentMethodId: 2, // UPI; Cash (1) is the default.
        eventIds: const {},
      ),
    );
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    await tester.tap(find.text('Payment methods'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('"UPI" is used by 1 expense.'), findsOneWidget);
    await tester.tap(find.text('Cash'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Move and delete'));
    await tester.pumpAndSettle();

    expect(find.text('UPI'), findsNothing, reason: 'deleted');
    expect((await deps.expenses.byId(upi.id))!.paymentMethodId, 1);
  });

  testWidgets('the only category in use asks to add another one first', (
    tester,
  ) async {
    usePhoneSize(tester);
    await seedExpense(); // Food
    for (final category in await deps.categories.all()) {
      if (category.id != 1) await deps.categories.delete(category.id);
    }
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '"Food" is used by 1 expense.\n\n'
        'Add another one first, so its expenses have somewhere to go.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await deps.categories.all(), hasLength(1), reason: 'not deleted');
  });

  testWidgets(
    'currency chip: new expenses default to the picked currency, old ones keep theirs',
    (tester) async {
      usePhoneSize(tester);
      await seedExpense();
      await pumpApp(tester, dependencies: deps);
      expect(find.text('₹ INR'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('currencyChip')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'usd');
      await tester.pumpAndSettle();
      await tester.tap(find.text('US Dollar'));
      await tester.pumpAndSettle();
      expect(find.text(r'$ USD'), findsOneWidget);

      await openAddForm(tester);
      await tester.enterText(field('Title'), 'Taxi');
      await tester.enterText(field('Amount'), '12');
      await tester.tap(find.text('Food'));
      await tapSave(tester);

      expect(find.text(r'$12.00'), findsOneWidget);
      expect(find.text('₹110.50'), findsOneWidget, reason: 'unchanged');

      // Both are now recent: each shows once in Recent, with the selected
      // one first.
      await tester.tap(find.byKey(const ValueKey('currencyChip')));
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('All currencies'), findsOneWidget);
      final recent = [
        for (final widget in tester.widgetList<KeyedSubtree>(
          find.byWidgetPredicate(
            (w) =>
                w is KeyedSubtree &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('recent:'),
          ),
        ))
          (widget.key! as ValueKey<String>).value,
      ];
      expect(recent, ['recent:USD', 'recent:INR']);
    },
  );

  group('pickers', () {
    Finder categorySearch() => find.byTooltip('Search').first;
    Finder eventSearch() => find.byTooltip('Search').last;

    testWidgets(
      'search replaces the first row, filters, and back closes it first',
      (tester) async {
        usePhoneSize(tester);
        await pumpApp(tester, dependencies: deps);
        await openAddForm(tester);
        await tester.enterText(field('Title'), 'Chai');
        expect(find.text('Bills'), findsOneWidget);

        await tester.tap(categorySearch());
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextField, 'Search categories…'),
          findsOneWidget,
        );
        expect(find.byTooltip('More results'), findsOneWidget);
        expect(find.byTooltip('New category'), findsNothing);

        await tester.enterText(
          find.widgetWithText(TextField, 'Search categories…'),
          'in',
        );
        await tester.pumpAndSettle();
        // "Investment" starts with it, so it comes first; the others only
        // contain it, in popularity (here: name) order.
        final shown = [
          for (final name in [
            'Investment',
            'Drinks',
            'Entertainment',
            'Shopping',
          ])
            tester.getTopLeft(find.text(name)).dx,
        ];
        expect(shown, [...shown]..sort());
        expect(find.text('Bills'), findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextField, 'Search categories…'),
          findsNothing,
        );
        expect(find.text('Bills'), findsOneWidget);
        expect(find.byTooltip('New category'), findsOneWidget);
        expect(find.text('Draft saved'), findsNothing, reason: 'still here');

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Draft saved'), findsOneWidget);
      },
    );

    testWidgets('a category search result is selected and closes search', (
      tester,
    ) async {
      usePhoneSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      await tester.tap(categorySearch());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search categories…'),
        'trav',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'Search categories…'),
        findsNothing,
      );
      // Not in the top 8 by name, so it took the 8th slot.
      expect(find.text('Travel'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Travel')),
        isSemantics(isSelected: true, label: '✈️\nTravel'),
      );
    });

    testWidgets('event search results toggle and keep searching', (
      tester,
    ) async {
      usePhoneSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      await tester.tap(eventSearch());
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextField, 'Search events…');
      await tester.enterText(search, 'r');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Party'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Birthday'));
      await tester.pumpAndSettle();

      expect(search, findsOneWidget, reason: 'still searching');
      await tester.enterText(field('Title'), 'Cake');
      await tester.enterText(field('Amount'), '500');
      await tester.tap(find.text('Food'));
      await tapSave(tester);

      final saved = (await deps.expenses.page()).single;
      final events = await deps.events.all();
      expect(saved.eventIds, {
        for (final e in events)
          if (e.builtinKey == 'party' || e.builtinKey == 'birthday') e.id,
      });
    });

    testWidgets(
      '⋯ → New event starts with the query as its name and selects it',
      (tester) async {
        usePhoneSize(tester);
        await pumpApp(tester, dependencies: deps);
        await openAddForm(tester);
        await tester.tap(eventSearch());
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Search events…'),
          ' chai ',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More results'));
        await tester.pumpAndSettle();

        expect(find.text('No more matches'), findsOneWidget);
        await tester.tap(find.text('New event'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('name')))
              .controller!
              .text,
          'chai',
        );
        await tester.tap(find.byType(EmojiPickerField));
        await tester.pumpAndSettle();
        await tester.tap(find.text('☕').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        // Back on the expense form, search closed, the new event selected.
        expect(find.text('Add expense'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Search events…'), findsNothing);
        expect(find.text('chai'), findsOneWidget);

        await tester.enterText(field('Title'), 'Tea');
        await tester.enterText(field('Amount'), '20');
        await tester.tap(find.text('Food'));
        await tapSave(tester);
        final chai = (await deps.events.all()).singleWhere(
          (e) => e.name == 'chai',
        );
        expect((await deps.expenses.page()).single.eventIds, {chai.id});
      },
    );
  });

  testWidgets('deleting a used event says how many expenses lose it', (
    tester,
  ) async {
    usePhoneSize(tester);
    final trip = (await deps.events.all()).singleWhere(
      (e) => e.builtinKey == 'trip',
    );
    final expense = await deps.expenses.add(
      ExpenseInput(
        title: 'Hotel',
        description: null,
        amount: const Money(500000, 'INR'),
        occurredAt: DateTime.now().toUtc(),
        utcOffsetMinutes: 0,
        categoryId: 1,
        paymentMethodId: 1,
        eventIds: {trip.id},
      ),
    );
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('It will be removed from 1 expense. The expenses stay.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect((await deps.expenses.byId(expense.id))!.eventIds, isEmpty);
  });

  testWidgets('the search bar takes focus even while the amount field has it', (
    tester,
  ) async {
    usePhoneSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openAddForm(tester);
    await tester.tap(field('Amount'));
    await tester.pump();
    await tester.tap(find.byTooltip('Search').first);
    await tester.pumpAndSettle();

    final search = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextField, 'Search categories…'),
        matching: find.byType(EditableText),
      ),
    );
    expect(search.focusNode.hasFocus, isTrue);
  });

  testWidgets('"Moved to bin" goes away and stays on Home', (tester) async {
    usePhoneSize(tester);
    await seedExpense();
    await pumpApp(tester, dependencies: deps);
    await openExpense(tester, 'Lunch');
    await deleteFromForm(tester);
    expect(find.text('Moved to bin'), findsOneWidget);

    await openTab(tester, 'Settings');
    expect(find.text('Moved to bin'), findsNothing, reason: 'not on Settings');
    await openTab(tester, 'Home');

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Moved to bin'), findsNothing, reason: 'dismissed');
  });

  group('day headers follow the date', () {
    Future<TestClock> pumpAt23h59m50s(WidgetTester tester) async {
      final clock = TestClock(DateTime(2026, 10, 2, 23, 59, 50).toUtc());
      deps = await openTestDependencies(clock: clock);
      await deps.settings.setOnboardingCompleted();
      final noon = DateTime(2026, 10, 2, 12);
      await deps.expenses.add(
        ExpenseInput(
          title: 'Lunch',
          description: null,
          amount: const Money(11050, 'INR'),
          occurredAt: noon.toUtc(),
          utcOffsetMinutes: noon.timeZoneOffset.inMinutes,
          categoryId: 1,
          paymentMethodId: 1,
          eventIds: const {},
        ),
      );
      await pumpApp(tester, dependencies: deps);
      expect(find.text('Today'), findsOneWidget);
      return clock;
    }

    testWidgets('"Today" becomes "Yesterday" at midnight', (tester) async {
      usePhoneSize(tester);
      final clock = await pumpAt23h59m50s(tester);

      clock.now = clock.now.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Today'), findsNothing);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('coming back to the app the next day updates them', (
      tester,
    ) async {
      usePhoneSize(tester);
      final clock = await pumpAt23h59m50s(tester);

      // In the background overnight: no timer runs while paused. Android
      // goes through every state in between, and so must the test.
      void moveTo(List<AppLifecycleState> states) {
        for (final state in states) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      moveTo(const [
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      clock.now = clock.now.add(const Duration(hours: 9));
      moveTo(const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
      expect(find.text('Yesterday'), findsOneWidget);
    });
  });

  testWidgets('an expense from another time zone keeps its own time and day', (
    tester,
  ) async {
    // Recorded at 23:30 on 1 Oct, on a phone ten hours away from this
    // machine's zone (the stand-in for "change the phone's time zone",
    // phase-2.md §13). Home must show that wall clock and day, not the
    // same moment in the current zone (database.md §1).
    usePhoneSize(tester);
    final here = DateTime(2026, 10, 1).timeZoneOffset.inMinutes;
    final there = here >= 0 ? here - 600 : here + 600;
    final wallClock = DateTime.utc(2026, 10, 1, 23, 30);
    await deps.expenses.add(
      ExpenseInput(
        title: 'Late dinner',
        description: null,
        amount: const Money(11050, 'INR'),
        occurredAt: wallClock.subtract(Duration(minutes: there)),
        utcOffsetMinutes: there,
        categoryId: 1,
        paymentMethodId: 1,
        eventIds: const {},
      ),
    );
    await pumpApp(tester, dependencies: deps);

    // intl puts a narrow no-break space before AM/PM.
    expect(find.textContaining('11:30 PM'), findsOneWidget);
    // Tests run as a US phone (see 'dates follow the phone country').
    expect(find.text('Thu, Oct 1'), findsOneWidget);

    await openExpense(tester, 'Late dinner');
    // The date and time buttons are at the end of the (lazy) form.
    await tester.scrollUntilVisible(
      find.byIcon(Icons.schedule),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('11:30 PM'), findsOneWidget, reason: 'form time');
    expect(find.text('Thu, Oct 1, 2026'), findsOneWidget, reason: 'form date');
  });

  group('dates follow the phone country, like money', () {
    /// An expense on Thu 1 Oct 2026, opened on a phone set to [device]
    /// with the app in English.
    Future<void> pumpWithPhoneIn(WidgetTester tester, Locale device) async {
      usePhoneSize(tester);
      tester.platformDispatcher.localeTestValue = device;
      tester.platformDispatcher.localesTestValue = [device];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final noon = DateTime(2026, 10, 1, 12);
      await deps.expenses.add(
        ExpenseInput(
          title: 'Lunch',
          description: null,
          amount: const Money(11050, 'INR'),
          occurredAt: noon.toUtc(),
          utcOffsetMinutes: noon.timeZoneOffset.inMinutes,
          categoryId: 1,
          paymentMethodId: 1,
          eventIds: const {},
        ),
      );
      await pumpApp(tester, dependencies: deps);
    }

    Future<void> scrollFormToDate(WidgetTester tester) async {
      await openExpense(tester, 'Lunch');
      await tester.scrollUntilVisible(
        find.byIcon(Icons.calendar_today_outlined),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }

    testWidgets('an Indian phone shows the day first', (tester) async {
      await pumpWithPhoneIn(tester, const Locale('en', 'IN'));
      expect(find.text('Thu, 1 Oct'), findsOneWidget, reason: 'day header');
      await scrollFormToDate(tester);
      expect(find.text('Thu, 1 Oct, 2026'), findsOneWidget, reason: 'form');
    });

    testWidgets('the date picker follows the phone too', (tester) async {
      await pumpWithPhoneIn(tester, const Locale('en', 'IN'));
      await scrollFormToDate(tester);
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Select date'), findsOneWidget);
      expect(find.text('Thu, 1 Oct'), findsOneWidget, reason: 'picker');
    });

    testWidgets('a US phone shows the month first', (tester) async {
      await pumpWithPhoneIn(tester, const Locale('en', 'US'));
      expect(find.text('Thu, Oct 1'), findsOneWidget, reason: 'day header');
      await scrollFormToDate(tester);
      expect(find.text('Thu, Oct 1, 2026'), findsOneWidget, reason: 'form');
    });
  });

  group("Home's messages show on Home only", () {
    /// Whether [text] is shown inside Home (its own ScaffoldMessenger), not
    /// on the shell's Scaffold, where it would sit under Home's FAB and
    /// stay over the other tabs (phase-2.md §12a).
    Finder onHome(String text) =>
        find.descendant(of: find.byType(HomeScreen), matching: find.text(text));

    testWidgets('"no longer exists" after opening a binned expense', (
      tester,
    ) async {
      usePhoneSize(tester);
      final expense = await seedExpense();
      await pumpApp(tester, dependencies: deps);
      // Binned behind Home's back: the row is still on screen.
      await deps.expenses.moveToBin(expense.id);
      await openExpense(tester, 'Lunch');

      expect(find.text('This expense no longer exists'), findsOneWidget);
      expect(onHome('This expense no longer exists'), findsOneWidget);
      await openTab(tester, 'Settings');
      expect(find.text('This expense no longer exists'), findsNothing);
    });

    testWidgets('a failed Undo', (tester) async {
      usePhoneSize(tester);
      await seedExpense();
      await pumpApp(tester, dependencies: deps);
      await openExpense(tester, 'Lunch');
      await deleteFromForm(tester);
      // From here on, taking an expense out of the bin fails.
      await deps.database.execute(
        'CREATE TRIGGER no_restore BEFORE UPDATE OF deleted_at ON expenses '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(onHome("Couldn't save. Please try again."), findsOneWidget);
      await openTab(tester, 'Settings');
      expect(find.text("Couldn't save. Please try again."), findsNothing);
    });
  });

  group('picker look and form focus (device feedback)', () {
    /// The text field that has the focus, if any.
    EditableText? focusedField() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>();

    /// Scrolls the form (not one of its text fields) until [finder] shows.
    Future<void> scrollFormTo(WidgetTester tester, Finder finder) =>
        tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );

    bool isSelected(WidgetTester tester, String name) =>
        isSemantics(isSelected: true)
            .matches(tester.getSemantics(find.text(name)), {});

    testWidgets('"None" is selected until an event is, and clears them', (
      tester,
    ) async {
      usePhoneSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Events (optional)'), findsNothing);
      expect(isSelected(tester, 'None'), isTrue);

      await tester.tap(find.text('Trip'));
      await tester.pump();
      expect(isSelected(tester, 'None'), isFalse);
      expect(isSelected(tester, 'Trip'), isTrue);

      await tester.tap(find.text('None'));
      await tester.pump();
      expect(isSelected(tester, 'None'), isTrue);
      expect(isSelected(tester, 'Trip'), isFalse);
    });

    testWidgets('the ✕ in the search bar closes it', (tester) async {
      usePhoneSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      await tester.tap(find.byTooltip('Search').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Search'), findsOneWidget, reason: 'events only');

      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Search categories…'),
        findsNothing,
      );
      expect(find.byTooltip('Search'), findsNWidgets(2));
      expect(find.text('Bills'), findsOneWidget);
    });

    testWidgets('search animates: halfway, the old tiles are shrinking', (
      tester,
    ) async {
      usePhoneSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      // A scaled tile is drawn smaller, so its name's on-screen box shrinks.
      final fullWidth = tester.getRect(find.text('Bills')).width;
      await tester.tap(find.byTooltip('Search').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(tester.getRect(find.text('Bills')).width, lessThan(fullWidth));
      await tester.pumpAndSettle();
      // Fuel was a tile of the second row; an empty query's first matches
      // are Bills, Clothes, Drinks and Education.
      expect(find.text('Fuel'), findsNothing);
      expect(find.text('Education'), findsOneWidget);
    });

    testWidgets('picking a date does not give the focus back to a field', (
      tester,
    ) async {
      // A short screen, as on the device: scrolled down to the date, the
      // title field is out of the lazy list and gets rebuilt later, which
      // used to re-run its autofocus.
      tester.view.physicalSize = const Size(1080, 1500);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      expect(focusedField(), isNotNull, reason: 'the title has it');

      await scrollFormTo(tester, find.byIcon(Icons.calendar_today_outlined));
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(focusedField(), isNull);

      // Back at the top the title field is built again (on the device the
      // keyboard closing did this); it must not take the focus back.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
      expect(focusedField(), isNull);
    });

    testWidgets('the time picker reopens in the mode it was left in', (
      tester,
    ) async {
      usePhoneSize(tester);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      await scrollFormTo(tester, find.byIcon(Icons.schedule));
      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();
      expect(find.text('Select time'), findsOneWidget, reason: 'the dial');

      await tester.tap(find.byTooltip('Switch to text input mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();
      expect(find.text('Enter time'), findsOneWidget, reason: 'the keyboard');
      expect((await deps.settings.load()).timePickerKeyboard, isTrue);
    });

    testWidgets('circle tiles from Settings are used by the pickers', (
      tester,
    ) async {
      usePhoneSize(tester);
      await deps.settings.setTileShape(ItemShape.circle);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      final disc = find.ancestor(
        of: find.text('🧾'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(disc, findsOneWidget);
    });
  });
}
