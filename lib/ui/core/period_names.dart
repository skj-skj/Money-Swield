import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart' show BuildContext;

import '../../domain/periods.dart';
import '../../domain/totals.dart';
import '../../l10n/app_localizations.dart';
import 'date_texts.dart';
import 'formatting_locale.dart';
import 'money_formatter.dart';

/// The names of days, weeks, months and years on Home (phase-5.md §8.3,
/// P5-10): dates and numbers only, no "Today" or "This week". The year is
/// added when the period's year isn't [today]'s. Each name starts with a
/// capital letter: intl writes Spanish months and weekdays in lower case
/// (`lun, 5 oct`, R13).
class PeriodNames {
  const PeriodNames({
    required this.l10n,
    required this.locale,
    required this.today,
    required this.weekLabel,
  });

  /// With [context]'s language and date locale: what every screen naming
  /// periods builds (Home, Photos, Upcoming, a recurring page, Settings).
  factory PeriodNames.of(
    BuildContext context, {
    required String today,
    required WeekLabel weekLabel,
  }) => PeriodNames(
    l10n: AppLocalizations.of(context),
    locale: dateLocaleOf(context),
    today: today,
    weekLabel: weekLabel,
  );

  final AppLocalizations l10n;

  /// For intl's dates, e.g. `en_IN` (`dateLocaleOf`).
  final String locale;

  /// The device's local date, `YYYY-MM-DD`.
  final String today;

  final WeekLabel weekLabel;

  int get _thisYear => int.parse(today.substring(0, 4));

  /// A group's name: its day, week, month or year.
  String of(PeriodRange range) => switch (range.period) {
    Period.day => day(range.from),
    Period.week => week(range),
    Period.month => month(range.from),
    Period.year => range.from.substring(0, 4),
  };

  /// `Sat, 17 Oct` (en_IN), `Sat, Oct 17` (en_US); `Wed, 31 Dec 2025` in
  /// another year.
  String day(String day) {
    final date = parseDay(day);
    final format = date.year == _thisYear
        ? cachedDateFormat('MMMEd', locale)
        : cachedDateFormat('yMMMEd', locale);
    return _sentence(format.format(date));
  }

  /// The full date, for TalkBack: "Saturday 17 October".
  String spokenDay(String day) {
    final date = parseDay(day);
    final format = date.year == _thisYear
        ? cachedDateFormat('MMMMEEEEd', locale)
        : cachedDateFormat('yMMMMEEEEd', locale);
    return format.format(date);
  }

  /// `Oct Week 3` / `Dec 2025 Week 5`, or `Week 41` / `Week 52, 2025`:
  /// named after the year and month of its 4th day (§5.1).
  String week(PeriodRange week) {
    final id = weekIdOf(week);
    final otherYear = id.year != _thisYear;
    return switch (weekLabel) {
      WeekLabel.month => _sentence(
        l10n.weekOfMonth(
          _monthName(DateTime.utc(id.year, id.month), withYear: otherYear),
          id.numberInMonth,
        ),
      ),
      WeekLabel.number =>
        otherYear
            ? l10n.weekNumberWithYear(
                id.number,
                cachedDateFormat('y', locale).format(DateTime.utc(id.year)),
              )
            : l10n.weekNumber(id.number),
    };
  }

  /// `Oct` (`Sept` for en_IN: intl's data), `Sep 2025` in another year.
  String month(String day) {
    final date = parseDay(day);
    return _sentence(_monthName(date, withYear: date.year != _thisYear));
  }

  /// `Oct 2026`: a month with its year even in this year, for the Photos
  /// screen's frames (phase-6.md §8.9), which mix years more than Home.
  String monthWithYear(String day) =>
      _sentence(_monthName(parseDay(day), withYear: true));

  String _monthName(DateTime date, {required bool withYear}) =>
      (withYear
              ? cachedDateFormat('yMMM', locale)
              : cachedDateFormat('MMM', locale))
          .format(date);

  String _sentence(String text) => toBeginningOfSentenceCase(text, locale);
}

/// Totals per currency on one line, default first, then by code:
/// `₹4,560.00 + $85.00`. A total too large to print reads "Too large".
String totalsText(
  AppLocalizations l10n,
  MoneyFormatter formatter,
  CurrencyTotals totals,
  String defaultCurrency, {
  bool spoken = false,
}) {
  final parts = [
    for (final (code, minor) in orderedTotals(totals, defaultCurrency))
      totalText(l10n, formatter, code, minor),
  ];
  if (parts.isEmpty) return '';
  return parts.reduce(
    (first, rest) => spoken
        ? l10n.totalsJoinSpoken(first, rest)
        : l10n.totalsJoin(first, rest),
  );
}

/// One currency's total, or "Too large" (phase-5.md R3).
String totalText(
  AppLocalizations l10n,
  MoneyFormatter formatter,
  String code,
  BigInt minor,
) => formatter.formatTotal(code, minor) ?? l10n.totalTooLarge;

/// "Day", "Week" and the like.
String periodName(AppLocalizations l10n, Period period) => switch (period) {
  Period.day => l10n.periodDay,
  Period.week => l10n.periodWeek,
  Period.month => l10n.periodMonth,
  Period.year => l10n.periodYear,
};
