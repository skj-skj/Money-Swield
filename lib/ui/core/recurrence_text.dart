/// The texts of a recurring item's rule (phase-7a.md §5.5): pure, the
/// app's strings and a formatting locale in (`dateLocaleOf`). Weekdays and
/// months come from intl in that locale, numbers are grouped.
library;

import '../../domain/periods.dart';
import '../../domain/recurrence.dart';
import '../../l10n/app_localizations.dart';
import 'date_texts.dart';

/// "Every month on day 9", "Every 2 weeks on Monday", "Every year on 29 Feb
/// (28 Feb in other years)". "Day 9", not "the 9th": ordinals don't
/// translate (P7a-21). A start on the 29th–31st says shorter months use
/// their last day.
String scheduleText(AppLocalizations l10n, String locale, Schedule s) {
  final start = parseDay(s.startOn);
  final n = s.interval;
  return switch (s.frequency) {
    Frequency.daily => l10n.scheduleDaily(n),
    Frequency.weekly => l10n.scheduleWeekly(
      n,
      cachedDateFormat('EEEE', locale).format(start),
    ),
    Frequency.monthly when start.day > 28 => l10n.scheduleMonthlyClamped(
      n,
      start.day,
    ),
    Frequency.monthly => l10n.scheduleMonthly(n, start.day),
    Frequency.yearly when start.month == 2 && start.day == 29 =>
      l10n.scheduleYearlyLeap(
        n,
        _dayMonth(locale, start),
        _dayMonth(locale, DateTime.utc(start.year, 2, 28)),
      ),
    Frequency.yearly => l10n.scheduleYearly(n, _dayMonth(locale, start)),
  };
}

/// "Monthly", "Every 3 months": a row's short form.
String shortScheduleText(AppLocalizations l10n, Frequency f, int interval) =>
    switch (f) {
      Frequency.daily => l10n.repeatShortDaily(interval),
      Frequency.weekly => l10n.repeatShortWeekly(interval),
      Frequency.monthly => l10n.repeatShortMonthly(interval),
      Frequency.yearly => l10n.repeatShortYearly(interval),
    };

/// The unit next to the "Every" field, plural by [interval].
String unitText(AppLocalizations l10n, Frequency f, int interval) =>
    switch (f) {
      Frequency.daily => l10n.repeatUnitDays(interval),
      Frequency.weekly => l10n.repeatUnitWeeks(interval),
      Frequency.monthly => l10n.repeatUnitMonths(interval),
      Frequency.yearly => l10n.repeatUnitYears(interval),
    };

/// "Never ends" / "Ends 15 Sep 2026".
String endsText(AppLocalizations l10n, String locale, String? endOn) =>
    endOn == null
    ? l10n.endsNever
    : l10n.endsOn(shortDateText(locale, parseDay(endOn)));

/// "Next: 31 Oct" (the year only when it isn't [today]'s) / "No more
/// payments".
String nextText(
  AppLocalizations l10n,
  String locale,
  String? next, {
  required String today,
}) => next == null
    ? l10n.noMorePayments
    : l10n.nextOn(dayText(locale, next, today: today));

/// [day] as "31 Oct", or "31 Oct 2027" when it isn't in [today]'s year.
String dayText(String locale, String day, {required String today}) {
  final date = parseDay(day);
  return date.year == parseDay(today).year
      ? _dayMonth(locale, date)
      : shortDateText(locale, date);
}

/// The first three of [days] and "and 4 more": "31 Aug, 30 Sep".
String daysListText(
  AppLocalizations l10n,
  String locale,
  List<String> days, {
  required String today,
}) {
  final shown = [
    for (final day in days.take(3)) dayText(locale, day, today: today),
  ].join(', ');
  final more = days.length - 3;
  return more > 0 ? '$shown ${l10n.repeatAndMore(more)}' : shown;
}

String _dayMonth(String locale, DateTime date) =>
    cachedDateFormat('MMMd', locale).format(date);
