import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/backup_repository.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../core/emit_if_open.dart';

/// What the Settings tiles summarize that isn't a setting: when the last
/// backup was, and how many photos there are and their size.
class SettingsSummary {
  const SettingsSummary({this.lastBackupAt, this.photoCount, this.photoBytes});

  /// Null: never backed up (or not read).
  final DateTime? lastBackupAt;

  /// Null until read, or when the read failed.
  final int? photoCount;
  final int? photoBytes;
}

/// Reads the Settings tiles' summaries. Replaces the Settings screen's own read
/// of the backup repository: a widget doesn't call a repository. Read on start,
/// when the tab comes back, and when a sub-screen closes. Each read failing
/// leaves its value unknown, never an error on the screen.
class SettingsSummaryCubit extends CubitSignal<SettingsSummary>
    with EmitIfOpen<SettingsSummary> {
  SettingsSummaryCubit({required this._backups, required this._expenses})
    : super(initialState: const SettingsSummary());

  final BackupRepository _backups;
  final ExpenseRepository _expenses;

  Future<void> load() async {
    DateTime? lastBackupAt;
    ({int count, int bytes})? stats;
    try {
      lastBackupAt = await _backups.lastBackupAt();
    } catch (error) {
      // The tile then says "Never backed up" until the next load.
      debugPrint('Reading the last backup time failed: $error');
    }
    try {
      stats = await _expenses.photoStats();
    } catch (error) {
      debugPrint('Reading the photo stats failed: $error');
    }
    emitIfOpen(
      SettingsSummary(
        lastBackupAt: lastBackupAt,
        photoCount: stats?.count,
        photoBytes: stats?.bytes,
      ),
    );
  }
}
