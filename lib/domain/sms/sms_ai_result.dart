/// The on-device model's answer for one SMS, checked before anything of it is
/// used. Pure Dart.
library;

import 'dart:convert';

import 'package:characters/characters.dart';

import '../models/expense.dart' show maxTitleLength;
import '../title_suggestions.dart' show foldTitle;
import 'sms_ai_prompt.dart';
import 'sms_amount.dart';
import 'sms_text.dart';

/// What the model found in one SMS, after [acceptAiResult]'s checks.
/// Never holds the text.
typedef AiParse = ({
  int amountMinor,
  String? payee,

  /// As the model wrote it, trimmed and cut; the scan cleans it like a
  /// payee (`cleanPayee`).
  String? title,

  /// One of [aiPaymentKeys], or null: the regex text rule decides.
  String? paymentMethodKey,

  /// One of the categories offered, or null.
  int? categoryId,
});

/// The answer's JSON object: from the first `{` to the last `}`. The fast model
/// on the owner's Pixel wraps it in a Markdown fence (```` ```json … ``` ````)
/// though told not to (gate).
final _object = RegExp(r'\{.*\}', dotAll: true);

/// [answer] for the SMS [body], or null when it can't be trusted: then the
/// regex reads that SMS in the same scan (still parsed once).
///
/// - Not one JSON object, or `"is_debit"` not exactly `true` → null. A
///   "not a debit" goes to the regex too: one wrong answer must not lose
///   an expense.
/// - `"amount"` (a string or a number) must be one of the amounts the
///   text itself writes before its footer ([amountsInText]): the model
///   never invents, rounds or picks a balance. Else null.
/// - `"title"` and `"payee"`: strings, trimmed, cut to [maxTitleLength]
///   characters; empty → none.
/// - `"payment"`: one of [aiPaymentKeys], else none.
/// - `"category"`: one of [categories]' names, compared folded (an exact
///   match wins when two names fold alike); `"none"` (in any case, even
///   with a category of that name) or another → none.
///
/// Extra keys are ignored.
AiParse? acceptAiResult(
  String answer,
  String body,
  List<CategoryName> categories,
) {
  final json = _decodeObject(answer);
  if (json == null || json['is_debit'] != true) return null;
  final amount = _amountOf(json['amount'], body);
  if (amount == null) return null;
  final payment = json['payment'];
  return (
    amountMinor: amount,
    payee: _text(json['payee']),
    title: _text(json['title']),
    paymentMethodKey: payment is String && aiPaymentKeys.contains(payment)
        ? payment
        : null,
    categoryId: _categoryOf(json['category'], categories),
  );
}

Map<String, Object?>? _decodeObject(String answer) {
  final match = _object.firstMatch(answer);
  if (match == null) return null;
  try {
    final decoded = jsonDecode(match[0]!);
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// [value] in paise when the text writes that amount; else null. A JSON
/// number is read through its own text: an integer as is, a double only
/// when its text is plain digits (`150.5`), never as `1.5e2`.
int? _amountOf(Object? value, String body) {
  final digits = switch (value) {
    final String s => s.trim(),
    final int n => '$n',
    final double d => '$d',
    _ => null,
  };
  if (digits == null) return null;
  final minor = parseAmountMinor(digits);
  if (minor == null) return null;
  return amountsInText(withoutFooter(smsText(body))).contains(minor)
      ? minor
      : null;
}

String? _text(Object? value) {
  if (value is! String) return null;
  final chars = value.trim().characters;
  if (chars.isEmpty) return null;
  return chars.length > maxTitleLength
      ? chars.take(maxTitleLength).toString().trim()
      : chars.toString();
}

int? _categoryOf(Object? value, List<CategoryName> categories) {
  if (value is! String) return null;
  final name = value.trim();
  final folded = foldTitle(name);
  // The prompt's word for "no category": never a user's category that
  // happens to be called "None".
  if (folded == foldTitle('none')) return null;
  for (final category in categories) {
    if (category.name == name) return category.id;
  }
  for (final category in categories) {
    if (foldTitle(category.name.trim()) == folded) return category.id;
  }
  return null;
}
