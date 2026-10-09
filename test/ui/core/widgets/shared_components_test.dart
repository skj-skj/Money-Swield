import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/domain/models/category.dart';
import 'package:my_expense_tracker_app/domain/models/event.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/models/payment_method.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/builtin_names.dart';
import 'package:my_expense_tracker_app/ui/core/item_labels.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/app_sheet.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/async_body.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/choice_setting_tile.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/confirm_then_save.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/delayed_spinner.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/empty_state_view.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/expense_tile.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/load_failed_view.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/retry_row.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/section_heading.dart';

import '../../../helpers/test_database.dart';

/// The shared UI components (ui/core): each tested on its own, at the
/// Oppo's 360 dp where layout matters.
void main() {
  /// [child] in a MaterialApp with the app's strings, in a Scaffold (for
  /// snackbars).
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
  }) => tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  void useOppoSize(WidgetTester tester, {double textScale = 1}) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  group('item labels (1)', () {
    final now = DateTime.utc(2026);
    test('emoji, one space, the name in the app language', () {
      final cash = PaymentMethod(
        id: 1,
        builtinKey: 'cash',
        name: null,
        emoji: '💵',
        createdAt: now,
        updatedAt: now,
      );
      final food = Category(
        id: 1,
        builtinKey: 'food',
        name: null,
        description: null,
        emoji: '🍽️',
        createdAt: now,
        updatedAt: now,
      );
      final mine = Event(
        id: 9,
        builtinKey: null,
        name: 'Goa trip',
        description: null,
        emoji: '🏖️',
        archivedAt: null,
        createdAt: now,
        updatedAt: now,
      );
      expect(paymentMethodLabel(l10nFor('en'), cash), '💵 Cash');
      expect(paymentMethodLabel(l10nFor('hi'), cash), '💵 नकद');
      expect(categoryLabel(l10nFor('es'), food), '🍽️ Comida');
      expect(eventLabel(l10nFor('en'), mine), '🏖️ Goa trip');
      expect(emojiLabel('🧪', 'A  b'), '🧪 A  b', reason: 'the name as is');
    });

    test('compareNames ignores case', () {
      final names = ['banana', 'Apple', 'cherry', 'apple pie']
        ..sort(compareNames);
      expect(names, ['Apple', 'apple pie', 'banana', 'cherry']);
    });
  });

  group('EmptyStateView (2)', () {
    testWidgets('icon, title, message and the button that calls back', (
      tester,
    ) async {
      var tapped = 0;
      await pump(
        tester,
        EmptyStateView(
          icon: Icons.inbox,
          title: 'Nothing',
          message: 'Add one',
          actionLabel: 'Clear',
          actionKey: const ValueKey('action'),
          onAction: () => tapped++,
        ),
      );
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('Nothing'), findsOneWidget);
      expect(find.text('Add one'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('action')));
      expect(tapped, 1);
    });

    testWidgets('no button without an action; fits at 360 dp, font 2', (
      tester,
    ) async {
      useOppoSize(tester, textScale: 2);
      await pump(
        tester,
        EmptyStateView(
          icon: Icons.inbox,
          title: 'A long title ' * 6,
          message: 'A long message ' * 30,
        ),
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });
  });

  group('SectionHeading (3)', () {
    testWidgets('the text, and the error in the error colour', (tester) async {
      await pump(tester, const SectionHeading('Category', error: 'Pick one'));
      final context = tester.element(find.text('Pick one'));
      expect(
        tester.widget<Text>(find.text('Pick one')).style?.color,
        Theme.of(context).colorScheme.error,
      );
      expect(find.text('Category'), findsOneWidget);
    });

    testWidgets('accent uses the primary colour', (tester) async {
      await pump(tester, const SectionHeading('Recent', accent: true));
      expect(
        tester.widget<Text>(find.text('Recent')).style?.color,
        Theme.of(tester.element(find.text('Recent'))).colorScheme.primary,
      );
    });
  });

  testWidgets('showAppSheet: drag handle, scroll-controlled, safe area, '
      'returns its result (4)', (tester) async {
    String? result;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showAppSheet<String>(
            context,
            builder: (sheet) => TextButton(
              onPressed: () => Navigator.pop(sheet, 'picked'),
              child: const Text('Pick'),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isTrue);
    expect(find.byType(SafeArea), findsWidgets);
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    expect(result, 'picked');
  });

  group('ChoiceSettingTile (5)', () {
    Widget tile({required Future<void> Function(String) onSave}) =>
        ChoiceSettingTile<String>(
          icon: Icons.tune,
          title: 'Size',
          values: const ['S', 'M', 'L'],
          current: 'M',
          label: (v) => 'Size $v',
          onSave: onSave,
        );

    testWidgets('shows the current value; a pick is saved', (tester) async {
      final saved = <String>[];
      await pump(tester, tile(onSave: (v) async => saved.add(v)));
      expect(find.text('Size M'), findsOneWidget);
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      expect(find.text('Size S'), findsOneWidget);
      await tester.tap(find.text('Size L'));
      await tester.pumpAndSettle();
      expect(saved, ['L']);
    });

    testWidgets('dismissing saves nothing', (tester) async {
      final saved = <String>[];
      await pump(tester, tile(onSave: (v) async => saved.add(v)));
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    });

    testWidgets('a failed save says so', (tester) async {
      await pump(tester, tile(onSave: (v) async => throw Exception('disk')));
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Size S'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
    });
  });

  group('confirmThenSave (6)', () {
    Future<bool?> run(
      WidgetTester tester, {
      required String answer,
      required Future<void> Function() action,
    }) async {
      bool? result;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmThenSave(
              context,
              title: 'Sure?',
              confirmLabel: 'Do it',
              action: action,
            ),
            child: const Text('Go'),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('cancel: nothing runs, false', (tester) async {
      var runs = 0;
      expect(
        await run(tester, answer: 'Cancel', action: () async => runs++),
        isFalse,
      );
      expect(runs, 0);
    });

    testWidgets('confirm: runs once, true', (tester) async {
      var runs = 0;
      expect(
        await run(tester, answer: 'Do it', action: () async => runs++),
        isTrue,
      );
      expect(runs, 1);
    });

    testWidgets('confirm and fail: false, "Couldn\'t save"', (tester) async {
      expect(
        await run(
          tester,
          answer: 'Do it',
          action: () async => throw Exception('disk'),
        ),
        isFalse,
      );
      expect(find.text("Couldn't save. Please try again."), findsOneWidget);
    });
  });

  group('DelayedSpinner (7)', () {
    testWidgets('nothing before the delay, a spinner after', (tester) async {
      await pump(
        tester,
        const DelayedSpinner(delay: Duration(milliseconds: 300), size: 16),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getSize(find.byType(DelayedSpinner)), const Size(16, 16));
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('gone before the delay: no timer left behind', (tester) async {
      await pump(tester, const DelayedSpinner(delay: Duration(seconds: 1)));
      await pump(tester, const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      // A pending timer or a setState after dispose fails the test.
    });
  });

  testWidgets('RetryRow and LoadFailedView: message, Try again (8)', (
    tester,
  ) async {
    var retries = 0;
    await pump(
      tester,
      Column(
        children: [
          RetryRow(message: 'Couldn’t load', onRetry: () => retries++),
          Expanded(child: LoadFailedView(onRetry: () => retries++)),
        ],
      ),
    );
    expect(find.text('Couldn’t load'), findsOneWidget);
    expect(find.text("Couldn't load this list."), findsOneWidget);
    final buttons = find.text('Try again');
    expect(buttons, findsNWidgets(2));
    await tester.tap(buttons.first);
    await tester.tap(buttons.last);
    expect(retries, 2);
  });

  group('ExpenseTile (10)', () {
    testWidgets('a long amount at 360 dp and font 2 leaves the title room '
        'and is never cut', (tester) async {
      useOppoSize(tester, textScale: 2);
      await pump(
        tester,
        ListView(
          children: [
            ExpenseTile(
              emoji: '🍽️',
              title: 'Lunch with the whole team',
              subtitle: '💵  1:05 PM',
              amount: const Money(99999999999, 'INR'),
              marks: const [Icon(Icons.edit_note, key: ValueKey('mark'))],
              onTap: () {},
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text('Lunch with the whole team')).width,
        greaterThan(40),
      );
      // en_US grouping in tests: 999,999,999.99.
      final amount = find.text('₹999,999,999.99');
      expect(amount, findsOneWidget, reason: 'every digit, not cut');
      expect(find.byKey(const ValueKey('mark')), findsOneWidget);
      expect(
        tester.getSize(find.byType(FittedBox)).width,
        lessThanOrEqualTo(360 * 0.45 + 0.01),
      );
    });

    testWidgets('a tap calls back', (tester) async {
      var taps = 0;
      await pump(
        tester,
        ExpenseTile(
          emoji: ExpenseTile.missingEmoji,
          title: 'T',
          subtitle: 's',
          amount: const Money(100, 'JPY'),
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.text('T'));
      expect(taps, 1);
      expect(find.text('❓'), findsOneWidget);
    });
  });

  group('AsyncBody (11)', () {
    Future<void> phase(WidgetTester tester, LoadPhase phase) => pump(
      tester,
      AsyncBody(
        phase: phase,
        onRetry: () {},
        empty: const Text('empty'),
        builder: (_) => const Text('content'),
      ),
    );

    testWidgets('each phase shows its own body', (tester) async {
      await phase(tester, LoadPhase.loading);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await phase(tester, LoadPhase.failed);
      expect(find.byType(LoadFailedView), findsOneWidget);
      await phase(tester, LoadPhase.empty);
      expect(find.text('empty'), findsOneWidget);
      expect(find.text('content'), findsNothing);
      await phase(tester, LoadPhase.loaded);
      expect(find.text('content'), findsOneWidget);
    });
  });
}
