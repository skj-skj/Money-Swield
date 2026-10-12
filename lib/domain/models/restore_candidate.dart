/// Why a file can't be restored, one per text the user sees.
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

/// A validated database waiting to replace the live one, with what the confirm
/// dialog shows.
class RestoreCandidate {
  const RestoreCandidate({
    required this.source,
    required this.createdAt,
    required this.activeExpenses,
    required this.binnedExpenses,
    required this.latestExpenseOn,
    this.recurringItems,
    this.includesPhotos = false,
    this.photoCount = 0,
    this.photoBytes = 0,
    this.photoBytesToWrite = 0,
    this.freeBytes,
  });

  final RestoreSource source;

  /// When the backup (or the pre-restore copy) was made. Null when the
  /// manifest's `created_at` was unreadable: shown as "—", and the restore
  /// doesn't stamp `last_backup_at`.
  final DateTime? createdAt;

  /// Expenses not in the bin. Null when the backup has no `expenses` table (an
  /// older schema): shown as "—".
  final int? activeExpenses;

  /// Expenses in the bin, counted apart from [activeExpenses]. Null as above.
  final int? binnedExpenses;

  /// The local date of the newest active expense, or null when there is
  /// none (or no `expenses` table).
  final DateTime? latestExpenseOn;

  /// Running recurring items; null when the backup has no `recurring_expenses`
  /// table (from before recurring items).
  final int? recurringItems;

  /// Whether the backup holds its photos. A database-only backup, or Undo's
  /// copy, has none to write.
  final bool includesPhotos;

  /// The photos in the backup and their size.
  final int photoCount;
  final int photoBytes;

  /// The bytes of the photos this phone doesn't have yet (no file of that
  /// name and size): what restoring them writes.
  final int photoBytesToWrite;

  /// Free space where photos go, when known.
  final int? freeBytes;

  /// Room kept free besides what a restore writes.
  static const spaceMargin = 50 * 1024 * 1024;

  /// Whether the photos fit: if not, the confirm offers "Restore without
  /// photos" instead.
  bool get photosFit {
    final free = freeBytes;
    return free == null || photoBytesToWrite <= free - spaceMargin;
  }

  /// How much more room the photos need, when they don't fit.
  int get photoBytesShort =>
      photosFit ? 0 : photoBytesToWrite - (freeBytes! - spaceMargin);

  /// A copy with the photo summary.
  RestoreCandidate withPhotos({
    required int count,
    required int bytes,
    required int bytesToWrite,
    required int? free,
  }) => RestoreCandidate(
    source: source,
    createdAt: createdAt,
    activeExpenses: activeExpenses,
    binnedExpenses: binnedExpenses,
    latestExpenseOn: latestExpenseOn,
    recurringItems: recurringItems,
    includesPhotos: true,
    photoCount: count,
    photoBytes: bytes,
    photoBytesToWrite: bytesToWrite,
    freeBytes: free,
  );

  /// A zip restore writes the backup's own time into `last_backup_at`; Undo
  /// keeps the copy's value.
  bool get stampsLastBackup => source == RestoreSource.zip && createdAt != null;
}
