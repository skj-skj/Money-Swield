import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/ui/core/formatting_locale.dart';
import 'package:my_expense_tracker_app/ui/core/money_formatter.dart';

/// phase-2.md §4.4 and the "Formatting" tests of §13; phase-5.md §5.7
/// (R2, R3).
void main() {
  String format(Money money, {required String locale}) =>
      MoneyFormatter.forLocale(locale).format(money);

  const nbsp = ' ';

  group('formattingLocaleName', () {
    String localeFor(String app, String device) {
      final [language, country] = device.split('_');
      return formattingLocaleName(
        appLocale: Locale(app),
        deviceLocale: Locale(language, country),
      );
    }

    test('uses the device country with the app language when intl has it', () {
      expect(localeFor('en', 'en_IN'), 'en_IN');
      expect(localeFor('en', 'hi_IN'), 'en_IN');
      expect(localeFor('en', 'en_US'), 'en_US');
      expect(localeFor('es', 'es_MX'), 'es_MX');
    });

    test('falls back to the app language alone', () {
      expect(localeFor('hi', 'hi_IN'), 'hi', reason: 'intl has no hi_IN');
      expect(localeFor('es', 'en_IN'), 'es', reason: 'intl has no es_IN');
      expect(
        formattingLocaleName(
          appLocale: const Locale('en'),
          deviceLocale: const Locale('en'),
        ),
        'en',
      );
    });
  });

  group('format', () {
    const inr = Money(11005000, 'INR');

    test('groups the Indian way for en_IN and hi', () {
      expect(format(inr, locale: 'en_IN'), '₹1,10,050.00');
      expect(format(inr, locale: 'hi'), '₹1,10,050.00');
    });

    test('groups by thousands for English with a US device', () {
      expect(format(inr, locale: 'en_US'), '₹110,050.00');
    });

    test('Spanish uses a decimal comma and puts the symbol after', () {
      expect(format(inr, locale: 'es'), '110.050,00$nbsp₹');
      expect(
        format(const Money(123450, 'EUR'), locale: 'es'),
        '1.234,50$nbsp€',
      );
    });

    test('uses the currency own number of decimals', () {
      expect(format(const Money(500, 'JPY'), locale: 'en'), '¥500');
      expect(format(const Money(8500, 'USD'), locale: 'en'), r'$85.00');
      expect(format(const Money(5, 'INR'), locale: 'en_IN'), '₹0.05');
    });

    test('3-digit currencies show every decimal, with a space after a letter symbol', () {
      expect(format(const Money(1000, 'KWD'), locale: 'en'), 'din${nbsp}1.000');
      expect(format(const Money(1, 'KWD'), locale: 'en'), 'din${nbsp}0.001');
      expect(format(const Money(1000, 'KWD'), locale: 'es'), '1,000${nbsp}din');
    });

    test(
      'an unknown currency shows its code with 2 decimals instead of crashing',
      () {
        expect(
          format(const Money(11050, 'XYZ'), locale: 'en'),
          'XYZ${nbsp}110.50',
        );
      },
    );

    test('the largest amounts print every digit', () {
      expect(
        format(const Money(999999999999999, 'KWD'), locale: 'en'),
        'din${nbsp}999,999,999,999.999',
      );
      expect(
        format(const Money(99999999999999, 'INR'), locale: 'en_IN'),
        '₹9,99,99,99,99,999.99',
      );
      expect(
        format(const Money(999999999999, 'JPY'), locale: 'en'),
        '¥999,999,999,999',
      );
    });

    test('every minor unit near the cap comes out exactly', () {
      // A double would show a rounding error here if the cap were too high.
      for (final minor in [
        999999999999991,
        999999999999998,
        123456789012345,
        100000000000001,
      ]) {
        final text = format(Money(minor, 'KWD'), locale: 'en');
        expect(text.replaceAll(RegExp('[^0-9]'), ''), '$minor', reason: text);
      }
    });
  });

  group('exact for any amount (phase-5.md R2)', () {
    test('the same text as the old double path, 420 cases', () {
      // Captured from the old `amountMinor / 10^digits` path before the
      // change: 7 locales × 6 currencies × 10 amounts, all within the
      // double's exact range, so the old output was right.
      final expected = jsonDecode(
        File('test/ui/core/money_formatter_expected.json').readAsStringSync(),
      ) as Map<String, Object?>;
      expect(expected, hasLength(420));
      for (final MapEntry(:key, :value) in expected.entries) {
        final [locale, code, minor] = key.split(' ');
        expect(
          format(Money(int.parse(minor), code), locale: locale),
          value,
          reason: key,
        );
      }
    });

    test('past 2⁵³ every digit stays (the double path lost them)', () {
      expect(
        format(const Money(9007199254740993, 'INR'), locale: 'en_IN'),
        '₹9,00,71,99,25,47,409.93',
      );
      expect(
        format(const Money(12345678901234567, 'INR'), locale: 'en_IN'),
        '₹12,34,56,78,90,12,345.67',
      );
    });

    test('max int64 in INR, KWD and JPY', () {
      const max = 9223372036854775807;
      for (final (code, digits) in [('INR', 2), ('KWD', 3), ('JPY', 0)]) {
        final got = format(Money(max, code), locale: 'en');
        expect(got.replaceAll(RegExp('[^0-9]'), ''), '$max', reason: got);
        if (digits > 0) {
          expect(got, endsWith('.${'$max'.substring(19 - digits)}'));
        }
      }
    });

    test('Spanish with a Mexican phone uses the dot (es_MX)', () {
      expect(
        format(const Money(11005000, 'INR'), locale: 'es_MX'),
        startsWith('₹110,050.00'),
      );
      expect(
        format(const Money(11005000, 'INR'), locale: 'es'),
        '110.050,00$nbsp₹',
      );
    });
  });

  group('formatTotal (phase-5.md R3)', () {
    final formatter = MoneyFormatter.forLocale('en_IN');
    final max = BigInt.from(9223372036854775807);

    test('3 × (2⁶³ − 1) paise prints exactly', () {
      final total = max * BigInt.from(3);
      final text = formatter.formatTotal('INR', total)!;
      expect(text.replaceAll(RegExp('[^0-9]'), ''), '$total');
    });

    test('a major part beyond 2⁶³ − 1 is null ("Too large")', () {
      expect(
        formatter.formatTotal('INR', (max + BigInt.one) * BigInt.from(100)),
        isNull,
      );
      expect(
        formatter.formatTotal('INR', max * BigInt.from(100) + BigInt.from(99)),
        isNotNull,
      );
    });

    test('the same as format for an int', () {
      expect(
        formatter.formatTotal('INR', BigInt.from(11005000)),
        formatter.format(const Money(11005000, 'INR')),
      );
    });
  });

  group('caching', () {
    test('the same instance is reused per locale and per currency', () {
      final a = MoneyFormatter.forLocale('en_IN');
      expect(identical(a, MoneyFormatter.forLocale('en_IN')), isTrue);
      expect(identical(a, MoneyFormatter.forLocale('en_US')), isFalse);
      expect(identical(a.numberFormat('INR'), a.numberFormat('INR')), isTrue);
      expect(identical(a.numberFormat('INR'), a.numberFormat('USD')), isFalse);
    });
  });

  group('formatShort (amount chips)', () {
    String short(Money money, String locale) =>
        MoneyFormatter.forLocale(locale).formatShort(money);

    test('drops zero decimals of a whole amount', () {
      expect(short(const Money(5000, 'INR'), 'en_IN'), '₹50');
      expect(short(const Money(100000000, 'INR'), 'en_IN'), '₹10,00,000');
      expect(short(const Money(500, 'JPY'), 'en'), '¥500');
      expect(short(const Money(1000, 'KWD'), 'en'), 'din 1');
    });

    test('keeps the decimals of an amount that has them', () {
      expect(short(const Money(1250, 'INR'), 'en_IN'), '₹12.50');
      expect(short(const Money(1001, 'KWD'), 'en'), 'din 1.001');
    });

    test('format() is unchanged by it', () {
      final formatter = MoneyFormatter.forLocale('en_IN');
      formatter.formatShort(const Money(5000, 'INR'));
      expect(formatter.format(const Money(5000, 'INR')), '₹50.00');
    });
  });
}
