import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show ValueListenable, debugPrint;

import '../../../../data/repositories/backup_repository.dart';
import '../../../../data/services/backup/pre_restore_copy.dart';
import '../../../../data/services/database/app_database.dart';
import '../../../../data/services/document_service.dart';
import '../../../../domain/error_report.dart';
import '../../../../domain/models/sms_suggestion.dart' show ScanProgress;
import '../../../core/emit_if_open.dart';

/// What the Backup & restore screen shows.
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
    this.waitingForSms = false,
    this.smsProgress,
  });

  /// Null: never backed up.
  final DateTime? lastBackupAt;

  /// The copy "Undo last restore" would go back to, or null.
  final PreRestoreCopy? newestCopy;

  final bool backingUp;

  /// Set after a failed backup: the screen shows the error report.
  final String? failureReport;

  /// "Include photos", ticked every time the screen opens.
  final bool includePhotos;

  /// The photos and their size, for the checkbox; null until read.
  final int? photoCount;
  final int? photoBytes;

  /// Photos zipped so far, while a backup with photos runs.
  final int? photosDone;
  final int? photosTotal;

  /// Photos the last saved backup had to leave out (missing files).
  final int missingPhotos;

  /// The backup waits for an SMS scan to finish: "Waiting for SMS reading to
  /// finish…" with Cancel.
  final bool waitingForSms;

  /// While [waitingForSms] and the scan reads with the on-device model: "… (12
  /// of 40)". Null otherwise.
  final ScanProgress? smsProgress;

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
    bool? waitingForSms,
    ScanProgress? Function()? smsProgress,
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
      waitingForSms: waitingForSms ?? this.waitingForSms,
      // A function, like [progress], so it can be cleared.
      smsProgress: smsProgress == null ? this.smsProgress : smsProgress(),
    );
  }
}

/// How [BackupCubit.backUp] ended, for the screen's snackbar.
enum BackupResult {
  saved,
  cancelled,
  failed,
  ignored,

  /// Not enough room on the phone to build it.
  noSpace,

  /// The place picked in the save dialog had no room for it.
  saveTargetFull,
}

/// Backs up the data and says when the last backup was.
class BackupCubit extends CubitSignal<BackupState>
    with EmitIfOpen<BackupState> {
  BackupCubit({
    required this._backups,
    required this._documents,
    required this._appDatabase,
    this._photoStats,
    this._runningSmsScan,
    this._smsProgress,
  }) : super(initialState: const BackupState());

  final BackupRepository _backups;
  final DocumentService _documents;
  final AppDatabase _appDatabase;

  /// The photos' count and size, for "Include photos".
  final Future<({int count, int bytes})> Function()? _photoStats;

  /// The SMS scan running now, or null: a function, so this cubit doesn't know
  /// the scanner.
  final Future<void>? Function()? _runningSmsScan;

  /// The running scan's progress, shown while waiting.
  final ValueListenable<ScanProgress?>? _smsProgress;

  /// Completed by [cancelWait].
  Completer<void>? _cancelWait;

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
  ///
  /// A running SMS scan is waited for first, so the backup holds every
  /// suggestion that scan stores; Cancel meanwhile ([cancelWait]) ends it with
  /// nothing built. No SMS text is ever in the database, so the wait is not
  /// what keeps text out of a backup.
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
    if (!await _waitForSms()) {
      emitIfOpen(value.copyWith(backingUp: false, waitingForSms: false));
      return BackupResult.cancelled;
    }
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

  /// Stops waiting for the SMS scan: the backup is cancelled.
  void cancelWait() => _cancelWait?.complete();

  /// Waits for a running SMS scan, showing it; false when cancelled.
  Future<bool> _waitForSms() async {
    final scan = _runningSmsScan?.call();
    if (scan == null) return true;
    final cancel = _cancelWait = Completer<void>();
    final progress = _smsProgress;
    void showProgress() =>
        emitIfOpen(value.copyWith(smsProgress: () => progress?.value));
    emitIfOpen(
      value.copyWith(waitingForSms: true, smsProgress: () => progress?.value),
    );
    progress?.addListener(showProgress);
    try {
      await Future.any([scan.catchError((_) {}), cancel.future]);
      return !cancel.isCompleted;
    } finally {
      progress?.removeListener(showProgress);
      _cancelWait = null;
      emitIfOpen(value.copyWith(waitingForSms: false, smsProgress: () => null));
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
