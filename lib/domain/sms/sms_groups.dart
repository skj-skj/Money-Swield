/// The SMS screen's months and days (phase-9a.md §5.7). Pure Dart.
library;

import '../home_list.dart';
import '../models/sms_suggestion.dart';
import '../periods.dart';

/// A month frame of the SMS screen ("Oct 2026"): its days, newest first,
/// each with its suggestions.
typedef SmsMonth = DayFrame<SmsSuggestion>;

/// [loaded] (in the page order: `received_on` descending, then
/// `received_at`, then id) as month frames holding days, by the stored
/// `received_on`, so a suggestion stays on the day it was scanned on
/// whatever the phone's zone is now. The last month and day stay open
/// while [hasMore], like the Photos screen.
List<SmsMonth> smsGroups(List<SmsSuggestion> loaded, {required bool hasMore}) =>
    framesByDay(
      loaded,
      dayOf: (s) => s.receivedOn,
      grouping: Period.month,
      // Months don't depend on the week start.
      weekStart: WeekStart.monday,
      hasMore: hasMore,
    );
