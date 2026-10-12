/// The title suggested for an SMS, and the payee key the learning matches on.
/// Pure Dart.
library;

import 'sms_payment_method.dart' show isUpiId;

/// Company suffixes banks leave on a payee, whole or cut short (banks cut
/// names at ~25 letters: F4's "GLOBEX TECHNOLOGIES PRIVA"). Dropped from
/// the end while one is last; compared upper-cased.
const payeeSuffixes = {
  'PRIVATE',
  'PRIVA',
  'PRIV',
  'PVT',
  'PVT.',
  'LTD',
  'LTD.',
  'LIMITED',
  'LIMI',
};

final _spaces = RegExp(r'\s+');
final _lowerCase = RegExp(r'[a-z]');
final _ascii = RegExp(r'^[\x20-\x7E]*$');
final _asciiLetter = RegExp(r'[A-Z]');

/// Payees at least this long may end in a word the bank cut short.
const _cutLength = 20;

/// The words a cut suffix is the start of.
const _cutSuffixOf = ['PRIVATE', 'LIMITED', 'LTD'];

/// [payee]'s words, spaces collapsed, with trailing [payeeSuffixes]
/// dropped. A UPI ID is one word and never loses anything.
///
/// A long payee (banks cut names at about 25 characters) also loses a last word
/// that is the start of one of [_cutSuffixOf]: "GLOBEX DESIGNS PRIVATE LI",
/// "Example Clearing Corporation Lt" (found on the Oppo). A short name keeps
/// such a word ("ZEN LI").
List<String> _payeeWords(String payee) {
  final words = payee.trim().split(_spaces)..removeWhere((w) => w.isEmpty);
  if (words.length == 1 && isUpiId(words.single)) return words;
  if (words.length > 1 && words.join(' ').length >= _cutLength) {
    final last = words.last.toUpperCase();
    if (last.length >= 2 && _cutSuffixOf.any((w) => w.startsWith(last))) {
      words.removeLast();
    }
  }
  while (words.isNotEmpty && payeeSuffixes.contains(words.last.toUpperCase())) {
    words.removeLast();
  }
  return words;
}

/// [payee] as a title: suffixes dropped, an all-caps ASCII name
/// title-cased (`ACME MARKETPLACE` → `Acme Marketplace`); a name with
/// lower-case letters, no letters, or non-ASCII letters is kept as is, and
/// so is a UPI ID. Null when nothing is left ("PRIVATE" alone).
String? cleanPayee(String? payee) {
  if (payee == null) return null;
  final words = _payeeWords(payee);
  if (words.isEmpty) return null;
  final name = words.join(' ');
  if (isUpiId(name)) return name;
  final allCapsAscii =
      _ascii.hasMatch(name) &&
      _asciiLetter.hasMatch(name) &&
      !_lowerCase.hasMatch(name);
  if (!allCapsAscii) return name;
  return [
    for (final word in words)
      word.substring(0, 1) + word.substring(1).toLowerCase(),
  ].join(' ');
}

/// The key two spellings of one payee share: lower-cased (Unicode, in Dart: SQL
/// folds ASCII only in tests), spaces collapsed, suffixes dropped. "ACME
/// MARKETPLACE PRIVATE" and "Acme Marketplace Priva" are one payee. Null when
/// nothing is left.
String? payeeKeyOf(String? payee) {
  if (payee == null) return null;
  final words = _payeeWords(payee);
  return words.isEmpty ? null : words.join(' ').toLowerCase();
}

/// The suggested title, the first that gives one: the [learned] title of the
/// payee's newest SMS-added expense, the on-device model's title [ai], then
/// [cleanPayee]. Null: the form's title stays empty and Save asks for it.
///
/// The model's title is cleaned like a payee: it often repeats the bank's
/// all-caps name ("AMAZON", "GLOBEX TECHNOLOGIES"), which then reads as
/// "Amazon" like a regex card does (gate).
String? suggestedTitle({String? learned, String? ai, String? payee}) {
  final fromLearning = learned?.trim();
  if (fromLearning != null && fromLearning.isNotEmpty) return fromLearning;
  return cleanPayee(ai) ?? cleanPayee(payee);
}
