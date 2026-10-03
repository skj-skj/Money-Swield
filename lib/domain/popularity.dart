/// How much a category or event has been used, for the picker order
/// (application-design.md A3, phase-2.md §6.2). Computed from expenses,
/// never stored.
typedef ItemUsage = ({int recentCount, DateTime? lastUsedAt});

/// An item no active expense uses yet.
const ItemUsage noUsage = (recentCount: 0, lastUsedAt: null);

/// Orders by popularity: more uses in the last 90 days first, then the most
/// recently used, then [compareNames] on the display names, then id. Never
/// returns 0 for two different items, so the order is stable.
int comparePopularity(
  ({ItemUsage usage, String name, int id}) a,
  ({ItemUsage usage, String name, int id}) b, {
  required int Function(String a, String b) compareNames,
}) {
  final byCount = b.usage.recentCount.compareTo(a.usage.recentCount);
  if (byCount != 0) return byCount;
  final aLast = a.usage.lastUsedAt;
  final bLast = b.usage.lastUsedAt;
  if (aLast != bLast) {
    if (aLast == null) return 1;
    if (bLast == null) return -1;
    return bLast.compareTo(aLast);
  }
  final byName = compareNames(a.name, b.name);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}
