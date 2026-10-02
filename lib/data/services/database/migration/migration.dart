/// Everything needed to write a migration. Each migration file imports only
/// this file.
library;

import 'migrator.dart';

export 'migrator.dart' show Migrator, Row;
export 'sqlite_type.dart';
export 'table_builder.dart' show TableBuilder, TableEditor;

/// One step in the evolution of the database schema, like a Rails migration.
///
/// Create new ones with `dart tool/new_migration.dart <name>`; never edit a
/// migration that has already been released, add a new one instead.
///
/// [up] makes the change; [down] undoes it exactly. Each migration runs in
/// its own transaction, so if it throws, none of its changes are kept.
abstract class Migration {
  const Migration({required this.version, required this.name});

  /// Unix timestamp from the file name. Migrations run in this order.
  final int version;

  /// Name from the file name, e.g. `add_currency_to_expenses`.
  final String name;

  Future<void> up(Migrator m);

  Future<void> down(Migrator m);

  @override
  String toString() => '${version}_$name';
}

/// Throw from [Migration.down] when a change cannot be undone, e.g. because
/// data was deleted.
class IrreversibleMigration implements Exception {
  const IrreversibleMigration([
    this.reason = 'This migration cannot be undone',
  ]);

  final String reason;

  @override
  String toString() => 'IrreversibleMigration: $reason';
}
