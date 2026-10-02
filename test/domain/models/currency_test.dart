import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/domain/models/currency.dart';

void main() {
  group('catalog', () {
    test('codes are unique, three capital letters, and sorted', () {
      final codes = [for (final c in currencies) c.code];
      expect(codes.toSet(), hasLength(codes.length), reason: 'no duplicates');
      for (final code in codes) {
        expect(code, matches(RegExp(r'^[A-Z]{3}$')));
      }
      expect(codes, [...codes]..sort());
    });

    test('minor digits are 0, 2 or 3, and match well-known currencies', () {
      for (final c in currencies) {
        expect([0, 2, 3], contains(c.minorDigits), reason: c.code);
      }
      expect(findCurrency('INR')!.minorDigits, 2);
      expect(findCurrency('USD')!.minorDigits, 2);
      expect(findCurrency('JPY')!.minorDigits, 0);
      expect(findCurrency('KRW')!.minorDigits, 0);
      expect(findCurrency('KWD')!.minorDigits, 3);
      expect(findCurrency('BHD')!.minorDigits, 3);
    });

    test('every currency has a name and a symbol, and building the symbol never throws', () {
      for (final c in currencies) {
        expect(c.englishName.trim(), isNotEmpty, reason: c.code);
        expect(c.symbol, isNotEmpty, reason: c.code);
      }
    });

    test('common symbols come from intl', () {
      expect(findCurrency('INR')!.symbol, '₹');
      expect(findCurrency('USD')!.symbol, r'$');
      expect(findCurrency('EUR')!.symbol, '€');
      expect(findCurrency('GBP')!.symbol, '£');
    });

    test('withdrawn currencies are not offered', () {
      for (final code in ['HRK', 'BGN', 'SLL', 'ZWL', 'VEF']) {
        expect(findCurrency(code), isNull, reason: code);
      }
    });

    test('findCurrency is exact and case-sensitive', () {
      expect(findCurrency('INR'), isNotNull);
      expect(findCurrency('inr'), isNull);
      expect(findCurrency(''), isNull);
    });
  });

  group('deviceCurrency', () {
    test('uses the currency of the locale\'s country', () {
      expect(deviceCurrency(const Locale('en', 'IN')), 'INR');
      expect(deviceCurrency(const Locale('hi', 'IN')), 'INR');
      expect(deviceCurrency(const Locale('en', 'US')), 'USD');
      expect(deviceCurrency(const Locale('es', 'ES')), 'EUR');
      expect(deviceCurrency(const Locale('es', 'MX')), 'MXN');
      expect(deviceCurrency(const Locale('en', 'GB')), 'GBP');
      expect(deviceCurrency(const Locale('ja', 'JP')), 'JPY');
    });

    test('finds countries intl only knows under the bare language code', () {
      // intl has ja, fr, de but no ja_JP, fr_FR, de_DE.
      expect(deviceCurrency(const Locale('ja', 'JP')), 'JPY');
      expect(deviceCurrency(const Locale('fr', 'FR')), 'EUR');
      expect(deviceCurrency(const Locale('de', 'DE')), 'EUR');
      expect(deviceCurrency(const Locale('ko', 'KR')), 'KRW');
    });

    test('a language intl lacks for that country still finds the country\'s currency', () {
      // intl has no hi_GB, but has en_GB.
      expect(deviceCurrency(const Locale('hi', 'GB')), 'GBP');
    });

    test('falls back to USD without a country, or for an unknown one', () {
      expect(deviceCurrency(const Locale('en')), 'USD');
      expect(
        deviceCurrency(const Locale('es')),
        'USD',
        reason: 'Spanish alone does not mean euros',
      );
      expect(deviceCurrency(const Locale('xx', 'QQ')), 'USD');
    });

    test('always returns a currency from the catalog', () {
      for (final locale in const [
        Locale('en', 'IN'),
        Locale('fr', 'FR'),
        Locale('ar', 'KW'),
        Locale('xx', 'QQ'),
      ]) {
        expect(
          findCurrency(deviceCurrency(locale)),
          isNotNull,
          reason: '$locale',
        );
      }
    });
  });

  group('searchCurrencies', () {
    test('an empty or blank query returns everything', () {
      expect(searchCurrencies(''), currencies);
      expect(searchCurrencies('   '), currencies);
    });

    test(
      'matches the code ignoring case, codes starting with the query first',
      () {
        final results = searchCurrencies('in');
        expect(results.first.code, 'INR');
        expect(results.map((c) => c.code), contains('INR'));
        // "in" also appears in names like "Argentine" or "Bolivian".
        expect(results.length, greaterThan(1));
      },
    );

    test('matches the English name ignoring case', () {
      expect(
        searchCurrencies('rupee').map((c) => c.code),
        containsAll(['INR', 'LKR', 'NPR', 'PKR']),
      );
      expect(searchCurrencies('YEN').map((c) => c.code), ['JPY']);
    });

    test('ignores surrounding spaces', () {
      expect(searchCurrencies('  usd ').first.code, 'USD');
    });

    test('no match gives an empty list', () {
      expect(searchCurrencies('zzzz'), isEmpty);
    });

    test('never lists a currency twice', () {
      for (final query in ['a', 'd', 'dollar', 'u']) {
        final codes = searchCurrencies(query).map((c) => c.code).toList();
        expect(codes.toSet(), hasLength(codes.length), reason: query);
      }
    });
  });
}
