/// The prompt the on-device model reads for one bank SMS (phase-9b.md
/// §5.1). Pure Dart.
library;

import 'dart:convert';

/// A category the model may pick: its id and the name the user sees
/// (built-ins localized, R16). The UI builds these; the domain never
/// imports l10n.
typedef CategoryName = ({int id, String name});

/// The largest prompt sent, in UTF-8 bytes; a larger one → the regex
/// reads that SMS (§5.2).
///
/// Bytes, not characters: one Devanagari letter is 3 bytes, an emoji 4,
/// and the tokenizer works on bytes. Measured on the Pixel 11 Pro's
/// `nano-v4-fast` (`countTokens`, phase-9b.md §12a): 0.2 (Hindi) to 0.64
/// (digits) tokens a byte, and a limit of 8,192 tokens, not the 4,000 the
/// docs say. So 8,000 bytes stays under about 5,100 tokens. A model with a
/// smaller limit refuses a longer prompt itself (`REQUEST_TOO_LARGE`, read
/// as `failed`): the regex reads that SMS too, so nothing is lost either
/// way.
const aiPromptMaxBytes = 8000;

/// The payment method keys the model may answer, as 9a stores them
/// (P9a-53).
const aiPaymentKeys = ['upi', 'credit_card', 'debit_card'];

/// The prompt for [body] with the user's [categories] to pick from, or
/// null when it would exceed [aiPromptMaxBytes]. The model is told to
/// answer **only** one JSON object (P9b-55); `acceptAiResult` checks it.
///
/// The SMS goes last, between markers, so its own words read as data, not
/// as part of the instructions; whatever it makes the model say is still
/// checked against the text (the amount) and the list (the category).
String? buildAiPrompt(String body, List<CategoryName> categories) {
  final names = [for (final c in categories) '- ${c.name}'].join('\n');
  final prompt =
      'You read one bank SMS from India. Answer with only one JSON object '
      'and nothing else, with these keys:\n'
      '"is_debit": true if money left the account or card (a payment, '
      'purchase, transfer, mandate or debit); false for an OTP, a '
      'credit, a refund, a balance or a reminder.\n'
      '"amount": the amount debited, as written in the SMS, without the '
      'currency (for "Rs.1,250.00" answer "1,250.00").\n'
      '"payee": who was paid, as written in the SMS, or "".\n'
      // Asked for "a short title like 'Acme groceries'", the Pixel's model
      // dropped words of the name ("DOSA CORNER" for "KAMAT DOSA CORNER",
      // "TECHNOLOGIES PRIVA" for "SHOPSY TECHNOLOGIES PRIVA"); asked for
      // the whole name, it kept it (made-up SMS, phase-9b.md §12a).
      '"title": the name of the shop, service or person paid, in normal '
      'capitals, keeping every word of the name but leaving out company '
      'words like Private, Pvt, Limited, Ltd, Technologies; or "".\n'
      '"payment": "upi", "credit_card" or "debit_card".\n'
      '"category": the category from this list that fits best, copied '
      'exactly; "none" only when none fits:\n'
      '$names\n'
      'SMS:\n'
      '<<<\n'
      '$body\n'
      '>>>';
  return utf8.encode(prompt).length <= aiPromptMaxBytes ? prompt : null;
}
