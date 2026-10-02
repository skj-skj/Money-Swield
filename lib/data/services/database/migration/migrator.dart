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
  Migrator(this._db, {required this.locale, required this._prompter})
    : _reader = SchemaReader(_db);

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
  Future<void> createTable(
    String name,
    void Function(TableBuilder t) build, {
    bool id = true,
  }) async {
    checkIdentifier(name);
    if (await _reader.nameInUse(name) case final owner?) {
      throw ArgumentError(
        'Cannot create table "$name": the name is already used by $owner',
      );
    }

    final table = TableDefinition(name: name);
    if (id) {
      table.columns.add(ColumnDefinition(name: 'id', type: SqliteType.integer));
      table.primaryKey = ['id'];
      table.autoIncrement = true;
    }
    build(TableBuilder(table));
    table.validate();
    await _checkReferencedKeys(table);
    await _checkIndexNamesFree(table);

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

  /// Changes a table. Indexes and constraints are kept.
  ///
  /// SQLite's `ALTER TABLE` can only add plain columns everywhere; renaming
  /// and dropping columns need newer SQLite than older Android versions
  /// ship, and changing a type, NOT NULL, a default or a constraint is not
  /// possible at all. So plain new columns and index changes are applied in
  /// place, and anything else rebuilds the table: a new table with the
  /// wanted shape is created, the rows are copied over, and it replaces the
  /// old one. Put several changes in one [changeTable] to rebuild only once.
  Future<void> changeTable(
    String name,
    void Function(TableEditor t) edit,
  ) async {
    final before = await _reader.readTable(name);
    final editor = TableEditor(before.copy());
    edit(editor);
    final after = editor.table..validate();
    final sources = editor.sourceColumns;

    await _checkReferencesToTable(after, sources);
    await _checkReferencedKeys(after);
    await _checkIndexNamesFree(after);
    await _checkExistingRowsFit(after, sources);

    final added = [
      for (final c in after.columns)
        if (!sources.containsKey(c.name)) c,
    ];
    if (_canChangeInPlace(before, after, added)) {
      await _changeInPlace(before, after, added);
    } else {
      await _reader.checkCanRebuild(name);
      await _rebuild(before, after, sources);
    }
  }

  Future<bool> tableExists(String name) => _reader.tableExists(name);

  Future<bool> columnExists(String table, String column) async =>
      await tableExists(table) &&
      (await _reader.readTable(table)).hasColumn(column);

  // ---------------------------------------------------------------------------
  // Columns and indexes (each is a one-change changeTable)
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
    (t) => t.column(
      column,
      type,
      nullable: nullable,
      unique: unique,
      defaultValue: defaultValue,
    ),
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
    (t) => t.changeColumn(
      column,
      type,
      nullable: nullable,
      unique: unique,
      defaultValue: defaultValue,
    ),
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
    (t) => t.references(
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

  Future<void> addIndex(
    String table,
    List<String> columns, {
    bool unique = false,
    String? name,
  }) => changeTable(table, (t) => t.index(columns, unique: unique, name: name));

  /// Removes the index on exactly [columns], or the index called [name].
  Future<void> removeIndex(
    String table, {
    List<String>? columns,
    String? name,
  }) => changeTable(table, (t) => t.removeIndex(columns: columns, name: name));

  // ---------------------------------------------------------------------------
  // Data, for backfills. `where` matches columns by equality (null = IS NULL).
  // `bool` values are stored as 1 / 0.
  // ---------------------------------------------------------------------------

  Future<List<Row>> select(
    String table, {
    List<String>? columns,
    Map<String, Object?> where = const {},
  }) {
    final (whereSql, args) = _where(where);
    return _db.query(
      quote(table),
      columns: columns?.map(quote).toList(),
      where: whereSql,
      whereArgs: args,
    );
  }

  /// Inserts a row and returns its rowid.
  Future<int> insert(String table, Map<String, Object?> values) =>
      _db.insert(quote(table), _values(values));

  /// Updates matching rows (all rows if [where] is empty) and returns how
  /// many changed.
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    Map<String, Object?> where = const {},
  }) {
    final (whereSql, args) = _where(where);
    return _db.update(
      quote(table),
      _values(values),
      where: whereSql,
      whereArgs: args,
    );
  }

  /// Deletes matching rows (all rows if [where] is empty) and returns how
  /// many were deleted.
  Future<int> delete(String table, {Map<String, Object?> where = const {}}) {
    final (whereSql, args) = _where(where);
    return _db.delete(quote(table), where: whereSql, whereArgs: args);
  }

  Future<int> count(
    String table, {
    Map<String, Object?> where = const {},
  }) async {
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
  /// pick one of [options]. [initialValue], if given, must be one of the
  /// [options] and is shown already selected.
  Future<String> askChoice(
    String question,
    List<String> options, {
    String? initialValue,
  }) {
    if (options.isEmpty) {
      throw ArgumentError('askChoice needs at least one option');
    }
    if (initialValue != null && !options.contains(initialValue)) {
      throw ArgumentError.value(
        initialValue,
        'initialValue',
        'Must be one of the options $options',
      );
    }
    return _prompter.askChoice(question, options, initialValue: initialValue);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Other tables may point at columns of [after]. Those columns must keep
  /// their name and stay unique, or the other table's foreign keys break.
  Future<void> _checkReferencesToTable(
    TableDefinition after,
    Map<String, String> sources,
  ) async {
    for (final (:table, :foreignKey) in await _reader.foreignKeysReferencing(
      after.name,
    )) {
      final columns = foreignKey.parentColumns;
      for (final column in columns) {
        if (sources[column] != column) {
          throw ArgumentError(
            'Cannot rename or remove "${after.name}.$column": "$table" references it.',
          );
        }
      }
      if (!after.isKey(columns)) {
        throw ArgumentError(
          '"$table" references "${after.name}" (${columns.join(', ')}), so it must stay the primary key or unique.',
        );
      }
    }
  }

  /// A foreign key must point at the primary key or unique columns of an
  /// existing table. SQLite does not check this when the table is created,
  /// only later, when the app writes a row, so check it here instead.
  Future<void> _checkReferencedKeys(TableDefinition table) async {
    for (final foreignKey in table.foreignKeys) {
      final parentName = foreignKey.parentTable;
      final parent = parentName == table.name
          ? table
          : await _reader.tableExists(parentName)
          ? await _reader.readTable(parentName)
          : null;
      if (parent == null) {
        throw ArgumentError(
          '"${table.name}" references table "$parentName", which does not exist',
        );
      }
      if (!parent.isKey(foreignKey.parentColumns)) {
        throw ArgumentError(
          '"${table.name}" references "$parentName" (${foreignKey.parentColumns.join(', ')}), '
          'which is not its primary key or a unique column',
        );
      }
    }
  }

  /// Index names must be unique across the whole database, not just per
  /// table.
  Future<void> _checkIndexNamesFree(TableDefinition table) async {
    for (final index in table.indexes) {
      if (await _reader.nameInUse(index.name, exceptTable: table.name)
          case final owner?) {
        throw ArgumentError(
          'Index name "${index.name}" is already used by $owner',
        );
      }
    }
  }

  /// Gives a clear message instead of a bare "NOT NULL constraint failed".
  /// Columns with a default always fit: new rows get the default, and
  /// [_rebuild] replaces copied NULLs with it.
  Future<void> _checkExistingRowsFit(
    TableDefinition after,
    Map<String, String> sources,
  ) async {
    for (final column in after.columns.where(
      (c) => !c.nullable && c.defaultSql == null,
    )) {
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

  /// Whether the change only adds columns that `ALTER TABLE ADD COLUMN` can
  /// add and changes indexes, so no rebuild is needed. SQLite can add a
  /// column only if it is not UNIQUE, not NOT NULL without a default, and, if
  /// it is a reference, has no default.
  bool _canChangeInPlace(
    TableDefinition before,
    TableDefinition after,
    List<ColumnDefinition> added,
  ) {
    for (final column in added) {
      final isReference = _referenceOf(after, column.name) != null;
      final hasValue = column.nullable || column.defaultSql != null;
      if (!hasValue || (isReference && column.defaultSql != null)) return false;
    }
    // Apart from the added columns and their references, the table itself
    // (columns, primary key, constraints) must be unchanged.
    final addedNames = {for (final c in added) c.name};
    final rest = after.copy()
      ..columns.removeWhere((c) => addedNames.contains(c.name))
      ..foreignKeys.removeWhere(
        (f) => f.columns.length == 1 && addedNames.contains(f.columns.first),
      );
    return rest.createTableSql() == before.createTableSql();
  }

  Future<void> _changeInPlace(
    TableDefinition before,
    TableDefinition after,
    List<ColumnDefinition> added,
  ) async {
    final table = before.name;
    for (final column in added) {
      final reference = _referenceOf(after, column.name);
      await _db.execute(
        'ALTER TABLE ${quote(table)} ADD COLUMN ${column.toSql(isPrimaryKey: false, autoIncrement: false)}'
        '${reference == null ? '' : ' ${reference.referencesSql()}'}',
      );
    }

    final beforeIndexes = {for (final i in before.indexes) i.toSql(table)};
    final afterIndexes = {for (final i in after.indexes) i.toSql(table)};
    for (final index in before.indexes) {
      if (!afterIndexes.contains(index.toSql(table))) {
        await _db.execute('DROP INDEX ${quote(index.name)}');
      }
    }
    for (final index in after.indexes) {
      if (!beforeIndexes.contains(index.toSql(table))) {
        await _db.execute(index.toSql(table));
      }
    }
  }

  /// The single-column foreign key on [column], as added by `references`.
  ForeignKeyDefinition? _referenceOf(TableDefinition table, String column) =>
      table.foreignKeys
          .where((f) => f.columns.length == 1 && f.columns.first == column)
          .firstOrNull;

  /// SQLite's documented 12-step procedure for changing a table:
  /// https://www.sqlite.org/lang_altertable.html#otheralter
  /// Foreign key enforcement is switched off by the runner beforehand and
  /// checked after the migration.
  Future<void> _rebuild(
    TableDefinition before,
    TableDefinition after,
    Map<String, String> sources,
  ) async {
    final table = before.name;
    final temporary = '_migration_new_$table';
    final copied = after.columns
        .where((c) => sources.containsKey(c.name))
        .toList();

    // A column that becomes NOT NULL with a default gets that default where
    // it was NULL; inserting the NULL itself would fail.
    String copyFrom(ColumnDefinition c) {
      final source = quote(sources[c.name]!);
      return !c.nullable && c.defaultSql != null
          ? 'COALESCE($source, ${c.defaultSql})'
          : source;
    }

    await _db.execute(after.createTableSql(tableName: temporary));
    if (copied.isNotEmpty) {
      await _db.execute(
        'INSERT INTO ${quote(temporary)} (${quoteAll([for (final c in copied) c.name])}) '
        'SELECT ${copied.map(copyFrom).join(', ')} FROM ${quote(table)}',
      );
    }

    final lastId = before.autoIncrement
        ? await _autoIncrementCounter(table)
        : null;

    await _db.execute('DROP TABLE ${quote(table)}');
    await _db.execute(
      'ALTER TABLE ${quote(temporary)} RENAME TO ${quote(table)}',
    );
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
        await _db.update(
          'sqlite_sequence',
          {'seq': lastId},
          where: 'name = ?',
          whereArgs: [table],
        );
      }
    }
  }

  Future<int?> _autoIncrementCounter(String table) async {
    if (!await _reader.tableExists('sqlite_sequence')) return null;
    final rows = await _db.query(
      'sqlite_sequence',
      columns: ['seq'],
      where: 'name = ?',
      whereArgs: [table],
    );
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
        args.add(toSqlArgument(value));
      }
    }
    return (conditions.join(' AND '), args);
  }

  Map<String, Object?> _values(Map<String, Object?> values) => {
    for (final MapEntry(:key, :value) in values.entries)
      quote(key): toSqlArgument(value),
  };
}
