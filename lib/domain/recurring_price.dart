/// A recurring item's prices over time (phase-7a.md §5.4). Pure Dart.
///
/// A price change adds a price from a date; history is never edited
/// (database.md §3.8, A7). Payments already added keep their amount.
library;

/// A price in minor units of the item's currency, from a date on.
typedef PricePoint = ({String from, int amountMinor});

/// The price in force on [day]: the point with the latest `from` on or
/// before it. Null before the first (a stored item's first point is its
/// start). Agrees with the repository's SQL lookup (F4).
int? priceOn(List<PricePoint> points, String day) {
  PricePoint? best;
  for (final p in points) {
    if (p.from.compareTo(day) <= 0 &&
        (best == null || p.from.compareTo(best.from) > 0)) {
      best = p;
    }
  }
  return best?.amountMinor;
}

/// What a price change from a date does.
enum PriceChange {
  /// A new price; payments already added keep theirs.
  add,

  /// Replaces the scheduled price on that date.
  replace,

  /// Refused: the date is before the item's start.
  beforeStart,

  /// Refused: a price from that date is already in force (today or
  /// earlier), the first price too.
  inForce,
}

/// What changing the price from [from] does (§5.4's table), for an item
/// that starts on [startOn] with [points], when it is [today].
PriceChange priceChangeFor(
  List<PricePoint> points, {
  required String startOn,
  required String from,
  required String today,
}) {
  if (from.compareTo(startOn) < 0) return PriceChange.beforeStart;
  final taken = points.any((p) => p.from == from);
  if (!taken) return PriceChange.add;
  return from.compareTo(today) > 0 ? PriceChange.replace : PriceChange.inForce;
}

/// Whether the price from [from] may be removed: only a scheduled one
/// (after [today]) that isn't the first (§5.4).
bool canRemovePrice(
  List<PricePoint> points, {
  required String from,
  required String today,
}) {
  if (from.compareTo(today) <= 0) return false;
  if (!points.any((p) => p.from == from)) return false;
  final first = points
      .map((p) => p.from)
      .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  return from != first;
}
