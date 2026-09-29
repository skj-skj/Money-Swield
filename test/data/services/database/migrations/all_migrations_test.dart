import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration.dart';
import 'package:my_expense_tracker_app/data/services/database/migrations/all_migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../migration/test_helpers.dart';

/// Safety net for the real migrations shipped with the app.
void main() {
  test('every migration file is registered with the version and name from its file name', () {
    final files = Directory('lib/data/services/database/migrations')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => RegExp(r'^\d+_').hasMatch(name))
        .toList();
    final registered = {for (final m in allMigrations) '${m.version}_${m.name}.dart'};
    expect(registered, unorderedEquals(files));
  });

  test('every migration can run up, down and up again (like rails db:migrate:redo)', () async {
    final db = await openMemoryDatabase();
    addTearDown(db.close);
    // The same answer to every question the migrations ask.
    final m = migratorFor(db, prompter: FakePrompter(List.filled(100, '')));

    for (final migration in allMigrations) {
      await migration.up(m);
      final schemaAfterUp = await _schema(db);
      try {
        await migration.down(m);
      } on IrreversibleMigration {
        continue;
      }
      await migration.up(m);
      expect(await _schema(db), schemaAfterUp, reason: '$migration down() did not exactly undo up()');
    }
  });
}

Future<List<Map<String, Object?>>> _schema(Database db) =>
    db.rawQuery("SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name");
