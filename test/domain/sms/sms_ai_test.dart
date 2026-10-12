import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_ai_prompt.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_ai_result.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_amount.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_learning.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_title.dart';
import 'package:my_expense_tracker_app/domain/title_suggestions.dart';

import 'fixtures/india_sms.dart';

/// phase-9b.md §5 (§11 "Domain").
void main() {
  const categories = <CategoryName>[
    (id: 1, name: 'Groceries'),
    (id: 2, name: 'Food & Dining'),
    (id: 3, name: 'किराना'),
    (id: 4, name: '🎬 Movies'),
    (id: 5, name: 'Comida'),
  ];

  /// A model answer with [fields] over a plain debit of 150.
  String answer(Map<String, Object?> fields) => jsonEncode({
    'is_debit': true,
    'amount': '150.00',
    'payee': 'GLOBEX TECHNOLOGIES PRIVA',
    'title': 'Globex',
    'payment': 'upi',
    'category': 'Groceries',
    ...fields,
  });

  group('buildAiPrompt', () {
    test('holds the text and every category name, Hindi and emoji too', () {
      final prompt = buildAiPrompt(bankSent1, categories)!;
      expect(prompt, contains(bankSent1));
      for (final c in categories) {
        expect(prompt, contains('- ${c.name}\n'));
      }
      // The SMS goes last, between markers, after the instructions.
      expect(prompt.indexOf(bankSent1), greaterThan(prompt.indexOf('- 🎬')));
      expect(prompt, endsWith('$bankSent1\n>>>'));
    });

    test('asks for the whole name as the title (a "short title" made the '
        'Pixel\'s model drop words of it, phase-9b.md §12a)', () {
      final prompt = buildAiPrompt(bankSent1, categories)!;
      expect(prompt, contains('keeping every word of the name'));
      expect(prompt, isNot(contains('short expense title')));
    });

    test('no categories: still a prompt, the model can only say none', () {
      expect(buildAiPrompt(bankSent1, const []), contains('"none" only when'));
    });

    test('a 2,000-character ASCII SMS with 200 categories fits; the size is '
        'counted in UTF-8 bytes', () {
      final many = [for (var i = 0; i < 200; i++) (id: i, name: 'C$i')];
      final prompt = buildAiPrompt('a' * 2000, many);
      expect(prompt, isNotNull);
      expect(utf8.encode(prompt!).length, lessThanOrEqualTo(aiPromptMaxBytes));
    });

    test('over the byte limit → null (the regex reads it), though its '
        'characters would fit: Devanagari is 3 bytes a letter', () {
      // 2,700 characters, 8,100 bytes.
      final hindi = 'क' * 2700;
      expect(buildAiPrompt(hindi, categories), isNull);
      expect(buildAiPrompt('a' * 2700, categories), isNotNull);
    });

    test('200 long category names with a long SMS → null', () {
      final many = [
        for (var i = 0; i < 200; i++)
          (id: i, name: 'A rather long category name $i'),
      ];
      expect(buildAiPrompt('a' * 2000, many), isNull);
      expect(buildAiPrompt(bankSent1, many), isNotNull);
    });
  });

  group('amountsInText', () {
    test('every amount with a currency, before or after', () {
      expect(amountsInText('Rs.150.00 to X'), {15000});
      expect(amountsInText('INR 1,23,456.78'), {12345678});
      expect(amountsInText('₹99 paid'), {9900});
      expect(amountsInText('500 INR debited'), {50000});
      expect(amountsInText('Rs 5 and Rs.20 debited'), {500, 2000});
    });

    test('no currency → none: a date, a reference, a phone number', () {
      expect(amountsInText('debited by 20.0 on 01-10-26'), isEmpty);
      expect(amountsInText('Ref 100000000001'), isEmpty);
      expect(amountsInText('Call 18000000000'), isEmpty);
    });

    test('not a number glued to a code, nor a balance or limit', () {
      expect(amountsInText('A/c XX1234 INR 500 debited'), {50000});
      expect(amountsInText('Rs 250 spent. Avl Bal Rs 10,000'), {25000});
      expect(amountsInText('INR 2,500 spent. Avl Lmt INR 50,000'), {250000});
    });

    test('three decimals is no amount', () {
      expect(amountsInText('Rs 12.345 debited'), isEmpty);
    });
  });

  group('acceptAiResult', () {
    test('a plain answer → every field', () {
      expect(acceptAiResult(answer({}), bankSent1, categories), (
        amountMinor: 15000,
        payee: 'GLOBEX TECHNOLOGIES PRIVA',
        title: 'Globex',
        paymentMethodKey: 'upi',
        categoryId: 1,
      ));
    });

    test('wrapped in a Markdown fence (what the Pixel\'s model does) → '
        'read', () {
      final fenced = '```json\n${answer({})}\n```';
      expect(acceptAiResult(fenced, bankSent1, categories)?.amountMinor, 15000);
    });

    group('the amount must be one the text writes', () {
      for (final (amount, expected) in <(Object?, int?)>[
        ('150', 15000),
        ('150.00', 15000),
        ('150.0', 15000),
        (150, 15000),
        (150.0, 15000),
        ('1500', null),
        ('15', null),
        ('149.99', null),
        ('151', null),
        // The account number (*1234) and the footer's phone number.
        ('1234', null),
        ('18000000000', null),
        // The reference (12 digits, no currency): never an amount.
        ('100000000001', null),
        ('14', null), // the date "On 14/03/26"
        ('0', null),
        ('-150', null),
        ('Rs.150.00', null),
        ('', null),
        (null, null),
        (true, null),
        (['150'], null),
      ]) {
        test('$amount → $expected', () {
          expect(
            acceptAiResult(
              answer({'amount': amount}),
              bankSent1,
              categories,
            )?.amountMinor,
            expected,
          );
        });
      }
    });

    test('a balance the text writes is refused', () {
      const body = 'Rs 250 debited from A/c XX1234. Avl Bal Rs 10,000.00';
      expect(
        acceptAiResult(answer({'amount': '10,000.00'}), body, categories),
        isNull,
      );
      expect(
        acceptAiResult(
          answer({'amount': '250'}),
          body,
          categories,
        )?.amountMinor,
        25000,
      );
    });

    test('an amount only in the footer is refused', () {
      const body = 'Rs 5 debited from A/c XX1234. Not you? Call 1800 123 456';
      expect(
        acceptAiResult(answer({'amount': '456'}), body, categories),
        isNull,
      );
    });

    test('Indian grouping, with or without the commas', () {
      const body = 'INR 1,23,456.78 debited from A/c XX1234';
      for (final amount in ['1,23,456.78', '123456.78', '123,456.78']) {
        expect(
          acceptAiResult(
            answer({'amount': amount}),
            body,
            categories,
          )?.amountMinor,
          12345678,
          reason: amount,
        );
      }
    });

    test('is_debit false, missing, or a string → null (P9b-37)', () {
      for (final value in [false, null, 'true', 1]) {
        expect(
          acceptAiResult(answer({'is_debit': value}), bankSent1, categories),
          isNull,
          reason: '$value',
        );
      }
    });

    test('malformed or no JSON → null', () {
      for (final text in [
        '',
        'I think it is a debit of 150',
        '{"is_debit": true, "amount": "150"',
        '{}',
        'null',
      ]) {
        expect(acceptAiResult(text, bankSent1, categories), isNull);
      }
    });

    test('an object inside prose or an array is read; its checks still '
        'apply', () {
      expect(
        acceptAiResult(
          'Here: [{"is_debit": true, "amount": "150"}]',
          bankSent1,
          categories,
        )?.amountMinor,
        15000,
      );
    });

    test('extra keys ignored', () {
      expect(
        acceptAiResult(
          answer({'confidence': 0.9, 'currency': 'INR'}),
          bankSent1,
          categories,
        )?.amountMinor,
        15000,
      );
    });

    test('a 300-character title → cut to 100; graphemes are never split', () {
      final long = acceptAiResult(
        answer({'title': 'a' * 300}),
        bankSent1,
        categories,
      )!;
      expect(long.title, 'a' * 100);
      final emoji = acceptAiResult(
        answer({'title': '🍕' * 150}),
        bankSent1,
        categories,
      )!;
      expect(emoji.title, '🍕' * 100);
    });

    test('title and payee: trimmed; empty or not a string → none', () {
      final parse = acceptAiResult(
        answer({'title': '  Acme groceries  ', 'payee': '   '}),
        bankSent1,
        categories,
      )!;
      expect(parse.title, 'Acme groceries');
      expect(parse.payee, isNull);
      final other = acceptAiResult(
        answer({'title': 12, 'payee': null}),
        bankSent1,
        categories,
      )!;
      expect(other.title, isNull);
      expect(other.payee, isNull);
    });

    group('payment', () {
      for (final (payment, expected) in <(Object?, String?)>[
        ('upi', 'upi'),
        ('credit_card', 'credit_card'),
        ('debit_card', 'debit_card'),
        ('UPI', null),
        ('cash', null),
        ('neft', null), // the Pixel's model said this for NEFT
        ('none', null),
        (null, null), // also what a missing key reads as
      ]) {
        test('$payment → $expected (null: 9a\'s text rule)', () {
          expect(
            acceptAiResult(
              answer({'payment': payment}),
              bankSent1,
              categories,
            )?.paymentMethodKey,
            expected,
          );
        });
      }
    });

    group('category', () {
      for (final (category, expected) in <(Object?, int?)>[
        ('Groceries', 1),
        ('groceries', 1),
        ('GROCERIES', 1),
        (' Groceries ', 1),
        ('Food & Dining', 2),
        ('किराना', 3),
        ('🎬 Movies', 4),
        ('🎬 movies', 4),
        ('Movies', null),
        ('Grocery', null),
        ('none', null),
        ('', null),
        (null, null),
        (1, null),
      ]) {
        test('$category → $expected', () {
          expect(
            acceptAiResult(
              answer({'category': category}),
              bankSent1,
              categories,
            )?.categoryId,
            expected,
          );
        });
      }

      test('"none" is no category, even with a category called None', () {
        const withNone = <CategoryName>[(id: 9, name: 'None')];
        for (final word in ['none', 'None', ' NONE ']) {
          expect(
            acceptAiResult(
              answer({'category': word}),
              bankSent1,
              withNone,
            )?.categoryId,
            isNull,
            reason: word,
          );
        }
      });

      test('two names that fold alike: the exact one wins', () {
        const twins = <CategoryName>[
          (id: 7, name: 'food'),
          (id: 8, name: 'Food'),
        ];
        expect(
          acceptAiResult(
            answer({'category': 'Food'}),
            bankSent1,
            twins,
          )?.categoryId,
          8,
        );
        expect(
          acceptAiResult(
            answer({'category': 'food'}),
            bankSent1,
            twins,
          )?.categoryId,
          7,
        );
        expect(
          acceptAiResult(
            answer({'category': 'FOOD'}),
            bankSent1,
            twins,
          )?.categoryId,
          7,
        );
      });
    });
  });

  group('§5.3 with the model', () {
    test('title: learned > the model\'s (cleaned) > cleaned payee > none', () {
      expect(
        suggestedTitle(learned: 'Rent', ai: 'Acme', payee: 'ACME'),
        'Rent',
      );
      expect(suggestedTitle(ai: 'AMAZON', payee: 'X'), 'Amazon');
      expect(
        suggestedTitle(ai: 'Acme groceries', payee: 'X'),
        'Acme groceries',
      );
      expect(
        suggestedTitle(ai: 'GLOBEX TECHNOLOGIES PRIVA', payee: 'X'),
        'Globex Technologies',
      );
      expect(suggestedTitle(ai: '  ', payee: 'ACME'), 'Acme');
      expect(suggestedTitle(ai: 'PRIVATE', payee: 'ACME'), 'Acme');
      expect(suggestedTitle(ai: null, payee: null), isNull);
    });

    test('category: learned > same title\'s > the model\'s > none', () {
      final history = [
        TitleHistoryRow(
          title: 'Acme',
          amountMinor: 100,
          currencyCode: 'INR',
          categoryId: 7,
          lastAt: DateTime.utc(2026),
          recent: 1,
        ),
      ];
      const learned = (title: 'Acme', categoryId: 3);
      expect(
        suggestedCategory(
          learned: learned,
          title: 'Acme',
          history: history,
          ai: 9,
        ),
        3,
      );
      expect(suggestedCategory(title: 'Acme', history: history, ai: 9), 7);
      expect(suggestedCategory(title: 'Other', history: history, ai: 9), 9);
      expect(suggestedCategory(title: null, ai: 9), 9);
      expect(suggestedCategory(title: 'Other', history: history), isNull);
    });
  });
}
