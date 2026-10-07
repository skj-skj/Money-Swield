import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/models/currency.dart';
import 'package:my_expense_tracker_app/ui/core/currency_labels.dart';

void main() {
  group('currencyLabel', () {
    test('shows the symbol first, one space, then code and name', () {
      expect(currencyLabel('INR'), '₹ INR · Indian Rupee');
      expect(currencyLabel('EUR'), '€ EUR · Euro');
    });

    test('never repeats the code when intl has no symbol for it', () {
      for (final currency in currencies) {
        final label = currencyLabel(currency.code);
        expect(currency.code.allMatches(label), hasLength(1), reason: label);
        expect(label, isNot(contains('  ')), reason: label);
      }
    });

    test('a code from a newer app is shown as is', () {
      expect(currencyLabel('XYZ'), 'XYZ');
    });
  });

  group('currencyShortLabel', () {
    test('symbol and code', () {
      expect(currencyShortLabel('INR'), '₹ INR');
      expect(currencyShortLabel('USD'), r'$ USD');
    });

    test('just the code when there is no symbol or no such currency', () {
      for (final currency in currencies) {
        final label = currencyShortLabel(currency.code);
        expect(currency.code.allMatches(label), hasLength(1), reason: label);
        expect(label, startsWith(currency.symbol), reason: label);
      }
      expect(currencyShortLabel('XYZ'), 'XYZ');
    });
  });
}
