import 'sql.dart';
import 'sqlite_type.dart';
import 'table_definition.dart';

/// Describes the columns of a new table inside `Migrator.createTable`.
///
/// ```dart
/// await m.createTable('expenses', (t) {
///   t.text('title', nullable: false);
///   t.real('amount', nullable: false, defaultValue: 0);
///   t.references('category_id', toTable: 'categories');
/// });
/// ```
class TableBuilder {
  TableBuilder(this.table);

  /// The definition being built. Used by the framework.
  final TableDefinition table;

  void column(
    String name,
    SqliteType type, {
    bool nullable = true,
    bool unique = false,
    Object? defaultValue,
  }) {
    if (table.hasColumn(name)) throw ArgumentError('Column "$name" is defined twice on "${table.name}"');
    table.columns.add(_newColumn(name, type, nullable: nullable, defaultValue: defaultValue));
    if (unique) table.uniqueConstraints.add([name]);
  }

  void integer(String name, {bool nullable = true, bool unique = false, Object? defaultValue}) =>
      column(name, SqliteType.integer, nullable: nullable, unique: unique, defaultValue: defaultValue);

  void real(String name, {bool nullable = true, bool unique = false, Object? defaultValue}) =>
      column(name, SqliteType.real, nullable: nullable, unique: unique, defaultValue: defaultValue);

  void text(String name, {bool nullable = true, bool unique = false, Object? defaultValue}) =>
      column(name, SqliteType.text, nullable: nullable, unique: unique, defaultValue: defaultValue);

  void blob(String name, {bool nullable = true, bool unique = false}) =>
      column(name, SqliteType.blob, nullable: nullable, unique: unique);

  void numeric(String name, {bool nullable = true, bool unique = false, Object? defaultValue}) =>
      column(name, SqliteType.numeric, nullable: nullable, unique: unique, defaultValue: defaultValue);

  /// Adds an INTEGER column that points at [toColumn] of [toTable], plus an
  /// index on it unless [index] is false.
  void references(
    String column, {
    required String toTable,
    String toColumn = 'id',
    bool nullable = true,
    ForeignKeyAction onDelete = ForeignKeyAction.noAction,
    ForeignKeyAction onUpdate = ForeignKeyAction.noAction,
    bool index = true,
  }) {
    this.column(column, SqliteType.integer, nullable: nullable);
    table.foreignKeys.add(_newForeignKey(column, toTable, toColumn, onDelete, onUpdate));
    if (index) this.index([column]);
  }

  /// Sets the primary key. Only needed when the table was created with
  /// `id: false`.
  void primaryKey(List<String> columns) {
    if (table.primaryKey.isNotEmpty) {
      throw ArgumentError('Table "${table.name}" already has a primary key; pass id: false to createTable');
    }
    table.primaryKey = [...columns];
  }

  void index(List<String> columns, {bool unique = false, String? name}) {
    table.indexes.add(_newIndex(table, columns, unique: unique, name: name));
  }
}

/// Describes changes to an existing table inside `Migrator.changeTable`.
///
/// All changes are applied together by rebuilding the table once.
///
/// ```dart
/// await m.changeTable('expenses', (t) {
///   t.renameColumn('note', 'description');
///   t.addColumn('currency', SqliteType.text);
///   t.removeColumn('legacy_flag');
/// });
/// ```
class TableEditor {
  TableEditor(this.table) : sourceColumns = {for (final c in table.columns) c.name: c.name};

  /// The new definition of the table. Used by the framework.
  final TableDefinition table;

  /// For every column of the new table, the column of the old table its
  /// data is copied from, or null for new columns. Used by the framework.
  final Map<String, String?> sourceColumns;

  void addColumn(
    String name,
    SqliteType type, {
    bool nullable = true,
    bool unique = false,
    Object? defaultValue,
  }) {
    if (table.hasColumn(name)) throw ArgumentError('Column "$name" already exists on "${table.name}"');
    table.columns.add(_newColumn(name, type, nullable: nullable, defaultValue: defaultValue));
    if (unique) table.uniqueConstraints.add([name]);
    sourceColumns[name] = null;
  }

  /// Removes the column along with any index, unique constraint or foreign
  /// key that includes it.
  void removeColumn(String name) {
    table.column(name); // Throws if missing.
    if (table.primaryKey.contains(name)) {
      throw ArgumentError('Cannot remove "$name" from "${table.name}" because it is part of the primary key');
    }
    table.columns.removeWhere((c) => c.name == name);
    table.uniqueConstraints.removeWhere((u) => u.contains(name));
    table.indexes.removeWhere((i) => i.columns.contains(name));
    table.foreignKeys.removeWhere(
      (f) => f.columns.contains(name) || (f.parentTable == table.name && f.parentColumns.contains(name)),
    );
    sourceColumns.remove(name);
  }

  /// Renames the column and keeps its data, indexes and constraints.
  void renameColumn(String from, String to) {
    checkIdentifier(to);
    if (table.hasColumn(to)) throw ArgumentError('Column "$to" already exists on "${table.name}"');
    table.column(from).name = to;

    List<String> rename(List<String> names) => [for (final n in names) n == from ? to : n];
    table.primaryKey = rename(table.primaryKey);
    table.uniqueConstraints = [for (final u in table.uniqueConstraints) rename(u)];
    for (final index in table.indexes) {
      index.columns = rename(index.columns);
    }
    for (final foreignKey in table.foreignKeys) {
      foreignKey.columns = rename(foreignKey.columns);
      if (foreignKey.parentTable == table.name) foreignKey.parentColumns = rename(foreignKey.parentColumns);
    }
    sourceColumns[to] = sourceColumns.remove(from);
  }

  /// Redefines the column. Existing values are kept; SQLite converts them to
  /// the new [type] where it can do so without losing information.
  ///
  /// Like Rails' `change_column`, this replaces the whole definition: leaving
  /// out [defaultValue] removes the default, and `unique` defaults to false.
  void changeColumn(
    String name,
    SqliteType type, {
    bool nullable = true,
    bool unique = false,
    Object? defaultValue,
  }) {
    final column = table.column(name);
    final updated = _newColumn(name, type, nullable: nullable, defaultValue: defaultValue);
    column
      ..type = updated.type
      ..nullable = updated.nullable
      ..defaultSql = updated.defaultSql;
    table.uniqueConstraints.removeWhere((u) => u.length == 1 && u.first == name);
    if (unique) table.uniqueConstraints.add([name]);
  }

  /// Adds an INTEGER column that points at [toColumn] of [toTable], plus an
  /// index on it unless [index] is false.
  void addReference(
    String column, {
    required String toTable,
    String toColumn = 'id',
    bool nullable = true,
    ForeignKeyAction onDelete = ForeignKeyAction.noAction,
    ForeignKeyAction onUpdate = ForeignKeyAction.noAction,
    bool index = true,
  }) {
    addColumn(column, SqliteType.integer, nullable: nullable);
    table.foreignKeys.add(_newForeignKey(column, toTable, toColumn, onDelete, onUpdate));
    if (index) addIndex([column]);
  }

  /// Removes a column added with [addReference], with its foreign key and
  /// index.
  void removeReference(String column) {
    if (!table.foreignKeys.any((f) => f.columns.contains(column))) {
      throw ArgumentError('Column "$column" on "${table.name}" is not a reference');
    }
    removeColumn(column);
  }

  void addIndex(List<String> columns, {bool unique = false, String? name}) {
    table.indexes.add(_newIndex(table, columns, unique: unique, name: name));
  }

  /// Removes the index on exactly [columns], or the index called [name].
  void removeIndex({List<String>? columns, String? name}) {
    final index = findIndex(table, columns: columns, name: name);
    table.indexes.remove(index);
  }
}

/// Finds an index on exactly [columns] or called [name].
IndexDefinition findIndex(TableDefinition table, {List<String>? columns, String? name}) {
  if ((columns == null) == (name == null)) {
    throw ArgumentError('Pass either columns or name to find an index');
  }
  for (final index in table.indexes) {
    if (name != null && index.name == name) return index;
    if (columns != null && index.columns.join(',') == columns.join(',')) return index;
  }
  throw ArgumentError('No index ${name ?? 'on $columns'} found on "${table.name}"');
}

ColumnDefinition _newColumn(String name, SqliteType type, {required bool nullable, Object? defaultValue}) {
  return ColumnDefinition(
    name: checkIdentifier(name),
    type: type,
    nullable: nullable,
    defaultSql: defaultValue == null ? null : toSqlLiteral(defaultValue),
  );
}

ForeignKeyDefinition _newForeignKey(
  String column,
  String toTable,
  String toColumn,
  ForeignKeyAction onDelete,
  ForeignKeyAction onUpdate,
) {
  return ForeignKeyDefinition(
    columns: [column],
    parentTable: checkIdentifier(toTable),
    parentColumns: [checkIdentifier(toColumn)],
    onDelete: onDelete,
    onUpdate: onUpdate,
  );
}

IndexDefinition _newIndex(TableDefinition table, List<String> columns, {required bool unique, String? name}) {
  if (columns.isEmpty) throw ArgumentError('An index needs at least one column');
  final indexName = checkIdentifier(name ?? IndexDefinition.defaultName(table.name, columns));
  if (table.indexes.any((i) => i.name == indexName)) {
    throw ArgumentError('Index "$indexName" already exists on "${table.name}"');
  }
  return IndexDefinition(name: indexName, columns: [...columns], unique: unique);
}
