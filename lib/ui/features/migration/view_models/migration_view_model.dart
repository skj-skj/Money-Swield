import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../data/services/database/app_database.dart';
import '../../../../data/services/database/migration/migration_prompter.dart';
import '../../../../data/services/database/migration/migration_runner.dart';

/// A question a migration is waiting on. [options] is null for free text.
class MigrationQuestion {
  const MigrationQuestion({required this.text, this.options, this.initialValue});

  final String text;
  final List<String>? options;

  /// The prefilled text, or the option selected at first. Null for a choice
  /// means nothing is selected until the user picks.
  final String? initialValue;
}

/// Runs the database migrations on app start and exposes their progress,
/// questions and failures to the migration screen.
class MigrationViewModel extends ChangeNotifier implements MigrationPrompter {
  MigrationViewModel({required this._database, required this._locale});

  final AppDatabase _database;
  final Locale _locale;

  MigrationProgress? _progress;
  MigrationProgress? get progress => _progress;

  MigrationFailure? _failure;
  MigrationFailure? get failure => _failure;

  MigrationQuestion? _question;
  MigrationQuestion? get question => _question;
  Completer<String>? _answer;

  bool _isDone = false;
  bool get isDone => _isDone;

  bool _isRunning = false;

  Future<void> run() async {
    if (_isRunning || _isDone) return;
    _isRunning = true;
    _failure = null;
    _progress = null;
    notifyListeners();

    try {
      await _database.migrate(
        locale: _locale,
        prompter: this,
        onProgress: (progress) {
          _progress = progress;
          notifyListeners();
        },
      );
      _isDone = true;
    } on MigrationFailure catch (failure) {
      _failure = failure;
    } catch (error, stackTrace) {
      _failure = MigrationFailure(step: 'Starting database', error: error, stackTrace: stackTrace);
    } finally {
      _isRunning = false;
      _question = null;
      notifyListeners();
    }
  }

  /// Called by the screen when the user answers the current [question].
  void answer(String value) {
    final answer = _answer;
    if (answer == null) return;
    _answer = null;
    _question = null;
    notifyListeners();
    answer.complete(value);
  }

  @override
  Future<String> askText(String question, {String initialValue = ''}) =>
      _ask(MigrationQuestion(text: question, initialValue: initialValue));

  @override
  Future<String> askChoice(String question, List<String> options, {String? initialValue}) =>
      _ask(MigrationQuestion(text: question, options: List.unmodifiable(options), initialValue: initialValue));

  Future<String> _ask(MigrationQuestion question) {
    if (_answer != null) throw StateError('A migration question is already waiting for an answer');
    final answer = Completer<String>();
    _answer = answer;
    _question = question;
    notifyListeners();
    return answer.future;
  }
}
