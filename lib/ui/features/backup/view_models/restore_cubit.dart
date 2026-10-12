import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:material_ui/material_ui.dart' show Locale;

import '../../../../app/restore_tools.dart';
import '../../../../data/repositories/restore_repository.dart';
import '../../../../data/services/backup/pre_restore_copy.dart';
import '../../../../data/services/database/app_database.dart';
import '../../../../data/services/document_service.dart';
import '../../../../domain/error_report.dart';
import '../../../../domain/models/restore_candidate.dart';
import '../../../core/emit_if_open.dart';
import '../../migration/view_models/migration_cubit.dart';

/// Where a restore is. States don't override `==`, so every emitted state
/// reaches the screen.
sealed class RestoreState {
  const RestoreState();
}

/// The open dialog is (about to be) shown.
final class RestorePicking extends RestoreState {
  const RestorePicking();
}

final class RestoreValidating extends RestoreState {
  const RestoreValidating();
}

/// Waiting for the user to confirm. [currentExpenses] is this phone's
/// active expense count, or null when there is no data to speak of
/// (onboarding, a database that didn't open).
final class RestoreConfirm extends RestoreState {
  const RestoreConfirm(this.candidate, this.currentExpenses);

  final RestoreCandidate candidate;
  final int? currentExpenses;
}

/// The candidate's migrations run on [migration], which the screen shows
/// with the usual migration screen.
final class RestoreMigrating extends RestoreState {
  const RestoreMigrating(this.migration);

  final MigrationCubit migration;
}

final class RestoreSwapping extends RestoreState {
  const RestoreSwapping();
}

/// The backup's photos are being written, before the swap: [done] of [total].
final class RestoreWritingPhotos extends RestoreState {
  const RestoreWritingPhotos(this.done, this.total);

  final int done;
  final int total;
}

/// Swapped in: the app restarts. [settingsReset]: the backup's settings
/// were missing or unreadable, so it was restored with default settings
/// (RestoreRepository.repairSettings) and Home says so.
final class RestoreDone extends RestoreState {
  const RestoreDone({this.settingsReset = false, this.failedPhotos = 0});

  final bool settingsReset;

  /// Photos whose entry was damaged: they show as missing.
  final int failedPhotos;
}

/// Nothing picked, or the user said no.
final class RestoreCancelled extends RestoreState {
  const RestoreCancelled();
}

/// The file can't be restored, for [reason]. Nothing was changed.
final class RestoreRefused extends RestoreState {
  const RestoreRefused(this.reason);

  final RestoreRejection reason;
}

/// The picked file is larger than the phone's free space: it can't even be
/// copied in to be checked. Nothing was changed.
final class RestoreFailedNoSpace extends RestoreState {
  const RestoreFailedNoSpace();
}

/// Something went wrong. The live data is unchanged; [needsRestart] says
/// the app's connection was already closed, so the app must restart to
/// open it again.
final class RestoreFailed extends RestoreState {
  const RestoreFailed(this.report, {required this.needsRestart});

  final String report;
  final bool needsRestart;
}

/// Runs one restore: pick → validate → confirm → migrate the candidate → stamp
/// and check it → swap → restart. Until the swap's rename nothing the user has
/// is changed.
///
/// Calls that arrive while a step runs (a double tap) are ignored: there is
/// one candidate and one pending dialog.
class RestoreCubit extends CubitSignal<RestoreState>
    with EmitIfOpen<RestoreState> {
  RestoreCubit({
    required this._tools,
    required this._closeLiveConnection,
    required this._locale,
    this._currentExpenseCount,
    this._migrationCubitFor,
  }) : super(initialState: const RestorePicking());

  /// The mime types the open dialog offers. Some file providers label a
  /// zip `octet-stream` or `x-zip-compressed`.
  static const zipMimeTypes = [
    'application/zip',
    'application/octet-stream',
    'application/x-zip-compressed',
  ];

  final RestoreTools _tools;

  /// Closes the app's connection right before the swap.
  final Future<void> Function() _closeLiveConnection;

  /// The device locale, for migration questions.
  final Locale _locale;

  final Future<int> Function()? _currentExpenseCount;
  final MigrationCubit Function(AppDatabase candidate)? _migrationCubitFor;

  RestoreRepository get _repository => _tools.repository;
  DocumentService get _documents => _tools.documents;

  bool _started = false;
  bool _confirmed = false;
  bool _finishing = false;
  bool _withPhotos = false;
  RestoreCandidate? _candidate;
  MigrationCubit? _migration;

  /// The step running now, so [close] can wait for it before deleting the
  /// candidate: deleting under a running step lets sqflite recreate it.
  Future<void>? _running;

  /// Asks for a backup zip, then validates it.
  Future<void> startFromZip() => _start(() async {
    final paths = await _tools.appDatabase.paths();
    final String? picked;
    try {
      picked = await _documents.openDocument(
        mimeTypes: zipMimeTypes,
        destinationPath: paths.pickedZip,
        maxBytes: await _repository.maxBackupBytes(),
      );
    } on DocumentTooLarge {
      // Larger than the free space: it can't be opened here.
      return emitIfOpen(const RestoreFailedNoSpace());
    } catch (error, stackTrace) {
      // The dialog or the copy failed (a provider that can't stream the
      // file, no activity, a dialog already open). Shown with a report:
      // otherwise the screen would spin forever.
      return emitIfOpen(
        RestoreFailed(
          errorReport('Opening the backup file', error, stackTrace),
          needsRestart: false,
        ),
      );
    }
    if (picked == null) return emitIfOpen(const RestoreCancelled());
    await _validate(_repository.prepareFromZip);
  });

  /// Validates [copy] for "Undo last restore".
  Future<void> startFromCopy(PreRestoreCopy copy) =>
      _start(() => _validate(() => _repository.prepareFromCopy(copy)));

  /// "Restore" in the confirm dialog: migrates the candidate, then swaps.
  /// [withPhotos] false is "Restore without photos": the backup's photos aren't
  /// written; those this phone lacks show as missing.
  Future<void> confirm({bool withPhotos = true}) async {
    final candidate = switch (value) {
      RestoreConfirm(:final candidate) => candidate,
      _ => null,
    };
    // Set before the first await, so a second call meanwhile is ignored:
    // two migrations must never run on the one candidate.
    if (candidate == null || isClosed || _confirmed) return;
    _confirmed = true;
    _candidate = candidate;
    _withPhotos = withPhotos && candidate.includesPhotos;
    final migration = _newMigrationCubit(await _repository.candidatePath());
    _migration = migration;
    // Continues once the migration screen is done: at once when nothing is
    // pending, or after "Update done successfully" + Continue.
    createEffect(() {
      if (migration.state.value is MigrationDone) {
        scheduleMicrotask(_afterMigration);
      }
    });
    emitIfOpen(RestoreMigrating(migration));
    await _track(migration.run());
  }

  /// "Cancel" in the confirm dialog.
  Future<void> cancel() async {
    if (value is! RestoreConfirm || _confirmed) return;
    emitIfOpen(const RestoreCancelled());
    await _track(_repository.deleteCandidate());
  }

  /// Waits for the running step, then deletes the candidate: leaving the
  /// restore at any point leaves nothing behind. After a swap the folder is
  /// already gone. Back is blocked while migrating and swapping, so those
  /// never race with this.
  @override
  Future<void> close() async {
    final running = _running;
    if (running != null) await running;
    try {
      await _repository.deleteCandidate();
      await _repository.deletePickedZip();
    } catch (error) {
      // The next start deletes them.
      debugPrint('Deleting the restore candidate failed: $error');
    }
    await _migration?.close();
    await super.close();
  }

  Future<void> _start(Future<void> Function() action) async {
    if (_started) return;
    _started = true;
    await _track(action());
  }

  Future<void> _validate(Future<RestoreCandidate> Function() prepare) async {
    emitIfOpen(const RestoreValidating());
    try {
      final candidate = await prepare();
      emitIfOpen(RestoreConfirm(candidate, await _countCurrentQuietly()));
    } on RestoreRejected catch (rejected) {
      debugPrint('$rejected');
      emitIfOpen(RestoreRefused(rejected.reason));
    } catch (error, stackTrace) {
      emitIfOpen(
        RestoreFailed(
          errorReport('Checking the backup', error, stackTrace),
          needsRestart: false,
        ),
      );
    }
  }

  Future<int?> _countCurrentQuietly() async {
    try {
      return await _currentExpenseCount?.call();
    } catch (error) {
      debugPrint('Counting this phone\'s expenses failed: $error');
      return null;
    }
  }

  /// After the migration: stamp, check that it opens as the app would, swap.
  Future<void> _afterMigration() async {
    final candidate = _candidate;
    if (_finishing || candidate == null || isClosed) return;
    _finishing = true;
    emitIfOpen(const RestoreSwapping());
    await _track(_finish(candidate));
  }

  Future<void> _finish(RestoreCandidate candidate) async {
    final bool settingsReset;
    var failedPhotos = 0;
    try {
      settingsReset = await _repository.repairSettings();
      await _repository.stamp(candidate);
      await _repository.checkOpensAsApp();
      if (_withPhotos) {
        emitIfOpen(RestoreWritingPhotos(0, candidate.photoCount));
        failedPhotos = await _repository.writePhotos(
          onProgress: (done, total) =>
              emitIfOpen(RestoreWritingPhotos(done, total)),
        );
      }
    } on RestoreRejected catch (rejected) {
      debugPrint('$rejected');
      return emitIfOpen(RestoreRefused(rejected.reason));
    } catch (error, stackTrace) {
      return emitIfOpen(
        RestoreFailed(
          errorReport('Preparing the restored data', error, stackTrace),
          needsRestart: false,
        ),
      );
    }
    try {
      await _tools.appDatabase.replaceWith(
        await _repository.candidatePath(),
        closeConnection: _closeLiveConnection,
      );
      emitIfOpen(
        RestoreDone(settingsReset: settingsReset, failedPhotos: failedPhotos),
      );
    } on SwapFailure catch (failure) {
      emitIfOpen(
        RestoreFailed(failure.report, needsRestart: failure.needsRestart),
      );
    }
  }

  MigrationCubit _newMigrationCubit(String candidatePath) {
    final candidate = _tools.appDatabase.forFile(candidatePath);
    return _migrationCubitFor?.call(candidate) ??
        MigrationCubit(database: candidate, locale: _locale);
  }

  Future<void> _track(Future<void> step) {
    // Never completes with an error, so close() can always wait on it.
    _running = step.catchError((Object _) {});
    return step;
  }
}
