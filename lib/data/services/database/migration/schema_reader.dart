import 'package:sqflite/sqflite.dart';

import 'sql.dart';
import 'sqlite_type.dart';
import 'table_definition.dart';

/// Reads the current shape of tables from SQLite using `PRAGMA` queries.
///
/// The rebuild of a table (see `Migrator.changeTable`) relies on this to
/// know what the table looks like right now.
class SchemaReader {
  SchemaReader(this._db);

  final DatabaseExecutor _db;

  Future<bool> tableExists(String table) async {
    final rows = await _db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    return rows.isNotEmpty;
  }

  /// Describes what already uses [name], e.g. `index "by_x" on "a"`, or null
  /// if it is free. SQLite gives tables, indexes and views one namespace and
  /// ignores case. [exceptTable] and its own indexes are not counted.
  Future<String?> nameInUse(String name, {String exceptTable = ''}) async {
    final rows = await _db.rawQuery(
      'SELECT type, name, tbl_name FROM sqlite_master WHERE name = ? COLLATE NOCASE AND tbl_name != ? COLLATE NOCASE',
      [name, exceptTable],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final owner = row['type'] == 'index' ? ' on "${row['tbl_name']}"' : '';
    return '${row['type']} "${row['name']}"$owner';
  }

  /// Throws if rebuilding [table] (see `Migrator.changeTable`) would lose or
  /// break something the framework cannot recreate.
  ///
  /// The rebuild writes a fresh `CREATE TABLE` from what [readTable] sees,
  /// and SQLite's `PRAGMA`s do not report CHECK constraints, collations or
  /// generated columns, so those would be silently dropped. Triggers would be
  /// dropped with the old table, and views that use the table make SQLite
  /// refuse the rename at the end of the rebuild. Tables created by the
  /// framework never have any of these.
  Future<void> checkCanRebuild(String table) async {
    final master = await _db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    // Strip string literals and quoted names so that, say, DEFAULT 'check'
    // is not mistaken for a CHECK constraint.
    final createSql = (master.first['sql']! as String).replaceAll(
      _quotedText,
      '',
    );
    final feature = _featureWord.firstMatch(createSql)?.group(1)?.toUpperCase();
    if (feature != null) {
      final what = feature == 'CHECK' || feature == 'COLLATE'
          ? feature
          : 'a generated column';
      throw UnsupportedError(
        'Table "$table" uses $what, which the migration framework cannot rebuild',
      );
    }

    final dependents = await _db.rawQuery(
      "SELECT type, name FROM sqlite_master WHERE (type = 'trigger' AND tbl_name = ?) OR (type = 'view' AND sql LIKE ?)",
      [table, '%$table%'],
    );
    if (dependents.isNotEmpty) {
      final names = dependents
          .map((d) => '${d['type']} "${d['name']}"')
          .join(', ');
      throw UnsupportedError(
        'Table "$table" is used by $names, which the migration framework cannot rebuild',
      );
    }
  }

  static final _quotedText = RegExp(
    r"""'(?:[^']|'')*'|"(?:[^"]|"")*"|`[^`]*`|\[[^\]]*\]""",
  );
  static final _featureWord = RegExp(
    r'\b(CHECK|COLLATE|GENERATED|AS)\b',
    caseSensitive: false,
  );

  /// All tables except SQLite's own internal ones.
  Future<List<String>> tableNames() async {
    final rows = await _db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' ORDER BY name",
    );
    return [for (final row in rows) row['name']! as String];
  }

  Future<TableDefinition> readTable(String table) async {
    final master = await _db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (master.isEmpty) throw ArgumentError('Table "$table" does not exist');
    final createSql = master.first['sql']! as String;

    final definition = TableDefinition(
      name: table,
      autoIncrement: RegExp(
        r'\bAUTOINCREMENT\b',
        caseSensitive: false,
      ).hasMatch(createSql),
    );

    // Columns and primary key.
    final primaryKeyByPosition = <int, String>{};
    for (final row in await _db.rawQuery(
      'PRAGMA table_info(${quote(table)})',
    )) {
      final name = row['name']! as String;
      definition.columns.add(
        ColumnDefinition(
          name: name,
          type: SqliteType.fromSql(row['type']! as String),
          nullable: row['notnull'] == 0,
          defaultSql: row['dflt_value'] as String?,
        ),
      );
      final pkPosition = row['pk']! as int;
      if (pkPosition > 0) primaryKeyByPosition[pkPosition] = name;
    }
    definition.primaryKey = [
      for (final position in primaryKeyByPosition.keys.toList()..sort())
        primaryKeyByPosition[position]!,
    ];

    // Unique constraints and indexes. index_list lists newest first.
    final indexRows = await _db.rawQuery('PRAGMA index_list(${quote(table)})');
    for (final row in indexRows.reversed) {
      final name = row['name']! as String;
      final origin = row['origin']! as String;
      if (origin == 'pk') continue; // Already covered by the primary key.
      if (row['partial'] == 1) {
        throw UnsupportedError(
          'Partial index "$name" on "$table" is not supported',
        );
      }
      final columns = await _indexColumns(name);
      if (origin == 'u') {
        definition.uniqueConstraints.add(columns);
      } else {
        definition.indexes.add(
          IndexDefinition(
            name: name,
            columns: columns,
            unique: row['unique'] == 1,
          ),
        );
      }
    }

    definition.foreignKeys.addAll(await _foreignKeys(table));
    return definition;
  }

  /// Foreign keys in other tables that point at [parentTable].
  Future<List<({String table, ForeignKeyDefinition foreignKey})>>
  foreignKeysReferencing(String parentTable) async {
    return [
      for (final table in await tableNames())
        if (table != parentTable)
          for (final foreignKey in await _foreignKeys(table))
            if (foreignKey.parentTable == parentTable)
              (table: table, foreignKey: foreignKey),
    ];
  }

  Future<List<String>> _indexColumns(String index) async {
    final rows = await _db.rawQuery('PRAGMA index_info(${quote(index)})');
    final sorted = [...rows]
      ..sort((a, b) => (a['seqno']! as int).compareTo(b['seqno']! as int));
    return [
      for (final row in sorted)
        row['name'] as String? ??
            (throw UnsupportedError(
              'Expression index "$index" is not supported',
            )),
    ];
  }

  Future<List<ForeignKeyDefinition>> _foreignKeys(String table) async {
    final rows = await _db.rawQuery('PRAGMA foreign_key_list(${quote(table)})');
    final byId = <int, ForeignKeyDefinition>{};
    final sorted = [...rows]
      ..sort((a, b) => (a['seq']! as int).compareTo(b['seq']! as int));
    for (final row in sorted) {
      final to = row['to'] as String?;
      if (to == null) {
        throw UnsupportedError(
          'Foreign key on "$table" must name the referenced column explicitly',
        );
      }
      final foreignKey = byId.putIfAbsent(
        row['id']! as int,
        () => ForeignKeyDefinition(
          columns: [],
          parentTable: row['table']! as String,
          parentColumns: [],
          onDelete: ForeignKeyAction.fromSql(row['on_delete']! as String),
          onUpdate: ForeignKeyAction.fromSql(row['on_update']! as String),
        ),
      );
      foreignKey.columns.add(row['from']! as String);
      foreignKey.parentColumns.add(to);
    }
    // SQLite numbers foreign keys last-declared first; return them in the
    // order they were declared so a rebuild keeps the same schema.
    return [
      for (final id in byId.keys.toList()..sort((a, b) => b.compareTo(a)))
        byId[id]!,
    ];
  }
}
