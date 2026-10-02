import 'dart:ui' show Locale;

import 'package:my_expense_tracker_app/data/services/database/migration/migration.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration_prompter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Real SQLite (via FFI) for tests on the development machine.
DatabaseFactory testDatabaseFactory() {
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

Future<Database> openMemoryDatabase() => testDatabaseFactory().openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(singleInstance: false),
);

/// Answers questions with the queued answers, in order, and records what
/// was asked. Once the queue is empty it accepts the suggestion: the
/// `initialValue`, or for a choice without one, the first option.
class FakePrompter implements MigrationPrompter {
  FakePrompter([List<String> answers = const []]) : _answers = [...answers];

  final List<String> _answers;
  final List<String> questions = [];

  @override
  Future<String> askText(String question, {String initialValue = ''}) async {
    questions.add(question);
    return _answers.isEmpty ? initialValue : _answers.removeAt(0);
  }

  @override
  Future<String> askChoice(
    String question,
    List<String> options, {
    String? initialValue,
  }) async {
    questions.add(question);
    if (_answers.isEmpty) return initialValue ?? options.first;
    final answer = _answers.removeAt(0);
    if (!options.contains(answer)) {
      throw StateError('"$answer" is not one of $options for "$question"');
    }
    return answer;
  }
}

Migrator migratorFor(
  DatabaseExecutor db, {
  Locale locale = const Locale('en', 'IN'),
  FakePrompter? prompter,
}) => Migrator(db, locale: locale, prompter: prompter ?? FakePrompter());

/// A migration built from closures, for tests.
class TestMigration extends Migration {
  const TestMigration(int version, String name, this._up, [this._down])
    : super(version: version, name: name);

  final Future<void> Function(Migrator m) _up;
  final Future<void> Function(Migrator m)? _down;

  @override
  Future<void> up(Migrator m) => _up(m);

  @override
  Future<void> down(Migrator m) =>
      (_down ?? (_) => throw const IrreversibleMigration())(m);
}
