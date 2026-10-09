import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/backup_repository.dart';
import '../../../../data/services/backup/pre_restore_copy.dart';
import '../../../../data/services/database/app_database.dart';
import '../../../../data/services/document_service.dart';
import '../../../../domain/error_report.dart';
import '../../../core/emit_if_open.dart';

/// What the Backup & restore screen shows (phase-3.md §9).
class BackupState {
  const BackupState({
    this.lastBackupAt,
    this.newestCopy,
    this.backingUp = false,
    this.failureReport,
    this.includePhotos = true,
    this.photoCount,
    this.photoBytes,
    this.photosDone,
    this.photosTotal,
    this.missingPhotos = 0,
  });

  /// Null: never backed up.
  final DateTime? lastBackupAt;

  /// The copy "Undo last restore" would go back to, or null.
  final PreRestoreCopy? newestCopy;

  final bool backingUp;

  /// Set after a failed backup: the screen shows the error report.
  final String? failureReport;

  /// "Include photos", ticked every time the screen opens (P6-16).
  final bool includePhotos;

  /// The photos and their size, for the checkbox; null until read.
  final int? photoCount;
  final int? photoBytes;

  /// Photos zipped so far, while a backup with photos runs.
  final int? photosDone;
  final int? photosTotal;

  /// Photos the last saved backup had to leave out (missing files).
  final int missingPhotos;

  BackupState copyWith({
    DateTime? lastBackupAt,
    PreRestoreCopy? newestCopy,
    bool? backingUp,
    String? failureReport,
    bool clearFailure = false,
    bool? includePhotos,
    int? photoCount,
    int? photoBytes,
    (int, int)? Function()? progress,
    int? missingPhotos,
  }) {
    // A function, so null (no progress) can be told from "keep it".
    final current = photosDone == null ? null : (photosDone!, photosTotal!);
    final shown = progress == null ? current : progress();
    return BackupState(
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      newestCopy: newestCopy ?? this.newestCopy,
      backingUp: backingUp ?? this.backingUp,
      failureReport: clearFailure ? null : failureReport ?? this.failureReport,
      includePhotos: includePhotos ?? this.includePhotos,
      photoCount: photoCount ?? this.photoCount,
      photoBytes: photoBytes ?? this.photoBytes,
      photosDone: shown?.$1,
      photosTotal: shown?.$2,
      missingPhotos: missingPhotos ?? this.missingPhotos,
    );
  }
}

/// How [BackupCubit.backUp] ended, for the screen's snackbar.
enum BackupResult {
  saved,
  cancelled,
  failed,
  ignored,

  /// Not enough room on the phone to build it (phase-6.md §6.7).
  noSpace,

  /// The place picked in the save dialog had no room for it.
  saveTargetFull,
}

/// Backs up the data and says when the last backup was (§5.2).
class BackupCubit extends CubitSignal<BackupState>
    with EmitIfOpen<BackupState> {
  BackupCubit({
    required this._backups,
    required this._documents,
    required this._appDatabase,
    this._photoStats,
  }) : super(initialState: const BackupState());

  final BackupRepository _backups;
  final DocumentService _documents;
  final AppDatabase _appDatabase;

  /// The photos' count and size, for "Include photos" (§8.7).
  final Future<({int count, int bytes})> Function()? _photoStats;

  /// Reads the last backup time and the newest pre-restore copy. A failure
  /// leaves them unknown (shown as "never" / no Undo) rather than blocking
  /// the screen.
  Future<void> load() async {
    try {
      final lastBackupAt = await _backups.lastBackupAt();
      final copies = await _appDatabase.preRestoreCopies();
      emitIfOpen(
        value.copyWith(
          lastBackupAt: lastBackupAt,
          newestCopy: copies.firstOrNull,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Loading the backup screen failed: $error\n$stackTrace');
    }
    try {
      final stats = await _photoStats?.call();
      if (stats != null) {
        emitIfOpen(
          value.copyWith(photoCount: stats.count, photoBytes: stats.bytes),
        );
      }
    } catch (error) {
      // The checkbox then says nothing about them.
      debugPrint('Reading the photo stats failed: $error');
    }
  }

  /// The "Include photos" checkbox.
  void setIncludePhotos(bool include) {
    if (value.backingUp) return;
    emitIfOpen(value.copyWith(includePhotos: include));
  }

  /// Builds the zip, lets the user save it, records the time. A second call
  /// while one runs is ignored (a double tap): there is one temp folder and
  /// one pending dialog. The temp files are deleted in every case.
  Future<BackupResult> backUp() async {
    if (value.backingUp) return BackupResult.ignored;
    emitIfOpen(
      value.copyWith(
        backingUp: true,
        clearFailure: true,
        progress: () => null,
        missingPhotos: 0,
      ),
    );
    try {
      final file = await _backups.createBackup(
        appVersion: await _documents.appVersion(),
        includePhotos: value.includePhotos,
        onProgress: (done, total) =>
            emitIfOpen(value.copyWith(progress: () => (done, total))),
      );
      // The zip is built: the save dialog comes next.
      emitIfOpen(value.copyWith(progress: () => null));
      final saved = await _documents.saveDocument(
        sourcePath: file.path,
        suggestedName: file.name,
        mimeType: 'application/zip',
      );
      if (!saved) {
        emitIfOpen(value.copyWith(backingUp: false));
        return BackupResult.cancelled;
      }
      // The moment the data was copied: the same as the manifest's
      // created_at, which a restore of this file stamps.
      final recorded = await _recordQuietly(file.createdAt);
      emitIfOpen(
        value.copyWith(
          backingUp: false,
          lastBackupAt: recorded ? file.createdAt : null,
          missingPhotos: file.missingPhotos,
        ),
      );
      return BackupResult.saved;
    } on BackupNoSpace catch (error) {
      debugPrint('$error');
      emitIfOpen(value.copyWith(backingUp: false, progress: () => null));
      return BackupResult.noSpace;
    } catch (error, stackTrace) {
      // A save dialog's copy that ran out of room: said plainly, it is
      // the place the user picked, not a bug to report.
      if (_isNoSpace(error)) {
        emitIfOpen(value.copyWith(backingUp: false, progress: () => null));
        return BackupResult.saveTargetFull;
      }
      emitIfOpen(
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

  static bool _isNoSpace(Object error) {
    final text = '$error';
    return text.contains('ENOSPC') || text.contains('No space left');
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
}
