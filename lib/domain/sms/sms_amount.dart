/// Amounts in bank SMS (phase-9a.md §5.2 step 3, §5.6). Read as text into
/// integer minor units, never through `double`. Pure Dart.
library;

import '../amount_input.dart' show maxIntegerDigits;

/// INR has 2 minor digits; SMS suggestions are always INR (P9a-31).
const _minorDigits = 2;

/// Plain digits, or digits grouped by commas: a first group of 1–3, then
/// groups of 2 or 3 (Indian `1,23,456` and western `123,456`), the last
/// one of 3. Then an optional `.d` or `.dd`.
final _amountText = RegExp(
  r'^([0-9]+|[0-9]{1,3}(?:,[0-9]{2,3})*,[0-9]{3})(?:\.([0-9]{1,2}))?$',
);

/// [digits] (as the SMS writes it, no currency) in paise, or null when it
/// isn't a clear amount: `0`, `.50`, `1,2,3`, `1,,000`, `12.345`, more than
/// [maxIntegerDigits] integer digits. Never rounded (P9a-32).
int? parseAmountMinor(String digits) {
  final match = _amountText.firstMatch(digits);
  if (match == null) return null;
  final whole = match[1]!.replaceAll(',', '').replaceFirst(RegExp('^0+'), '');
  if (whole.length > maxIntegerDigits) return null;
  final fraction = (match[2] ?? '').padRight(_minorDigits, '0');
  final minor = int.parse('${whole.isEmpty ? '0' : whole}$fraction');
  return minor > 0 ? minor : null;
}

/// An amount's digits, commas and points, as far as they go, ending in a
/// digit (a trailing comma or full stop is punctuation: "Rs 500, debited",
/// "Rs.5000."). Taken whole and judged by [parseAmountMinor]: "Rs 12.345"
/// is then no amount, never skipped for a later one (which may be the
/// balance).
const _number = r'([0-9](?:[0-9,.]*[0-9])?)';

/// `Rs`, `Rs.`, `INR` or `₹` before the number, with no letter right
/// before the currency ("hou**rs 30**", "use**rs 100**" aren't amounts).
final _currencyFirst = RegExp(
  r'(?<![a-z])(?:rs\.?|inr|₹)\s*' + _number,
  caseSensitive: false,
);

/// "500 INR", "500 Rs": the number first, not part of a longer number or
/// of a word ("XX1234 INR 500": the 1234 is a card number).
final _currencyLast = RegExp(
  r'(?<![0-9a-z.,*/])' + _number + r'\s*(?:inr|rs)\b',
  caseSensitive: false,
);

/// Words after which an amount is a balance or a limit, not what was paid.
final _notPaidWord = RegExp(
  r'\b(?:bal|balance|avl|avbl|available|limit|lmt)\b',
  caseSensitive: false,
);

/// How far after one of [_notPaidWord] an amount still belongs to it.
const _notPaidReach = 15;

/// The amount paid in [text] (§5.2 step 3) in paise, or null. The first
/// amount that isn't a balance or a limit decides: when it isn't a clear
/// amount ([parseAmountMinor]) the result is null, never a later amount,
/// which may be the balance (never guessed, application-design §8.1).
///
/// "500 INR" is read only when the text has no "INR 500"-style amount at
/// all: in "A/c 1234 INR 500 debited" it would read the account number
/// (phase-9a.md §12a).
int? findAmountMinor(String text) {
  final first = _currencyFirst.allMatches(text).toList();
  final found = first.isNotEmpty
      ? first
      : _currencyLast.allMatches(text).toList();
  for (final match in found) {
    if (_isBalance(text, match.start)) continue;
    return parseAmountMinor(match[1]!);
  }
  return null;
}

/// Every amount [text] writes with its currency (`Rs`, `INR`, `₹`, before
/// or after), in paise, leaving out balances and limits (phase-9b.md §5.2):
/// what the on-device model may answer. Each is judged by
/// [parseAmountMinor], so "150", "150.0" and "150.00" are one amount and
/// "1500" is not "150.00".
///
/// Only amounts with a currency: the doc's "appears literally in the text"
/// let a 12-digit reference ("Ref 100000000001") or the footer's phone
/// number through as an amount (phase-9b.md §12a). Nothing is lost: an SMS
/// reaches the model only when it has such an amount (§5.1).
Set<int> amountsInText(String text) => {
  for (final match in [
    ..._currencyFirst.allMatches(text),
    ..._currencyLast.allMatches(text),
  ])
    if (!_isBalance(text, match.start)) ?parseAmountMinor(match[1]!),
};

/// Whether the amount at [start] comes within [_notPaidReach] characters
/// after a balance or limit word **with no other number between them**:
/// "Avl Lmt INR 50,000" is a limit; in "Avl Bal Rs 10,000. Rs 250
/// debited" the 250 is 12 characters after "Bal" but the 10,000 is
/// between, so it is the payment (phase-9a.md §12a: the doc's plain
/// 15-character rule would refuse it).
bool _isBalance(String text, int start) {
  for (final word in _notPaidWord.allMatches(text)) {
    if (word.end > start) break;
    final between = text.substring(word.end, start);
    if (between.length <= _notPaidReach && !between.contains(RegExp('[0-9]'))) {
      return true;
    }
  }
  return false;
}
