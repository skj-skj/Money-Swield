import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/amount_expression.dart';
import 'package:my_expense_tracker_app/domain/amount_input.dart';

ExpressionResult inr(String text) => evaluateExpression(text, minorDigits: 2);
ExpressionResult jpy(String text) => evaluateExpression(text, minorDigits: 0);
ExpressionResult kwd(String text) => evaluateExpression(text, minorDigits: 3);

Matcher value(int amountMinor, {bool rounded = false}) => isA<ExpressionValue>()
    .having((v) => v.amountMinor, 'amountMinor', amountMinor)
    .having((v) => v.rounded, 'rounded', rounded);

Matcher rejected(ExpressionError error) => equals(ExpressionRejected(error));

void main() {
  group('errors, in the order of the table (first match wins)', () {
    test('1 empty: nothing, or only a trailing operator', () {
      expect(inr(''), rejected(ExpressionError.empty));
      expect(inr('+'), rejected(ExpressionError.empty));
      expect(inr('*'), rejected(ExpressionError.empty));
    });

    test('2 invalid: grammar is checked before anything else', () {
      for (final text in [
        '5**2',
        '-5',
        '+5',
        '5*-2',
        '5.5.5',
        '5..5',
        '.',
        '5+.',
        'abc',
        '5 + 5',
        '1,5',
        '++',
        '5++',
        '١٢', // Arabic-Indic digits.
        '५', // Devanagari 5.
      ]) {
        expect(inr(text), rejected(ExpressionError.invalid), reason: text);
      }
    });

    test('2 invalid wins over a too large number and too many decimals', () {
      expect(inr('9999999999999.999+-1'), rejected(ExpressionError.invalid));
    });

    test('2 invalid: longer than 100 characters, even if well formed', () {
      final ok = List.filled(50, '1').join('+'); // 99 characters.
      expect(ok.length, 99);
      expect(inr(ok), value(5000));
      expect(inr('${ok}0'), value(5900), reason: '100 is fine');
      expect(inr('${ok}00'), rejected(ExpressionError.invalid));
    });

    test('3 tooLarge: a number with more than 12 integer digits', () {
      expect(inr('1234567890123'), rejected(ExpressionError.tooLarge));
      expect(inr('1+1234567890123'), rejected(ExpressionError.tooLarge));
      expect(
        inr('0001234567890.12'),
        value(123456789012),
        reason: 'leading zeros are not counted',
      );
    });

    test('3 tooLarge wins over tooManyDecimals', () {
      expect(inr('1234567890123.555'), rejected(ExpressionError.tooLarge));
    });

    test('4 tooManyDecimals', () {
      expect(inr('10.555+1'), rejected(ExpressionError.tooManyDecimals));
      expect(jpy('10.5'), rejected(ExpressionError.tooManyDecimals));
      expect(inr('1.2345*2'), rejected(ExpressionError.tooManyDecimals));
      expect(
        inr('1.000'),
        rejected(ExpressionError.tooManyDecimals),
        reason: '`1,000` typed for INR is never ₹1,000.00 nor ₹1.00',
      );
    });

    test('4 tooManyDecimals wins over divideByZero', () {
      expect(inr('10.555/0'), rejected(ExpressionError.divideByZero));
      expect(inr('10.555+1/0'), rejected(ExpressionError.tooManyDecimals));
    });

    test('5 divideByZero', () {
      expect(inr('10/0'), rejected(ExpressionError.divideByZero));
      expect(inr('10/0.00'), rejected(ExpressionError.divideByZero));
      expect(inr('10/.0'), rejected(ExpressionError.divideByZero));
      expect(inr('5+10/0*3'), rejected(ExpressionError.divideByZero));
    });

    test('6 tooLarge: the result has more than 12 integer digits', () {
      expect(inr('999999999999*10'), rejected(ExpressionError.tooLarge));
      expect(inr('999999999999+1'), rejected(ExpressionError.tooLarge));
      expect(
        inr('999999999999.99'),
        value(99999999999999),
        reason: 'the largest amount is fine',
      );
      expect(inr('999999999999.99+0.01'), rejected(ExpressionError.tooLarge));
    });

    test('6 tooLarge: also after rounding up to 10^12', () {
      // 999999999999.995 rounds half-up to 1000000000000.00.
      expect(inr('999999999999.99+0.01/2'), rejected(ExpressionError.tooLarge));
      expect(
        inr('999999999999.98+0.01/2'),
        value(99999999999999, rounded: true),
      );
    });

    test('7 notPositive', () {
      expect(inr('50-60'), rejected(ExpressionError.notPositive));
      expect(inr('10-10'), rejected(ExpressionError.notPositive));
      expect(inr('0'), rejected(ExpressionError.notPositive));
      expect(inr('0*5'), rejected(ExpressionError.notPositive));
      expect(
        inr('0.01/3'),
        rejected(ExpressionError.notPositive),
        reason: 'rounds to 0.00',
      );
    });
  });

  group('precedence and exactness', () {
    test('× ÷ before + −, left to right', () {
      expect(inr('2+3*4'), value(1400));
      expect(inr('10-4/2'), value(800));
      expect(inr('8/2/2'), value(200));
      expect(inr('2*3+4*5'), value(2600));
      expect(inr('100-20-30'), value(5000), reason: 'not 100-(20-30)');
      expect(inr('100/10*2'), value(2000), reason: 'not 100/(10*2)');
    });

    test('exact fractions, no drift', () {
      expect(inr('10/3*3'), value(1000));
      expect(inr('0.1+0.2'), value(30));
      expect(inr('1/3+1/3+1/3'), value(100));
      expect(
        inr('0.07*100'),
        value(700),
        reason:
            '0.07*100 is 7.000…01 in a '
            'double',
      );
    });

    test('a negative middle is fine when the result is positive', () {
      expect(inr('10-20+30'), value(2000));
    });
  });

  group('one rounding, at the end, half-up', () {
    test('examples', () {
      expect(inr('1/8'), value(13, rounded: true)); // 0.125
      expect(inr('1.15*1.15'), value(132, rounded: true)); // 1.3225
      expect(inr('2/3'), value(67, rounded: true));
      expect(jpy('1000/3'), value(333, rounded: true));
      expect(inr('1/3'), value(33, rounded: true));
      expect(inr('0.005*1'), value(1, rounded: true), reason: 'half up');
    });

    test('rounded only at the end, not per term', () {
      // Per term: 0.33 + 0.33 + 0.33 = 0.99; at the end: 1.00.
      expect(inr('1/3+1/3+1/3'), value(100));
      // 0.005 + 0.005 = 0.01 exactly; per term it would be 0.02.
      expect(inr('0.01/2+0.01/2'), value(1));
    });

    test('rounded is false when the result is exact', () {
      expect(inr('50+60*2'), value(17000));
      expect(inr('1/4'), value(25));
    });
  });

  group('decimals of operands of × and ÷', () {
    test('up to 3 for a quantity', () {
      expect(jpy('1.5*400'), value(600));
      expect(inr('0.375*120'), value(4500));
      expect(inr('120*0.375'), value(4500));
      expect(inr('100/0.125'), value(80000));
      expect(inr('1.234*2'), value(247, rounded: true));
    });

    test('a plain term keeps the currency digits', () {
      expect(inr('10.555+1'), rejected(ExpressionError.tooManyDecimals));
      expect(
        inr('1.5*2+0.125'),
        rejected(ExpressionError.tooManyDecimals),
        reason: '0.125 is a plain term',
      );
    });

    test('KWD has 3 minor digits, more than the operand limit on JPY', () {
      expect(kwd('1.234+1.001'), value(2235));
      expect(kwd('1.2345*2'), rejected(ExpressionError.tooManyDecimals));
      expect(kwd('1.234*1.5'), value(1851)); // 1.851 exactly
      expect(kwd('1/3'), value(333, rounded: true));
    });

    test('a currency with 4 digits lets operands have 4 too', () {
      expect(evaluateExpression('1.2345*2', minorDigits: 4), value(24690));
    });
  });

  group('trailing operator and normalization', () {
    test('a trailing operator is ignored for the value', () {
      expect(inr('50+'), value(5000));
      expect(inr('50*'), value(5000));
      expect(inr('50+60-'), value(11000));
    });

    test('stored form drops the trailing operator and trailing points', () {
      String? stored(String text) => (inr(text) as ExpressionValue).stored;
      expect(stored('50+60+'), '50+60');
      expect(stored('5.+3'), '5+3');
      expect(stored('5.+3.'), '5+3');
      expect(stored('007'), isNull, reason: 'a single number');
      expect(stored('50+'), isNull, reason: 'one number remains');
      expect(stored('5.'), isNull);
      expect(stored('.5+1'), '.5+1');
    });

    test('what is stored evaluates back to the same amount', () {
      for (final text in ['50+60*2-10', '5.+3.5*2', '1/3*3+', '0.375*120']) {
        final first = inr(text) as ExpressionValue;
        final again = inr(first.stored!) as ExpressionValue;
        expect(again.amountMinor, first.amountMinor, reason: text);
        expect(again.stored, first.stored, reason: text);
      }
    });
  });

  group('a single number is the same as parseAmount', () {
    test('examples', () {
      for (final text in [
        '110.50',
        '110.5',
        '5.',
        '.5',
        '007',
        '0',
        '0.00',
        '10.555',
        '1234567890123',
        '999999999999.99',
      ]) {
        for (final digits in [0, 2, 3]) {
          expect(
            _asParse(evaluateExpression(text, minorDigits: digits)),
            parseAmount(text, minorDigits: digits),
            reason: '$text with $digits digits',
          );
        }
      }
    });

    test('random numbers', () {
      final random = Random(4);
      for (var i = 0; i < 2000; i++) {
        final integer = List.generate(
          random.nextInt(15),
          (_) => random.nextInt(10),
        ).join();
        final fraction = List.generate(
          random.nextInt(5),
          (_) => random.nextInt(10),
        ).join();
        final text = random.nextBool() ? '$integer.$fraction' : integer;
        final digits = random.nextInt(4);
        expect(
          _asParse(evaluateExpression(text, minorDigits: digits)),
          parseAmount(text, minorDigits: digits),
          reason: '"$text" with $digits digits',
        );
      }
    });
  });

  test('random sums and products agree with an independent oracle', () {
    final random = Random(7);
    for (var i = 0; i < 3000; i++) {
      final count = 1 + random.nextInt(5);
      String randomNumber() {
        final integer = random.nextInt(1000);
        if (!random.nextBool()) return '$integer';
        return '$integer.${random.nextInt(100).toString().padLeft(2, '0')}';
      }

      final numbers = [for (var n = 0; n < count; n++) randomNumber()];
      final ops = [for (var n = 1; n < count; n++) '+-*/'[random.nextInt(4)]];
      final text = StringBuffer(numbers[0]);
      for (var n = 1; n < count; n++) {
        text
          ..write(ops[n - 1])
          ..write(numbers[n]);
      }
      final expected = _oracle(numbers, ops);
      final actual = inr(text.toString());
      if (expected == null) {
        expect(actual, rejected(ExpressionError.divideByZero), reason: '$text');
      } else if (expected <= 0) {
        expect(actual, rejected(ExpressionError.notPositive), reason: '$text');
      } else if (expected >= 100000000000000) {
        expect(actual, rejected(ExpressionError.tooLarge), reason: '$text');
      } else {
        expect(
          (actual as ExpressionValue).amountMinor,
          expected,
          reason: '$text',
        );
      }
    }
  });

  test('terms are the additive terms, products whole', () {
    List<String> terms(String text) => (inr(text) as ExpressionValue).terms;
    expect(terms('50+60*2-10'), ['50', '+60*2', '-10']);
    expect(terms('50'), ['50']);
    expect(terms('2*3*4'), ['2*3*4']);
    expect(terms('10/2+5.+'), ['10/2', '+5']);
  });

  group('evaluateField: grouping-like operands (the other separator)', () {
    ExpressionResult en(String field, [int digits = 2]) =>
        evaluateField(field, minorDigits: digits, decimalSeparator: '.');
    ExpressionResult es(String field) =>
        evaluateField(field, minorDigits: 2, decimalSeparator: ',');
    const tooManyDecimals = ExpressionRejected(ExpressionError.tooManyDecimals);

    test('en: 1,000 × 2 is refused, 1.000 × 2 is a quantity', () {
      expect(en('1,000×2'), tooManyDecimals);
      expect(en('2×1,000'), tooManyDecimals);
      expect(en('1.000×2'), value(200));
    });

    test('es: the other way round', () {
      expect(es('1.000×2'), tooManyDecimals);
      expect(es('1,000×2'), value(200));
    });

    test('within the minor digits either separator works', () {
      expect(en('1,5×400'), value(60000));
      expect(es('1.5×400'), value(60000));
      expect(en('1,000×2', 3), value(2000), reason: 'KWD: 3 digits anyway');
    });

    test('plain terms and earlier errors are unchanged', () {
      expect(en('1,000+1'), tooManyDecimals);
      expect(
        en('5++1,000×2'),
        const ExpressionRejected(ExpressionError.invalid),
      );
      expect(en('50+60×2'), inr('50+60*2'));
      expect(en('50+'), inr('50+'));
    });
  });

  group('field and canonical forms', () {
    test('field → canonical maps the symbols and `,`', () {
      expect(fieldToCanonical('50+60×2−10÷5'), '50+60*2-10/5');
      expect(fieldToCanonical('1,5+2.5'), '1.5+2.5');
    });

    test('round trip in en and es keeps one character each', () {
      for (final (canonical, separator, field) in [
        ('50+60*2-10/4.5', '.', '50+60×2−10÷4.5'),
        ('50+60*2-10/4.5', ',', '50+60×2−10÷4,5'),
      ]) {
        final shown = canonicalToField(canonical, separator);
        expect(shown, field);
        expect(shown.length, canonical.length, reason: 'offsets preserved');
        expect(fieldToCanonical(shown), canonical);
      }
    });

    test('`1,000` typed for INR is too many decimals, never a thousand', () {
      expect(
        inr(fieldToCanonical('1,000')),
        rejected(ExpressionError.tooManyDecimals),
      );
    });

    test('display form spaces the operators', () {
      expect(displayExpression('50+60*2-10/5', '.'), '50 + 60 × 2 − 10 ÷ 5');
      expect(displayExpression('1.5*2', ','), '1,5 × 2');
      expect(displayExpression('50', '.'), '50');
    });

    test('the result line shows for an operator, `,` or two separators', () {
      expect(needsResultLine('110.50'), isFalse);
      expect(needsResultLine('110'), isFalse);
      expect(needsResultLine(''), isFalse);
      expect(needsResultLine('50+60'), isTrue);
      expect(needsResultLine('50×'), isTrue);
      expect(needsResultLine('50−'), isTrue);
      expect(needsResultLine('1,5'), isTrue);
      expect(needsResultLine('1.5.5'), isTrue);
    });
  });
}

/// [result] in parseAmount's terms, to compare the two.
AmountParse _asParse(ExpressionResult result) => switch (result) {
  ExpressionValue(:final amountMinor) => AmountParsed(amountMinor),
  ExpressionRejected(:final error) => AmountRejected(switch (error) {
    ExpressionError.empty => AmountError.empty,
    ExpressionError.invalid => AmountError.invalid,
    ExpressionError.tooLarge => AmountError.tooLarge,
    ExpressionError.tooManyDecimals => AmountError.tooManyDecimals,
    ExpressionError.notPositive => AmountError.notPositive,
    ExpressionError.divideByZero => throw StateError('not for one number'),
  }),
};

/// The exact value of `numbers ops` in paise, rounded half-up, computed a
/// different way: everything scaled to a common integer first, with Dart's
/// own BigInt, products folded before sums. Null on a division by zero.
int? _oracle(List<String> numbers, List<String> ops) {
  // Each number as a fraction over 100.
  BigInt cents(String n) {
    final [i, ...f] = n.split('.');
    return BigInt.parse(i) * BigInt.from(100) +
        BigInt.parse((f.firstOrNull ?? '').padRight(2, '0'));
  }

  // Terms as (numerator, denominator) where value = num / den paise.
  final terms = <(BigInt, BigInt, int)>[];
  var num = cents(numbers[0]);
  var den = BigInt.one;
  var sign = 1;
  for (var i = 0; i < ops.length; i++) {
    final next = cents(numbers[i + 1]);
    switch (ops[i]) {
      case '*':
        num = num * next;
        den = den * BigInt.from(100);
      case '/':
        if (next == BigInt.zero) return null;
        num = num * BigInt.from(100);
        den = den * next;
      default:
        terms.add((num, den, sign));
        num = next;
        den = BigInt.one;
        sign = ops[i] == '+' ? 1 : -1;
    }
  }
  terms.add((num, den, sign));
  var totalNum = BigInt.zero;
  var totalDen = BigInt.one;
  for (final (n, d, s) in terms) {
    totalNum = totalNum * d + BigInt.from(s) * n * totalDen;
    totalDen = totalDen * d;
  }
  if (totalNum <= BigInt.zero) return 0;
  // Half-up: floor(x + 1/2).
  return ((totalNum * BigInt.two + totalDen) ~/ (totalDen * BigInt.two))
      .toInt();
}
