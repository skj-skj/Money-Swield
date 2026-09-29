import 'dart:ui' show Locale;

import 'package:sqflite/sqflite.dart';

import 'migration_prompter.dart';
import 'schema_reader.dart';
import 'sql.dart';
import 'sqlite_type.dart';
import 'table_builder.dart';
import 'table_definition.dart';

/// A database row: column name -> value.
typedef Row = Map<String, Object?>;

/// Everything a migration can do. Passed to `Migration.up` and
/// `Migration.down`.
///
/// Schema changes: [createTable], [dropTable], [changeTable], [addColumn],
/// [removeColumn], [renameColumn], [changeColumn], [addReference],
/// [removeReference], [addIndex], [removeIndex].
///
/// Backfilling data: [select], [insert], [update], [delete], [count].
///
/// Asking the user: [askText], [askChoice]. Device settings: [locale].
class Migrator {
  Migrator(this._db, {required this.locale, required this._prompter}) : _reader = SchemaReader(_db);

  final DatabaseExecutor _db;
  final MigrationPrompter _prompter;
  final SchemaReader _reader;

  /// The device's preferred locale, e.g. to pick a default currency.
  final Locale locale;

  // ---------------------------------------------------------------------------
  // Tables
  // ---------------------------------------------------------------------------

  /// Creates a table. Unless [id] is false, it gets an
  /// `id INTEGER PRIMARY KEY AUTOINCREMENT` column first.
  Future<void> createTable(String name, void Function(TableBuilder t) build, {bool id = true}) async {
    checkIdentifier(name);
    if (await tableExists(name)) throw ArgumentError('Table "$name" already exists');

    final table = TableDefinition(name: name);
    if (id) {
      table.columns.add(ColumnDefinition(name: 'id', type: SqliteType.integer));
      table.primaryKey = ['id'];
      table.autoIncrement = true;
    }
    build(TableBuilder(table));
    table.validate();

    await _db.execute(table.createTableSql());
    for (final index in table.indexes) {
      await _db.execute(index.toSql(name));
    }
  }

  /// Drops a table and all its data. Fails if another table still has a
  /// foreign key pointing at it.
  Future<void> dropTable(String name) async {
    await _reader.readTable(name); // Throws if missing.
    final referencing = await _reader.foreignKeysReferencing(name);
    if (referencing.isNotEmpty) {
      throw ArgumentError(
        'Cannot drop "$name": ${referencing.map((r) => '"${r.table}"').join(', ')} still reference it. '
        'Remove those references first.',
      );
    }
    await _db.execute('DROP TABLE ${quote(name)}');
  }

  /// Changes a table by rebuilding it: SQLite's `ALTER TABLE` can only do a
  /// few things, so a new table with the wanted shape is created, the rows
  /// are copied over, and it replaces the old one. Indexes and constraints
  /// are kept.
  Future<void> changeTable(String name, void Function(TableEditor t) edit) async {
    final before = await _reader.readTable(name);
    final editor = TableEditor(before.copy());
    edit(editor);
    final after = editor.table..validate();

    await _checkNoOutsideReferencesBreak(before, editor.sourceColumns);
    await _checkExistingRowsFit(after, editor.sourceColumns);
    await _rebuild(before, after, editor.sourceColumns);
  }

  Future<bool> tableExists(String name) => _reader.tableExists(name);

  Future<bool> columnExists(String table, String column) async =>
      await tableExists(table) && (await _reader.readTable(table)).hasColumn(column);

  // ---------------------------------------------------------------------------
  // Columns (each is a one-change changeTable)
  // ---------------------------------------------------------------------------

  Future<void> addColumn(
    String table,
    String column,
    SqliteType type, {
    bool nullable = true,
    bool unique = false,
    Object? defaultValue,
  }) => changeTable(
    table,
    (t) => t.addColumn(column, type, nullable: nullable, unique: unique, defaultValue: defaultValue),
  );

  Future<void> removeColumn(String table, String column) =>
      changeTable(table, (t) => t.removeColumn(column));

  Future<void> renameColumn(String table, String from, String to) =>
      changeTable(table, (t) => t.renameColumn(from, to));

  /// Redefines a column's type and constraints; see [TableEditor.changeColumn].
  Future<void> changeColumn(
    String table,
    String column,
    SqliteType type, {
    bool nullable = true,
    bool unique = false,
    Object? defaultValue,
  }) => changeTable(
    table,
    (t) => t.changeColumn(column, type, nullable: nullable, unique: unique, defaultValue: defaultValue),
  );

  Future<void> addReference(
    String table,
    String column, {
    required String toTable,
    String toColumn = 'id',
    bool nullable = true,
    ForeignKeyAction onDelete = ForeignKeyAction.noAction,
    ForeignKeyAction onUpdate = ForeignKeyAction.noAction,
    bool index = true,
  }) => changeTable(
    table,
    (t) => t.addReference(
      column,
      toTable: toTable,
      toColumn: toColumn,
      nullable: nullable,
      onDelete: onDelete,
      onUpdate: onUpdate,
      index: index,
    ),
  );

  Future<void> removeReference(String table, String column) =>
      changeTable(table, (t) => t.removeReference(column));

  // ---------------------------------------------------------------------------
  // Indexes (no rebuild needed)
  // ---------------------------------------------------------------------------

  Future<void> addIndex(String table, List<String> columns, {bool unique = false, String? name}) async {
    final definition = await _reader.readTable(table);
    final editor = TableEditor(definition)..addIndex(columns, unique: unique, name: name);
    definition.validate();
    await _db.execute(editor.table.indexes.last.toSql(table));
  }

  /// Removes the index on exactly [columns], or the index called [name].
  Future<void> removeIndex(String table, {List<String>? columns, String? name}) async {
    final index = findIndex(await _reader.readTable(table), columns: columns, name: name);
    await _db.execute('DROP INDEX ${quote(index.name)}');
  }

  // ---------------------------------------------------------------------------
  // Data, for backfills. `where` matches columns by equality (null = IS NULL).
  // ---------------------------------------------------------------------------

  Future<List<Row>> select(String table, {List<String>? columns, Map<String, Object?> where = const {}}) {
    final (whereSql, args) = _where(where);
    return _db.query(quote(table), columns: columns?.map(quote).toList(), where: whereSql, whereArgs: args);
  }

  /// Inserts a row and returns its rowid.
  Future<int> insert(String table, Map<String, Object?> values) => _db.insert(quote(table), _quoteKeys(values));

  /// Updates matching rows (all rows if [where] is empty) and returns how
  /// many changed.
  Future<int> update(String table, Map<String, Object?> values, {Map<String, Object?> where = const {}}) {
    final (whereSql, args) = _where(where);
    return _db.update(quote(table), _quoteKeys(values), where: whereSql, whereArgs: args);
  }

  /// Deletes matching rows (all rows if [where] is empty) and returns how
  /// many were deleted.
  Future<int> delete(String table, {Map<String, Object?> where = const {}}) {
    final (whereSql, args) = _where(where);
    return _db.delete(quote(table), where: whereSql, whereArgs: args);
  }

  Future<int> count(String table, {Map<String, Object?> where = const {}}) async {
    final (whereSql, args) = _where(where);
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${quote(table)}${whereSql == null ? '' : ' WHERE $whereSql'}',
      args,
    );
    return rows.first['n']! as int;
  }

  // ---------------------------------------------------------------------------
  // Asking the user
  // ---------------------------------------------------------------------------

  /// Shows [question] on the migration screen and waits for typed text.
  Future<String> askText(String question, {String initialValue = ''}) =>
      _prompter.askText(question, initialValue: initialValue);

  /// Shows [question] on the migration screen and waits for the user to
  /// pick one of [options].
  Future<String> askChoice(String question, List<String> options) {
    if (options.isEmpty) throw ArgumentError('askChoice needs at least one option');
    return _prompter.askChoice(question, options);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Other tables may point at a column that the change renames or removes;
  /// their foreign keys would silently break, so refuse.
  Future<void> _checkNoOutsideReferencesBreak(TableDefinition before, Map<String, String?> sources) async {
    final keptColumns = sources.entries.where((e) => e.key == e.value).map((e) => e.key).toSet();
    for (final reference in await _reader.foreignKeysReferencing(before.name)) {
      for (final column in reference.foreignKey.parentColumns) {
        if (!keptColumns.contains(column)) {
          throw ArgumentError(
            'Cannot rename or remove "${before.name}.$column": "${reference.table}" references it.',
          );
        }
      }
    }
  }

  /// Gives a clear message instead of a bare "NOT NULL constraint failed".
  Future<void> _checkExistingRowsFit(TableDefinition after, Map<String, String?> sources) async {
    for (final column in after.columns.where((c) => !c.nullable && c.defaultSql == null)) {
      final source = sources[column.name];
      final missing = source == null
          ? await count(after.name)
          : await count(after.name, where: {source: null});
      if (missing > 0) {
        throw StateError(
          '"${after.name}.${column.name}" cannot be NOT NULL: $missing existing row(s) have no value. '
          'Add it as nullable, backfill it with update(), then changeColumn(..., nullable: false).',
        );
      }
    }
  }

  /// SQLite's documented 12-step procedure for changing a table:
  /// https://www.sqlite.org/lang_altertable.html#otheralter
  /// Foreign key enforcement is switched off by the runner beforehand and
  /// checked after the migration.
  Future<void> _rebuild(TableDefinition before, TableDefinition after, Map<String, String?> sources) async {
    final table = before.name;
    final temporary = '_migration_new_$table';
    final copied = after.columns.where((c) => sources[c.name] != null).toList();

    await _db.execute(after.createTableSql(tableName: temporary));
    if (copied.isNotEmpty) {
      await _db.execute(
        'INSERT INTO ${quote(temporary)} (${quoteAll([for (final c in copied) c.name])}) '
        'SELECT ${quoteAll([for (final c in copied) sources[c.name]!])} FROM ${quote(table)}',
      );
    }

    final lastId = before.autoIncrement ? await _autoIncrementCounter(table) : null;

    await _db.execute('DROP TABLE ${quote(table)}');
    await _db.execute('ALTER TABLE ${quote(temporary)} RENAME TO ${quote(table)}');
    for (final index in after.indexes) {
      await _db.execute(index.toSql(table));
    }

    // Dropping the old table forgets the highest id ever handed out. Restore
    // it so ids of deleted rows are never reused.
    if (after.autoIncrement && lastId != null) {
      final current = await _autoIncrementCounter(table);
      if (current == null) {
        await _db.insert('sqlite_sequence', {'name': table, 'seq': lastId});
      } else if (current < lastId) {
        await _db.update('sqlite_sequence', {'seq': lastId}, where: 'name = ?', whereArgs: [table]);
      }
    }
  }

  Future<int?> _autoIncrementCounter(String table) async {
    if (!await _reader.tableExists('sqlite_sequence')) return null;
    final rows = await _db.query('sqlite_sequence', columns: ['seq'], where: 'name = ?', whereArgs: [table]);
    return rows.isEmpty ? null : rows.first['seq']! as int;
  }

  (String?, List<Object?>) _where(Map<String, Object?> where) {
    if (where.isEmpty) return (null, const []);
    final conditions = <String>[];
    final args = <Object?>[];
    for (final MapEntry(:key, :value) in where.entries) {
      if (value == null) {
        conditions.add('${quote(key)} IS NULL');
      } else {
        conditions.add('${quote(key)} = ?');
        args.add(value);
      }
    }
    return (conditions.join(' AND '), args);
  }

  Map<String, Object?> _quoteKeys(Map<String, Object?> values) =>
      {for (final MapEntry(:key, :value) in values.entries) quote(key): value};
}
