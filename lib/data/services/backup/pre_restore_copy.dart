import 'package:path/path.dart' as p;

import '../database/database_files.dart';

/// A copy of the data a restore replaced, kept for "Undo last restore"
/// (phase-3.md §6.5): `databases/backups/pre-restore-<seq>-<UTC stamp>.db`.
///
/// "Newest" is the highest [sequence], never the time (P3-16): with the
/// clock set back, ordering by time would make Undo pick the wrong copy and
/// the pruning delete the real newest one, and two restores in the same
/// second would collide on the name. The stamp is only for people and for
/// the "before the restore on …" text.
class PreRestoreCopy {
  const PreRestoreCopy({
    required this.path,
    required this.sequence,
    required this.createdAt,
  });

  static const prefix = 'pre-restore-';

  static final _name = RegExp(
    r'^pre-restore-(\d{6,})-(\d{4})-(\d\d)-(\d\d)T(\d\d)-(\d\d)-(\d\d)Z\.db$',
  );

  final String path;
  final int sequence;

  /// When the copy was made (UTC), from its name.
  final DateTime createdAt;

  /// `pre-restore-000012-2026-10-03T08-50-00Z.db`.
  static String fileName(int sequence, DateTime at) =>
      '$prefix${sequence.toString().padLeft(6, '0')}-${fileStamp(at)}.db';

  /// The copy named by [path], or null for any other file (a `.partial`,
  /// a sidecar, a migration backup).
  static PreRestoreCopy? parse(String path) {
    final match = _name.firstMatch(p.basename(path));
    if (match == null) return null;
    final [seq, y, mo, d, h, mi, s] = [
      for (var i = 1; i <= 7; i++) int.parse(match.group(i)!),
    ];
    return PreRestoreCopy(
      path: path,
      sequence: seq,
      createdAt: DateTime.utc(y, mo, d, h, mi, s),
    );
  }

  /// The sequence number in any file of a pre-restore copy, complete or
  /// not (`.partial`, sidecars), so a new copy never reuses one.
  static int? sequenceIn(String path) {
    final match = RegExp(r'^pre-restore-(\d{6,})-')
        .firstMatch(p.basename(path));
    return match == null ? null : int.parse(match.group(1)!);
  }
}
