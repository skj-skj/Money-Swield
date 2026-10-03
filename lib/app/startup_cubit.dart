import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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
  const StartupFailed(this.step, this.error, this.stackTrace);

  /// What was running, e.g. "Loading settings". English on purpose: it is
  /// part of the report the user sends us.
  final String step;

  final Object error;
  final StackTrace stackTrace;

  /// Plain-text report for the user to copy into a bug report.
  String get report => 'Step: $step\nError: $error\n\n$stackTrace';
}

final class StartupReady extends StartupState {
  const StartupReady(this.dependencies);

  final AppDependencies dependencies;
}

/// Opens the database, loads the settings and empties old expenses from
/// the bin once migrations are done (phase-1.md §5, phase-2.md §9.3).
class StartupCubit extends CubitSignal<StartupState> {
  StartupCubit({required this._openDependencies, required this._settingsCubit})
    : super(initialState: const StartupLoading());

  final Future<AppDependencies> Function() _openDependencies;
  final SettingsCubit _settingsCubit;

  // Kept apart from the state because the initial state is StartupLoading
  // before start() has been called.
  bool _isRunning = false;

  Future<void> start() async {
    if (_isRunning || value is StartupReady) return;
    _isRunning = true;
    _emitIfOpen(const StartupLoading());
    var step = 'Opening database';
    try {
      final dependencies = await _openDependencies();
      step = 'Loading settings';
      await _settingsCubit.load(dependencies.settings);
      await _purgeBin(dependencies);
      _emitIfOpen(StartupReady(dependencies));
    } catch (error, stackTrace) {
      // Never fall through to onboarding here: with settings unreadable it
      // would overwrite a real user's settings.
      _emitIfOpen(StartupFailed(step, error, stackTrace));
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

  // start() keeps going across awaits, so the cubit may have been closed by
  // the time a result arrives. Emitting after close() asserts in debug mode.
  void _emitIfOpen(StartupState state) {
    if (!isClosed) emit(state);
  }
}
