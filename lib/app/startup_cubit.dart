import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/services/backup/pre_restore_copy.dart';
import '../domain/error_report.dart';
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
  const StartupReady(this.dependencies);

  final AppDependencies dependencies;
}

/// Opens the database, loads the settings, empties old expenses from the
/// bin and deletes what a cut-short backup or restore left, once
/// migrations are done (phase-1.md §5, phase-2.md §9.3, phase-3.md §6.6).
class StartupCubit extends CubitSignal<StartupState> {
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
    _emitIfOpen(const StartupLoading());
    var step = 'Opening database';
    AppDependencies? dependencies;
    try {
      dependencies = await _openDependencies();
      step = 'Loading settings';
      await _settingsCubit.load(dependencies.settings);
      await _purgeBin(dependencies);
      await _cleanUpLeftovers(dependencies);
      _emitIfOpen(StartupReady(dependencies));
    } catch (error, stackTrace) {
      // Closed so that Retry starts afresh and Undo last restore can
      // replace the file.
      await _closeQuietly(dependencies);
      // Never fall through to onboarding here: with settings unreadable it
      // would overwrite a real user's settings.
      _emitIfOpen(
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

  /// Deletes expenses binned more than 30 days ago. A failure doesn't block
  /// the app (P2-7): unlike opening the database or reading the settings,
  /// skipping it loses nothing, and it is retried on the next start.
  static Future<void> _purgeBin(AppDependencies dependencies) async {
    try {
      await dependencies.expenses.purgeBin();
      // Phase 6 adds the orphan-photo cleanup here.
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

  // start() keeps going across awaits, so the cubit may have been closed by
  // the time a result arrives. Emitting after close() asserts in debug mode.
  void _emitIfOpen(StartupState state) {
    if (!isClosed) emit(state);
  }
}
