/// What tapping an SMS card does with the draft slot (owner rev 3). Pure Dart.
library;

import '../models/expense_draft.dart';
import '../models/sms_suggestion.dart';

enum SmsOpen {
  /// No draft: a new form from the SMS.
  fresh,

  /// The slot holds this SMS's own draft: open it, no question.
  resume,

  /// Another draft waits (an Add draft, another SMS's draft, an Edit
  /// draft): ask before it is dismissed (Cancel / Dismiss draft).
  ask,
}

/// [slot] (the draft slot, null when empty) against the tapped [link]. An
/// SMS form never replaces a draft silently.
SmsOpen smsOpenRule(ExpenseDraft? slot, SmsLink link) {
  if (slot == null) return SmsOpen.fresh;
  if (slot.isAdd && slot.sms == link) return SmsOpen.resume;
  return SmsOpen.ask;
}
