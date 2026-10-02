import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/services/database/app_database.dart';
import '../../../../data/services/database/migration/migration_prompter.dart';
import '../../../../data/services/database/migration/migration_runner.dart';

/// A question a migration is waiting on. [options] is null for free text.
class MigrationQuestion {
  const MigrationQuestion({
    required this.text,
    this.options,
    this.initialValue,
  });

  final String text;
  final List<String>? options;

  /// The prefilled text, or the option selected at first. Null for a choice
  /// means nothing is selected until the user picks.
  final String? initialValue;
}

/// What the migration screen shows. States don't override `==`, so emitting
/// a new state object always reaches the screen, even with the same values.
sealed class MigrationState {
  const MigrationState();
}

/// Migrations are running (or about to). [progress] is null before the
/// first report arrives.
final class MigrationInProgress extends MigrationState {
  const MigrationInProgress([this.progress]);

  final MigrationProgress? progress;
}

/// A migration is waiting for the user to answer [question].
///
/// [progress] is kept so the screen can go back to it after the answer.
final class MigrationAsking extends MigrationState {
  const MigrationAsking({required this.question, this.progress});

  final MigrationQuestion question;
  final MigrationProgress? progress;
}

/// A migration failed; the screen shows the report and a retry button.
final class MigrationFailed extends MigrationState {
  const MigrationFailed(this.failure);

  final MigrationFailure failure;
}

/// The database is up to date and the app can open.
final class MigrationDone extends MigrationState {
  const MigrationDone();
}

/// Runs the database migrations on app start and exposes their progress,
/// questions and failures to the migration screen.
class MigrationCubit extends CubitSignal<MigrationState>
    implements MigrationPrompter {
  MigrationCubit({required this._database, required this._locale})
    : super(initialState: const MigrationInProgress());

  final AppDatabase _database;
  final Locale _locale;

  Completer<String>? _answer;

  // Kept apart from the state because "running" covers both
  // MigrationInProgress and MigrationAsking, and the initial state is
  // MigrationInProgress before run() has been called.
  bool _isRunning = false;

  Future<void> run() async {
    if (_isRunning || value is MigrationDone) return;
    _isRunning = true;
    // A failed run can leave a question unanswered if the migration threw
    // without waiting for it. Drop it so a retry can ask again.
    _answer = null;
    _emitIfOpen(const MigrationInProgress());

    try {
      await _database.migrate(
        locale: _locale,
        prompter: this,
        // Progress is only reported between migrations, never while one is
        // waiting for an answer, so this cannot hide a pending question.
        onProgress: (progress) => _emitIfOpen(MigrationInProgress(progress)),
      );
      _emitIfOpen(const MigrationDone());
    } on MigrationFailure catch (failure) {
      _emitIfOpen(MigrationFailed(failure));
    } catch (error, stackTrace) {
      _emitIfOpen(
        MigrationFailed(
          MigrationFailure(
            step: 'Starting database',
            error: error,
            stackTrace: stackTrace,
          ),
        ),
      );
    } finally {
      _isRunning = false;
    }
  }

  /// Called by the screen when the user answers the current question.
  void answer(String text) {
    final answer = _answer;
    final state = value;
    if (answer == null || state is! MigrationAsking) return;
    _answer = null;
    _emitIfOpen(MigrationInProgress(state.progress));
    answer.complete(text);
  }

  @override
  Future<String> askText(String question, {String initialValue = ''}) =>
      _ask(MigrationQuestion(text: question, initialValue: initialValue));

  @override
  Future<String> askChoice(
    String question,
    List<String> options, {
    String? initialValue,
  }) => _ask(
    MigrationQuestion(
      text: question,
      options: List.unmodifiable(options),
      initialValue: initialValue,
    ),
  );

  Future<String> _ask(MigrationQuestion question) {
    if (_answer != null) {
      throw StateError('A migration question is already waiting for an answer');
    }
    final state = value;
    final progress = state is MigrationInProgress ? state.progress : null;
    final answer = Completer<String>();
    _answer = answer;
    _emitIfOpen(MigrationAsking(question: question, progress: progress));
    return answer.future;
  }

  // run() keeps going across awaits, so the cubit may have been closed by
  // the time a result arrives. Emitting after close() asserts in debug mode.
  void _emitIfOpen(MigrationState state) {
    if (!isClosed) emit(state);
  }
}
