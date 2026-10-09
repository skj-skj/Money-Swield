import '../../../../domain/models/restore_candidate.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/byte_size_text.dart';
import '../../../core/date_texts.dart';
import '../../../core/days_ago.dart';

/// Shown where a date is unknown (an unreadable `created_at`, a backup
/// without an `expenses` table).
const unknownValue = '—';

/// "Last backup: today" / "Last backup: 12 days ago" / "Never backed up".
/// Calendar days, like the bin's "Deleted N days ago". A time in the
/// future (the clock was moved back, or a restore stamped another phone's
/// time) reads "today", never "-3 days ago".
String lastBackupText(AppLocalizations l10n, DateTime? at, DateTime now) {
  if (at == null) return l10n.lastBackupNever;
  return l10n.lastBackupSubtitle(daysAgoText(l10n, at, now));
}

/// The confirm dialog's lines (§6.3), without the title and buttons.
List<String> restoreSummary(
  AppLocalizations l10n, {
  required String locale,
  required RestoreCandidate candidate,
  required int? currentExpenses,
}) {
  final createdAt = candidate.createdAt;
  final date = createdAt == null
      ? unknownValue
      : dateTimeText(locale, createdAt);
  return [
    switch (candidate.source) {
      RestoreSource.zip => l10n.restoreBackupFrom(date),
      RestoreSource.preRestoreCopy => l10n.restoreCopyFrom(date),
    },
    _countsLine(l10n, locale, candidate),
    ...photoLines(l10n, locale, candidate),
    // Left out from onboarding: there's only the seed data there.
    if (currentExpenses != null) ...[
      l10n.restoreReplacesData(currentExpenses),
      l10n.restoreKeepsCopy,
    ],
  ];
}

/// The photos of a zip restore (phase-6.md §8.8): how many and their size,
/// and that they don't fit; or that the backup has none. Nothing for
/// Undo's copy (its photos are on the phone).
List<String> photoLines(
  AppLocalizations l10n,
  String locale,
  RestoreCandidate candidate,
) {
  if (candidate.source != RestoreSource.zip) return const [];
  if (!candidate.includesPhotos) return [l10n.restoreBackupWithoutPhotos];
  if (candidate.photoCount == 0) return const [];
  return [
    l10n.restoreIncludesPhotos(
      candidate.photoCount,
      byteSizeText(l10n, locale, candidate.photoBytes),
    ),
    if (!candidate.photosFit)
      l10n.restoreNoSpaceForPhotos(
        byteSizeText(l10n, locale, candidate.photoBytesShort),
      ),
  ];
}

/// "121 expenses, plus 3 in the bin. Latest on 2 Oct 2026". The bin part
/// is left out when it's empty, "Latest on" when there are no expenses.
String _countsLine(
  AppLocalizations l10n,
  String locale,
  RestoreCandidate candidate,
) {
  final active = candidate.activeExpenses;
  if (active == null) return unknownValue;
  final binned = candidate.binnedExpenses ?? 0;
  final latest = candidate.latestExpenseOn;
  final counts = [
    l10n.restoreExpenseCount(active),
    if (binned > 0) l10n.restoreBinCount(binned),
  ].join(', ');
  if (latest == null || active == 0) return counts;
  return '$counts. ${l10n.restoreLatestOn(shortDateText(locale, latest))}';
}

/// The text for a file that can't be restored.
String rejectionText(AppLocalizations l10n, RestoreRejection reason) =>
    switch (reason) {
      RestoreRejection.notABackup => l10n.notABackup,
      RestoreRejection.tooNew => l10n.backupTooNew,
      RestoreRejection.damaged => l10n.backupDamaged,
    };
