import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/domain/models/app_settings.dart';
import 'package:my_expense_tracker_app/domain/models/app_theme_mode.dart';
import 'package:my_expense_tracker_app/ui/features/settings/view_models/settings_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late Database db;
  late SettingsRepository repository;

  setUp(() async {
    db = await openMigratedDatabase();
    repository = SettingsRepository(db, deviceCurrency: 'INR');
  });

  SettingsCubit newCubit() {
    final cubit = SettingsCubit(initial: AppSettings.beforeLoad);
    addTearDown(cubit.close);
    return cubit;
  }

  Future<SettingsCubit> loadedCubit() async {
    final cubit = newCubit();
    await cubit.load(repository);
    return cubit;
  }

  group('load', () {
    test(
      'starts with the before-load settings: device language, system theme',
      () {
        final cubit = newCubit();
        expect(cubit.value.locale, isNull);
        expect(cubit.value.theme, AppThemeMode.system);
        expect(cubit.value.onboardingCompleted, isFalse);
      },
    );

    test('replaces them with the stored settings', () async {
      await repository.setTheme(AppThemeMode.dark);
      await repository.setOnboardingCompleted();
      final cubit = await loadedCubit();
      expect(cubit.value.theme, AppThemeMode.dark);
      expect(cubit.value.onboardingCompleted, isTrue);
      expect(cubit.value.defaultCurrency, 'INR');
    });

    test(
      'a failing load leaves the before-load settings and rethrows',
      () async {
        final cubit = newCubit();
        final broken = SettingsRepository(
          await openEmptyDatabase(),
          deviceCurrency: 'INR',
        );
        await expectLater(
          cubit.load(broken),
          throwsA(isA<DatabaseException>()),
        );
        expect(cubit.value, AppSettings.beforeLoad);
      },
    );

    test('changing a setting before load is a programming error, not a silent no-op', () async {
      expect(newCubit().setTheme(AppThemeMode.dark), throwsStateError);
    });
  });

  group('each setter writes, then emits', () {
    test('setLocale', () async {
      final cubit = await loadedCubit();
      await cubit.setLocale(const Locale('hi'));
      expect(cubit.value.locale, const Locale('hi'));
      expect((await repository.load()).locale, const Locale('hi'));

      await cubit.setLocale(null);
      expect(cubit.value.locale, isNull);
      expect((await repository.load()).locale, isNull);
    });

    test('setTheme', () async {
      final cubit = await loadedCubit();
      await cubit.setTheme(AppThemeMode.light);
      expect(cubit.value.theme, AppThemeMode.light);
      expect((await repository.load()).theme, AppThemeMode.light);
    });

    test('setDefaultCurrency', () async {
      final cubit = await loadedCubit();
      await cubit.setDefaultCurrency('USD');
      expect(cubit.value.defaultCurrency, 'USD');
      expect((await repository.load()).defaultCurrency, 'USD');
    });

    test('setDefaultPaymentMethodId', () async {
      final cubit = await loadedCubit();
      final upi =
          (await db.query(
                'payment_methods',
                where: "builtin_key = 'upi'",
              )).single['id']!
              as int;
      await cubit.setDefaultPaymentMethodId(upi);
      expect(cubit.value.defaultPaymentMethodId, upi);
      expect((await repository.load()).defaultPaymentMethodId, upi);
    });

    test('setOnboardingCompleted', () async {
      final cubit = await loadedCubit();
      await cubit.setOnboardingCompleted();
      expect(cubit.value.onboardingCompleted, isTrue);
      expect((await repository.load()).onboardingCompleted, isTrue);
    });

    test('the new state is not emitted before the write finished', () async {
      final cubit = await loadedCubit();
      final writing = cubit.setTheme(AppThemeMode.dark);
      expect(cubit.value.theme, AppThemeMode.system, reason: 'still writing');
      await writing;
      expect(cubit.value.theme, AppThemeMode.dark);
    });

    test('a setter keeps the other settings', () async {
      final cubit = await loadedCubit();
      await cubit.setLocale(const Locale('es'));
      await cubit.setTheme(AppThemeMode.dark);
      await cubit.setDefaultCurrency('EUR');
      expect(
        cubit.value.locale,
        const Locale('es'),
        reason: 'copyWith must keep the locale',
      );
      expect(cubit.value.theme, AppThemeMode.dark);
    });

    test('setters started together all end up applied', () async {
      final cubit = await loadedCubit();
      await Future.wait([
        cubit.setTheme(AppThemeMode.dark),
        cubit.setDefaultCurrency('EUR'),
        cubit.setLocale(const Locale('hi')),
      ]);
      expect(cubit.value.theme, AppThemeMode.dark);
      expect(cubit.value.defaultCurrency, 'EUR');
      expect(cubit.value.locale, const Locale('hi'));
      expect(
        await repository.load(),
        cubit.value.copyWith(),
        reason: 'memory and database agree',
      );
    });
  });

  group('a failing write', () {
    test('keeps the old state and reaches the caller', () async {
      final cubit = await loadedCubit();
      final before = cubit.value;
      // Make every settings write fail.
      await db.execute('DROP TABLE settings');

      await expectLater(
        cubit.setTheme(AppThemeMode.dark),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        cubit.setLocale(const Locale('hi')),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        cubit.setOnboardingCompleted(),
        throwsA(isA<DatabaseException>()),
      );
      expect(cubit.value, before);
    });
  });

  test('a write finishing after close does not throw', () async {
    final cubit = await loadedCubit();
    final writing = cubit.setTheme(AppThemeMode.dark);
    await cubit.close();
    await writing;
  });
}
