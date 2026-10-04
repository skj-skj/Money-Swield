/// Amounts typed as sums: `50+60*2` (phase-4.md §5.1, D8).
///
/// Three forms of the same text, one character each, so a cursor offset
/// means the same position in all three:
///
/// - **canonical**: what is stored and evaluated. Digits, `.`, `+ - * /`.
/// - **field**: what the amount text field holds. `.` or `,` as typed,
///   `+ − × ÷`.
/// - **display**: the field form with spaces around the operators, for the
///   result line, the Itemize line and TalkBack.
///
/// Every number is an exact fraction of `BigInt`s; the result is rounded
/// once, at the end, half-up. No `double` anywhere.
library;

import 'amount_input.dart';

/// Why an expression was refused. When several apply, the first in this
/// order wins (phase-4.md §5.1 error table).
enum ExpressionError {
  empty,
  invalid,
  tooLarge,
  tooManyDecimals,
  divideByZero,
  notPositive,
}

/// The result of [evaluateExpression].
sealed class ExpressionResult {
  const ExpressionResult();
}

final class ExpressionValue extends ExpressionResult {
  const ExpressionValue({
    required this.amountMinor,
    required this.terms,
    required this.rounded,
    required this.stored,
  });

  /// The result in minor units, > 0.
  final int amountMinor;

  /// The additive terms in canonical form, the first without a sign:
  /// `50+60*2-10` → `50`, `+60*2`, `-10`. A product is one term.
  final List<String> terms;

  /// Whether rounding to the minor unit changed the exact result.
  final bool rounded;

  /// What `amount_expression` stores: normalized (no trailing operator,
  /// no trailing `.` on a number), or null when it is a single number.
  /// Always evaluates back to [amountMinor].
  final String? stored;

  @override
  bool operator ==(Object other) =>
      other is ExpressionValue &&
      other.amountMinor == amountMinor &&
      _sameList(other.terms, terms) &&
      other.rounded == rounded &&
      other.stored == stored;

  @override
  int get hashCode => Object.hash(amountMinor, Object.hashAll(terms), rounded);

  @override
  String toString() =>
      'ExpressionValue($amountMinor, $terms, rounded: $rounded, '
      'stored: $stored)';
}

final class ExpressionRejected extends ExpressionResult {
  const ExpressionRejected(this.error);

  final ExpressionError error;

  @override
  bool operator ==(Object other) =>
      other is ExpressionRejected && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'ExpressionRejected(${error.name})';
}

/// The longest expression accepted, typed or stored (P4-7).
const maxExpressionLength = 100;

/// Decimals an operand of `×` or `÷` may have (a quantity like `1.5 × 400`),
/// or the currency's minor digits if more (P4-15).
const maxOperandDecimals = 3;

const _operators = '+-*/';

/// The field form's operator symbols, by canonical operator.
const _fieldSymbols = {'-': '−', '*': '×', '/': '÷'};

/// One number: `5`, `5.`, `5.25` or `.5`.
final _number = RegExp(r'^(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$');

final _leadingZeros = RegExp('^0+');

/// Any operator, field or canonical.
final _anyOperator = RegExp('[-+*/−×÷]');

bool isOperator(String char) => _operators.contains(char) && char.isNotEmpty;

/// Evaluates [canonical] for a currency with [minorDigits] decimals.
ExpressionResult evaluateExpression(
  String canonical, {
  required int minorDigits,
}) => _evaluateText(canonical, minorDigits: minorDigits);

/// Evaluates the amount field's text ([field], field form), like
/// [evaluateExpression] on its canonical form, with one more rule: an
/// operand of × or ÷ gets the extra quantity decimals (P4-15) only when it
/// is written with the locale's [decimalSeparator]. With the other one it
/// is probably grouping: `1,000 × 2` typed for INR in English means 2000,
/// not 2.00, so it is `tooManyDecimals`, as `1,000` alone already is.
/// `1.000 × 2` (the locale's separator) is still a quantity.
ExpressionResult evaluateField(
  String field, {
  required int minorDigits,
  required String decimalSeparator,
}) => _evaluateText(
  fieldToCanonical(field),
  minorDigits: minorDigits,
  field: field,
  decimalSeparator: decimalSeparator,
);

/// [canonical] evaluated; [field], when given, is the same text in field
/// form (one character each), to see which separator each number was
/// typed with.
ExpressionResult _evaluateText(
  String canonical, {
  required int minorDigits,
  String? field,
  String decimalSeparator = '.',
}) {
  // A trailing operator is ignored, like a trailing `.` (P4-4).
  var text = canonical;
  if (text.isNotEmpty && isOperator(text[text.length - 1])) {
    text = text.substring(0, text.length - 1);
  }
  if (text.isEmpty) return const ExpressionRejected(ExpressionError.empty);
  if (canonical.length > maxExpressionLength) {
    return const ExpressionRejected(ExpressionError.invalid);
  }

  final tokens = _tokenize(text);
  if (tokens == null) return const ExpressionRejected(ExpressionError.invalid);

  // The separator that isn't the locale's, when the field text is known.
  final foreign = field == null ? null : (decimalSeparator == ',' ? '.' : ',');
  // Each number with whether it is an operand of × or ÷, and whether it
  // was typed with the foreign separator.
  final numbers = <_Number>[];
  var offset = 0;
  for (var i = 0; i < tokens.length; i += 2) {
    final token = tokens[i];
    final multiplied =
        (i > 0 && '*/'.contains(tokens[i - 1])) ||
        (i + 1 < tokens.length && '*/'.contains(tokens[i + 1]));
    final typedForeign =
        foreign != null &&
        field!.substring(offset, offset + token.length).contains(foreign);
    numbers.add(_Number.parse(token, quantity: multiplied && !typedForeign));
    // The number and the operator after it.
    offset += token.length + 1;
  }
  if (numbers.any((n) => n.integerDigits > maxIntegerDigits)) {
    return const ExpressionRejected(ExpressionError.tooLarge);
  }
  final operandDecimals = minorDigits > maxOperandDecimals
      ? minorDigits
      : maxOperandDecimals;
  if (numbers.any(
    (n) => n.decimals > (n.quantity ? operandDecimals : minorDigits),
  )) {
    return const ExpressionRejected(ExpressionError.tooManyDecimals);
  }

  final exact = _evaluate(tokens, numbers);
  if (exact == null) {
    return const ExpressionRejected(ExpressionError.divideByZero);
  }

  final (amountMinor, rounded) = exact.roundHalfUp(minorDigits);
  final limit = BigInt.from(10).pow(maxIntegerDigits + minorDigits);
  if (amountMinor.abs() >= limit) {
    return const ExpressionRejected(ExpressionError.tooLarge);
  }
  if (amountMinor <= BigInt.zero) {
    return const ExpressionRejected(ExpressionError.notPositive);
  }

  final normalized = [
    for (var i = 0; i < tokens.length; i++)
      i.isEven ? _dropTrailingPoint(tokens[i]) : tokens[i],
  ];
  return ExpressionValue(
    amountMinor: amountMinor.toInt(),
    terms: _terms(normalized),
    rounded: rounded,
    stored: normalized.length == 1 ? null : normalized.join(),
  );
}

/// The field form ([field]) as canonical: `−`→`-`, `×`→`*`, `÷`→`/`,
/// `,`→`.`. Any other character is kept (and then refused as invalid).
String fieldToCanonical(String field) {
  final out = StringBuffer();
  for (final rune in field.runes) {
    final char = String.fromCharCode(rune);
    out.write(switch (char) {
      '−' => '-',
      '×' => '*',
      '÷' => '/',
      ',' => '.',
      _ => char,
    });
  }
  return out.toString();
}

/// [canonical] as the field shows it, with [decimalSeparator] (`.` or
/// `,`, the formatting locale's, P4-5).
String canonicalToField(String canonical, String decimalSeparator) {
  final out = StringBuffer();
  for (final rune in canonical.runes) {
    final char = String.fromCharCode(rune);
    out.write(_fieldSymbols[char] ?? (char == '.' ? decimalSeparator : char));
  }
  return out.toString();
}

/// [canonical] in display form: the field form with a space on each side
/// of every operator, `50 + 60 × 2`.
String displayExpression(String canonical, String decimalSeparator) {
  final out = StringBuffer();
  for (final rune in canonical.runes) {
    final char = String.fromCharCode(rune);
    if (isOperator(char)) {
      out.write(' ${_fieldSymbols[char] ?? char} ');
    } else {
      out.write(char == '.' ? decimalSeparator : char);
    }
  }
  return out.toString();
}

/// Whether the field text holds an operator symbol (field or canonical).
bool hasOperator(String text) => _anyOperator.hasMatch(text);

/// Whether the result line shows under the amount: an operator, a `,`, or
/// two separators (R8). A plain `110.50` needs no line.
bool needsResultLine(String fieldText) =>
    hasOperator(fieldText) || amountNeedsPreview(fieldText);

/// [text] split into number, operator, number, …, or null when it doesn't
/// follow `number (op number)*`.
List<String>? _tokenize(String text) {
  final tokens = <String>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    if (!isOperator(text[i])) continue;
    tokens
      ..add(text.substring(start, i))
      ..add(text[i]);
    start = i + 1;
  }
  tokens.add(text.substring(start));
  for (var i = 0; i < tokens.length; i += 2) {
    if (!_number.hasMatch(tokens[i])) return null;
  }
  return tokens;
}

String _dropTrailingPoint(String number) =>
    number.endsWith('.') ? number.substring(0, number.length - 1) : number;

/// The additive terms of normalized [tokens], each but the first with its
/// sign.
List<String> _terms(List<String> tokens) {
  final terms = <String>[];
  final current = StringBuffer();
  for (final token in tokens) {
    if ((token == '+' || token == '-') && current.isNotEmpty) {
      terms.add(current.toString());
      current.clear();
    }
    current.write(token);
  }
  terms.add(current.toString());
  return terms;
}

/// × and ÷ first, then + and −, left to right. Null on a division by zero.
_Fraction? _evaluate(List<String> tokens, List<_Number> numbers) {
  var sum = _Fraction.zero;
  var term = numbers[0].value;
  var sign = 1;
  for (var i = 1; i < tokens.length; i += 2) {
    final op = tokens[i];
    final next = numbers[(i + 1) ~/ 2].value;
    switch (op) {
      case '*':
        term = term.times(next);
      case '/':
        if (next.isZero) return null;
        term = term.dividedBy(next);
      default:
        sum = sum.plus(term, sign);
        term = next;
        sign = op == '+' ? 1 : -1;
    }
  }
  return sum.plus(term, sign);
}

class _Number {
  _Number.parse(String text, {required this.quantity})
    : integerDigits = text.split('.')[0].replaceFirst(_leadingZeros, '').length,
      decimals = text.contains('.') ? text.split('.')[1].length : 0,
      value = _Fraction.parse(text);

  /// May have up to [maxOperandDecimals] decimals: an operand of × or ÷
  /// typed with the locale's separator (P4-15).
  final bool quantity;
  final int integerDigits;
  final int decimals;
  final _Fraction value;
}

/// An exact rational number, [numerator] / [denominator], denominator > 0.
class _Fraction {
  const _Fraction(this.numerator, this.denominator);

  static final zero = _Fraction(BigInt.zero, BigInt.one);

  factory _Fraction.parse(String number) {
    final [integer, ...rest] = number.split('.');
    final fraction = rest.firstOrNull ?? '';
    final digits = '$integer$fraction';
    return _Fraction(
      BigInt.parse(digits.isEmpty ? '0' : digits),
      BigInt.from(10).pow(fraction.length),
    );
  }

  final BigInt numerator;
  final BigInt denominator;

  bool get isZero => numerator == BigInt.zero;

  _Fraction times(_Fraction other) =>
      _Fraction(numerator * other.numerator, denominator * other.denominator);

  _Fraction dividedBy(_Fraction other) =>
      _Fraction(numerator * other.denominator, denominator * other.numerator);

  _Fraction plus(_Fraction other, int sign) => _Fraction(
    numerator * other.denominator +
        BigInt.from(sign) * other.numerator * denominator,
    denominator * other.denominator,
  );

  /// In units of 10^-[digits], rounded half away from zero (half-up for
  /// the positive amounts that are kept), and whether that changed it.
  (BigInt, bool) roundHalfUp(int digits) {
    final scaled = numerator.abs() * BigInt.from(10).pow(digits);
    final two = BigInt.two;
    final magnitude = (scaled * two + denominator) ~/ (denominator * two);
    final exact = scaled % denominator == BigInt.zero;
    return (numerator.isNegative ? -magnitude : magnitude, !exact);
  }
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
