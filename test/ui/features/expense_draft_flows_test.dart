import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';

import 'package:my_expense_tracker_app/ui/features/home/views/home_list_slivers.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// Phase 4's flows through the real app (phase-4.md §12 "Widgets").
void main() {
  late AppDependencies deps;

  setUp(() async {
    deps = await openTestDependencies();
    await deps.settings.setOnboardingCompleted();
  });

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  /// The keyboard is up: the operator row shows only then.
  void showKeyboard(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: 800);
    addTearDown(tester.view.resetViewInsets);
  }

  Finder field(String label) => find.widgetWithText(TextField, label);
  Finder rowKey(String name) => find.byKey(ValueKey('rowKey-$name'));
  Finder button(String label) => find.widgetWithText(TextButton, label);

  TextField textField(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label));

  String textOf(WidgetTester tester, String label) =>
      textField(tester, label).controller!.text;

  Future<void> openAdd(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add expense'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  /// Scrolls [text] into view first: with the keyboard up the category
  /// tiles sit below the date / time / payment row, under the operator row.
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Future<Expense> seed({
    String title = 'Lunch',
    Money amount = const Money(11050, 'INR'),
    String? expression,
    int categoryId = 1,
  }) => deps.expenses.add(
    ExpenseInput(
      title: title,
      description: 'With rice',
      amount: amount,
      amountExpression: expression,
      occurredAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      categoryId: categoryId,
      paymentMethodId: 2,
      eventIds: const {},
    ),
  );

  /// Puts the amount field's cursor at [offset].
  Future<void> amountCursorAt(WidgetTester tester, int offset) async {
    final controller = textField(tester, 'Amount').controller!;
    controller.selection = TextSelection.collapsed(offset: offset);
    await tester.pump();
  }

  /// Types [text] into the amount field where its cursor is, like the
  /// keyboard does (an edit at the cursor), through the field's filter.
  Future<void> typeAmount(WidgetTester tester, String text) async {
    final controller = textField(tester, 'Amount').controller!;
    final value = controller.value;
    final at = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final next = value.text.replaceRange(at, at, text);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: at + text.length),
      ),
    );
    await tester.pump();
  }

  testWidgets('lu → pick "Lunch" → the fields are filled → Save → on Home', (
    tester,
  ) async {
    usePhoneSize(tester);
    await seed();
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);

    await tester.enterText(field('Title'), 'lu');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suggestion-Lunch')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('suggestion-Lunch')));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'Title'), 'Lunch');
    expect(textOf(tester, 'Amount'), '110.50');
    expect(textOf(tester, 'Description (optional)'), 'With rice');
    expect(find.byKey(const ValueKey('suggestion-Lunch')), findsNothing);

    await tester.tap(button('Save'));
    await tester.pumpAndSettle();
    expect(field('Title'), findsNothing);
    expect(find.text('Lunch'), findsNWidgets(2));
  });

  testWidgets('50 + 60 × 2 with the operator row → = ₹170.00 → Save → '
      'Edit shows 50+60×2', (tester) async {
    usePhoneSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.enterText(field('Title'), 'Veg');
    await tester.tap(field('Amount'));
    showKeyboard(tester);
    await tester.pumpAndSettle();

    await typeAmount(tester, '50');
    await tester.tap(rowKey('plus'));
    await tester.pump();
    await typeAmount(tester, '60');
    await tester.tap(rowKey('times'));
    await tester.pump();
    await typeAmount(tester, '2');
    expect(textOf(tester, 'Amount'), '50+60×2');
    expect(find.text('= ₹170.00'), findsOneWidget);
    final amountFocus = textField(tester, 'Amount').focusNode!;
    expect(amountFocus.hasFocus, isTrue, reason: 'the keys keep the focus');

    await tapText(tester, 'Food');
    await tester.tap(button('Save'));
    await tester.pumpAndSettle();
    final saved = (await deps.expenses.page()).single;
    expect(saved.amount.amountMinor, 17000);
    expect(saved.amountExpression, '50+60*2');

    tester.view.resetViewInsets();
    await tapText(tester, 'Veg');
    expect(textOf(tester, 'Amount'), '50+60×2');
    expect(button('Update'), findsOneWidget);
  });

  testWidgets('a key in the middle goes in at the cursor and the result '
      'follows', (tester) async {
    usePhoneSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.tap(field('Amount'));
    showKeyboard(tester);
    await tester.pumpAndSettle();
    await typeAmount(tester, '50+60');
    expect(find.text('= ₹110.00'), findsOneWidget);

    await amountCursorAt(tester, 1);
    await tester.tap(rowKey('times'));
    await tester.pump();
    expect(textOf(tester, 'Amount'), '5×0+60');
    expect(
      textField(tester, 'Amount').controller!.selection,
      const TextSelection.collapsed(offset: 2),
    );
    expect(find.text('= ₹60.00'), findsOneWidget);
  });

  testWidgets('the operator row shows only while the amount has focus and '
      'the keyboard is up', (tester) async {
    usePhoneSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    // The title has focus.
    showKeyboard(tester);
    await tester.pumpAndSettle();
    expect(rowKey('plus'), findsNothing);

    await tester.tap(field('Amount'));
    await tester.pumpAndSettle();
    expect(rowKey('plus'), findsOneWidget);
    expect(find.byType(TextButton).evaluate().length, greaterThan(5));

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(rowKey('plus'), findsNothing, reason: 'keyboard hidden');
  });

  testWidgets('es on a phone in Spain: the decimal key is `,`', (tester) async {
    usePhoneSize(tester);
    tester.platformDispatcher.localeTestValue = const Locale('es', 'ES');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await deps.settings.setLocale(es);
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(field('Importe'));
    showKeyboard(tester);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: rowKey('decimal'), matching: find.text(',')),
      findsOneWidget,
    );
    await tester.tap(rowKey('decimal'));
    await tester.pump();
    expect(textOf(tester, 'Importe'), '0,');
  });

  testWidgets('Itemize: the line goes first; again unchanged → replaced; '
      'edited → added above', (tester) async {
    usePhoneSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.enterText(field('Amount'), '50+60×2');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Itemize'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'no label yet',
    );
    await tester.enterText(find.byKey(const ValueKey('itemLabel-0')), 'potato');
    await tester.enterText(find.byKey(const ValueKey('itemLabel-1')), 'onion');
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      textOf(tester, 'Description (optional)'),
      '50 (potato) + 60 × 2 (onion)',
    );

    await tester.tap(find.text('Itemize'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('itemLabel-0')))
          .controller!
          .text,
      'potato',
      reason: 'labels come back',
    );
    await tester.enterText(find.byKey(const ValueKey('itemLabel-0')), 'aloo');
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      textOf(tester, 'Description (optional)'),
      '50 (aloo) + 60 × 2 (onion)',
    );

    await tester.enterText(
      field('Description (optional)'),
      '50 (aloo) + 60 × 2 (onion)!',
    );
    await tester.pump();
    await tester.tap(find.text('Itemize'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      textOf(tester, 'Description (optional)'),
      '50 (aloo) + 60 × 2 (onion)\n50 (aloo) + 60 × 2 (onion)!',
    );
  });

  testWidgets('Add → back → "Draft saved" → FAB → restored with a banner → '
      'Clear → Undo → Clear → back → FAB → empty', (tester) async {
    usePhoneSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.enterText(field('Title'), 'Chai');
    await tester.pump();
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Draft saved'), findsOneWidget);

    await openAdd(tester);
    expect(textOf(tester, 'Title'), 'Chai');
    expect(find.text('Unsaved expense restored (today)'), findsOneWidget);

    await tester.tap(button('Clear'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Title'), '');
    expect(find.text('Form cleared'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Title'), 'Chai');

    await back(tester);
    expect(find.text('Draft saved'), findsOneWidget);
    await openAdd(tester);
    expect(textOf(tester, 'Title'), 'Chai');
    await tester.tap(button('Clear'));
    await tester.pumpAndSettle();
    await back(tester);
    // The "Draft saved" of the last back has gone by now; this back says
    // nothing: there is no draft.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved'), findsNothing);
    await openAdd(tester);
    expect(textOf(tester, 'Title'), '');
    expect(find.textContaining('restored'), findsNothing);
  });

  testWidgets('Edit → change → back → the mark, stored amount on Home → '
      'tap → draft values, Update → Discard draft → back → mark gone', (
    tester,
  ) async {
    usePhoneSize(tester);
    final semantics = tester.ensureSemantics();
    await seed();
    await pumpApp(tester, dependencies: deps);
    await tapText(tester, 'Lunch');
    await tester.enterText(field('Amount'), '999');
    await tester.pump();
    await back(tester);

    expect(find.byKey(const ValueKey('unsavedMark')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ExpenseRow),
        matching: find.text('₹110.50'),
      ),
      findsOneWidget,
      reason: 'stored value',
    );
    // Read with the row: TalkBack says it after the amount.
    expect(find.bySemanticsLabel(RegExp('Unsaved changes')), findsOneWidget);

    await tapText(tester, 'Lunch');
    expect(textOf(tester, 'Amount'), '999');
    expect(find.text('Unsaved changes restored (today)'), findsOneWidget);
    expect(button('Update'), findsOneWidget);

    await tester.tap(button('Discard draft'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Amount'), '110.50');
    expect(find.text('Draft discarded'), findsOneWidget);
    expect(
      tester.widget<TextButton>(button('Update')).onPressed,
      isNull,
      reason: 'nothing to update',
    );
    await back(tester);
    expect(find.byKey(const ValueKey('unsavedMark')), findsNothing);
    semantics.dispose();
  });

  testWidgets('an Edit draft is replaced by a change in Add: the mark goes', (
    tester,
  ) async {
    usePhoneSize(tester);
    await seed();
    await pumpApp(tester, dependencies: deps);
    await tapText(tester, 'Lunch');
    await tester.enterText(field('Title'), 'Lunch!');
    await tester.pump();
    await back(tester);
    expect(find.byKey(const ValueKey('unsavedMark')), findsOneWidget);

    await openAdd(tester);
    expect(textOf(tester, 'Title'), '', reason: 'not the Edit draft');
    await tester.enterText(field('Title'), 'Tea');
    await tester.pump();
    await back(tester);
    expect(find.byKey(const ValueKey('unsavedMark')), findsNothing);
  });

  testWidgets('a chip with an Add draft whose amount is set replaces it', (
    tester,
  ) async {
    usePhoneSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.enterText(field('Amount'), '70');
    await tester.pump();
    await back(tester);

    await tester.tap(find.byKey(const ValueKey('amountChip-5000')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Amount'), '50.00');
    expect(find.text('Unsaved expense restored (today)'), findsOneWidget);
  });

  testWidgets('after a pick: another pick replaces it while nothing changed; '
      'a change hides the suggestions until Clear (owner, 2026-10-04)', (
    tester,
  ) async {
    usePhoneSize(tester);
    await seed(title: 'Lunch');
    await seed(title: 'Taxi', amount: const Money(30000, 'INR'));
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.enterText(field('Title'), 'Lu');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('suggestion-Lunch')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Amount'), '110.50');

    await tester.enterText(field('Title'), 'Ta');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('suggestion-Taxi')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Amount'), '300.00');

    await tester.enterText(field('Amount'), '');
    await tester.enterText(field('Title'), 'Lu');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suggestion-Lunch')), findsNothing);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Title'), 'Lu');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suggestion-Lunch')), findsOneWidget);
  });

  testWidgets('pick a suggestion → back: no draft; FAB → an empty form '
      '(owner, 2026-10-04)', (tester) async {
    usePhoneSize(tester);
    await seed(title: 'Lunch');
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.enterText(field('Title'), 'Lu');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('suggestion-Lunch')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Amount'), '110.50');
    await back(tester);
    expect(find.text('Draft saved'), findsNothing);
    await openAdd(tester);
    expect(textOf(tester, 'Title'), '');
    expect(textOf(tester, 'Amount'), '');
  });

  testWidgets('pick → append " at office" → back without a pick: "Draft '
      'saved"; FAB → the new title, no suggestions (owner, 2026-10-04)', (
    tester,
  ) async {
    usePhoneSize(tester);
    await seed(title: 'Lunch');
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.enterText(field('Title'), 'Lu');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('suggestion-Lunch')));
    await tester.pumpAndSettle();
    await tester.enterText(field('Title'), 'Lunch at office');
    await tester.pumpAndSettle();
    await back(tester);
    expect(find.text('Draft saved'), findsOneWidget);

    await openAdd(tester);
    expect(textOf(tester, 'Title'), 'Lunch at office');
    expect(textOf(tester, 'Amount'), '110.50');
    await tester.enterText(field('Title'), 'Lu');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suggestion-Lunch')), findsNothing);
  });

  testWidgets('a chip opens Add with that amount and the title focused', (
    tester,
  ) async {
    usePhoneSize(tester);
    await pumpApp(tester, dependencies: deps);
    expect(find.byKey(const ValueKey('amountChip-1000')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('amountChip-5000')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Amount'), '50.00');
    expect(textField(tester, 'Title').focusNode!.hasFocus, isTrue);
  });

  testWidgets('the app going to the background writes the draft before the '
      '500 ms', (tester) async {
    usePhoneSize(tester);
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.enterText(field('Title'), 'Chai');
    await tester.pump(const Duration(milliseconds: 10));
    expect(await deps.database.query('expense_draft'), isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.runAsync(() => deps.drafts.flush());
    expect(await deps.database.query('expense_draft'), hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  });

  testWidgets('back closes the suggestions, then the search, then the form', (
    tester,
  ) async {
    usePhoneSize(tester);
    await seed();
    await pumpApp(tester, dependencies: deps);
    await openAdd(tester);
    await tester.enterText(field('Title'), 'lu');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('suggestion-Lunch')), findsOneWidget);

    await back(tester);
    expect(find.byKey(const ValueKey('suggestion-Lunch')), findsNothing);
    expect(field('Title'), findsOneWidget, reason: 'still on the form');

    await tester.tap(find.byTooltip('Search').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Search categories…'), findsOne);
    await back(tester);
    expect(find.widgetWithText(TextField, 'Search categories…'), findsNothing);
    expect(field('Title'), findsOneWidget);

    await back(tester);
    expect(field('Title'), findsNothing);
    expect(find.text('Draft saved'), findsOneWidget);
  });

  testWidgets('FAB, chip and row tapped while the slot read waits open one '
      'form (R12)', (tester) async {
    usePhoneSize(tester);
    await seed();
    await pumpApp(tester, dependencies: deps);
    // Hold the database: the first read of the draft slot waits for it.
    final release = Completer<void>();
    late Future<void> held;
    await tester.runAsync(() async {
      held = deps.database.transaction((_) => release.future);
    });
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('amountChip-5000')));
    await tester.pump();
    await tester.tap(find.text('Lunch'));
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    release.complete();
    await tester.runAsync(() => held);
    await pumpUntilFound(tester, field('Title'));
    await tester.pumpAndSettle();

    expect(field('Title'), findsOneWidget);
    await back(tester);
    expect(field('Title'), findsNothing, reason: 'there was only one');
  });

  testWidgets('Update of an expense binned meanwhile keeps the edits as an '
      'Add draft', (tester) async {
    usePhoneSize(tester);
    final lunch = await seed();
    await pumpApp(tester, dependencies: deps);
    await tapText(tester, 'Lunch');
    await tester.enterText(field('Title'), 'Edited');
    await tester.pump();
    await tester.runAsync(() => deps.expenses.moveToBin(lunch.id));
    await tester.tap(button('Update'));
    await tester.pumpAndSettle();
    expect(field('Title'), findsNothing);
    expect(find.textContaining('your changes were kept'), findsOneWidget);

    await openAdd(tester);
    expect(textOf(tester, 'Title'), 'Edited');
  });
}
