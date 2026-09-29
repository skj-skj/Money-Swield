/// Small helpers for turning names and values into safe SQL text.
///
/// These are internal to the migration framework. Migrations never write
/// SQL themselves.
library;

final _identifierPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Throws if [name] is not a plain table / column / index name.
///
/// Only letters, digits and underscores are allowed so that names never
/// need escaping and never clash with SQLite's internal `sqlite_` tables.
String checkIdentifier(String name) {
  if (!_identifierPattern.hasMatch(name)) {
    throw ArgumentError.value(
      name,
      'name',
      'Use only letters, digits and underscores, starting with a letter',
    );
  }
  if (name.toLowerCase().startsWith('sqlite_')) {
    throw ArgumentError.value(name, 'name', 'Names starting with "sqlite_" are reserved by SQLite');
  }
  return name;
}

/// Wraps a name in double quotes, e.g. `amount` -> `"amount"`.
String quote(String name) => '"${name.replaceAll('"', '""')}"';

/// Quotes each name and joins them with commas.
String quoteAll(List<String> names) => names.map(quote).join(', ');

/// Converts a Dart value into a SQL literal usable after `DEFAULT`.
///
/// Supports `int`, `double`, `bool` (stored as 1 / 0) and `String`.
String toSqlLiteral(Object value) {
  return switch (value) {
    bool() => value ? '1' : '0',
    int() => value.toString(),
    double() when value.isFinite => value.toString(),
    String() => "'${value.replaceAll("'", "''")}'",
    _ => throw ArgumentError.value(
      value,
      'defaultValue',
      'Only int, finite double, bool and String default values are supported',
    ),
  };
}
