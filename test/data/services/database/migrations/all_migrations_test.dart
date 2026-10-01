import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/schema_reader.dart';
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
    // Every question is answered with its suggested value.
    final m = migratorFor(db);

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

/// Every table as the framework sees it, as SQL. Compared via the framework
/// rather than SQLite's stored text, because a column added in place is
/// written differently from the same column after a rebuild.
Future<List<String>> _schema(Database db) async {
  final reader = SchemaReader(db);
  return [
    for (final name in await reader.tableNames())
      if (await reader.readTable(name) case final table) ...[
        table.createTableSql(),
        for (final index in table.indexes) index.toSql(name),
      ],
  ];
}
