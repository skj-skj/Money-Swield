import '../../domain/calendar_days.dart';
import '../../l10n/app_localizations.dart';

/// "today", "yesterday" or "3 days ago": calendar days from [at] to [now],
/// lowercase, to sit inside a sentence ("Last backup: …", the draft
/// banner's "(…)"). A time on a later day (the clock was moved back) reads
/// "today", never "-3 days ago".
String daysAgoText(AppLocalizations l10n, DateTime at, DateTime now) =>
    switch (calendarDaysAgo(at, now)) {
      <= 0 => l10n.lastBackupToday,
      1 => l10n.lastBackupYesterday,
      final days => l10n.lastBackupDaysAgo(days),
    };
