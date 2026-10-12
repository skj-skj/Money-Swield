/// The texts of the Recurring screens: pure, the app's strings and a formatting
/// locale in.
library;

import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/recurring_plan.dart';
import '../../../../domain/repeat_input.dart' show maxPastPayments;
import '../../../../l10n/app_localizations.dart';
import '../../../core/recurrence_text.dart';

/// A list row's second line: "Monthly · next 9 Nov", "10 payments
/// waiting", "No more payments · ends 15 Oct", or that it can't be read.
String recurringRowSubtitle(
  AppLocalizations l10n,
  String locale,
  RecurringItem item, {
  required String today,
}) {
  final schedule = item.schedule;
  if (schedule == null || item.isBroken) return l10n.recurringBroken;
  final hold = item.hold;
  if (hold != null) return l10n.recurringPaymentsWaiting(hold.count);
  final short = shortScheduleText(l10n, schedule.frequency, schedule.interval);
  final next = item.nextDueOn;
  if (next != null) {
    return l10n.recurringRowNext(short, _day(locale, next, today));
  }
  final endOn = schedule.endOn;
  return endOn == null
      ? l10n.noMorePayments
      : l10n.recurringRowEnds(_day(locale, endOn, today));
}

/// An Archive row's second line: "Monthly · stopped 9 Oct" / "Monthly ·
/// expired 15 Oct" (its end date).
String archiveRowSubtitle(
  AppLocalizations l10n,
  String locale,
  RecurringItem item, {
  required String today,
}) {
  final schedule = item.schedule;
  if (schedule == null) return l10n.recurringBroken;
  final short = shortScheduleText(l10n, schedule.frequency, schedule.interval);
  final label = switch (item.archiveReason) {
    ArchiveReason.expired => l10n.archivedExpired(
      _day(locale, schedule.endOn!, today),
    ),
    ArchiveReason.replaced => l10n.archivedReplaced(
      _day(locale, item.archivedOn ?? today, today),
    ),
    _ => l10n.archivedStopped(_day(locale, item.archivedOn ?? today, today)),
  };
  return '$short · $label';
}

/// "Netflix · Every week on Monday": an item named with its rule, where two
/// items of one bill must be told apart (the new-schedule and swap dialogs).
/// The title alone when the rule can't be read.
String recurringName(AppLocalizations l10n, String locale, RecurringItem item) {
  final schedule = item.schedule;
  return schedule == null
      ? item.title
      : '${item.title} · ${scheduleText(l10n, locale, schedule)}';
}

/// The hold card's text: "10 payments are due, 3 Aug – 5 Oct."; over 1,000,
/// "More than 1,000 payments are due, …".
String holdText(
  AppLocalizations l10n,
  String locale,
  HoldPayments hold, {
  required String today,
}) {
  final from = _day(locale, hold.from, today);
  final range = hold.from == hold.to
      ? from
      : '$from – ${_day(locale, hold.to, today)}';
  return hold.count > maxPastPayments
      ? l10n.recurringHoldMany(maxPastPayments, range)
      : l10n.recurringHoldText(hold.count, range);
}

/// [day] as [dayText], with no line break inside it: the Oppo wrapped "9 Aug –
/// 9 / Oct" on the hold card and "ends 10 / Oct" in a row.
String _day(String locale, String day, String today) =>
    dayText(locale, day, today: today).replaceAll(' ', ' ');
