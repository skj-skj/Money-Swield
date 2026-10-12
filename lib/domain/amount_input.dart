/// Turning what the user typed in the amount field into minor units and back.
/// Works on the digits of the string only, never through `double`, so nothing
/// is ever rounded.
library;

/// Why a typed amount was refused. When several apply, the first in this
/// order wins.
enum AmountError { empty, invalid, tooLarge, tooManyDecimals, notPositive }

/// The result of [parseAmount]: [AmountParsed] or [AmountRejected].
sealed class AmountParse {
  const AmountParse();
}

final class AmountParsed extends AmountParse {
  const AmountParsed(this.amountMinor);

  final int amountMinor;

  @override
  bool operator ==(Object other) =>
      other is AmountParsed && other.amountMinor == amountMinor;

  @override
  int get hashCode => amountMinor.hashCode;

  @override
  String toString() => 'AmountParsed($amountMinor)';
}

final class AmountRejected extends AmountParse {
  const AmountRejected(this.error);

  final AmountError error;

  @override
  bool operator ==(Object other) =>
      other is AmountRejected && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'AmountRejected(${error.name})';
}

/// At most this many digits before the separator, leading zeros not counted.
/// Keeps one amount at 15 significant digits or fewer even for a 3-digit
/// currency, which a double (used only to display it) holds exactly.
const maxIntegerDigits = 12;

final _digitsOnly = RegExp(r'^[0-9]*$');

/// Parses [text] typed for a currency with [minorDigits] decimals.
///
/// One `.` or `,` is the decimal separator (Spanish keyboards type `,`).
/// Grouping separators aren't accepted, so `1,000` for INR is
/// [AmountError.tooManyDecimals], never ₹1.00. A trailing separator (`5.`)
/// is fine: the field holds it while the user is typing.
AmountParse parseAmount(String text, {required int minorDigits}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const AmountRejected(AmountError.empty);

  final separators = RegExp('[.,]').allMatches(trimmed).length;
  if (separators > 1) return const AmountRejected(AmountError.invalid);
  final parts = trimmed.split(RegExp('[.,]'));
  final integer = parts[0];
  final fraction = parts.length > 1 ? parts[1] : '';
  if (!_digitsOnly.hasMatch(integer) ||
      !_digitsOnly.hasMatch(fraction) ||
      integer.isEmpty && fraction.isEmpty) {
    return const AmountRejected(AmountError.invalid);
  }

  final significant = integer.replaceFirst(RegExp('^0+'), '');
  if (significant.length > maxIntegerDigits) {
    return const AmountRejected(AmountError.tooLarge);
  }
  if (fraction.length > minorDigits) {
    return const AmountRejected(AmountError.tooManyDecimals);
  }

  final amountMinor = int.parse(
    '${significant.isEmpty ? '0' : significant}'
    '${fraction.padRight(minorDigits, '0')}',
  );
  if (amountMinor <= 0) return const AmountRejected(AmountError.notPositive);
  return AmountParsed(amountMinor);
}

/// Whether the live preview should show under the amount field: the text has a
/// `,` or more than one `.`. For 3-digit currencies `1,000` is one dinar, not a
/// thousand, and only the preview tells the user which one they typed.
bool amountNeedsPreview(String text) =>
    text.contains(',') || '.'.allMatches(text).length > 1;

/// [amountMinor] as the edit form prefills it: `110.50`, `500` for a
/// 0-digit currency. Always `.`, which [parseAmount] takes back.
String formatAmountForInput(int amountMinor, int minorDigits) {
  if (minorDigits == 0) return '$amountMinor';
  final digits = '$amountMinor'.padLeft(minorDigits + 1, '0');
  final split = digits.length - minorDigits;
  return '${digits.substring(0, split)}.${digits.substring(split)}';
}
