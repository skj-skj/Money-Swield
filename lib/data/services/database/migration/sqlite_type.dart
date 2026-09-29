/// The column types SQLite understands (its five type affinities).
///
/// SQLite has no dedicated boolean or date types. Store booleans as
/// [integer] (0 / 1) and dates as [integer] (Unix epoch milliseconds).
enum SqliteType {
  integer('INTEGER'),
  real('REAL'),
  text('TEXT'),
  blob('BLOB'),
  numeric('NUMERIC');

  const SqliteType(this.sql);

  /// The type name as written in SQL.
  final String sql;

  /// Finds the type for a declared type name read back from SQLite.
  static SqliteType fromSql(String declaredType) {
    final upper = declaredType.trim().toUpperCase();
    for (final type in values) {
      if (type.sql == upper) return type;
    }
    throw StateError(
      'Unsupported column type "$declaredType". Only ${values.map((t) => t.sql).join(', ')} are supported.',
    );
  }
}

/// What happens to a child row when the parent row it references is
/// deleted or its key is updated.
enum ForeignKeyAction {
  noAction('NO ACTION'),
  restrict('RESTRICT'),
  setNull('SET NULL'),
  setDefault('SET DEFAULT'),
  cascade('CASCADE');

  const ForeignKeyAction(this.sql);

  /// The action as written in SQL.
  final String sql;

  static ForeignKeyAction fromSql(String action) {
    final upper = action.trim().toUpperCase();
    for (final value in values) {
      if (value.sql == upper) return value;
    }
    throw StateError('Unsupported foreign key action "$action".');
  }
}
