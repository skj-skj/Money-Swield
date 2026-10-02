import 'package:flutter/foundation.dart' show setEquals;

import 'sql.dart';
import 'sqlite_type.dart';

/// One column of a table.
class ColumnDefinition {
  ColumnDefinition({
    required this.name,
    required this.type,
    this.nullable = true,
    this.defaultSql,
  });

  String name;
  SqliteType type;
  bool nullable;

  /// The default value as SQL text (e.g. `'INR'` or `0`), or null for none.
  String? defaultSql;

  ColumnDefinition copy() => ColumnDefinition(
    name: name,
    type: type,
    nullable: nullable,
    defaultSql: defaultSql,
  );

  String toSql({required bool isPrimaryKey, required bool autoIncrement}) {
    final sql = StringBuffer('${quote(name)} ${type.sql}');
    if (isPrimaryKey) sql.write(' PRIMARY KEY');
    if (isPrimaryKey && autoIncrement) sql.write(' AUTOINCREMENT');
    if (!nullable) sql.write(' NOT NULL');
    if (defaultSql != null) sql.write(' DEFAULT $defaultSql');
    return sql.toString();
  }
}

/// A `FOREIGN KEY (...) REFERENCES parent (...)` constraint.
class ForeignKeyDefinition {
  ForeignKeyDefinition({
    required this.columns,
    required this.parentTable,
    required this.parentColumns,
    this.onDelete = ForeignKeyAction.noAction,
    this.onUpdate = ForeignKeyAction.noAction,
  });

  List<String> columns;
  String parentTable;
  List<String> parentColumns;
  ForeignKeyAction onDelete;
  ForeignKeyAction onUpdate;

  ForeignKeyDefinition copy() => ForeignKeyDefinition(
    columns: [...columns],
    parentTable: parentTable,
    parentColumns: [...parentColumns],
    onDelete: onDelete,
    onUpdate: onUpdate,
  );

  String toSql() => 'FOREIGN KEY (${quoteAll(columns)}) ${referencesSql()}';

  /// The `REFERENCES ...` part, also used when adding a column in place.
  String referencesSql() =>
      'REFERENCES ${quote(parentTable)} (${quoteAll(parentColumns)})'
      ' ON DELETE ${onDelete.sql} ON UPDATE ${onUpdate.sql}';
}

/// A `CREATE [UNIQUE] INDEX` on one or more columns.
class IndexDefinition {
  IndexDefinition({
    required this.name,
    required this.columns,
    this.unique = false,
  });

  String name;
  List<String> columns;
  bool unique;

  IndexDefinition copy() =>
      IndexDefinition(name: name, columns: [...columns], unique: unique);

  String toSql(String table) =>
      'CREATE ${unique ? 'UNIQUE ' : ''}INDEX ${quote(name)} ON ${quote(table)} (${quoteAll(columns)})';

  /// Rails-style default name: `index_expenses_on_category_id_and_spent_at`.
  static String defaultName(String table, List<String> columns) =>
      'index_${table}_on_${columns.join('_and_')}';
}

/// Everything needed to recreate a table exactly: columns, constraints and
/// indexes.
class TableDefinition {
  TableDefinition({
    required this.name,
    List<ColumnDefinition>? columns,
    List<String>? primaryKey,
    this.autoIncrement = false,
    List<List<String>>? uniqueConstraints,
    List<ForeignKeyDefinition>? foreignKeys,
    List<IndexDefinition>? indexes,
  }) : columns = columns ?? [],
       primaryKey = primaryKey ?? [],
       uniqueConstraints = uniqueConstraints ?? [],
       foreignKeys = foreignKeys ?? [],
       indexes = indexes ?? [];

  String name;
  List<ColumnDefinition> columns;
  List<String> primaryKey;

  /// Whether the single integer primary key is `AUTOINCREMENT`, which stops
  /// SQLite from ever reusing the id of a deleted row.
  bool autoIncrement;

  List<List<String>> uniqueConstraints;
  List<ForeignKeyDefinition> foreignKeys;
  List<IndexDefinition> indexes;

  TableDefinition copy() => TableDefinition(
    name: name,
    columns: [for (final c in columns) c.copy()],
    primaryKey: [...primaryKey],
    autoIncrement: autoIncrement,
    uniqueConstraints: [
      for (final u in uniqueConstraints) [...u],
    ],
    foreignKeys: [for (final f in foreignKeys) f.copy()],
    indexes: [for (final i in indexes) i.copy()],
  );

  bool hasColumn(String column) => columns.any((c) => c.name == column);

  ColumnDefinition column(String column) => columns.firstWhere(
    (c) => c.name == column,
    orElse: () => throw ArgumentError('Table "$name" has no column "$column"'),
  );

  /// Whether [keyColumns] identify a row, i.e. are the primary key or have a
  /// unique constraint or unique index. A foreign key can only point at
  /// such columns.
  bool isKey(List<String> keyColumns) {
    final wanted = keyColumns.toSet();
    return setEquals(primaryKey.toSet(), wanted) ||
        uniqueConstraints.any((u) => setEquals(u.toSet(), wanted)) ||
        indexes.any((i) => i.unique && setEquals(i.columns.toSet(), wanted));
  }

  /// The `CREATE TABLE` statement. [tableName] overrides [name], which is
  /// used when building the replacement table during a rebuild.
  String createTableSql({String? tableName}) {
    if (columns.isEmpty) {
      throw StateError('Table "$name" must have at least one column');
    }
    final inlinePrimaryKey = primaryKey.length == 1;
    final parts = <String>[
      for (final c in columns)
        c.toSql(
          isPrimaryKey: inlinePrimaryKey && primaryKey.first == c.name,
          autoIncrement: autoIncrement,
        ),
      if (primaryKey.length > 1) 'PRIMARY KEY (${quoteAll(primaryKey)})',
      for (final u in uniqueConstraints) 'UNIQUE (${quoteAll(u)})',
      for (final f in foreignKeys) f.toSql(),
    ];
    return 'CREATE TABLE ${quote(tableName ?? name)} (\n  ${parts.join(',\n  ')}\n)';
  }

  /// Throws if the definition refers to columns that do not exist or uses
  /// `AUTOINCREMENT` where SQLite does not allow it.
  void validate() {
    void checkColumns(List<String> names, String what) {
      for (final n in names) {
        if (!hasColumn(n)) {
          throw ArgumentError('$what on "$name" refers to unknown column "$n"');
        }
      }
    }

    final seen = <String>{};
    for (final c in columns) {
      if (!seen.add(c.name)) {
        throw ArgumentError('Table "$name" has column "${c.name}" twice');
      }
    }
    checkColumns(primaryKey, 'Primary key');
    for (final u in uniqueConstraints) {
      checkColumns(u, 'Unique constraint');
    }
    for (final f in foreignKeys) {
      checkColumns(f.columns, 'Foreign key');
    }
    final indexNames = <String>{};
    for (final i in indexes) {
      if (!indexNames.add(i.name)) {
        throw ArgumentError('Table "$name" has index "${i.name}" twice');
      }
      checkColumns(i.columns, 'Index "${i.name}"');
    }
    if (autoIncrement &&
        (primaryKey.length != 1 ||
            column(primaryKey.first).type != SqliteType.integer)) {
      throw ArgumentError(
        'AUTOINCREMENT needs a single INTEGER primary key on "$name"',
      );
    }
  }
}
