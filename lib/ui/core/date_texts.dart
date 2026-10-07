/// The app's date and time texts, one format each, in the locale from
/// `dateLocaleOf`.
///
/// Two kinds of `DateTime` come in, and they must not be mixed up:
/// - an expense's **wall clock** (`Expense.wallClock`): the time as it read
///   where the expense was recorded. It is formatted as given, never
///   converted, so a Honolulu lunch stays at 12:30 pm in India.
/// - a **moment** (a backup, a deletion): a real instant, shown in the
///   device's time zone ([dateTimeText] converts it).
library;

import 'package:intl/intl.dart';

/// The `DateFormat` for [skeleton] (`'MMMEd'`, `'jm'` …) in [locale],
/// built once: building one parses its pattern again on first use, and
/// Home names every day header, frame and row time on each list build.
/// Never call `add_*` on the result: it is shared.
DateFormat cachedDateFormat(String skeleton, String locale) => _formats
    .putIfAbsent('$skeleton|$locale', () => DateFormat(skeleton, locale));

final _formats = <String, DateFormat>{};

/// e.g. "12:30 pm", as given.
String timeText(String locale, DateTime wallClock) =>
    cachedDateFormat('jm', locale).format(wallClock);

/// e.g. "Monday, 5 October 2026", as given.
String longDateText(String locale, DateTime day) =>
    cachedDateFormat('yMMMMEEEEd', locale).format(day);

/// e.g. "5 Oct 2026", as given.
String shortDateText(String locale, DateTime day) =>
    cachedDateFormat('yMMMd', locale).format(day);

/// e.g. "3 Oct 2026, 2:05 pm": the moment [at] in the device's time zone.
String dateTimeText(String locale, DateTime at) =>
    DateFormat.yMMMd(locale).add_jm().format(at.toLocal());
