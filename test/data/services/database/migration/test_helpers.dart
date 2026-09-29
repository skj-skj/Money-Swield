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

/// Answers every question with the queued answers, in order, and records
/// what was asked.
class FakePrompter implements MigrationPrompter {
  FakePrompter([List<String> answers = const []]) : _answers = [...answers];

  final List<String> _answers;
  final List<String> questions = [];

  @override
  Future<String> askText(String question, {String initialValue = ''}) async {
    questions.add(question);
    return _answers.removeAt(0);
  }

  @override
  Future<String> askChoice(String question, List<String> options) async {
    questions.add(question);
    return _answers.removeAt(0);
  }
}

Migrator migratorFor(DatabaseExecutor db, {Locale locale = const Locale('en', 'IN'), FakePrompter? prompter}) =>
    Migrator(db, locale: locale, prompter: prompter ?? FakePrompter());

/// A migration built from closures, for tests.
class TestMigration extends Migration {
  const TestMigration(int version, String name, this._up, [this._down]) : super(version: version, name: name);

  final Future<void> Function(Migrator m) _up;
  final Future<void> Function(Migrator m)? _down;

  @override
  Future<void> up(Migrator m) => _up(m);

  @override
  Future<void> down(Migrator m) => (_down ?? (_) => throw const IrreversibleMigration())(m);
}
