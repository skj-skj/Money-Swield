import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/payment_method_repository.dart';
import 'package:my_expense_tracker_app/domain/models/app_settings.dart';
import 'package:my_expense_tracker_app/domain/models/category.dart';
import 'package:my_expense_tracker_app/domain/models/payment_method.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/async_body.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/emoji_picker_field.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/empty_state_view.dart';
import 'package:my_expense_tracker_app/ui/features/categories/views/category_form_screen.dart';
import 'package:my_expense_tracker_app/ui/features/manage/views/manage_list_scaffold.dart';
import 'package:my_expense_tracker_app/ui/features/payment_methods/view_models/payment_method_form_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/payment_methods/views/payment_method_form_screen.dart';
import 'package:my_expense_tracker_app/ui/features/settings/view_models/settings_cubit.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

/// Holds every `add` until the test completes its gate.
class _SlowMethods extends PaymentMethodRepository {
  _SlowMethods(super.db, {required super.settings, required super.dataVersion});

  final gate = Completer<void>();

  @override
  Future<PaymentMethod> add({
    required String name,
    required String emoji,
  }) async {
    await gate.future;
    return super.add(name: name, emoji: emoji);
  }
}

/// The shared Manage pieces (steps 12–13 of the components list): the
/// list scaffold and the form base and scaffold.
void main() {
  late AppDependencies deps;
  late SettingsCubit settings;

  setUp(() async {
    deps = await openTestDependencies();
    settings = SettingsCubit(initial: AppSettings.beforeLoad);
    addTearDown(settings.close);
    await settings.load(deps.settings);
  });

  /// [screen] pushed over a page that records what it popped with.
  Future<List<Object?>> pushed(WidgetTester tester, Widget screen) async {
    final popped = <Object?>[];
    await tester.pumpWidget(
      BlocSignalProvider<SettingsCubit>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => popped.add(
                await Navigator.push<Object?>(
                  context,
                  MaterialPageRoute(builder: (_) => screen),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return popped;
  }

  Future<void> pickEmoji(WidgetTester tester, String emoji) async {
    await tester.tap(find.byType(EmojiPickerField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(emoji).last);
    await tester.pumpAndSettle();
  }

  group('form scaffold: what a save pops with', () {
    testWidgets('a new category pops with itself (the Add form selects it)', (
      tester,
    ) async {
      final popped = await pushed(
        tester,
        CategoryFormScreen(
          repository: deps.categories,
          original: null,
          existing: await deps.categories.all(),
          initialName: 'Snacks',
        ),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('name')))
            .controller!
            .text,
        'Snacks',
        reason: 'the picker search text prefills the name',
      );
      await pickEmoji(tester, '🐶');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(popped.single, isA<Category>());
      expect((popped.single! as Category).name, 'Snacks');
    });

    testWidgets('a payment method pops with nothing', (tester) async {
      final popped = await pushed(
        tester,
        PaymentMethodFormScreen(
          repository: deps.paymentMethods,
          original: null,
          existing: await deps.paymentMethods.all(),
        ),
      );
      expect(find.byKey(const ValueKey('description')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('name')), 'Wallet');
      await pickEmoji(tester, '🐶');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(popped, [null]);
      expect(
        (await deps.paymentMethods.all()).map((m) => m.name),
        contains('Wallet'),
      );
    });
  });

  group('form base: payment methods', () {
    PaymentMethodFormCubit formFor(
      PaymentMethodRepository repository, {
      PaymentMethod? original,
    }) {
      final cubit = PaymentMethodFormCubit(
        repository: repository,
        settings: settings,
        l10n: l10nFor('en'),
        original: original,
        existing: const [],
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test(
      'have no description: a long one neither blocks nor is saved',
      () async {
        final cubit = formFor(deps.paymentMethods)
          ..nameChanged('Wallet')
          ..emojiChanged('👛')
          ..descriptionChanged('x' * 500);
        final saved = await cubit.save();
        expect(saved, isNotNull);
        expect(cubit.descriptionError, isNull);
        expect(cubit.hasDescription, isFalse);
      },
    );

    test('set as default, delete and move do nothing on a new form', () async {
      final cubit = formFor(deps.paymentMethods);
      await cubit.setAsDefault();
      await cubit.delete();
      await cubit.moveExpensesAndDelete(1);
      expect(cubit.value.saving, isFalse);
      expect(await deps.paymentMethods.all(), hasLength(4));
    });

    test('while a save runs, a second save and the other actions are '
        'ignored', () async {
      final slow = _SlowMethods(
        deps.database,
        settings: deps.settings,
        dataVersion: deps.dataVersion,
      );
      final cubit = formFor(slow)
        ..nameChanged('Wallet')
        ..emojiChanged('👛');
      final save = cubit.save();
      expect(cubit.value.saving, isTrue);
      expect(await cubit.save(), isNull, reason: 'a second save is ignored');
      slow.gate.complete();
      expect(await save, isNotNull);
      expect(cubit.value.saving, isFalse);
      expect(
        (await deps.paymentMethods.all()).where((m) => m.name == 'Wallet'),
        hasLength(1),
        reason: 'saved once',
      );
    });

    test(
      'set as default on an edited method, through the busy guard',
      () async {
        final upi = (await deps.paymentMethods.all()).firstWhere(
          (m) => m.builtinKey == 'upi',
        );
        final cubit = formFor(deps.paymentMethods, original: upi);
        final setting = cubit.setAsDefault();
        expect(cubit.value.saving, isTrue);
        await cubit.delete(); // ignored while busy
        await setting;
        expect(cubit.value.saving, isFalse);
        expect(settings.value.defaultPaymentMethodId, upi.id);
        expect(
          await deps.paymentMethods.all(),
          hasLength(4),
          reason: 'not deleted',
        );
      },
    );
  });

  group('list scaffold', () {
    Future<void> scaffold(WidgetTester tester, LoadPhase phase) =>
        tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ManageListScaffold(
              title: 'Things',
              addLabel: 'Add thing',
              phase: phase,
              onRetry: () {},
              onAdd: () {},
              emptyIcon: Icons.category_outlined,
              emptyText: 'Nothing here yet',
              builder: (_) => ItemCardGrid(
                items: [
                  (
                    key: 1,
                    emoji: '🍔',
                    title: 'Food',
                    description: 'Meals',
                    badge: 'Default',
                    onTap: () {},
                  ),
                ],
                trailing: const Text('trailing'),
              ),
            ),
          ),
        );

    testWidgets('loading: no Add button yet; loaded and empty: the button', (
      tester,
    ) async {
      await scaffold(tester, LoadPhase.loading);
      expect(find.byType(FloatingActionButton), findsNothing);
      await scaffold(tester, LoadPhase.failed);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      await scaffold(tester, LoadPhase.empty);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      await scaffold(tester, LoadPhase.loaded);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Meals'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('trailing'), findsOneWidget);
    });
  });

  testWidgets('events: archived ones in a collapsed part that opens', (
    tester,
  ) async {
    await deps.settings.setOnboardingCompleted();
    final trip = (await deps.events.all()).firstWhere(
      (e) => e.builtinKey == 'trip',
    );
    await deps.events.setArchived(trip.id, true);
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('Trip'), findsNothing, reason: 'collapsed');
    await tester.tap(find.text('Archived (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Trip'), findsOneWidget);
  });
}
