import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/models/app_theme_mode.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/home_list_slivers.dart';
import 'package:my_expense_tracker_app/ui/features/recurring/views/recurring_list_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// The Recurring flows through the real app (phase-7a.md §8.1 A–I, §12
/// "Widgets"). Today is Fri 9 Oct 2026, noon.
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

  /// What TalkBack reads for a Recurring tile: "Waiting, 3".
  String tileLabel(WidgetTester tester, String section) =>
      tester.getSemantics(find.byKey(ValueKey('section-$section'))).label;

  bool tileSelected(WidgetTester tester, String section) => tester
      .getSemantics(find.byKey(ValueKey('section-$section')))
      .flagsCollection
      .isSelected
      .toBoolOrNull()!;

  /// Fails with the whole error (which widget overflowed), not only its
  /// first line.
  void noException(WidgetTester tester) {
    final error = tester.takeException();
    if (error == null) return;
    fail(error is FlutterError ? error.toStringDeep() : '$error');
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await tester.pumpAndSettle();
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

  Finder repeatMarks() => find.descendant(
    of: find.byType(ExpenseRow),
    matching: find.byKey(const ValueKey('repeatMark')),
  );

  /// Netflix, monthly from today, saved through the repository.
  Future<Expense> savedNetflix({String day = '2026-10-09'}) async {
    final local = DateTime(
      int.parse(day.substring(0, 4)),
      int.parse(day.substring(5, 7)),
      int.parse(day.substring(8, 10)),
      10,
    );
    return (await deps.expenses.addRepeating(
      ExpenseInput(
        title: 'Netflix',
        description: null,
        amount: const Money(64900, 'INR'),
        occurredAt: local.toUtc(),
        utcOffsetMinutes: local.timeZoneOffset.inMinutes,
        categoryId: 1,
        paymentMethodId: 1,
        eventIds: const {},
      ),
      RepeatChoice.defaults,
    )).expense;
  }

  testWidgets('A: Add with Repeats → saved, Home says so, the row has the '
      'mark', (tester) async {
    useOppoSize(tester);
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Title'), 'Netflix');
    await tester.enterText(field('Amount'), '649');
    await tester.tap(find.text('Food'));
    await tester.pump();
    final repeats = find.byKey(const ValueKey('repeatsSwitch'));
    await scrollTo(tester, repeats);
    expect(find.text('Repeats'), findsOneWidget);
    await tester.tap(repeats);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('repeatNext')));
    expect(find.text('Every month on day 9'), findsOneWidget);
    expect(find.text('Next: Nov 9'), findsOneWidget);
    // Found on the Oppo: "On" showed "—" until a date was picked; it shows
    // the date it would end on (six months on).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('repeatEndDate')),
        matching: find.text('Apr 9, 2027'),
      ),
      findsOneWidget,
    );
    // Found on the Oppo: TalkBack read the rule, "Ends" and "Next" as one
    // node; each is its own now.
    expect(
      tester.getSemantics(find.byKey(const ValueKey('repeatSchedule'))).label,
      'Every month on day 9',
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('repeatNext'))).label,
      'Next: Nov 9',
    );
    expect(find.byKey(const ValueKey('repeatAlsoAdds')), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved. Repeats: Every month on day 9'), findsOneWidget);
    expect(repeatMarks(), findsOneWidget);
    expect(tester.getSemantics(repeatMarks()).label, contains('Repeats'));
  });

  testWidgets('A: an invalid Every shows its error after Save, and nothing '
      'is saved', (tester) async {
    useOppoSize(tester);
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Title'), 'Netflix');
    await tester.enterText(field('Amount'), '649');
    await tester.tap(find.text('Food'));
    final repeats = find.byKey(const ValueKey('repeatsSwitch'));
    await scrollTo(tester, repeats);
    await tester.tap(repeats);
    await tester.pumpAndSettle();
    final every = find.byKey(const ValueKey('repeatInterval'));
    await scrollTo(tester, every);
    await tester.enterText(every, '0');
    await tester.pump();
    expect(find.text('1 to 99'), findsNothing, reason: 'not before Save');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('1 to 99'), findsOneWidget);
    expect(await deps.database.query('expenses'), isEmpty);
  });

  testWidgets('B: a resumed draft from 31 Jul says what Save adds; Save adds '
      'it', (tester) async {
    useOppoSize(tester);
    deps.drafts.update(
      ExpenseDraft(
        editingExpenseId: null,
        title: 'Netflix',
        amountExpression: '649',
        description: '',
        categoryId: 1,
        eventIds: const {},
        paymentMethodId: 1,
        currencyCode: 'INR',
        pickedWallClock: DateTime(2026, 7, 31, 10),
        touched: const {
          DraftField.title,
          DraftField.amount,
          DraftField.dateTime,
        },
        itemizeLine: null,
        itemizeLabels: const [],
        itemizeTerms: const [],
        updatedAt: clock.now.toUtc(),
        repeat: RepeatChoice.defaults,
      ),
    );
    await deps.drafts.flush();
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add expense'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('repeatNext')));
    expect(
      find.text("Every month on day 31 (or the month's last day)"),
      findsOneWidget,
    );
    expect(
      find.text('Also adds 2 earlier payments: Aug 31, Sep 30'),
      findsOneWidget,
    );
    expect(find.text('Next: Oct 31'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved with 2 earlier payments.'), findsOneWidget);
    expect(repeatMarks(), findsNWidgets(3));
  });

  testWidgets('B: too many earlier payments: warned live; Save blocked', (
    tester,
  ) async {
    useOppoSize(tester);
    deps.drafts.update(
      ExpenseDraft(
        editingExpenseId: null,
        title: 'Milk',
        amountExpression: '30',
        description: '',
        categoryId: 1,
        eventIds: const {},
        paymentMethodId: 1,
        currencyCode: 'INR',
        pickedWallClock: DateTime(2023, 1, 1, 7),
        touched: const {
          DraftField.title,
          DraftField.amount,
          DraftField.dateTime,
        },
        itemizeLine: null,
        itemizeLabels: const [],
        itemizeTerms: const [],
        updatedAt: clock.now.toUtc(),
        repeat: const RepeatChoice(frequency: Frequency.daily),
      ),
    );
    await deps.drafts.flush();
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add expense'));
    await tester.pumpAndSettle();
    final warning = find.byKey(const ValueKey('repeatTooMany'));
    await scrollTo(tester, warning);
    expect(
      find.text(
        "That's 1,377 earlier payments; at most 1,000. Pick a later date or "
        'a longer interval.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(await deps.database.query('expenses'), isEmpty);
    expect(find.text('Add expense'), findsWidgets, reason: 'still the form');
  });

  testWidgets('Manage reads its counts again when its tab shows (found on '
      'the Oppo: a repeating expense saved on Home left "None running")', (
    tester,
  ) async {
    useOppoSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    expect(find.text('None running'), findsOneWidget);
    await openTab(tester, 'Home');
    await savedNetflix();
    await openTab(tester, 'Manage');
    expect(find.text('1 running'), findsOneWidget);
  });

  testWidgets('Edit: "On" shows the earliest end it would get, not "—" '
      '(found on the Oppo)', (tester) async {
    useOppoSize(tester);
    final expense = await savedNetflix();
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    await tester.tap(find.byKey(const ValueKey('manageRecurring')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editRecurring')));
    await tester.pumpAndSettle();
    final endDate = find.byKey(const ValueKey('recurringEndDate'));
    await scrollTo(tester, endDate);
    expect(
      find.descendant(of: endDate, matching: find.text('Oct 9, 2026')),
      findsOneWidget,
    );
    expect(expense.isRecurring, isTrue);
  });

  testWidgets('Recurring: Waiting is shown first while anything waits; a '
      'tile lists its own items; an empty one says so (owner, 2026-10-09)', (
    tester,
  ) async {
    useOppoSize(tester);
    await savedNetflix();
    await insertRecurringRow(
      deps.database,
      title: 'Gym',
      startOn: '2026-07-09',
      nextDueOn: '2026-08-09',
    );
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    await tester.tap(find.byKey(const ValueKey('manageRecurring')));
    await tester.pumpAndSettle();
    expect(tileLabel(tester, 'waiting'), 'Waiting, 1');
    expect(tileSelected(tester, 'waiting'), isTrue);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('section-active')));
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Gym'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('section-archived')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sectionEmpty')), findsOneWidget);
  });

  testWidgets('Recurring: the tiles stay put over a long list, so the '
      'Archive is one tap away at its end (owner, 2026-10-09)', (tester) async {
    useOppoSize(tester);
    for (var i = 0; i < 40; i++) {
      await insertRecurringRow(
        deps.database,
        title: 'Bill $i',
        startOn: '2026-10-09',
        nextDueOn: '2026-11-09',
      );
    }
    final old = await insertRecurringRow(deps.database, title: 'Old');
    await deps.recurring.archive(old);
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    await tester.tap(find.byKey(const ValueKey('manageRecurring')));
    await tester.pumpAndSettle();
    await tester.fling(find.text('Bill 0'), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    expect(find.text('Bill 0'), findsNothing, reason: 'scrolled away');
    await tester.tap(find.byKey(const ValueKey('section-archived')));
    await tester.pumpAndSettle();
    expect(find.text('Old'), findsOneWidget);
  });

  testWidgets('C: a payment due at startup is added, and Home says so', (
    tester,
  ) async {
    useOppoSize(tester);
    await insertRecurringRow(
      deps.database,
      startOn: '2026-09-09',
      nextDueOn: '2026-10-09',
    );
    await pumpApp(tester, dependencies: deps);
    expect(find.text('Added 1 recurring expense'), findsOneWidget);
    expect(repeatMarks(), findsOneWidget);
  });

  testWidgets('D: a backlog of two months is held: Review → the page → '
      'Skip them', (tester) async {
    useOppoSize(tester);
    await insertRecurringRow(
      deps.database,
      title: 'Gym',
      startOn: '2026-07-09',
      nextDueOn: '2026-08-09',
    );
    await pumpApp(tester, dependencies: deps);
    expect(find.text('Gym has 3 payments waiting'), findsOneWidget);
    expect(await deps.database.query('expenses'), isEmpty);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Review'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holdCard')), findsOneWidget);
    // No line break inside a date (it wrapped "9 Aug – 9 / Oct" on the
    // Oppo), and no "Next: Aug 9", two months back, under the card.
    expect(
      find.text('3 payments are due, Aug\u00A09 – Oct\u00A09.'),
      findsOneWidget,
    );
    expect(find.textContaining('Next:'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Add all 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skipThem')));
    await tester.pumpAndSettle();
    expect(find.text('Skipped 2. Next: Nov 9'), findsOneWidget);
    expect(find.byKey(const ValueKey('holdCard')), findsNothing);
    // Today's payment was added, the two before it skipped.
    final rows = await deps.database.query('expenses');
    expect([for (final r in rows) r['recurring_due_on']], ['2026-10-09']);
  });

  testWidgets('E: a payment\'s Edit shows its link row; the link opens the '
      'page; Delete moves it to the bin', (tester) async {
    useOppoSize(tester);
    await savedNetflix();
    await pumpApp(tester, dependencies: deps);
    await tester.tap(
      find.descendant(
        of: find.byType(ExpenseRow),
        matching: find.text('Netflix'),
      ),
    );
    await tester.pumpAndSettle();
    final link = find.byKey(const ValueKey('recurringLink'));
    await scrollTo(tester, link);
    expect(
      find.text('Changes here are for this payment only.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('repeatsSwitch')), findsNothing);
    expect(
      tester.getSemantics(link).label,
      'Recurring item Netflix, Every month on day 9. Opens its page.',
    );
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stopRecurring')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Moved to bin'), findsOneWidget);
  });

  testWidgets('F + G: Manage → Recurring → the page; Change price; Stop → '
      'Undo', (tester) async {
    useOppoSize(tester);
    await savedNetflix();
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    expect(find.text('1 running'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('manageRecurring')));
    await tester.pumpAndSettle();
    // The three tiles with their counts; Active chosen (nothing waits).
    expect(tileLabel(tester, 'waiting'), 'Waiting, 0');
    expect(tileLabel(tester, 'active'), 'Active, 1');
    expect(tileLabel(tester, 'archived'), 'Archive, 0');
    expect(tileSelected(tester, 'active'), isTrue);
    // A low rectangle: the icon and the count on one row, the label under
    // them (owner, 2026-10-09: the square tile looked too big).
    final tile = find.byKey(const ValueKey('section-active'));
    final size = tester.getSize(tile);
    expect(size.width, greaterThan(size.height));
    final icon = tester.getCenter(
      find.descendant(of: tile, matching: find.byIcon(Icons.repeat)),
    );
    final count = tester.getCenter(
      find.descendant(of: tile, matching: find.text('1')),
    );
    final label = tester.getCenter(
      find.descendant(of: tile, matching: find.text('Active')),
    );
    expect((icon.dy - count.dy).abs(), lessThan(2));
    expect(icon.dx, lessThan(count.dx));
    expect(label.dy, greaterThan(count.dy));
    expect(find.text('Monthly · next Nov\u00A09'), findsOneWidget);
    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();

    // G: Change price from the next payment.
    await tester.tap(find.byKey(const ValueKey('changePrice')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('savePrice'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    // The symbol only before the amount: the item's currency is fixed
    // (owner, 2026-10-09: was "₹ INR").
    expect(find.text('₹ '), findsOneWidget);
    expect(find.text('₹ INR '), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('newPrice')), '600+99');
    await tester.pump();
    expect(find.text('= ₹699.00'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Price changed'), findsOneWidget);
    expect(find.text('from Nov 9, 2026 · scheduled'), findsOneWidget);

    // F: Stop → the list, with Undo.
    await tester.tap(find.byKey(const ValueKey('stopRecurring')));
    await tester.pumpAndSettle();
    expect(find.text('Netflix stopped and archived.'), findsOneWidget);
    expect(tileLabel(tester, 'archived'), 'Archive, 1');
    expect(tileLabel(tester, 'active'), 'Active, 0');
    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly · next Nov\u00A09'), findsOneWidget);
    expect(tileLabel(tester, 'archived'), 'Archive, 0');
  });

  testWidgets('H: the Archive tile → Restore asks, restores, and the list '
      'says so', (tester) async {
    useOppoSize(tester);
    final expense = await savedNetflix();
    await deps.recurring.archive(expense.recurringExpenseId!);
    clock.now = DateTime(2026, 12, 20, 12);
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    await tester.tap(find.byKey(const ValueKey('manageRecurring')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('section-archived')));
    await tester.pumpAndSettle();
    expect(tileSelected(tester, 'archived'), isTrue);
    expect(find.text('Monthly · stopped Oct\u00A09'), findsOneWidget);
    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsOneWidget);
    expect(find.byKey(const ValueKey('editRecurring')), findsNothing);
    expect(find.byKey(const ValueKey('changePrice')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('restoreRecurring')));
    await tester.pumpAndSettle();
    expect(find.text('Restore Netflix?'), findsOneWidget);
    expect(
      find.text('It adds payments again from Jan 9, 2027.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Netflix restored. Next: Jan 9, 2027'), findsOneWidget);
    // Still on the Archive tile, now empty; Active counts it.
    expect(
      find.text('Nothing is archived. Stopped and ended items go here.'),
      findsOneWidget,
    );
    expect(tileLabel(tester, 'active'), 'Active, 1');
    // The archived gap (Nov 9, Dec 9) is not caught up.
    expect(await deps.database.query('expenses'), hasLength(1));
  });

  testWidgets('H: Delete for good asks with the count; the payment stays '
      'without the mark', (tester) async {
    useOppoSize(tester);
    final expense = await savedNetflix();
    await deps.recurring.archive(expense.recurringExpenseId!);
    await pumpApp(tester, dependencies: deps);
    expect(repeatMarks(), findsOneWidget);
    await openTab(tester, 'Manage');
    await tester.tap(find.byKey(const ValueKey('manageRecurring')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('section-archived')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('deleteForGood')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Its payment stays, without the repeat mark. This can't be undone.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Netflix deleted. Its payment stays.'), findsOneWidget);
    // Back on the (now empty) list, not further: the page closed once
    // (it closed twice, with "no longer exists", before the fix).
    expect(find.text('This recurring item no longer exists.'), findsNothing);
    expect(
      find.text(
        'Nothing repeats yet. Turn on Repeats when you add an expense.',
      ),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openTab(tester, 'Home');
    expect(repeatMarks(), findsNothing);
  });

  testWidgets('New with an Add draft in the slot: the draft as it was, '
      'Repeats on', (tester) async {
    useOppoSize(tester);
    deps.drafts.update(
      ExpenseDraft(
        editingExpenseId: null,
        title: 'Typed before',
        amountExpression: '12',
        description: '',
        categoryId: null,
        eventIds: const {},
        paymentMethodId: 1,
        currencyCode: 'INR',
        pickedWallClock: null,
        touched: const {DraftField.title, DraftField.amount},
        itemizeLine: null,
        itemizeLabels: const [],
        itemizeTerms: const [],
        updatedAt: clock.now.toUtc(),
      ),
    );
    await deps.drafts.flush();
    await pumpApp(tester, dependencies: deps);
    await openTab(tester, 'Manage');
    await tester.tap(find.byKey(const ValueKey('manageRecurring')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Nothing repeats yet. Turn on Repeats when you add an expense.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('newRecurring')));
    await tester.pumpAndSettle();
    expect(find.text('Typed before'), findsOneWidget);
    final repeats = find.byKey(const ValueKey('repeatsSwitch'));
    await scrollTo(tester, repeats);
    expect(tester.widget<SwitchListTile>(repeats).value, isTrue);
  });

  testWidgets('Manage at 360 dp, font 2.0, Spanish, nothing running: the '
      '"Ninguno activo" count fits (it was a trailing text that took the '
      'whole tile; the hidden tab broke Home)', (tester) async {
    useOppoSize(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await deps.settings.setLocale(const Locale('es'));
    await pumpApp(tester, dependencies: deps);
    noException(tester);
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    noException(tester);
    expect(find.text('Ninguno activo'), findsOneWidget);
  });

  group('layout: no overflow at 360 and 411 dp, font 1.0 and 2.0, en / es '
      '/ hi, dark', () {
    for (final (width, scale, language, dark) in [
      (360.0, 1.0, 'en', false),
      (360.0, 2.0, 'en', false),
      (360.0, 2.0, 'es', true),
      (360.0, 2.0, 'hi', false),
      (411.0, 2.0, 'en', true),
    ]) {
      testWidgets('$width dp, ×$scale, $language${dark ? ', dark' : ''}', (
        tester,
      ) async {
        useOppoSize(tester, width: width);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await deps.settings.setLocale(Locale(language));
        if (dark) await deps.settings.setTheme(AppThemeMode.dark);
        final expense = await savedNetflix(day: '2026-07-31');
        await deps.recurring.changePrice(
          expense.recurringExpenseId!,
          amountMinor: 69900,
          from: '2027-01-31',
        );
        await insertRecurringRow(
          deps.database,
          title: 'A gym membership with a very long name indeed',
          startOn: '2026-07-09',
          nextDueOn: '2026-08-09',
        );
        // The screens alone, not the whole app: Home and Manage have
        // layout tests of their own, and the list is reached from Manage
        // only ("Manage at 360 dp" above covers its tile).
        await pumpScreen(
          tester,
          dependencies: deps,
          screen: RecurringListScreen(dependencies: deps),
        );
        noException(tester);

        // The list and the page with the hold card.
        await tester.tap(
          find.text('A gym membership with a very long name indeed'),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('holdCard')), findsOneWidget);
        noException(tester);
        // The system Back: pageBack() looks for the English tooltip.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Netflix's page with a scheduled price, then the sheet. The list
        // opens on Waiting (the gym): Active first.
        await tester.tap(find.byKey(const ValueKey('section-active')));
        await tester.pumpAndSettle();
        noException(tester);
        await tester.tap(find.text('Netflix'));
        await tester.pumpAndSettle();
        noException(tester);
        await tester.tap(find.byKey(const ValueKey('changePrice')));
        await tester.pumpAndSettle();
        noException(tester);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // The Edit screen.
        await tester.tap(find.byKey(const ValueKey('editRecurring')));
        await tester.pumpAndSettle();
        noException(tester);
      });
    }
  });
}
