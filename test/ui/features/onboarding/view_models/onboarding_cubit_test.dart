import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/payment_method_repository.dart';
import 'package:my_expense_tracker_app/domain/models/app_settings.dart';
import 'package:my_expense_tracker_app/domain/models/payment_method.dart';
import 'package:my_expense_tracker_app/ui/features/onboarding/view_models/onboarding_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/settings/view_models/settings_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/fake_sms_service.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDependencies deps;
  late SettingsCubit settings;

  setUp(() async {
    deps = await openTestDependencies(deviceCurrency: 'INR');
    settings = SettingsCubit(initial: AppSettings.beforeLoad);
    addTearDown(settings.close);
    await settings.load(deps.settings);
  });

  OnboardingCubit newOnboarding() {
    final cubit = OnboardingCubit(
      settings: settings,
      paymentMethods: deps.paymentMethods,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<int> methodId(String key) async => (await deps.paymentMethods.all())
      .firstWhere((m) => m.builtinKey == key)
      .id;

  group('initial choices', () {
    test(
      'on a fresh install: device language, device currency, cash',
      () async {
        final cubit = newOnboarding();
        expect(cubit.value.step, OnboardingStep.language);
        expect(cubit.value.locale, isNull);
        expect(cubit.value.currency, 'INR');
        expect(cubit.value.paymentMethodId, await methodId('cash'));
      },
    );

    test('payment methods load in seed order, Cash first', () async {
      final cubit = newOnboarding();
      expect(cubit.value.paymentMethods, isNull);
      await cubit.loadPaymentMethods();
      expect(cubit.value.paymentMethods!.map((m) => m.builtinKey), [
        'cash',
        'upi',
        'debit_card',
        'credit_card',
      ]);
    });

    test('a failed load is shown, and loading again retries', () async {
      final failing = _FailingOnce(deps.database, settings: deps.settings);
      final cubit = OnboardingCubit(
        settings: settings,
        paymentMethods: failing,
      );
      addTearDown(cubit.close);

      await cubit.loadPaymentMethods();
      expect(cubit.value.paymentMethodsFailed, isTrue);
      expect(cubit.value.paymentMethods, isNull);

      await cubit.loadPaymentMethods();
      expect(cubit.value.paymentMethodsFailed, isFalse);
      expect(cubit.value.paymentMethods, hasLength(4));
    });
  });

  group('steps', () {
    test('next and back move one step, and stop at both ends', () {
      final cubit = newOnboarding();
      cubit.back();
      expect(cubit.value.step, OnboardingStep.language);
      expect(cubit.value.isFirstStep, isTrue);

      cubit.next();
      expect(cubit.value.step, OnboardingStep.currency);
      cubit.next();
      expect(cubit.value.step, OnboardingStep.paymentMethod);
      expect(cubit.value.isLastStep, isTrue);
      cubit.next();
      expect(cubit.value.step, OnboardingStep.paymentMethod);

      cubit.back();
      expect(cubit.value.step, OnboardingStep.currency);
    });

    test('moving between steps keeps the choices', () async {
      final cubit = newOnboarding();
      await cubit.selectLanguage(hi);
      cubit.next();
      await cubit.selectCurrency('USD');
      cubit.back();
      expect(cubit.value.locale, hi);
      expect(cubit.value.currency, 'USD');
    });
  });

  group('each choice is saved at once', () {
    test('language applies to the app immediately', () async {
      final cubit = newOnboarding();
      await cubit.selectLanguage(hi);
      expect(
        settings.value.locale,
        hi,
        reason: 'MaterialApp follows SettingsCubit',
      );
      expect((await deps.settings.load()).locale, hi);
    });

    test(
      'choosing "system default" after a language goes back to null',
      () async {
        final cubit = newOnboarding();
        await cubit.selectLanguage(es);
        await cubit.selectLanguage(null);
        expect(cubit.value.locale, isNull);
        expect((await deps.settings.load()).locale, isNull);
      },
    );

    test('currency and payment method', () async {
      final cubit = newOnboarding();
      final upi = await methodId('upi');
      await cubit.selectCurrency('EUR');
      await cubit.selectPaymentMethod(upi);
      final stored = await deps.settings.load();
      expect(stored.defaultCurrency, 'EUR');
      expect(stored.defaultPaymentMethodId, upi);
      expect(stored.onboardingCompleted, isFalse, reason: 'not finished yet');
    });

    test('a failed save keeps the previous choice and rethrows', () async {
      final cubit = newOnboarding();
      await deps.database.execute('DROP TABLE settings');
      await expectLater(
        cubit.selectCurrency('EUR'),
        throwsA(isA<DatabaseException>()),
      );
      expect(cubit.value.currency, 'INR');
      expect(cubit.value.busy, isFalse, reason: 'the user can try again');
    });
  });

  group('resume after the app was killed', () {
    test('restarts at step 1 with the saved choices preselected', () async {
      final first = newOnboarding();
      final debit = await methodId('debit_card');
      await first.selectLanguage(es);
      first.next();
      await first.selectCurrency('USD');
      first.next();
      await first.selectPaymentMethod(debit);
      await first.close();

      // A new app start: settings loaded again from the database.
      settings = SettingsCubit(initial: AppSettings.beforeLoad);
      addTearDown(settings.close);
      await settings.load(deps.settings);
      final resumed = newOnboarding();

      expect(resumed.value.step, OnboardingStep.language);
      expect(resumed.value.locale, es);
      expect(resumed.value.currency, 'USD');
      expect(resumed.value.paymentMethodId, debit);
      expect(settings.value.onboardingCompleted, isFalse);
    });
  });

  group('finish', () {
    test(
      'writes the untouched preselected choices, then completes onboarding',
      () async {
        final cubit = newOnboarding();
        await cubit.finish();

        final stored = await deps.database.query('settings');
        final values = {for (final row in stored) row['key']: row['value']};
        expect(
          values['default_currency'],
          'INR',
          reason: 'device currency, now saved',
        );
        expect(
          values['default_payment_method_id'],
          '${await methodId('cash')}',
        );
        expect(values['onboarding_completed'], '1');
        expect(settings.value.onboardingCompleted, isTrue);
      },
    );

    test(
      'a later device-language change no longer changes the saved currency',
      () async {
        await newOnboarding().finish();
        // Same database, but the phone now says JPY.
        final settingsOnNewPhone = AppDependencies.forDatabase(
          deps.database,
          deviceCurrency: 'JPY',
        ).settings;
        expect((await settingsOnNewPhone.load()).defaultCurrency, 'INR');
      },
    );

    test('if a write fails, onboarding is not marked complete', () async {
      final cubit = newOnboarding();
      await deps.database.execute('DROP TABLE settings');
      await expectLater(cubit.finish(), throwsA(isA<DatabaseException>()));
      expect(settings.value.onboardingCompleted, isFalse);
      expect(cubit.value.busy, isFalse);
    });

    test('a second tap while finishing is ignored', () async {
      final cubit = newOnboarding();
      final first = cubit.finish();
      await cubit.finish();
      await first;
      expect(settings.value.onboardingCompleted, isTrue);
    });

    test('finishing closes the screen mid-way without errors', () async {
      final cubit = newOnboarding();
      final finishing = cubit.finish();
      await cubit.close(); // The gate swaps onboarding for the shell.
      await finishing;
      expect(settings.value.onboardingCompleted, isTrue);
    });
  });

  test('choices made while a save is running are ignored, so they cannot land out of order', () async {
    final cubit = newOnboarding();
    final first = cubit.selectCurrency('EUR');
    final second = cubit.selectCurrency('USD');
    await Future.wait([first, second]);
    expect(
      cubit.value.currency,
      settings.value.defaultCurrency,
      reason: 'screen and settings agree',
    );
    expect((await deps.settings.load()).defaultCurrency, cubit.value.currency);
  });

  group('the SMS step', () {
    OnboardingCubit withSms(FakeSmsService sms) {
      final cubit = OnboardingCubit(
        settings: settings,
        paymentMethods: deps.paymentMethods,
        sms: sms,
        setSmsEnabled: deps.settings.setSmsEnabled,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('only when built: four steps, Not now by default', () async {
      final built = withSms(FakeSmsService(granted: false))
        ..next()
        ..next();
      await built.loadSms();
      expect(built.value.isLastStep, isFalse);
      built.next();
      expect(built.value.step, OnboardingStep.sms);
      expect(built.value.isLastStep, isTrue);
      expect(built.value.smsOn, isFalse);
      built.back();
      expect(built.value.step, OnboardingStep.paymentMethod);

      final notBuilt = withSms(FakeSmsService(built: false))
        ..next()
        ..next();
      await notBuilt.loadSms();
      expect(notBuilt.value.isLastStep, isTrue);
      expect(notBuilt.value.steps, hasLength(3));
      expect(newOnboarding().value.steps, hasLength(3));
    });

    test('Yes → the permission; granted → on; refused → off and the '
        'message; Get started works either way', () async {
      final sms = FakeSmsService(granted: false);
      final cubit = withSms(sms);
      await cubit.loadSms();
      sms.grantOnRequest = false;
      await cubit.chooseSms(true);
      expect(cubit.value.smsOn, isFalse);
      expect(cubit.value.smsRefused, isTrue);
      expect(await deps.settings.smsEnabled(), isFalse);
      sms.grantOnRequest = true;
      await cubit.chooseSms(true);
      expect(cubit.value.smsOn, isTrue);
      expect(cubit.value.smsRefused, isFalse);
      expect(await deps.settings.smsEnabled(), isTrue);
      await cubit.chooseSms(false);
      expect(await deps.settings.smsEnabled(), isFalse);
      await cubit.finish();
      expect(settings.value.onboardingCompleted, isTrue);
    });
  });
}

/// Throws on the first [all] call, then works.
class _FailingOnce extends PaymentMethodRepository {
  _FailingOnce(super.db, {required super.settings});

  var _failed = false;

  @override
  Future<List<PaymentMethod>> all() async {
    if (_failed) return super.all();
    _failed = true;
    throw StateError('database is locked');
  }
}
