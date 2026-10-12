/// The payment method of an SMS debit (owner rev 5): from the words in the
/// text, never an account or card number. Pure Dart.
library;

/// `upi` as a word, or `vpa`.
final _upiWord = RegExp(r'\b(?:upi|vpa)\b', caseSensitive: false);

/// A UPI ID (`name@bank`), not an e-mail address: the handle after `@` is
/// letters only and isn't followed by `.letter` (`x@gmail.com`) or another
/// letter or digit. A full stop that ends the sentence is fine: sample #5 ends
/// "…@ybl. If not you" — the doc's "not followed by `.`" would make it a debit
/// card.
final _upiId = RegExp(
  r'[\w.\-]+@[a-z]+(?![a-z0-9]|\.[a-z0-9])',
  caseSensitive: false,
);

final _creditCard = RegExp(r'\bcredit\s+card\b', caseSensitive: false);

/// `upi`, `credit_card` or `debit_card` (the default), the first that
/// matches [text]. Reads the **whole** text, footer included: some banks'
/// "Sent Rs" SMS say UPI only in their footer ("SMS BLOCK UPI"). UPI is
/// checked first, so a UPI payment from a RuPay credit card is UPI.
String paymentMethodKeyOf(String text) {
  if (_upiWord.hasMatch(text) || _upiId.hasMatch(text)) return 'upi';
  if (_creditCard.hasMatch(text)) return 'credit_card';
  return 'debit_card';
}

/// Whether [text] is a UPI ID as [_upiId] reads one, whole.
bool isUpiId(String text) {
  final match = _upiId.firstMatch(text);
  return match != null && match.start == 0 && match.end == text.length;
}
