/// Why a file can't be restored, one per text the user sees (phase-3.md
/// §6.2).
enum RestoreRejection {
  /// "This file isn't a backup from Expense Tracker."
  notABackup,

  /// "This backup was made by a newer version of the app."
  tooNew,

  /// "This backup is damaged and can't be restored."
  damaged,
}

/// Thrown when a restore candidate fails a check. Nothing has been changed
/// when it is thrown. [detail] is English, for logs and tests.
class RestoreRejected implements Exception {
  const RestoreRejected(this.reason, this.detail);

  final RestoreRejection reason;
  final String detail;

  @override
  String toString() => 'RestoreRejected(${reason.name}): $detail';
}

/// Where a restore candidate came from.
enum RestoreSource {
  /// A backup zip picked in the system open dialog.
  zip,

  /// A pre-restore copy, for "Undo last restore".
  preRestoreCopy,
}

/// A validated database waiting to replace the live one, with what the
/// confirm dialog shows (§6.3).
class RestoreCandidate {
  const RestoreCandidate({
    required this.source,
    required this.createdAt,
    required this.activeExpenses,
    required this.binnedExpenses,
    required this.latestExpenseOn,
  });

  final RestoreSource source;

  /// When the backup (or the pre-restore copy) was made. Null when the
  /// manifest's `created_at` was unreadable: shown as "—", and the restore
  /// doesn't stamp `last_backup_at`.
  final DateTime? createdAt;

  /// Expenses not in the bin (database.md §3.5). Null when the backup has no
  /// `expenses` table (an older schema): shown as "—".
  final int? activeExpenses;

  /// Expenses in the bin, counted apart from [activeExpenses]. Null as above.
  final int? binnedExpenses;

  /// The local date of the newest active expense, or null when there is
  /// none (or no `expenses` table).
  final DateTime? latestExpenseOn;

  /// A zip restore writes the backup's own time into `last_backup_at`
  /// (P3-9); Undo keeps the copy's value.
  bool get stampsLastBackup => source == RestoreSource.zip && createdAt != null;
}
