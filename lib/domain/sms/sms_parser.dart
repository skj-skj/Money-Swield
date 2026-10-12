/// Bank SMS parsers: one class per country's banks. Pure Dart, so the scan runs
/// a parser in `Isolate.run`.
library;

import 'package:characters/characters.dart';

import '../models/expense.dart' show maxTitleLength;
import 'sms_amount.dart';
import 'sms_payment_method.dart';
import 'sms_text.dart';

/// What a parser found in one SMS. Never holds the text.
typedef SmsParse = ({
  int amountMinor,
  String paymentMethodKey,
  String? payee,
  String? reference,
});

/// Reads one country's bank debit SMS.
abstract interface class SmsParser {
  /// Whether the SMS from [sender] with [body] may be a debit worth
  /// parsing. Cheap: it runs on every inbox row the scan reads.
  bool isDebitCandidate(String sender, String body);

  /// [body] parsed as a debit, or null when it has no clear amount (never
  /// guessed). Call it only on a candidate.
  SmsParse? parse(String body);

  /// Everything [parse] reads but the amount. The on-device model's path takes
  /// the amount from the model and these from here: the reference keeps the
  /// duplicate check, and the payee keeps one payee key per payee for the
  /// learning.
  SmsDetails details(String body);
}

/// [SmsParse] without the amount.
typedef SmsDetails = ({
  String paymentMethodKey,
  String? payee,
  String? reference,
});

/// Indian bank debits (India only for now).
class IndiaSmsParser implements SmsParser {
  const IndiaSmsParser();

  /// Words that say money left the account. Whole words only: a substring
  /// match would read "de**pos**ited" as a card payment.
  static const debitWords = [
    'debited',
    'spent',
    'paid',
    'sent',
    'withdrawn',
    'withdrawal',
    'purchase',
    'deducted',
    'charged',
    'debit',
  ];

  /// Words that say it isn't a payment that happened: an OTP, a future or
  /// failed debit, a request, money coming in.
  static const notPaymentWords = [
    'otp',
    'one time password',
    'will be debited',
    'to be debited',
    'is due',
    'due on',
    'due date',
    'request',
    'requested',
    'collect',
    'failed',
    'declined',
    'unsuccessful',
    'reversed',
    'refund',
    'cashback',
    'credited to your',
    'received',
  ];

  /// The pre-filter rules, in order. Reads the body with its footer cut off
  /// ([withoutFooter]): footers say "if not requested by you".
  @override
  bool isDebitCandidate(String sender, String body) {
    final from = sender.trim();
    if (_promotional.hasMatch(from) || _phoneNumber.hasMatch(from)) {
      return false;
    }
    final text = withoutFooter(smsText(body));
    if (findAmountMinor(text) == null) return false;
    if (!_debit.hasMatch(text)) return false;
    if (_notPayment.hasMatch(text)) return false;
    if (_withdraw.hasMatch(text) &&
        (_atm.hasMatch(text) || _card.hasMatch(text))) {
      return false;
    }
    if (_cashWithdrawal.hasMatch(text)) return false;
    return true;
  }

  /// The body's own date ("On 14/03/26") is not read: the expense gets the time
  /// the SMS came.
  @override
  SmsParse? parse(String body) {
    final amount = findAmountMinor(withoutFooter(smsText(body)));
    if (amount == null) return null;
    final found = details(body);
    return (
      amountMinor: amount,
      paymentMethodKey: found.paymentMethodKey,
      payee: found.payee,
      reference: found.reference,
    );
  }

  @override
  SmsDetails details(String body) {
    final text = smsText(body);
    final main = withoutFooter(text);
    return (
      paymentMethodKey: paymentMethodKeyOf(text),
      payee: _payee(main),
      reference: _reference.firstMatch(main)?[1]?.toUpperCase(),
    );
  }
}

RegExp _anyWord(List<String> words) => RegExp(
  '\\b(?:${[for (final w in words) RegExp.escape(w).replaceAll(' ', r'\s+')].join('|')})\\b',
  caseSensitive: false,
);

final _debit = _anyWord(IndiaSmsParser.debitWords);
final _notPayment = _anyWord(IndiaSmsParser.notPaymentWords);

/// ATM withdrawals are never suggested (owner rev 3): the cash is entered by
/// hand when it is spent, so suggesting the withdrawal would count it twice.
final _atm = RegExp(r'\batm\b', caseSensitive: false);
final _withdraw = RegExp(
  r'\b(?:withdraw|withdrawal|withdrawn)\b',
  caseSensitive: false,
);
final _cashWithdrawal = RegExp(r'\bcash\s+withdrawal\b', caseSensitive: false);

/// Cash taken out with a card, at an ATM or a bank branch: some banks write
/// `Withdrawn Rs.AMOUNT From BANK Card xNNNN At PLACE` without the word ATM
/// (found on a test phone).
final _card = RegExp(r'\bcard\b', caseSensitive: false);

/// A phone number: `+` first, or only digits. Banks send from IDs; a
/// person's "sent you Rs 500" is not the user's debit.
final _phoneNumber = RegExp(r'^(?:\+.*|[0-9]+)$');

/// Indian sender IDs end in `-P` for promotions.
final _promotional = RegExp(r'-P$', caseSensitive: false);

/// `to X`, `at X`, `towards X` (an optional `:`). X runs to the end of the
/// line or to [_payeeEnd].
final _payeeStart = RegExp(
  r'\b(?:towards|to|at)\b:?[ ]*',
  caseSensitive: false,
);

/// Where a payee stops: ` on `, ` ref`, ` via`, ` avl`, ` UMRN` (a NACH
/// mandate's number, found on the Oppo), a comma, `. ` or a
/// full stop at the end. The line's end stops it too ([_payeeAfter] reads
/// one line).
final _payeeEnd = RegExp(
  r'\s+(?:on|ref|via|avl|umrn|umn|upi\s+ref)\b|,|\.\s|\.$',
  caseSensitive: false,
);

/// "VPA abc@ybl": the word VPA isn't part of the payee.
final _vpaPrefix = RegExp(r'^vpa\b:?\s*', caseSensitive: false);

/// "M/s. Acme Stores", "Mr. Ravi Kumar": the title isn't part of the
/// payee, and its full stop would end the payee at [_payeeEnd]'s `. `,
/// leaving only "M/s" (and one payee key, `mr`, shared by strangers).
final _honorific = RegExp(
  r'^(?:m/s|mr|mrs|ms|dr|shri|smt)\.?\s+(?=\S)',
  caseSensitive: false,
);

final _hasLetter = RegExp(r'\p{L}', unicode: true);

/// Ref / RRN / UTR / Txn ID, then a code of 6+ letters and digits that holds a
/// digit: "Reference Number 1234…" must not give `NUMBER`, which would make
/// every later SMS with that wording a duplicate.
final _reference = RegExp(
  r'\b(?:ref(?:erence)?(?:\s+no|\s+number)?|rrn|utr(?:\s+no|\s+number)?|'
  r'txn\s+id)\s*[:.]?\s*((?=[a-z]*[0-9])[a-z0-9]{6,})',
  caseSensitive: false,
);

/// The first `to / at / towards` that gives a payee: one whose first word
/// has a letter ("at 14:05" doesn't; "9876543210@ybl" does), spaces
/// collapsed, cut to [maxTitleLength]
/// characters. The doc says "the earliest match"; taking the earliest
/// *usable* one keeps "on 01-10 at 14:05 to AMAZON".
String? _payee(String text) {
  for (final start in _payeeStart.allMatches(text)) {
    final payee = _payeeAfter(text.substring(start.end));
    if (payee != null) return payee;
  }
  return null;
}

String? _payeeAfter(String rest) {
  final line = rest
      .split('\n')
      .first
      .replaceFirst(_vpaPrefix, '')
      .replaceFirst(_honorific, '');
  final end = _payeeEnd.firstMatch(line);
  var payee = (end == null ? line : line.substring(0, end.start))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (payee.endsWith('.')) payee = payee.substring(0, payee.length - 1).trim();
  // A first word without a letter is a time, a date or a number ("at
  // 14:05 to ACME"): not a payee; the next "to / at" may give one.
  if (!_hasLetter.hasMatch(payee.split(' ').first)) return null;
  final chars = payee.characters;
  return chars.length > maxTitleLength
      ? chars.take(maxTitleLength).toString().trim()
      : payee;
}
