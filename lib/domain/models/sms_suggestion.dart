/// An expense suggested from a bank SMS (database.md §3.10, phase-9a.md
/// §4). The SMS text itself is never kept (P9a-19): only what was parsed
/// out of it and a SHA-256 of it.
library;

/// What the form keeps to mark the suggestion on Save: the row's id **and**
/// its text's SHA-256, since after a restore the same id may name another
/// SMS (phase-9a.md §9).
typedef SmsLink = ({int id, String bodySha256});

/// Where `SmsSuggestionRepository.pendingPage` continues from (keyset, as
/// Home's `ExpenseCursor`).
typedef SmsPageKey = ({String receivedOn, int receivedAtMs, int id});

enum SmsStatus { pending, added, dismissed }

/// The three payment method keys a suggestion can have (§5.5): the
/// `builtin_key` of a built-in payment method.
const smsPaymentMethodKeys = {'upi', 'credit_card', 'debit_card'};

/// The only currency of SMS suggestions this phase (P9a-31).
const smsCurrencyCode = 'INR';

/// One stored suggestion (a row of `sms_suggestions`).
class SmsSuggestion {
  const SmsSuggestion({
    required this.id,
    required this.sender,
    required this.receivedAt,
    required this.utcOffsetMinutes,
    required this.receivedOn,
    required this.bodySha256,
    required this.amountMinor,
    required this.currencyCode,
    required this.paymentMethodKey,
    required this.payee,
    required this.payeeKey,
    required this.reference,
    required this.title,
    required this.categoryId,
    required this.status,
    required this.expenseId,
  });

  final int id;

  /// e.g. `VM-ABCBNK-S`.
  final String sender;

  /// When the phone received the SMS, UTC: the expense's moment (P9a-4).
  final DateTime receivedAt;

  final int utcOffsetMinutes;

  /// Local `YYYY-MM-DD` of [receivedAt] at [utcOffsetMinutes].
  final String receivedOn;

  final String bodySha256;
  final int amountMinor;
  final String currencyCode;

  /// One of [smsPaymentMethodKeys].
  final String paymentMethodKey;

  /// As the SMS has it, or null when none was found.
  final String? payee;
  final String? payeeKey;
  final String? reference;

  /// The suggested title and category (§5.3, §5.4), or null.
  final String? title;
  final int? categoryId;

  final SmsStatus status;
  final int? expenseId;

  /// When the SMS came, as the clock read where it was scanned: a UTC
  /// `DateTime` whose fields are that wall-clock time, like
  /// `Expense.wallClock`. The card and the banner show it, so a card's time
  /// always matches its day header ([receivedOn]), whatever the phone's
  /// zone is now.
  DateTime get wallClock => receivedAt.add(Duration(minutes: utcOffsetMinutes));

  SmsLink get link => (id: id, bodySha256: bodySha256);

  SmsPageKey get pageKey => (
    receivedOn: receivedOn,
    receivedAtMs: receivedAt.millisecondsSinceEpoch,
    id: id,
  );

  @override
  String toString() =>
      'SmsSuggestion($id, $sender, $amountMinor, ${status.name})';
}

/// How far an SMS scan with the on-device model is: the backup's "(12 of
/// 40)" (phase-9b.md §6.2). Here, not in the scanner, so the backup's
/// cubit can show it without knowing the scanner.
typedef ScanProgress = ({int done, int total});

/// Who read an SMS (`parsed_by`, phase-9b.md §4): for debugging, never
/// shown (P9a-9).
enum SmsParsedBy { regex, ai }

/// What a scan parsed out of one SMS, before it is stored: everything but
/// the title and category, which `insertScanned` fills inside its
/// transaction (§6.3 step 5) from what was learned and, for an SMS the
/// on-device model read, its [aiTitle] and [aiCategoryId] (phase-9b.md
/// §5.3). Holds a hash of the text, never the text.
class NewSmsSuggestion {
  const NewSmsSuggestion({
    required this.sender,
    required this.receivedAtMs,
    required this.utcOffsetMinutes,
    required this.bodySha256,
    required this.amountMinor,
    required this.paymentMethodKey,
    this.payee,
    this.reference,
    this.parsedBy = SmsParsedBy.regex,
    this.aiTitle,
    this.aiCategoryId,
  });

  final String sender;
  final int receivedAtMs;
  final int utcOffsetMinutes;
  final String bodySha256;
  final int amountMinor;
  final String paymentMethodKey;
  final String? payee;
  final String? reference;
  final SmsParsedBy parsedBy;

  /// The model's title, as checked (`acceptAiResult`), or null.
  final String? aiTitle;

  /// The model's pick among the user's categories, or null.
  final int? aiCategoryId;
}
