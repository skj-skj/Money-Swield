import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/domain/models/app_settings.dart';
import 'package:my_expense_tracker_app/domain/models/app_theme_mode.dart';
import 'package:my_expense_tracker_app/domain/models/dashboard_options.dart';
import 'package:my_expense_tracker_app/domain/models/item_shape.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
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

  group('picker look and picker modes (phase-2.md §12a)', () {
    test(
      'default to rounded tiles, circle buttons, dial and calendar',
      () async {
        final settings = await repository.load();
        expect(settings.tileShape, ItemShape.rounded);
        expect(settings.buttonShape, ItemShape.circle);
        expect(settings.timePickerKeyboard, isFalse);
        expect(settings.datePickerKeyboard, isFalse);
      },
    );

    test('the theme color follows the wallpaper until one is picked', () async {
      expect((await repository.load()).themeSeed, isNull);

      await repository.setThemeSeed(0xFF1565C0);
      expect((await repository.load()).themeSeed, 0xFF1565C0);

      await repository.setThemeSeed(null);
      expect((await repository.load()).themeSeed, isNull);
      final row = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['theme_color'],
      );
      expect(row.single['value'], 'dynamic');
    });

    test('an unreadable theme color falls back to the wallpaper', () async {
      await db.insert('settings', {'key': 'theme_color', 'value': 'blue'});
      expect((await repository.load()).themeSeed, isNull);
    });

    test('restoreDefaultLook resets the look and nothing else', () async {
      await repository.setThemeSeed(0xFF1565C0);
      await repository.setTileShape(ItemShape.circle);
      await repository.setButtonShape(ItemShape.square);
      await repository.setDefaultCurrency('USD');
      await repository.setTimePickerKeyboard(true);

      await repository.restoreDefaultLook();
      final settings = await repository.load();
      expect(settings.themeSeed, isNull);
      expect(settings.tileShape, ItemShape.rounded);
      expect(settings.buttonShape, ItemShape.circle);
      expect(settings.defaultCurrency, 'USD', reason: 'not part of the look');
      expect(settings.timePickerKeyboard, isTrue);
    });

    test('round-trip', () async {
      await repository.setTileShape(ItemShape.circle);
      await repository.setButtonShape(ItemShape.square);
      await repository.setTimePickerKeyboard(true);
      await repository.setDatePickerKeyboard(true);
      final settings = await repository.load();
      expect(settings.tileShape, ItemShape.circle);
      expect(settings.buttonShape, ItemShape.square);
      expect(settings.timePickerKeyboard, isTrue);
      expect(settings.datePickerKeyboard, isTrue);

      await repository.setTimePickerKeyboard(false);
      expect((await repository.load()).timePickerKeyboard, isFalse);
    });

    test('an unknown shape (a newer app\'s) falls back to rounded', () async {
      await db.insert('settings', {'key': 'tile_shape', 'value': 'hexagon'});
      expect((await repository.load()).tileShape, ItemShape.rounded);
    });
  });

  group('Home settings (phase-5.md §4.2)', () {
    test('defaults: Monday, month names, card Month, list Week, filled '
        'line, locked', () async {
      final settings = await repository.load();
      expect(settings.weekStart, WeekStart.monday);
      expect(settings.weekLabel, WeekLabel.month);
      expect(settings.cardPeriod, Period.month);
      expect(settings.listGrouping, Period.week);
      expect(settings.trendChartStyle, TrendChartStyle.lineFilled);
      expect(settings.trendCardPosition, TrendCardPosition.locked);
      expect(settings.trendCardSize, TrendCardSize.medium);
      expect(settings.trendCardHaptics, CardHaptics.light);
    });

    test('restoreHomeDefaults resets the six Home settings and nothing '
        'else', () async {
      await repository.setTrendChartStyle(TrendChartStyle.bar);
      await repository.setTrendCardPosition(TrendCardPosition.scrolls);
      await repository.setTrendCardSize(TrendCardSize.small);
      await repository.setTrendCardHaptics(CardHaptics.off);
      await repository.setWeekStart(WeekStart.sunday);
      await repository.setWeekLabel(WeekLabel.number);
      await repository.setCardPeriod(Period.year);
      await repository.setListGrouping(Period.day);
      await repository.setDefaultCurrency('USD');
      await repository.setTileShape(ItemShape.square);

      await repository.restoreHomeDefaults();
      final settings = await repository.load();
      expect(settings.trendChartStyle, TrendChartStyle.lineFilled);
      expect(settings.trendCardPosition, TrendCardPosition.locked);
      expect(settings.trendCardSize, TrendCardSize.medium);
      expect(settings.trendCardHaptics, CardHaptics.light);
      expect(settings.weekStart, WeekStart.monday);
      expect(settings.weekLabel, WeekLabel.month);
      expect(settings.cardPeriod, Period.year, reason: 'set on Home itself');
      expect(settings.listGrouping, Period.day, reason: 'set on Home itself');
      expect(settings.defaultCurrency, 'USD');
      expect(settings.tileShape, ItemShape.square);
    });

    test(
      'card size, vibration and the two later chart styles round-trip',
      () async {
        for (final size in TrendCardSize.values) {
          await repository.setTrendCardSize(size);
          expect((await repository.load()).trendCardSize, size);
        }
        for (final haptics in CardHaptics.values) {
          await repository.setTrendCardHaptics(haptics);
          expect((await repository.load()).trendCardHaptics, haptics);
        }
        expect(
          (await db.query(
            'settings',
            where: 'key = ?',
            whereArgs: ['trend_card_haptics'],
          )).single['value'],
          'strong',
        );
        for (final style in TrendChartStyle.values) {
          await repository.setTrendChartStyle(style);
          expect((await repository.load()).trendChartStyle, style);
        }
        final stored = await db.query(
          'settings',
          where: 'key = ?',
          whereArgs: ['trend_chart_style'],
        );
        expect(stored.single['value'], 'running_total');
        await db.update(
          'settings',
          {'value': 'huge'},
          where: 'key = ?',
          whereArgs: ['trend_card_size'],
        );
        expect((await repository.load()).trendCardSize, TrendCardSize.medium);
      },
    );

    test('round trip of each, with the stored values of database.md', () async {
      await repository.setWeekStart(WeekStart.sunday);
      await repository.setWeekLabel(WeekLabel.number);
      await repository.setCardPeriod(Period.year);
      await repository.setListGrouping(Period.day);
      await repository.setTrendChartStyle(TrendChartStyle.bar);
      await repository.setTrendCardPosition(TrendCardPosition.scrolls);
      final settings = await repository.load();
      expect(settings.weekStart, WeekStart.sunday);
      expect(settings.weekLabel, WeekLabel.number);
      expect(settings.cardPeriod, Period.year);
      expect(settings.listGrouping, Period.day);
      expect(settings.trendChartStyle, TrendChartStyle.bar);
      expect(settings.trendCardPosition, TrendCardPosition.scrolls);

      await repository.setTrendChartStyle(TrendChartStyle.lineFilled);
      final rows = {
        for (final row in await db.query('settings'))
          row['key']! as String: row['value'],
      };
      expect(rows, containsPair('week_start', 'sunday'));
      expect(rows, containsPair('week_label', 'number'));
      expect(rows, containsPair('dashboard_period', 'year'));
      expect(rows, containsPair('list_grouping', 'day'));
      expect(rows, containsPair('trend_chart_style', 'line_filled'));
      expect(rows, containsPair('trend_card_position', 'scrolls'));
    });

    test('an unknown value (a newer app\'s) reads as the default', () async {
      for (final key in [
        'week_start',
        'week_label',
        'dashboard_period',
        'list_grouping',
        'trend_chart_style',
        'trend_card_position',
      ]) {
        await store(key, 'saturday');
      }
      // The card has no Day face.
      await db.update(
        'settings',
        {'value': 'day'},
        where: 'key = ?',
        whereArgs: ['dashboard_period'],
      );
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

    test('every enum setting: junk, wrong case or empty reads as the '
        'default, never as another value', () async {
      const keys = [
        'theme',
        'tile_shape',
        'button_shape',
        'week_start',
        'week_label',
        'dashboard_period',
        'list_grouping',
        'trend_chart_style',
        'trend_card_position',
        'trend_card_size',
        'trend_card_haptics',
      ];
      final defaults = await repository.load();
      for (final stored in ['junk', 'Monday', 'WEEK', 'Large', '', ' ']) {
        await db.delete('settings');
        for (final key in keys) {
          await store(key, stored);
        }
        expect(await repository.load(), defaults, reason: '"$stored"');
      }
    });

    test('the picker keyboards are on only for "1", and are written as '
        '"1" / "0"', () async {
      for (final stored in ['0', 'true', 'yes', '', null]) {
        await db.delete('settings');
        await store('time_picker_keyboard', stored);
        await store('date_picker_keyboard', stored);
        final settings = await repository.load();
        expect(settings.timePickerKeyboard, isFalse, reason: '$stored');
        expect(settings.datePickerKeyboard, isFalse, reason: '$stored');
      }
      Future<String?> raw(String key) async =>
          (await db.query(
                'settings',
                where: 'key = ?',
                whereArgs: [key],
              )).single['value']
              as String?;
      await repository.setTimePickerKeyboard(true);
      await repository.setDatePickerKeyboard(false);
      expect(await raw('time_picker_keyboard'), '1');
      expect(await raw('date_picker_keyboard'), '0');
      final settings = await repository.load();
      expect(settings.timePickerKeyboard, isTrue);
      expect(settings.datePickerKeyboard, isFalse);
    });

    test(
      'restoreDefaultLook leaves every Home setting alone (P5-33)',
      () async {
        await repository.setTrendCardSize(TrendCardSize.small);
        await repository.setTrendCardHaptics(CardHaptics.strong);
        await repository.setWeekStart(WeekStart.sunday);
        await repository.setWeekLabel(WeekLabel.number);
        await repository.setCardPeriod(Period.year);
        await repository.setListGrouping(Period.day);
        await repository.setTrendChartStyle(TrendChartStyle.bar);
        await repository.setTrendCardPosition(TrendCardPosition.scrolls);
        final before = await repository.load();
        await repository.restoreDefaultLook();
        expect(await repository.load(), before);
      },
    );
  });

  group('last backup', () {
    test('is null (never) until one is recorded', () async {
      expect(await repository.lastBackupAt(), isNull);
    });

    test('round trips as the same UTC moment, to the millisecond', () async {
      final at = DateTime.utc(2026, 10, 3, 8, 35, 12, 345);
      await repository.setLastBackupAt(at.toLocal());
      final read = await repository.lastBackupAt();
      expect(read, at);
      expect(read!.isUtc, isTrue);
      expect(
        (await db.query(
          'settings',
          where: "key = 'last_backup_at'",
        )).single['value'],
        '${at.millisecondsSinceEpoch}',
        reason: 'stored as epoch ms like every time in the database',
      );
    });

    test('an unreadable value reads as never', () async {
      await store('last_backup_at', 'yesterday');
      expect(await repository.lastBackupAt(), isNull);
    });

    test(
      'is not part of AppSettings: recording one leaves load() equal',
      () async {
        final before = await repository.load();
        await repository.setLastBackupAt(DateTime.utc(2026));
        expect(await repository.load(), before);
      },
    );
  });
}
