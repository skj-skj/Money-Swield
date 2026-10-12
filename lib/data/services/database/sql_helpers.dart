/// Small helpers every repository shares, so each storage rule lives in one
/// place.
library;

/// Android 10–11 ship SQLite versions (3.22) that allow at most 999 bound
/// variables per statement. `IN (…)` lists with bound values stay well
/// under it, leaving room for the statement's other arguments.
const maxBoundValues = 500;

/// `?, ?, ?` for an `IN (…)` list of [count] bound values. [count] must be
/// 1 to [maxBoundValues]: `IN ()` is a syntax error, and a longer list
/// would fail on Android 10 (use [inChunks]).
String sqlPlaceholders(int count) {
  if (count < 1 || count > maxBoundValues) {
    throw RangeError.range(count, 1, maxBoundValues, 'count');
  }
  return List.filled(count, '?').join(', ');
}

/// Runs [query] on [values] in slices of at most [maxBoundValues], in
/// order, and joins what they return. Nothing is queried for no values.
Future<List<R>> inChunks<T, R>(
  List<T> values,
  Future<List<R>> Function(List<T> chunk) query,
) async {
  final results = <R>[];
  for (var start = 0; start < values.length; start += maxBoundValues) {
    final end = start + maxBoundValues;
    results.addAll(
      await query(
        values.sublist(start, end < values.length ? end : values.length),
      ),
    );
  }
  return results;
}

/// A stored timestamp: epoch milliseconds, always read as UTC. Without `isUtc`
/// the same instant comes back in local time, and a later `.day` or `.hour`
/// would silently be the device's, not UTC's. (Writing needs no helper:
/// `millisecondsSinceEpoch` is the same instant whatever the time zone.)
DateTime utcFromEpochMs(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
