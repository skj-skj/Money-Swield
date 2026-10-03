import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/amount_input.dart';

/// Every row of the table in phase-2.md §4.2.
void main() {
  AmountParse inr(String text) => parseAmount(text, minorDigits: 2);

  void expectAmount(String text, int minor, {int minorDigits = 2}) => expect(
    parseAmount(text, minorDigits: minorDigits),
    AmountParsed(minor),
    reason: '"$text" with $minorDigits digits',
  );

  void expectError(String text, AmountError error, {int minorDigits = 2}) =>
      expect(
        parseAmount(text, minorDigits: minorDigits),
        AmountRejected(error),
        reason: '"$text" with $minorDigits digits',
      );

  group('parseAmount', () {
    test('empty text or only spaces is empty', () {
      expectError('', AmountError.empty);
      expectError('   ', AmountError.empty);
    });

    test('accepts one . or , as the decimal separator', () {
      expectAmount('110', 11000);
      expectAmount('110.5', 11050);
      expectAmount('110,50', 11050);
      expectAmount('.5', 50);
      expectAmount(',05', 5);
      expectAmount('007', 700);
    });

    test('trims leading and trailing whitespace', () {
      expectAmount('  110.50 ', 11050);
      expectAmount('\t5\n', 500);
    });

    test('a trailing separator, as while typing, is the whole number', () {
      expectAmount('5.', 500);
      expectAmount('5,', 500);
      expectAmount('5.', 5, minorDigits: 0);
    });

    test('too many decimals is an error, never rounded', () {
      expectError('110.505', AmountError.tooManyDecimals);
      expectError('10.5', AmountError.tooManyDecimals, minorDigits: 0);
      expectError('1.0001', AmountError.tooManyDecimals, minorDigits: 3);
    });

    test('a grouped number is an error, never a smaller amount', () {
      // Would otherwise be ₹1.00 for someone who meant a thousand.
      expectError('1,000', AmountError.tooManyDecimals);
    });

    test('in a 3-digit currency 1,000 and 1.000 are one unit', () {
      expectAmount('1,000', 1000, minorDigits: 3);
      expectAmount('1.000', 1000, minorDigits: 3);
    });

    test('anything that is not one plain number is invalid', () {
      for (final text in [
        '1.000.000',
        '1,000.50',
        '.',
        ',',
        '1 000',
        '12a',
        '-5',
        '+5',
        '1e3',
        '½',
        '١٢', // Arabic-Indic digits.
      ]) {
        expectError(text, AmountError.invalid);
      }
    });

    test('zero is not positive', () {
      expectError('0', AmountError.notPositive);
      expectError('0.00', AmountError.notPositive);
      expectError('000', AmountError.notPositive);
      expectError('0.', AmountError.notPositive);
    });

    test('up to 12 digits before the separator, leading zeros not counted', () {
      expectAmount('999999999999', 99999999999900);
      expectError('1000000000000', AmountError.tooLarge);
      expectAmount('0000000000001', 100);
      expectAmount('999999999999.999', 999999999999999, minorDigits: 3);
    });

    test('the first error in the documented order wins', () {
      // tooLarge before tooManyDecimals.
      expectError('1234567890123.505', AmountError.tooLarge);
      // invalid before tooLarge.
      expectError('12345678901234a', AmountError.invalid);
      // tooManyDecimals before notPositive.
      expectError('0.000', AmountError.tooManyDecimals);
    });

    test('works for 0, 2 and 3 digit currencies', () {
      expectAmount('500', 500, minorDigits: 0);
      expectAmount('85.5', 8550);
      expectAmount('1.5', 1500, minorDigits: 3);
      expectAmount('0.001', 1, minorDigits: 3);
    });

    test('the INR typed result is the same with , and .', () {
      expect(inr('10,5'), inr('10.5'));
      expect(inr('10,5'), const AmountParsed(1050));
    });
  });

  group('formatAmountForInput', () {
    test('writes minor units with a . and every decimal', () {
      expect(formatAmountForInput(11050, 2), '110.50');
      expect(formatAmountForInput(5, 2), '0.05');
      expect(formatAmountForInput(100, 2), '1.00');
      expect(formatAmountForInput(500, 0), '500');
      expect(formatAmountForInput(1000, 3), '1.000');
      expect(formatAmountForInput(1, 3), '0.001');
    });

    test('round-trips through parseAmount', () {
      for (final (minor, digits) in [
        (1, 2),
        (11050, 2),
        (99999999999999, 2),
        (500, 0),
        (999999999999, 0),
        (1, 3),
        (999999999999999, 3),
      ]) {
        expect(
          parseAmount(formatAmountForInput(minor, digits), minorDigits: digits),
          AmountParsed(minor),
          reason: '$minor with $digits digits',
        );
      }
    });
  });

  group('amountNeedsPreview', () {
    test('only for a , or more than one .', () {
      expect(amountNeedsPreview('110.50'), isFalse);
      expect(amountNeedsPreview('110'), isFalse);
      expect(amountNeedsPreview('10,5'), isTrue);
      expect(amountNeedsPreview('1.000.000'), isTrue);
      expect(amountNeedsPreview('1,000'), isTrue);
    });
  });
}
