import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_parser.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_payment_method.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_text.dart';

import 'fixtures/india_sms.dart';

void main() {
  const parser = IndiaSmsParser();

  group('IndiaSmsParser.isDebitCandidate', () {
    const bank = 'VM-ABCBNK-S';
    for (final (sender, body, expected) in [
      (bank, bankSent1, true),
      (bank, bankSent2, true),
      (bank, bankSent3, true),
      (bank, bankMandate, true),
      (bank, bankAtm, false), // #4: ATM
      ('VM-ABCBNK-P', 'Rs 500 off on your next purchase', false),
      ('vm-abcbnk-p', 'Rs 500 debited', false),
      ('+919876543210', 'I sent you Rs 500', false),
      ('9876543210', 'Rs 500 debited', false),
      (bank, 'Rs.500 deposited in your A/c', false), // a whole word: not "pos"
      (bank, 'Your OTP for Rs 500 is 123456', false),
      (bank, 'Rs 500 will be debited on 01-10', false),
      (bank, 'UPI collect request of Rs 99 from X', false),
      (bank, 'Rs 500 credited to your a/c XX1234', false),
      (bank, impsToRavi, true),
      (
        bank,
        'Rs 500 debited from A/c XX1234. If not requested by you, call us',
        true,
      ),
      (bank, 'Rs 2000 withdrawn at ATM XX on 01-10', false),
      (bank, 'Cash withdrawal of Rs 500 at XX', false),
      (bank, 'Rs 50 paid at ATMOSPHERE CAFE', true),
      // A card cash withdrawal without the word ATM (found on the Oppo).
      (
        bank,
        'Withdrawn Rs.500 From ABC Bank Card x0000 At +SOMEPLACE On '
            '2026-01-01:10:00:00 Bal Rs.99.00 Not You? Call 1800',
        false,
      ),
      (bank, '₹500 आपके खाते से', false),
      (bank, '', false),
      (bank, 'Rs 500 payment failed', false),
      (bank, 'Rs 500 refund processed', false),
      (bank, 'Debited Rs 500. Cashback of Rs 5', false),
      (bank, 'Your bill of Rs 500 is due on 01-10', false),
      (bank, 'Rs 500 received from Ravi', false),
      (bank, creditCardSpend, true),
      (bank, swiggyUpi, true),
      (bank, threeDecimals, false), // no clear amount
      (bank, noCurrency, false), // never guessed
      ('VM-ABCBNK', 'Rs 500 debited', true), // an old ID without suffix
    ]) {
      test('$sender "${body.split('\n').first}" → $expected', () {
        expect(parser.isDebitCandidate(sender, body), expected);
      });
    }
  });

  group('IndiaSmsParser.parse', () {
    void expectParse(
      String body, {
      required int amount,
      required String method,
      String? payee,
      String? reference,
    }) {
      final parse = parser.parse(body);
      expect(parse, isNotNull);
      expect(parse!.amountMinor, amount);
      expect(parse.paymentMethodKey, method);
      expect(parse.payee, payee);
      expect(parse.reference, reference);
    }

    test('the samples #1–#3: UPI from the footer, payee on its own line', () {
      expectParse(
        bankSent1,
        amount: 15000,
        method: 'upi',
        payee: 'GLOBEX TECHNOLOGIES PRIVA',
        reference: '100000000001',
      );
      expectParse(
        bankSent2,
        amount: 7500,
        method: 'upi',
        payee: 'Sunrise REFRESHMENT',
        reference: '100000000002',
      );
      expectParse(
        bankSent3,
        amount: 32000,
        method: 'upi',
        payee: 'UMBRA MARKETPLACE PRIVATE',
        reference: '100000000003',
      );
    });

    test('sample #5: "towards X" (not "wards X"), UPI from @ybl followed by '
        'a full stop, no reference', () {
      expectParse(
        bankMandate,
        amount: 1250000,
        method: 'upi',
        payee: 'Example Ceramics Limited',
      );
    });

    test('a credit card: the amount, not the limit after it', () {
      expectParse(
        creditCardSpend,
        amount: 250000,
        method: 'credit_card',
        payee: 'AMAZON',
      );
    });

    test('a UPI ID payee ends at " via"', () {
      expectParse(swiggyUpi, amount: 9900, method: 'upi', payee: 'swiggy@ybl');
    });

    // The amount rules themselves are sms_amount_test's.
    test('no clear amount → null', () {
      expect(parser.parse(noCurrency), isNull);
      expect(parser.parse(''), isNull);
    });

    test('references need a digit', () {
      expect(parser.parse(referenceNumber)!.reference, '123456789012');
      expect(parser.parse(utrNumber)!.reference, '1234567');
      expect(
        parser.parse('Rs 5 debited. Reference Number pending')!.reference,
        isNull,
      );
      expect(
        parser.parse('Rs 5 debited. Ref No. ab12cd34')!.reference,
        'AB12CD34',
      );
      expect(
        parser.parse('Rs 5 debited. UPI RRN:012345678904')!.reference,
        '012345678904',
      );
    });

    test('payees: a long one cut to 100, none from digits or none at all, '
        'the first usable "to / at"', () {
      final long = 'A' * 150;
      expect(parser.parse('Rs 5 paid to $long on 01-10')!.payee, 'A' * 100);
      expect(parser.parse('Rs 5 paid to 9876543210')!.payee, isNull);
      expect(parser.parse('Rs 5 debited from A/c XX12')!.payee, isNull);
      expect(
        parser.parse('Rs 5 debited on 01-10 at 14:05 to ACME')!.payee,
        'ACME',
      );
      expect(
        parser.parse('Rs 5 debited to VPA abc@okbank via UPI')!.payee,
        'abc@okbank',
      );
      expect(
        parser.parse('Rs 5 paid to:  Big   Bazaar , Avl Bal Rs 9')!.payee,
        'Big Bazaar',
      );
    });

    test('a title before the payee is dropped, its full stop does not end '
        'it (one payee key "mr" would join strangers)', () {
      for (final (body, payee) in [
        ('Rs 5 paid to M/s. Acme Stores on 01-10', 'Acme Stores'),
        ('Rs 5 paid to M/S ACME STORES', 'ACME STORES'),
        ('Rs 5 sent to Mr. Ravi Kumar on 01-10', 'Ravi Kumar'),
        ('Rs 5 debited towards Dr. Rao Clinic', 'Rao Clinic'),
        ('Rs 5 paid to Smt Lata Devi', 'Lata Devi'),
        // A name that only starts like a title keeps it.
        ('Rs 5 paid to Mrinal Sen', 'Mrinal Sen'),
        ('Rs 5 paid to Dr.', 'Dr'),
      ]) {
        expect(parser.parse(body)!.payee, payee, reason: body);
      }
    });

    test('a NACH mandate\'s UMRN is not part of the payee (found on the '
        'Oppo)', () {
      expect(
        parser
            .parse(
              'PAYMENT ALERT!\nINR 750.00 deducted from ABC Bank A/C No 1234 '
              'towards Example Clearing Corporation Lt UMRN: ABCB0000000000000000',
            )!
            .payee,
        'Example Clearing Corporation Lt',
      );
    });

    test('the footer never gives the payee ("to 9000000000")', () {
      expect(
        parser.parse('Sent Rs.5\nNot You?\nSMS BLOCK UPI to Mr X')!.payee,
        isNull,
      );
    });

    test(r'\r\n line ends read like \n', () {
      final windows = bankSent1.replaceAll('\n', '\r\n');
      expect(parser.parse(windows), parser.parse(bankSent1));
    });

    test('a body of 2,000+ characters gives the same result', () {
      final long = '$creditCardSpend ${'x' * 2000}';
      expect(parser.parse(long)!.amountMinor, 250000);
      expect(parser.parse(long)!.payee, 'AMAZON');
    });

    test('a Devanagari payee is kept as is', () {
      expect(parser.parse('Rs 5 paid to राम स्टोर')!.payee, 'राम स्टोर');
    });
  });

  group('paymentMethodKeyOf', () {
    for (final (text, expected) in [
      (bankSent1, 'upi'),
      (bankMandate, 'upi'),
      (rupayUpi, 'upi'),
      ('Rs 500 spent on Credit Card XX1234', 'credit_card'),
      (neftDebit, 'debit_card'),
      (gmailMention, 'debit_card'),
      (impsToRavi, 'debit_card'), // "credited" isn't "credit card"
      ('Rupee 500 debited', 'debit_card'),
      ('Rs 5 to VPA abc', 'upi'),
      ('Rs 5 to abc@ybl', 'upi'),
      ('Rs 5 to abc@ybl.', 'upi'),
      ('Rs 5 mail abc@example.co.in', 'debit_card'),
      ('Rs 5 to abc@ybl2', 'debit_card'),
      ('', 'debit_card'),
    ]) {
      test('"${text.split('\n').first}" → $expected', () {
        expect(paymentMethodKeyOf(text), expected);
      });
    }
  });

  group('smsText / withoutFooter', () {
    test('spaces collapse, line breaks stay one per run', () {
      expect(smsText('  a \t b\r\n\r\n c  '), 'a b\nc');
    });

    test('the footer goes from "If not you" and its other wordings', () {
      expect(withoutFooter('Paid. If not you, call'), 'Paid.');
      expect(withoutFooter('Paid. Not You? Call'), 'Paid.');
      expect(withoutFooter('Paid. If not requested by you, call'), 'Paid.');
      expect(withoutFooter('Paid to X'), 'Paid to X');
    });
  });
}
