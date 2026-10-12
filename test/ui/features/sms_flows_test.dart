import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/models/sms_suggestion.dart';
import 'package:my_expense_tracker_app/ui/features/expenses/views/expense_form_screen.dart';
import 'package:my_expense_tracker_app/ui/features/sms/views/sms_card.dart';
import 'package:my_expense_tracker_app/ui/features/sms/views/sms_screen.dart';

import '../../domain/sms/fixtures/india_sms.dart';
import '../../helpers/fake_sms_service.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// Home's SMS icon, the SMS screen, the draft dialog and the form's banner.
/// Today is Sun 11 Oct 2026, 14:30 IST.
void main() {
  late AppDependencies deps;
  late FakeSmsService sms;
  late TestClock clock;

  const day = Duration.millisecondsPerDay;
  const bank = 'VM-ABCBNK-S';

  Future<void> setUpApp(
    WidgetTester tester, {
    String language = 'en',
    double width = 360,
    double textScale = 1,
    bool enabled = true,
    bool granted = true,
    bool withExpense = true,
    void Function()? seedInbox,
  }) async {
    await tester.runAsync(() async {
      clock = TestClock(DateTime.utc(2026, 10, 11, 9));
      sms = FakeSmsService(granted: granted);
      deps = await openTestDependencies(clock: clock, sms: sms);
      await deps.settings.setOnboardingCompleted();
      await deps.settings.setSmsEnabled(enabled);
      if (language != 'en') await deps.settings.setLocale(Locale(language));
      // One expense, so Home shows its filter bar (an empty Home
      // hides it).
      if (withExpense) {
        await deps.expenses.add(
          ExpenseInput(
            title: 'Tea',
            description: null,
            amount: const Money(2000, 'INR'),
            occurredAt: clock.now.subtract(const Duration(days: 2)),
            utcOffsetMinutes: 330,
            categoryId: 1,
            paymentMethodId: 1,
            eventIds: const {},
          ),
        );
      }
    });
    seedInbox?.call();
    tester.view.physicalSize = Size(width * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  int nowMs() => clock.now.millisecondsSinceEpoch;

  /// Three debits: Sunrise (₹75) today, Globex (₹150) and a mandate
  /// (₹12,500) yesterday.
  void standardInbox() => sms
    ..add(bank, nowMs() - 2 * 60 * 60 * 1000, bankSent2)
    ..add(bank, nowMs() - day, bankSent1)
    ..add(bank, nowMs() - day - 60 * 1000, bankMandate)
    ..add(bank, nowMs() - day - 120 * 1000, bankAtm);

  Future<void> start(WidgetTester tester) async {
    await pumpApp(tester, dependencies: deps);
    await pumpUntil(
      tester,
      () => find.byKey(const ValueKey('smsButton')).evaluate().isNotEmpty,
      description: 'the SMS icon',
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSms(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('smsButton')));
    await pumpUntil(
      tester,
      () =>
          find.byType(SmsCard).evaluate().isNotEmpty ||
          find.text('No new bank SMS').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
  }

  group('the icon', () {
    testWidgets('first of the icons, with a count badge that follows what '
        'the SMS screen did', (t) async {
      await setUpApp(t, seedInbox: standardInbox);
      await start(t);
      final icon = find.byKey(const ValueKey('smsButton'));
      final filter = find.byKey(const ValueKey('filterButton'));
      expect(t.getCenter(icon).dx, lessThan(t.getCenter(filter).dx));
      expect(
        find.descendant(of: icon, matching: find.text('3')),
        findsOneWidget,
      );
      expect(find.byTooltip('3 new SMS suggestions'), findsOneWidget);

      // One dismissed there → 2 back on Home.
      await openSms(t);
      await t.tap(find.byTooltip('Dismiss').first);
      await t.pumpAndSettle();
      await t.pageBack();
      await pumpUntil(
        t,
        () => find
            .descendant(of: icon, matching: find.text('2'))
            .evaluate()
            .isNotEmpty,
      );
    });

    testWidgets('an empty Home (no filter bar): the icon in the app '
        'bar, left of the currency button; once an expense is added, only '
        'in the filter bar (regression: found on the Oppo, the suggestions '
        'had no way in; owner, 2026-10-11)', (t) async {
      await setUpApp(t, withExpense: false, seedInbox: standardInbox);
      await start(t);
      expect(find.byKey(const ValueKey('filterButton')), findsNothing);
      expect(find.text('No expenses yet'), findsOneWidget);
      final icon = find.byKey(const ValueKey('smsButton'));
      expect(icon, findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: icon),
        findsOneWidget,
      );
      expect(
        t.getCenter(icon).dx,
        lessThan(t.getCenter(find.byKey(const ValueKey('currencyChip'))).dx),
      );
      await openSms(t);
      expect(find.byType(SmsCard), findsNWidgets(3));
      // Add one: the icon moves to the filter bar only.
      await t.tap(find.text('Sunrise REFRESHMENT'));
      await pumpUntilFound(t, find.byType(ExpenseFormScreen));
      await t.pumpAndSettle();
      await t.tap(find.text('Food'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await pumpUntil(t, () => find.byType(SmsCard).evaluate().length == 2);
      await t.pumpAndSettle();
      await t.pageBack();
      await pumpUntilFound(t, find.byKey(const ValueKey('filterButton')));
      await t.pumpAndSettle();
      expect(icon, findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: icon),
        findsNothing,
      );
    });

    testWidgets('hidden while off', (t) async {
      await setUpApp(t, enabled: false, seedInbox: standardInbox);
      await pumpApp(t, dependencies: deps);
      await pumpUntil(
        t,
        () => find.byKey(const ValueKey('filterButton')).evaluate().isNotEmpty,
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('smsButton')), findsNothing);
    });

    testWidgets('permission taken away: the failed icon, no badge; the '
        'screen offers Allow, which turns it back on', (t) async {
      await setUpApp(t, granted: false, seedInbox: standardInbox);
      await start(t);
      final icon = find.byKey(const ValueKey('smsButton'));
      expect(
        find.descendant(
          of: icon,
          matching: find.byIcon(Icons.sms_failed_outlined),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('SMS permission is off'), findsOneWidget);
      await openSms(t);
      expect(find.text('SMS permission is off'), findsOneWidget);
      await t.tap(find.text('Allow'));
      await pumpUntil(t, () => find.byType(SmsCard).evaluate().length == 3);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('smsPermissionBanner')), findsNothing);
    });
  });

  testWidgets('Settings → SMS tile follows the SMS state: the count, then '
      'Off once turned off there', (t) async {
    await setUpApp(t, seedInbox: standardInbox);
    await start(t);
    await t.tap(find.text('Settings'));
    await t.pumpAndSettle();
    final tile = find.byKey(const ValueKey('settingsSms'));
    expect(
      find.descendant(of: tile, matching: find.text('On · 3 waiting')),
      findsOneWidget,
    );
    await t.tap(tile);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('smsSwitch')));
    await pumpUntil(
      t,
      () => !t
          .widget<SwitchListTile>(find.byKey(const ValueKey('smsSwitch')))
          .value,
    );
    await t.pageBack();
    await t.pumpAndSettle();
    expect(
      find.descendant(of: tile, matching: find.text('Off')),
      findsOneWidget,
    );
  });

  group('the screen', () {
    testWidgets('frames and day headers; two columns; ATM not there; the '
        'dismiss icon removes that card only, Undo brings it back', (t) async {
      await setUpApp(t, seedInbox: standardInbox);
      await start(t);
      await openSms(t);
      expect(find.text('Oct 2026'), findsOneWidget);
      expect(find.byType(SmsCard), findsNWidgets(3));
      expect(find.textContaining('₹5,000'), findsNothing);
      expect(find.text('Sunrise REFRESHMENT'), findsOneWidget);
      expect(find.text('GLOBEX TECHNOLOGIES PRIVA'), findsOneWidget);
      // Yesterday's two cards side by side.
      final globex = t.getTopLeft(find.text('GLOBEX TECHNOLOGIES PRIVA'));
      final mandate = t.getTopLeft(find.text('Example Ceramics Limited'));
      expect(globex.dx, isNot(mandate.dx));

      final card = find.ancestor(
        of: find.text('GLOBEX TECHNOLOGIES PRIVA'),
        matching: find.byType(SmsCard),
      );
      final id = t.widget<SmsCard>(card).sms.id;
      await t.tap(find.byKey(ValueKey('smsDismiss $id')));
      await t.pumpAndSettle();
      expect(find.byType(SmsCard), findsNWidgets(2));
      expect(find.text('Suggestion dismissed'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await pumpUntil(t, () => find.byType(SmsCard).evaluate().length == 3);
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.text('GLOBEX TECHNOLOGIES PRIVA')),
        globex,
        reason: 'back in its place',
      );
    });

    testWidgets('tap → the form filled, with the banner; Save → the card '
        'goes and the badge counts down', (t) async {
      await setUpApp(t, seedInbox: standardInbox);
      await start(t);
      await openSms(t);
      await t.tap(find.text('Sunrise REFRESHMENT'));
      await pumpUntilFound(t, find.byType(ExpenseFormScreen));
      await t.pumpAndSettle();
      expect(find.textContaining('From SMS · VM-ABCBNK-S'), findsOneWidget);
      expect(find.text('Sunrise REFRESHMENT'), findsOneWidget, reason: 'title');
      expect(find.text('75.00'), findsOneWidget);
      // No keyboard on the filled title: the category tiles stay in view
      // (found on the Oppo).
      expect(
        t
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isFalse,
      );
      expect(find.text('Food'), findsOneWidget);
      // Pick a category, then Save.
      await t.tap(find.text('Food'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await pumpUntil(
        t,
        () =>
            find.byType(SmsScreen).evaluate().isNotEmpty &&
            find.byType(ExpenseFormScreen).evaluate().isEmpty,
      );
      await pumpUntil(t, () => find.byType(SmsCard).evaluate().length == 2);
      await t.pageBack();
      await pumpUntil(
        t,
        () => find
            .descendant(
              of: find.byKey(const ValueKey('smsButton')),
              matching: find.text('2'),
            )
            .evaluate()
            .isNotEmpty,
      );
    });

    testWidgets('empty: "No new bank SMS" and when it was checked', (t) async {
      await setUpApp(t);
      await start(t);
      await openSms(t);
      expect(find.text('No new bank SMS'), findsOneWidget);
      expect(find.textContaining('Checked'), findsOneWidget);
    });

    testWidgets('a "99+" badge at text ×2 stays clear of the filter icon '
        '(found on the Oppo at its largest font)', (t) async {
      await setUpApp(t, textScale: 2.0);
      await t.runAsync(() async {
        await deps.smsSuggestions.insertScanned([
          for (var i = 0; i < 120; i++)
            NewSmsSuggestion(
              sender: bank,
              receivedAtMs: nowMs() - 3 * day - i,
              utcOffsetMinutes: 330,
              bodySha256: i.toRadixString(16).padLeft(64, '0'),
              amountMinor: 100,
              paymentMethodKey: 'upi',
            ),
        ], cursorMs: nowMs());
      });
      await start(t);
      final badge = find.descendant(
        of: find.byKey(const ValueKey('smsButton')),
        matching: find.text('99+'),
      );
      expect(badge, findsOneWidget);
      final filter = find.byKey(const ValueKey('filterButton'));
      final filterIcon = find.descendant(
        of: filter,
        matching: find.byType(Icon),
      );
      expect(
        t.getRect(badge).right,
        lessThanOrEqualTo(t.getRect(filterIcon).left),
      );
    });

    for (final (language, scale) in [('en', 2.0), ('hi', 2.0), ('es', 2.0)]) {
      testWidgets('$language at 360 dp, text ×$scale: no overflow', (t) async {
        await setUpApp(
          t,
          language: language,
          textScale: scale,
          seedInbox: standardInbox,
        );
        await start(t);
        await openSms(t);
        expect(find.byType(SmsCard), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('the draft dialog', () {
    ExpenseDraft addDraft({int? editing, String title = 'Lunch'}) =>
        ExpenseDraft(
          editingExpenseId: editing,
          title: title,
          amountExpression: '42',
          description: '',
          categoryId: null,
          eventIds: const {},
          paymentMethodId: null,
          currencyCode: 'INR',
          pickedWallClock: null,
          touched: const {DraftField.title, DraftField.amount},
          itemizeLine: null,
          itemizeLabels: const [],
          itemizeTerms: const [],
          updatedAt: DateTime.utc(2026, 10, 11, 8),
        );

    Future<void> putDraft(WidgetTester t, ExpenseDraft draft) =>
        t.runAsync(() async {
          deps.drafts.update(draft);
          await deps.drafts.flush();
        });

    testWidgets('an Add draft → the dialog; Cancel (and back) → nothing '
        'changes; Dismiss draft → the slot empty, the SMS form', (t) async {
      await setUpApp(t, seedInbox: standardInbox);
      await start(t);
      await putDraft(t, addDraft());
      await openSms(t);
      await t.tap(find.text('Sunrise REFRESHMENT'));
      await t.pumpAndSettle();
      expect(find.text('Unsaved draft'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.byType(ExpenseFormScreen), findsNothing);
      expect((await t.runAsync(deps.drafts.read))?.title, 'Lunch');

      await t.tap(find.text('Sunrise REFRESHMENT'));
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(ExpenseFormScreen), findsNothing);
      expect((await t.runAsync(deps.drafts.read))?.title, 'Lunch');

      await t.tap(find.text('Sunrise REFRESHMENT'));
      await t.pumpAndSettle();
      await t.tap(find.text('Dismiss draft'));
      await pumpUntilFound(t, find.byType(ExpenseFormScreen));
      await t.pumpAndSettle();
      expect(find.textContaining('From SMS'), findsOneWidget);
      expect(await t.runAsync(deps.drafts.read), isNull);
    });

    testWidgets('an Edit draft: the message names the expense', (t) async {
      await setUpApp(t, seedInbox: standardInbox);
      await start(t);
      await putDraft(t, addDraft(editing: 99, title: 'Dinner'));
      await openSms(t);
      await t.tap(find.text('Sunrise REFRESHMENT'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('unsaved changes to "Dinner"'),
        findsOneWidget,
      );
    });

    testWidgets('this SMS\'s own draft → no dialog, the draft opens', (
      t,
    ) async {
      await setUpApp(t, seedInbox: standardInbox);
      await start(t);
      await openSms(t);
      final row = t
          .widget<SmsCard>(
            find.ancestor(
              of: find.text('Sunrise REFRESHMENT'),
              matching: find.byType(SmsCard),
            ),
          )
          .sms;
      await putDraft(
        t,
        ExpenseDraft(
          editingExpenseId: null,
          title: 'Sunrise juice',
          amountExpression: '75',
          description: '',
          categoryId: null,
          eventIds: const {},
          paymentMethodId: null,
          currencyCode: 'INR',
          pickedWallClock: null,
          touched: const {DraftField.title},
          itemizeLine: null,
          itemizeLabels: const [],
          itemizeTerms: const [],
          updatedAt: DateTime.utc(2026, 10, 11, 8),
          sms: row.link,
        ),
      );
      await t.tap(find.text('Sunrise REFRESHMENT'));
      await pumpUntilFound(t, find.byType(ExpenseFormScreen));
      await t.pumpAndSettle();
      expect(find.text('Unsaved draft'), findsNothing);
      expect(find.text('Sunrise juice'), findsOneWidget);
      expect(find.textContaining('From SMS'), findsOneWidget);
    });
  });
}
