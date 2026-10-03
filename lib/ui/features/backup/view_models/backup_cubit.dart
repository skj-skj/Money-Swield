import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/backup_repository.dart';
import '../../../../data/services/backup/pre_restore_copy.dart';
import '../../../../data/services/database/app_database.dart';
import '../../../../data/services/document_service.dart';
import '../../../../domain/error_report.dart';

/// What the Backup & restore screen shows (phase-3.md §9).
class BackupState {
  const BackupState({
    this.lastBackupAt,
    this.newestCopy,
    this.backingUp = false,
    this.failureReport,
  });

  /// Null: never backed up.
  final DateTime? lastBackupAt;

  /// The copy "Undo last restore" would go back to, or null.
  final PreRestoreCopy? newestCopy;

  final bool backingUp;

  /// Set after a failed backup: the screen shows the error report.
  final String? failureReport;

  BackupState copyWith({
    DateTime? lastBackupAt,
    PreRestoreCopy? newestCopy,
    bool? backingUp,
    String? failureReport,
    bool clearFailure = false,
  }) => BackupState(
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    newestCopy: newestCopy ?? this.newestCopy,
    backingUp: backingUp ?? this.backingUp,
    failureReport: clearFailure ? null : failureReport ?? this.failureReport,
  );
}

/// How [BackupCubit.backUp] ended, for the screen's snackbar.
enum BackupResult { saved, cancelled, failed, ignored }

/// Backs up the data and says when the last backup was (§5.2).
class BackupCubit extends CubitSignal<BackupState> {
  BackupCubit({
    required this._backups,
    required this._documents,
    required this._appDatabase,
  }) : super(initialState: const BackupState());

  final BackupRepository _backups;
  final DocumentService _documents;
  final AppDatabase _appDatabase;

  /// Reads the last backup time and the newest pre-restore copy. A failure
  /// leaves them unknown (shown as "never" / no Undo) rather than blocking
  /// the screen.
  Future<void> load() async {
    try {
      final lastBackupAt = await _backups.lastBackupAt();
      final copies = await _appDatabase.preRestoreCopies();
      _emitIfOpen(
        value.copyWith(
          lastBackupAt: lastBackupAt,
          newestCopy: copies.firstOrNull,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Loading the backup screen failed: $error\n$stackTrace');
    }
  }

  /// Builds the zip, lets the user save it, records the time. A second call
  /// while one runs is ignored (a double tap): there is one temp folder and
  /// one pending dialog. The temp files are deleted in every case.
  Future<BackupResult> backUp() async {
    if (value.backingUp) return BackupResult.ignored;
    _emitIfOpen(value.copyWith(backingUp: true, clearFailure: true));
    try {
      final file = await _backups.createBackup(
        appVersion: await _documents.appVersion(),
      );
      final saved = await _documents.saveDocument(
        sourcePath: file.path,
        suggestedName: file.name,
        mimeType: 'application/zip',
      );
      if (!saved) {
        _emitIfOpen(value.copyWith(backingUp: false));
        return BackupResult.cancelled;
      }
      // The moment the data was copied: the same as the manifest's
      // created_at, which a restore of this file stamps.
      final recorded = await _recordQuietly(file.createdAt);
      _emitIfOpen(
        value.copyWith(
          backingUp: false,
          lastBackupAt: recorded ? file.createdAt : null,
        ),
      );
      return BackupResult.saved;
    } catch (error, stackTrace) {
      _emitIfOpen(
        value.copyWith(
          backingUp: false,
          failureReport: errorReport('Backing up', error, stackTrace),
        ),
      );
      return BackupResult.failed;
    } finally {
      await _deleteFilesQuietly();
    }
  }

  /// The file is saved by now, so a failure to note the time doesn't make
  /// the backup fail: reporting one would make the user save a second
  /// copy. "Last backup" then keeps its old value until the next backup.
  Future<bool> _recordQuietly(DateTime at) async {
    try {
      await _backups.recordBackup(at);
      return true;
    } catch (error) {
      debugPrint('Recording the backup time failed: $error');
      return false;
    }
  }

  Future<void> _deleteFilesQuietly() async {
    try {
      await _backups.deleteBackupFiles();
    } catch (error) {
      // The next start deletes them.
      debugPrint('Deleting the backup files failed: $error');
    }
  }

  // backUp() keeps going across awaits, so the cubit may have been closed by
  // the time a result arrives. Emitting after close() asserts in debug mode.
  void _emitIfOpen(BackupState state) {
    if (!isClosed) emit(state);
  }
}
