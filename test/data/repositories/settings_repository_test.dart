import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/domain/models/app_settings.dart';
import 'package:my_expense_tracker_app/domain/models/app_theme_mode.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;
  late SettingsRepository repository;

  setUp(() async {
    db = await openMigratedDatabase();
    repository = SettingsRepository(db, deviceCurrency: 'INR');
  });

  Future<int> paymentMethodId(String builtinKey) async =>
      (await db.query(
            'payment_methods',
            where: 'builtin_key = ?',
            whereArgs: [builtinKey],
          )).single['id']!
          as int;

  Future<void> store(String key, String? value) =>
      db.insert('settings', {'key': key, 'value': value});

  group('defaults when nothing is stored', () {
    test('every setting has its default', () async {
      expect(
        await repository.load(),
        AppSettings(
          onboardingCompleted: false,
          locale: null,
          theme: AppThemeMode.system,
          defaultCurrency: 'INR',
          defaultPaymentMethodId: await paymentMethodId('cash'),
        ),
      );
    });

    test('the default currency is the device currency passed in', () async {
      final repository = SettingsRepository(db, deviceCurrency: 'JPY');
      expect((await repository.load()).defaultCurrency, 'JPY');
    });

    test('load does not write anything', () async {
      await repository.load();
      expect(await db.query('settings'), isEmpty);
    });
  });

  group('round trip', () {
    test('onboarding completed', () async {
      await repository.setOnboardingCompleted();
      expect((await repository.load()).onboardingCompleted, isTrue);
    });

    for (final code in supportedLanguageCodes) {
      test('locale $code', () async {
        await repository.setLocale(Locale(code));
        expect((await repository.load()).locale, Locale(code));
      });
    }

    test('locale back to null follows the device again', () async {
      await repository.setLocale(const Locale('hi'));
      await repository.setLocale(null);
      expect((await repository.load()).locale, isNull);
    });

    test('a locale with a country is stored by its language only', () async {
      await repository.setLocale(const Locale('hi', 'IN'));
      expect((await repository.load()).locale, const Locale('hi'));
    });

    for (final theme in AppThemeMode.values) {
      test('theme ${theme.name}', () async {
        await repository.setTheme(theme);
        expect((await repository.load()).theme, theme);
      });
    }

    test('default currency', () async {
      await repository.setDefaultCurrency('EUR');
      expect((await repository.load()).defaultCurrency, 'EUR');
    });

    test('default payment method', () async {
      final upi = await paymentMethodId('upi');
      await repository.setDefaultPaymentMethodId(upi);
      expect((await repository.load()).defaultPaymentMethodId, upi);
    });

    test('writing a key twice keeps one row with the last value', () async {
      await repository.setTheme(AppThemeMode.dark);
      await repository.setTheme(AppThemeMode.light);
      final rows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['theme'],
      );
      expect(rows.single['value'], 'light');
    });

    test('setters only touch their own key', () async {
      await repository.setTheme(AppThemeMode.dark);
      await repository.setDefaultCurrency('EUR');
      await repository.setLocale(const Locale('es'));
      final settings = await repository.load();
      expect(settings.theme, AppThemeMode.dark);
      expect(settings.defaultCurrency, 'EUR');
      expect(settings.locale, const Locale('es'));
      expect(settings.onboardingCompleted, isFalse);
    });
  });

  group('unexpected stored values fall back to the default', () {
    test(
      'an unknown theme (e.g. a newer app\'s, after a downgrade) is system',
      () async {
        await store('theme', 'liquid_glass');
        expect((await repository.load()).theme, AppThemeMode.system);
      },
    );

    test('a NULL theme is system', () async {
      await store('theme', null);
      expect((await repository.load()).theme, AppThemeMode.system);
    });

    test('an unsupported language follows the device', () async {
      await store('locale', 'fr');
      expect((await repository.load()).locale, isNull);
    });

    test('an empty currency uses the device currency', () async {
      await store('default_currency', '');
      expect((await repository.load()).defaultCurrency, 'INR');
    });

    test('onboarding is only completed by "1"', () async {
      for (final value in ['0', 'true', '', null]) {
        await db.delete('settings');
        await store('onboarding_completed', value);
        expect(
          (await repository.load()).onboardingCompleted,
          isFalse,
          reason: '$value',
        );
      }
    });

    test('a non-numeric payment method id falls back to cash', () async {
      await store('default_payment_method_id', 'abc');
      expect(
        (await repository.load()).defaultPaymentMethodId,
        await paymentMethodId('cash'),
      );
    });
  });

  group('default payment method fallback', () {
    test('a stored id whose row is gone falls back to cash', () async {
      final upi = await paymentMethodId('upi');
      await repository.setDefaultPaymentMethodId(upi);
      await db.delete('payment_methods', where: 'id = ?', whereArgs: [upi]);
      expect(
        (await repository.load()).defaultPaymentMethodId,
        await paymentMethodId('cash'),
      );
    });

    test('with cash deleted, the first payment method by id', () async {
      await db.delete(
        'payment_methods',
        where: 'builtin_key = ?',
        whereArgs: ['cash'],
      );
      expect(
        (await repository.load()).defaultPaymentMethodId,
        await paymentMethodId('upi'),
      );
    });

    test(
      'a renamed cash row is still the fallback (found by key, not name)',
      () async {
        await db.update(
          'payment_methods',
          {'name': 'Nakad'},
          where: 'builtin_key = ?',
          whereArgs: ['cash'],
        );
        expect(
          (await repository.load()).defaultPaymentMethodId,
          await paymentMethodId('cash'),
        );
      },
    );

    test('with no payment methods at all, null', () async {
      await db.delete('payment_methods');
      expect((await repository.load()).defaultPaymentMethodId, isNull);
    });
  });

  test('load fails loudly when the settings table is missing', () async {
    final empty = await openEmptyDatabase();
    expect(
      SettingsRepository(empty, deviceCurrency: 'INR').load(),
      throwsA(isA<DatabaseException>()),
    );
  });
}
