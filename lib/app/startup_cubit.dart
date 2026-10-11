import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/services/backup/pre_restore_copy.dart';
import '../domain/error_report.dart';
import '../domain/models/recurring_item.dart';
import '../ui/core/emit_if_open.dart';
import '../ui/features/settings/view_models/settings_cubit.dart';
import 'app_dependencies.dart';

/// What the startup gate shows after migrations are done. States don't
/// override `==`, so every emitted state reaches the screen.
sealed class StartupState {
  const StartupState();
}

final class StartupLoading extends StartupState {
  const StartupLoading();
}

/// Opening the database or loading the settings failed.
final class StartupFailed extends StartupState {
  const StartupFailed(this.step, this.error, this.stackTrace, {this.undoCopy});

  /// What was running, e.g. "Loading settings". English on purpose: it is
  /// part of the report the user sends us.
  final String step;

  final Object error;
  final StackTrace stackTrace;

  /// The newest pre-restore copy, when there is one: the screen then offers
  /// "Undo last restore", the only way out if a restored database can't
  /// start the app (phase-3.md §6.6, P3-18).
  final PreRestoreCopy? undoCopy;

  /// Plain-text report for the user to copy into a bug report.
  String get report => errorReport(step, error, stackTrace);
}

final class StartupReady extends StartupState {
  const StartupReady(this.dependencies, {this.recurring = GenerateReport.none});

  final AppDependencies dependencies;

  /// What the recurring generator did at this start (phase-7a.md §6.3):
  /// Home says "Added 2 recurring expenses" or asks about a backlog.
  final GenerateReport recurring;
}

/// Opens the database, loads the settings, adds the recurring payments
/// that came due, empties old expenses from the bin, deletes what a
/// cut-short backup or restore left and sweeps unused photos, once
/// migrations are done (phase-1.md §5, phase-7a.md §6.3, phase-2.md §9.3,
/// phase-3.md §6.6, phase-6.md §6.5).
class StartupCubit extends CubitSignal<StartupState>
    with EmitIfOpen<StartupState> {
  StartupCubit({
    required this._openDependencies,
    required this._settingsCubit,
    this._newestPreRestoreCopy,
  }) : super(initialState: const StartupLoading());

  final Future<AppDependencies> Function() _openDependencies;
  final SettingsCubit _settingsCubit;

  /// Looks for a pre-restore copy when startup fails. Null when restoring
  /// isn't available (tests).
  final Future<PreRestoreCopy?> Function()? _newestPreRestoreCopy;

  // Kept apart from the state because the initial state is StartupLoading
  // before start() has been called.
  bool _isRunning = false;

  Future<void> start() async {
    if (_isRunning || value is StartupReady) return;
    _isRunning = true;
    emitIfOpen(const StartupLoading());
    var step = 'Opening database';
    AppDependencies? dependencies;
    try {
      dependencies = await _openDependencies();
      step = 'Loading settings';
      await _settingsCubit.load(dependencies.settings);
      final recurring = await _generateRecurring(dependencies);
      await _purgeBin(dependencies);
      await _cleanUpLeftovers(dependencies);
      await _deleteOldReports(dependencies);
      await _sweepPhotos(dependencies);
      emitIfOpen(StartupReady(dependencies, recurring: recurring));
    } catch (error, stackTrace) {
      // Closed so that Retry starts afresh and Undo last restore can
      // replace the file.
      await _closeQuietly(dependencies);
      // Never fall through to onboarding here: with settings unreadable it
      // would overwrite a real user's settings.
      emitIfOpen(
        StartupFailed(
          step,
          error,
          stackTrace,
          undoCopy: await _newestCopyQuietly(),
        ),
      );
    } finally {
      _isRunning = false;
    }
  }

  /// Adds the recurring payments that came due (phase-7a.md §6.3, R13),
  /// before the bin purge (application-design.md §3). A backlog older than
  /// 31 days is held, not added. Like the purge, a failure is logged and
  /// never blocks the app: every payment is added again the next run, and
  /// no payment is lost.
  static Future<GenerateReport> _generateRecurring(
    AppDependencies dependencies,
  ) async {
    try {
      final watch = Stopwatch()..start();
      final report = await dependencies.recurring.generateDue();
      debugPrint('Recurring: $report in ${watch.elapsedMilliseconds} ms');
      return report;
    } catch (error, stackTrace) {
      debugPrint('Adding recurring payments failed: $error\n$stackTrace');
      return GenerateReport.none;
    }
  }

  /// Deletes expenses binned more than 30 days ago. A failure doesn't block
  /// the app (P2-7): unlike opening the database or reading the settings,
  /// skipping it loses nothing, and it is retried on the next start.
  static Future<void> _purgeBin(AppDependencies dependencies) async {
    try {
      await dependencies.expenses.purgeBin();
    } catch (error, stackTrace) {
      debugPrint(
        'Emptying old expenses from the bin failed: $error\n$stackTrace',
      );
    }
  }

  /// Deletes cut-short backup and restore files. Awaited (P3-19), so a
  /// restore started right away (e.g. from onboarding) can't have its new
  /// candidate deleted under it; it takes milliseconds. Like the purge, a
  /// failure is logged and doesn't block the app.
  static Future<void> _cleanUpLeftovers(AppDependencies dependencies) async {
    try {
      await dependencies.restoreTools.repository.cleanUpLeftovers();
    } catch (error, stackTrace) {
      debugPrint(
        'Deleting backup and restore leftovers failed: $error\n$stackTrace',
      );
    }
  }

  /// Deletes report exports older than a day and any half-made PDF's work
  /// file (phase-8.md §6.3, application-design §3 step 4b). Awaited: it
  /// empties `cache/report_work/`, so an export started meanwhile would
  /// lose its work file; it only lists the app's own cache, quickly. A
  /// failure is logged and doesn't block the app.
  static Future<void> _deleteOldReports(AppDependencies dependencies) async {
    try {
      await dependencies.reportExports.deleteOld();
    } catch (error, stackTrace) {
      debugPrint('Deleting old report files failed: $error\n$stackTrace');
    }
  }

  /// Deletes photo rows and files nothing uses any more: from permanent
  /// deletes, the purge above, Updates that removed a photo (phase-6.md
  /// §6.5, P6-13). Awaited, after the purge, before any form can save.
  /// Like the purge, a failure is logged and doesn't block the app; a file
  /// is never deleted when anything that might need it can't be read.
  static Future<void> _sweepPhotos(AppDependencies dependencies) async {
    final sweeper = dependencies.photoSweeper;
    if (sweeper == null) return;
    try {
      final watch = Stopwatch()..start();
      final result = await sweeper.sweep();
      debugPrint(
        'Photo sweep: ${result.rows} rows, ${result.files} files '
        '${result.filesSkipped ? '(files skipped) ' : ''}'
        'in ${watch.elapsedMilliseconds} ms',
      );
    } catch (error, stackTrace) {
      debugPrint('Sweeping unused photos failed: $error\n$stackTrace');
    }
  }

  static Future<void> _closeQuietly(AppDependencies? dependencies) async {
    try {
      await dependencies?.database.close();
    } catch (error) {
      debugPrint('Closing the database after a failed start failed: $error');
    }
  }

  Future<PreRestoreCopy?> _newestCopyQuietly() async {
    try {
      return await _newestPreRestoreCopy?.call();
    } catch (error) {
      debugPrint('Looking for pre-restore copies failed: $error');
      return null;
    }
  }
}
