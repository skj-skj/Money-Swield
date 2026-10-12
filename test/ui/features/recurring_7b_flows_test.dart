import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/models/app_theme_mode.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/models/recurring_item.dart';
import 'package:my_expense_tracker_app/domain/recurrence.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/home_list_slivers.dart';
import 'package:my_expense_tracker_app/ui/features/recurring/views/recurring_detail_screen.dart';
import 'package:my_expense_tracker_app/ui/features/recurring/views/upcoming_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// More Recurring flows through the real app. Today is Fri 9 Oct 2026, noon.
void main() {
  late AppDependencies deps;
  late TestClock clock;

  setUp(() async {
    clock = TestClock(DateTime(2026, 10, 9, 12));
    deps = await openTestDependencies(clock: clock);
    await deps.settings.setOnboardingCompleted();
  });

  /// The Oppo A77s: 360 dp wide.
  void useOppoSize(WidgetTester tester, {double width = 360}) {
    tester.view.physicalSize = Size(width * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  void noException(WidgetTester tester) {
    final error = tester.takeException();
    if (error == null) return;
    fail(error is FlutterError ? error.toStringDeep() : '$error');
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pumpAndSettle();
  }

  ExpenseInput inputOn(String day, {String title = 'Netflix'}) {
    final local = DateTime(
      int.parse(day.substring(0, 4)),
      int.parse(day.substring(5, 7)),
      int.parse(day.substring(8, 10)),
      10,
    );
    return ExpenseInput(
      title: title,
      description: null,
      amount: const Money(64900, 'INR'),
      occurredAt: local.toUtc(),
      utcOffsetMinutes: local.timeZoneOffset.inMinutes,
      categoryId: 1,
      paymentMethodId: 1,
      eventIds: const {},
    );
  }

  /// Netflix monthly from [day], saved through the repository.
  Future<int> savedNetflix({String day = '2026-10-09'}) async =>
      (await deps.expenses.addRepeating(
        inputOn(day),
        RepeatChoice.defaults,
      )).expense.recurringExpenseId!;

  Future<void> openPage(WidgetTester tester, int id) => pumpScreen(
    tester,
    dependencies: deps,
    screen: RecurringDetailScreen(dependencies: deps, itemId: id),
  );

  group('A: ends after N payments', () {
    testWidgets('After [12] payments: picking After fills 12 and focuses the '
        'field; 3 typed → "Next … · last …"; saved with the end', (
      tester,
    ) async {
      useOppoSize(tester);
      await pumpApp(tester, dependencies: deps);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Add expense'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('Title'), 'Gym');
      await tester.enterText(field('Amount'), '1500');
      await tester.tap(find.text('Food'));
      await tester.pump();
      final repeats = find.byKey(const ValueKey('repeatsSwitch'));
      await scrollTo(tester, repeats);
      await tester.tap(repeats);
      await tester.pumpAndSettle();
      final after = find.byKey(const ValueKey('repeatEndsAfter'));
      await scrollTo(tester, after);
      await tester.tap(find.byType(Radio<RepeatEnd>).last);
      await tester.pumpAndSettle();
      final count = find.byKey(const ValueKey('repeatCount'));
      expect(tester.widget<TextField>(count).controller!.text, '12');
      expect(
        tester.widget<TextField>(count).focusNode!.hasFocus,
        isTrue,
        reason: 'the cursor is in the field',
      );
      final selection = tester.widget<TextField>(count).controller!.selection;
      expect((selection.start, selection.end), (0, 2), reason: 'all selected');
      expect(find.text('payments'), findsOneWidget);
      // Typing "1" (one payment, refused) never crashes the section: the
      // rule line used to come from scheduleFor, which throws then.
      await tester.enterText(count, '1');
      await tester.pumpAndSettle();
      noException(tester);
      expect(find.text('Every month on day 9'), findsOneWidget);
      expect(find.text('payment'), findsOneWidget, reason: 'singular');
      await tester.enterText(count, '3');
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('repeatNext')));
      expect(find.text('Next: Nov 9 · last Dec 9'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final item = (await deps.recurring.all()).single;
      expect(item.schedule!.endOn, '2026-12-09');
    });

    testWidgets('an empty After or Every field shows its hint, not a cut '
        'label ("Numb…" on the Oppo); TalkBack still reads the label', (
      tester,
    ) async {
      useOppoSize(tester);
      await pumpApp(tester, dependencies: deps);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Add expense'),
      );
      await tester.pumpAndSettle();
      final repeats = find.byKey(const ValueKey('repeatsSwitch'));
      await scrollTo(tester, repeats);
      await tester.tap(repeats);
      await tester.pumpAndSettle();
      final count = find.byKey(const ValueKey('repeatCount'));
      await scrollTo(tester, count);
      expect(
        find.descendant(of: count, matching: find.text('Number of payments')),
        findsNothing,
      );
      expect(
        find.descendant(of: count, matching: find.text('12')),
        findsOneWidget,
        reason: 'the hint',
      );
      // One node, the text field itself, read with its label.
      final nodes = find.semantics
          .byLabel(RegExp('Number of payments'))
          .evaluate()
          .toList();
      expect(nodes, hasLength(1));
      expect(nodes.single.flagsCollection.isTextField, isTrue);
      final every = find.byKey(const ValueKey('repeatInterval'));
      await tester.enterText(every, '');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: every, matching: find.text('Every')),
        findsNothing,
      );
    });

    testWidgets('typing the count: "Next … · last …" stays above the '
        'keyboard (it was covered on the Oppo)', (tester) async {
      useOppoSize(tester);
      await pumpApp(tester, dependencies: deps);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Add expense'),
      );
      await tester.pumpAndSettle();
      final repeats = find.byKey(const ValueKey('repeatsSwitch'));
      await scrollTo(tester, repeats);
      await tester.tap(repeats);
      await tester.pumpAndSettle();
      // The section's end at the screen's bottom, as on the Oppo.
      await scrollTo(tester, find.byKey(const ValueKey('repeatEndsAfter')));
      await tester.tap(find.byType(Radio<RepeatEnd>).last);
      // The keyboard comes up: 300 of the 800 dp, as on the Oppo.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300.0 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final next = tester.getRect(find.byKey(const ValueKey('repeatNext')));
      expect(next.bottom, lessThanOrEqualTo(800 - 300));
      final field = tester.getRect(find.byKey(const ValueKey('repeatCount')));
      expect(field.top, greaterThanOrEqualTo(0));
    });

    testWidgets('After 1000 → refused: the field says "2 to 999" after Save', (
      tester,
    ) async {
      useOppoSize(tester);
      await pumpApp(tester, dependencies: deps);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Add expense'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(field('Title'), 'Gym');
      await tester.enterText(field('Amount'), '1500');
      await tester.tap(find.text('Food'));
      await tester.pump();
      final repeats = find.byKey(const ValueKey('repeatsSwitch'));
      await scrollTo(tester, repeats);
      await tester.tap(repeats);
      await tester.pumpAndSettle();
      final count = find.byKey(const ValueKey('repeatCount'));
      await scrollTo(tester, count);
      // The field takes 3 digits: "1000" becomes "100" (valid); "1" isn't.
      await tester.enterText(count, '1');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('2 to 999'), findsOneWidget);
      expect(await deps.database.query('expenses'), isEmpty);
    });
  });

  group('B: an existing expense made to repeat', () {
    testWidgets('Edit Rent of 1 Sep → Repeats → "Also adds 1 earlier '
        'payment: Oct 1" → Update → Home says so; 2 rows with the mark', (
      tester,
    ) async {
      useOppoSize(tester);
      await deps.expenses.add(inputOn('2026-09-01', title: 'Rent'));
      await pumpApp(tester, dependencies: deps);
      await tester.tap(
        find.descendant(
          of: find.byType(ExpenseRow),
          matching: find.text('Rent'),
        ),
      );
      await tester.pumpAndSettle();
      final update = find.widgetWithText(TextButton, 'Update');
      expect(tester.widget<TextButton>(update).onPressed, isNull);
      final repeats = find.byKey(const ValueKey('repeatsSwitch'));
      await scrollTo(tester, repeats);
      await tester.tap(repeats);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextButton>(update).onPressed,
        isNotNull,
        reason: 'Repeats alone enables Update',
      );
      await scrollTo(tester, find.byKey(const ValueKey('repeatNext')));
      expect(find.text('Also adds 1 earlier payment: Oct 1'), findsOneWidget);
      expect(find.text('Next: Nov 1'), findsOneWidget);
      await tester.tap(update);
      await tester.pumpAndSettle();
      expect(find.text('Updated with 1 earlier payment.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExpenseRow),
          matching: find.byKey(const ValueKey('repeatMark')),
        ),
        findsNWidgets(2),
      );
    });
  });

  group('C: changing how often', () {
    testWidgets('Edit → Every week → First payment appears (next date) and '
        'the notice → Save asks → Create new → the new item\'s page, '
        '"Netflix archived"; the old one is "replaced" in the Archive', (
      tester,
    ) async {
      useOppoSize(tester);
      final old = await savedNetflix();
      await openPage(tester, old);
      await tester.tap(find.byKey(const ValueKey('editRecurring')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('firstPayment')), findsNothing);
      final every = find.byKey(const ValueKey('repeatFrequency'));
      await scrollTo(tester, every);
      await tester.tap(every);
      await tester.pumpAndSettle();
      await tester.tap(find.text('week').last);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('newItemNotice')));
      // Which weekday it picks (found on the Oppo: nothing said it).
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('howOftenRule'))).data,
        'Every week on Monday',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('firstPayment')),
          matching: find.text('Nov 9, 2026'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Saving makes a new recurring item; this one is archived.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('saveRecurring')));
      await tester.pumpAndSettle();
      expect(find.text('Make a new recurring item?'), findsOneWidget);
      expect(
        find.textContaining('Netflix · Every week on Monday, from Nov 9, 2026'),
        findsOneWidget,
      );
      expect(find.textContaining('Its payment stays.'), findsOneWidget);
      // Cancel first: nothing written.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await deps.recurring.all(), hasLength(1));
      await tester.tap(find.byKey(const ValueKey('saveRecurring')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Create new'));
      await tester.pumpAndSettle();
      noException(tester);
      expect(find.text('Netflix archived'), findsOneWidget);
      // The page shows the new item now.
      expect(find.text('Every week on Monday'), findsOneWidget);
      final items = await deps.recurring.all();
      expect(items.single.replacesId, old);
      expect(
        (await deps.recurring.archived()).single.archiveReason,
        ArchiveReason.replaced,
      );
    });

    testWidgets('payments waiting: Every is off with a line saying why', (
      tester,
    ) async {
      useOppoSize(tester);
      final id = await savedNetflix(day: '2026-07-09');
      await deps.database.update('recurring_expenses', {
        'next_due_on': '2026-08-09',
      }, where: 'id = $id');
      await openPage(tester, id);
      await tester.tap(find.byKey(const ValueKey('editRecurring')));
      await tester.pumpAndSettle();
      final every = find.byKey(const ValueKey('repeatInterval'));
      await scrollTo(tester, every);
      expect(tester.widget<TextField>(every).enabled, isFalse);
      expect(
        find.text(
          'Payments are waiting. Add or skip them on the item\'s page '
          'before changing how often.',
        ),
        findsOneWidget,
      );
    });
  });

  group('E: Add selected', () {
    /// Gym weekly, saved on 27 Jul (the app not opened since): 3 Aug … 5
    /// Oct (10) held.
    Future<int> heldGym() async {
      clock.now = DateTime(2026, 7, 27, 12);
      final id = (await deps.expenses.addRepeating(
        inputOn('2026-07-27', title: 'Gym'),
        const RepeatChoice(frequency: Frequency.weekly),
      )).expense.recurringExpenseId!;
      clock.now = DateTime(2026, 10, 9, 12);
      return id;
    }

    testWidgets('the card\'s three buttons → the sheet, all ticked; None → '
        '"Skip all 10"; untick two → "Add 8" → "8 added, 2 skipped. Next: '
        'Oct 12"', (tester) async {
      useOppoSize(tester);
      final id = await heldGym();
      await openPage(tester, id);
      for (final key in ['addAll', 'addSelected', 'skipThem']) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      await tester.tap(find.byKey(const ValueKey('addSelected')));
      await tester.pumpAndSettle();
      noException(tester);
      expect(find.text('Which payments to add?'), findsOneWidget);
      expect(find.text('Mon, Aug 3'), findsOneWidget);
      expect(find.text('₹649.00'), findsWidgets);
      final confirm = find.byKey(const ValueKey('addSelectedConfirm'));
      expect(
        find.descendant(of: confirm, matching: find.text('Add 10')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('selectNoneHeld')));
      await tester.pump();
      expect(
        find.descendant(of: confirm, matching: find.text('Skip all 10')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('selectAllHeld')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('held 2026-08-10')));
      await tester.tap(find.byKey(const ValueKey('held 2026-08-17')));
      await tester.pump();
      expect(
        find.descendant(of: confirm, matching: find.text('Add 8')),
        findsOneWidget,
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('8 added, 2 skipped. Next: Oct 12'), findsOneWidget);
      expect(find.byKey(const ValueKey('holdCard')), findsNothing);
      final payments = await deps.database.query(
        'expenses',
        columns: ['recurring_due_on'],
        orderBy: 'recurring_due_on',
      );
      expect(payments, hasLength(9));
      expect([
        for (final p in payments) p['recurring_due_on'],
      ], isNot(contains('2026-08-10')));
    });

    testWidgets('Back on the sheet writes nothing', (tester) async {
      useOppoSize(tester);
      final id = await heldGym();
      await openPage(tester, id);
      await tester.tap(find.byKey(const ValueKey('addSelected')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('holdCard')), findsOneWidget);
      expect(await deps.database.query('expenses'), hasLength(1));
    });
  });

  group('F: Upcoming payments', () {
    Future<int> gym() async => (await deps.expenses.addRepeating(
      inputOn('2026-10-05', title: 'Gym'),
      const RepeatChoice(frequency: Frequency.weekly),
    )).expense.recurringExpenseId!;

    testWidgets('the icon left of the filter icon (photos too when there '
        'are any) → month frame, day headers, rows nearest first; skip '
        'once → greyed, Undo; bring back; stop → Undo; the end line', (
      tester,
    ) async {
      useOppoSize(tester);
      await gym();
      await savedNetflix();
      await pumpApp(tester, dependencies: deps);
      final upcoming = find.byKey(const ValueKey('upcomingButton'));
      expect(upcoming, findsOneWidget);
      expect(
        tester.getCenter(upcoming).dx,
        lessThan(
          tester.getCenter(find.byKey(const ValueKey('filterButton'))).dx,
        ),
      );
      await tester.tap(upcoming);
      await tester.pumpAndSettle();
      noException(tester);
      expect(find.text('Upcoming payments'), findsOneWidget);
      expect(find.text('Oct 2026'), findsOneWidget);
      expect(find.text('Mon, Oct 12'), findsOneWidget);
      // TalkBack: "Gym, ₹649.00, Monday, October 12".
      final row = find.byKey(const ValueKey('upcoming 1 2026-10-12'));
      expect(
        tester
            .getSemantics(
              find.descendant(of: row, matching: find.byType(ListTile)),
            )
            .label,
        'Gym, ₹649.00, Monday, October 12',
      );

      await tester.tap(find.byKey(const ValueKey('skip 1 2026-10-12')));
      await tester.pumpAndSettle();
      expect(find.text('Skip Gym on Mon, Oct 12?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('skipConfirm')));
      await tester.pumpAndSettle();
      expect(find.text('Skipped Gym on Mon, Oct 12'), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Skipped')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('bringBack 1 2026-10-12')), findsOne);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('skip 1 2026-10-12')), findsOneWidget);

      // Skip again, then Bring back (no dialog).
      await tester.tap(find.byKey(const ValueKey('skip 1 2026-10-12')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('skipConfirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bringBack 1 2026-10-12')));
      await tester.pumpAndSettle();
      expect(find.text('Gym on Mon, Oct 12 is back'), findsOneWidget);

      // Stop from the dialog: Gym's rows leave; Undo brings them back.
      await tester.tap(find.byKey(const ValueKey('skip 1 2026-10-12')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('skipStop')));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('skipConfirm')),
          matching: find.text('Stop'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('skipConfirm')));
      await tester.pumpAndSettle();
      expect(find.text('Gym stopped and archived.'), findsOneWidget);
      expect(row, findsNothing);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);

      // Scrolled to the end: the end line.
      await scrollTo(tester, find.byKey(const ValueKey('upcomingEnd')));
      expect(find.text('Shows the next 12 months.'), findsOneWidget);
      noException(tester);
    });

    testWidgets('found on the Oppo: no repeat mark (titles were cut at 360 '
        'dp); a skipped amount is struck through', (tester) async {
      useOppoSize(tester);
      final id = (await deps.expenses.addRepeating(
        inputOn('2026-10-05', title: 'Swimming class'),
        const RepeatChoice(frequency: Frequency.weekly),
      )).expense.recurringExpenseId!;
      await deps.recurring.skipOnce(id, '2026-10-12');
      await pumpScreen(
        tester,
        dependencies: deps,
        screen: UpcomingScreen(dependencies: deps),
      );
      final row = find.byKey(ValueKey('upcoming $id 2026-10-12'));
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.repeat)),
        findsNothing,
      );
      // Whether the title fits is checked on the phone: the test font
      // draws every glyph (the amount's too) a full em wide. At the
      // largest font it wraps instead of "Swim…".
      expect(
        tester
            .widget<Text>(
              find.descendant(of: row, matching: find.text('Swimming class')),
            )
            .maxLines,
        2,
      );
      final amount = tester.widget<Text>(
        find.descendant(of: row, matching: find.text('₹649.00')),
      );
      expect(amount.style!.decoration, TextDecoration.lineThrough);
      final next = find.byKey(ValueKey('upcoming $id 2026-10-19'));
      expect(
        tester
            .widget<Text>(
              find.descendant(of: next, matching: find.text('₹649.00')),
            )
            .style!
            .decoration,
        isNot(TextDecoration.lineThrough),
      );
    });

    testWidgets('follows Home\'s filter like the Photos screen (owner, '
        '2026-10-10): the icon has the dot, the screen "Filtered" and only '
        'matching items; a filter hiding all greys the icon', (tester) async {
      useOppoSize(tester);
      await gym();
      await savedNetflix();
      await pumpApp(tester, dependencies: deps);
      await tester.tap(find.byKey(const ValueKey('filterButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('filterSearch')), 'gym');
      await tester.tap(find.byKey(const ValueKey('showResults')));
      await tester.pumpAndSettle();
      final upcoming = find.byKey(const ValueKey('upcomingButton'));
      final dot = tester.widget<Badge>(
        find.descendant(of: upcoming, matching: find.byType(Badge)),
      );
      expect(dot.isLabelVisible, isTrue);
      await tester.tap(upcoming);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('upcomingFiltered')), findsOneWidget);
      expect(find.text('Gym'), findsWidgets);
      expect(find.text('Netflix'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // A filter hiding every item: greyed, with its tooltip.
      await tester.tap(find.byKey(const ValueKey('filterButton')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('filterSearch')),
        'electricity',
      );
      await tester.tap(find.byKey(const ValueKey('showResults')));
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(upcoming);
      expect(button.onPressed, isNull);
      expect(button.tooltip, 'No upcoming payments match the filters');
    });

    testWidgets('Undo of a Stop refused (restored meanwhile) says so, not '
        'nothing', (tester) async {
      useOppoSize(tester);
      final id = await gym();
      await pumpScreen(
        tester,
        dependencies: deps,
        screen: UpcomingScreen(dependencies: deps),
      );
      await tester.tap(find.byKey(ValueKey('skip $id 2026-10-12')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('skipStop')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('skipConfirm')));
      await tester.pumpAndSettle();
      await deps.recurring.restore(id);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Couldn't undo: it was restored, deleted or switched for another "
          'item since.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no running item: no icon', (tester) async {
      useOppoSize(tester);
      final id = await savedNetflix();
      await deps.recurring.archive(id);
      await pumpApp(tester, dependencies: deps);
      expect(find.byKey(const ValueKey('upcomingButton')), findsNothing);
    });
  });

  group('G: Only recurring', () {
    testWidgets('the switch → the chip first after the text chip; the dots; '
        'the list shows payments only; ✕ turns it off', (tester) async {
      useOppoSize(tester);
      await deps.expenses.add(inputOn('2026-10-08', title: 'Lunch'));
      await savedNetflix();
      await pumpApp(tester, dependencies: deps);
      expect(find.text('Lunch'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('filterButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filterOnlyRecurring')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('showResults')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('filterChipRecurring')), findsOne);
      expect(find.text('🔁 Recurring'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExpenseRow),
          matching: find.text('Lunch'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ExpenseRow),
          matching: find.text('Netflix'),
        ),
        findsOneWidget,
      );
      // The filter icon's dot.
      final dot = tester.widget<Badge>(
        find.descendant(
          of: find.byKey(const ValueKey('filterButton')),
          matching: find.byType(Badge),
        ),
      );
      expect(dot.isLabelVisible, isTrue);
      // Upcoming's icon has none, and its screen isn't "Filtered": every
      // item repeats, so Only recurring narrows nothing there.
      final upcoming = find.byKey(const ValueKey('upcomingButton'));
      expect(
        tester
            .widget<Badge>(
              find.descendant(of: upcoming, matching: find.byType(Badge)),
            )
            .isLabelVisible,
        isFalse,
      );
      await tester.tap(upcoming);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('upcomingFiltered')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('filterChipRecurring')),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('filterChipRecurring')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ExpenseRow),
          matching: find.text('Lunch'),
        ),
        findsOneWidget,
      );
    });
  });

  group('D: Restore of a replaced item swaps back', () {
    testWidgets('the swap dialog names both, counts the payments that stay; '
        'Switch back → "Switched back to Netflix · Every month on day 9"', (
      tester,
    ) async {
      useOppoSize(tester);
      final old = await savedNetflix();
      final newer = await deps.recurring.replaceSchedule(
        old,
        const RecurringEdit(
          title: 'Netflix',
          description: null,
          categoryId: 1,
          paymentMethodId: 1,
          eventIds: {},
          timeOfDayMinutes: 600,
          endOn: null,
        ),
        const Schedule(
          frequency: Frequency.weekly,
          interval: 1,
          startOn: '2026-10-12',
        ),
      );
      clock.now = DateTime(2026, 10, 20, 12);
      await deps.recurring.generateDue();
      await pumpApp(tester, dependencies: deps);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manageRecurring')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-archived')));
      await tester.pumpAndSettle();
      expect(find.text('Monthly · replaced Oct 9'), findsOneWidget);
      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('restoreRecurring')));
      await tester.pumpAndSettle();
      expect(
        find.text('Switch back to Netflix · Every month on day 9?'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Netflix · Every week on Monday is archived: it adds nothing '
          'more. Its 2 payments already added stay.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('It adds payments again from Nov 9.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Switch back'));
      await tester.pumpAndSettle();
      noException(tester);
      expect(
        find.text('Switched back to Netflix · Every month on day 9'),
        findsOneWidget,
      );
      expect([for (final i in await deps.recurring.all()) i.id], [old]);
      expect((await deps.recurring.byId(newer))!.isArchived, isTrue);
      // The weekly one's payments stay on Home.
      expect(await deps.database.query('expenses'), hasLength(3));
    });
  });

  // 360 dp × 1.0 in English isn't here: every flow above runs there, and an
  // overflow fails any widget test.
  group('layout: no overflow at 360 and 411 dp, font 1.0 and 2.0, en / es '
      '/ hi, dark', () {
    for (final (width, scale, language, dark) in [
      (360.0, 2.0, 'en', false),
      (360.0, 2.0, 'es', true),
      (360.0, 2.0, 'hi', false),
      (411.0, 2.0, 'en', true),
      (411.0, 1.0, 'hi', true),
    ]) {
      testWidgets('$width dp, ×$scale, $language${dark ? ', dark' : ''}', (
        tester,
      ) async {
        useOppoSize(tester, width: width);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await deps.settings.setLocale(Locale(language));
        if (dark) await deps.settings.setTheme(AppThemeMode.dark);
        // A held item with a long name (the three-button card), and a
        // running one with a photo (the bar's three icons).
        clock.now = DateTime(2026, 7, 27, 12);
        final held = (await deps.expenses.addRepeating(
          inputOn(
            '2026-07-27',
            title: 'A gym membership with a very long name indeed',
          ),
          const RepeatChoice(frequency: Frequency.weekly),
        )).expense.recurringExpenseId!;
        clock.now = DateTime(2026, 10, 9, 12);
        final netflix = await savedNetflix();
        await deps.database.insert('photos', {
          'relative_path': 'photos/${'b' * 64}.jpg',
          'sha256': 'b' * 64,
          'byte_size': 1,
          'created_at': 0,
          'updated_at': 0,
        });
        final payment = (await deps.recurring.payments(netflix)).single;
        await deps.database.insert('expense_photos', {
          'expense_id': payment.id,
          'photo_id': 1,
          'sort_order': 0,
        });

        // Home: chips, the three icons. The startup's "… payments waiting"
        // message times out first: it covers the bar at font 2.0.
        await pumpApp(tester, dependencies: deps);
        noException(tester);
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        for (final key in ['upcomingButton', 'photosButton', 'filterButton']) {
          expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
        }
        // The filter sheet with Only recurring on.
        await tester.tap(find.byKey(const ValueKey('filterButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('filterOnlyRecurring')));
        await tester.pumpAndSettle();
        noException(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        noException(tester);

        // Upcoming and the skip dialog.
        await tester.tap(find.byKey(const ValueKey('upcomingButton')));
        await tester.pumpAndSettle();
        noException(tester);
        await tester.tap(find.byIcon(Icons.event_busy_outlined).first);
        await tester.pumpAndSettle();
        noException(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // The held page: the card, then the sheet.
        await tester.pumpWidget(const SizedBox());
        await openPage(tester, held);
        noException(tester);
        await tester.tap(find.byKey(const ValueKey('addSelected')));
        await tester.pumpAndSettle();
        noException(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Netflix's Edit with how often changed: First payment shows.
        await tester.pumpWidget(const SizedBox());
        await openPage(tester, netflix);
        await tester.tap(find.byKey(const ValueKey('editRecurring')));
        await tester.pumpAndSettle();
        final every = find.byKey(const ValueKey('repeatInterval'));
        await scrollTo(tester, every);
        await tester.enterText(every, '2');
        await tester.pumpAndSettle();
        await scrollTo(tester, find.byKey(const ValueKey('newItemNotice')));
        noException(tester);

        // The Add form's Repeats with After N.
        await tester.pumpWidget(const SizedBox());
        await pumpApp(tester, dependencies: deps);
        await tester.tap(find.byType(FloatingActionButton).first);
        await tester.pumpAndSettle();
        final repeats = find.byKey(const ValueKey('repeatsSwitch'));
        await scrollTo(tester, repeats);
        await tester.tap(repeats);
        await tester.pumpAndSettle();
        final after = find.byKey(const ValueKey('repeatEndsAfter'));
        await scrollTo(tester, after);
        await tester.tap(find.byType(Radio<RepeatEnd>).last);
        await tester.pumpAndSettle();
        await scrollTo(tester, find.byKey(const ValueKey('repeatNext')));
        noException(tester);
      });
    }
  });
}
