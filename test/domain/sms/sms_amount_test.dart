import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_amount.dart';

/// phase-9a.md §5.6 and §5.2 step 3.
void main() {
  group('parseAmountMinor', () {
    for (final (input, expected) in [
      ('150.00', 15000),
      ('150.0', 15000),
      ('150', 15000),
      ('75.10', 7510),
      ('75.1', 7510),
      ('1,23,456.78', 12345678),
      ('123,456.78', 12345678),
      ('1,00,000', 10000000),
      ('1,234', 123400),
      ('12,34,567', 123456700),
      ('0150', 15000),
      ('9,99,99,99,99,999.99', 99999999999999),
      ('999999999999', 99999999999900),
      ('0', null),
      ('0.00', null),
      ('.50', null),
      ('1,2,3', null),
      ('1,,000', null),
      ('12.345', null),
      ('12,34', null),
      (',100', null),
      ('100,', null),
      ('1234567890123', null), // 13 integer digits
      ('', null),
      ('1 000', null),
      ('१००', null), // Devanagari digits are not read
    ]) {
      test('"$input" → $expected', () {
        expect(parseAmountMinor(input), expected);
      });
    }
  });

  group('findAmountMinor', () {
    for (final (text, expected) in [
      ('Sent Rs.150.00\nFrom', 15000),
      ('Rs 1,23,456.78 debited', 12345678),
      ('INR 2,500 spent', 250000),
      ('₹99 paid', 9900),
      ('Rs.5000.\nFrom', 500000),
      ('Rs 500, debited', 50000),
      ('rs.500 DEBITED', 50000),
      ('500 INR debited', 50000),
      ('500Rs debited', 50000),
      ('Rs 12.345 debited', null),
      ('Rs 1,,000 debited', null),
      ('debited by 20.0', null),
      ('for 2 hours 30 min Rs 500 debited', 50000),
      ('users 100 and Rs 20 debited', 2000),
      ('INR 2,500 spent at X. Avl Lmt INR 50,000', 250000),
      ('Avl Lmt INR 50,000. INR 2,500 spent', 250000),
      ('Avl Bal Rs 10,000. Rs 250 debited', 25000),
      ('Avl Bal: Rs 10,000', null),
      ('Available balance is Rs 900', null),
      ('A/c 1234 INR 500 debited', 50000),
      ('A/c XX1234 INR 500 debited', 50000),
      ('Rs 0 debited', null),
      ('', null),
    ]) {
      test('"$text" → $expected', () {
        expect(findAmountMinor(text), expected);
      });
    }

    test('an ambiguous first amount gives null, not a later one (a later '
        'one may be the balance)', () {
      expect(findAmountMinor('Rs 1,2,3 debited. Rs 500 later'), isNull);
      expect(findAmountMinor('Rs 12.345 debited. Rs 500 later'), isNull);
      expect(findAmountMinor('INR 1,234.567 spent. Avl Bal Rs 50'), isNull);
    });
  });
}
