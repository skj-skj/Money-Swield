/// Title suggestions (phase-4.md §6.1, P4-2): the title history is read
/// once per form open and matched here, case-folded in Dart. SQL's
/// `lower()` / `LIKE` fold ASCII only in tests and Unicode on phones
/// (sqlite.md §5.4), so they're never used on user text.
library;

/// One exact spelling of a title, as the history query returns it: the
/// newest active, not future-dated expense with it, and its uses in the
/// last 180 days.
class TitleHistoryRow {
  const TitleHistoryRow({
    required this.title,
    required this.amountMinor,
    required this.currencyCode,
    required this.categoryId,
    required this.lastAt,
    required this.recent,
  });

  final String title;
  final int amountMinor;
  final String currencyCode;
  final int categoryId;
  final DateTime lastAt;
  final int recent;
}

/// A title as the dropdown shows it: every spelling that folds to the same
/// key, shown in its newest one.
class TitleSuggestion {
  const TitleSuggestion({
    required this.title,
    required this.spellings,
    required this.amountMinor,
    required this.currencyCode,
    required this.categoryId,
    required this.lastAt,
    required this.recent,
  });

  /// The newest spelling.
  final String title;

  /// Every spelling, for the prefill query.
  final List<String> spellings;

  /// The newest spelling's last amount and category, for display only.
  final int amountMinor;
  final String currencyCode;
  final int categoryId;

  final DateTime lastAt;

  /// Uses in the last 180 days, all spellings together.
  final int recent;

  @override
  String toString() => 'TitleSuggestion($title, recent: $recent)';
}

/// The most suggestions shown.
const maxTitleSuggestions = 5;

/// The case-folded form two spellings are compared by. Unicode-aware
/// (`CAFÉ` → `café`); no normalization (NFC and NFD `é` stay different).
String foldTitle(String title) => title.toLowerCase();

/// [rows] grouped by [foldTitle]: counts added, shown in the newest
/// spelling.
List<TitleSuggestion> groupTitleHistory(List<TitleHistoryRow> rows) {
  final groups = <String, List<TitleHistoryRow>>{};
  for (final row in rows) {
    groups.putIfAbsent(foldTitle(row.title), () => []).add(row);
  }
  return [for (final group in groups.values) _suggestionOf(group)];
}

TitleSuggestion _suggestionOf(List<TitleHistoryRow> group) {
  var newest = group.first;
  var recent = 0;
  for (final row in group) {
    recent += row.recent;
    // Ties keep the spelling first in code-unit order, so the choice
    // doesn't depend on the order SQLite returned the groups in.
    if (row.lastAt.isAfter(newest.lastAt) ||
        row.lastAt == newest.lastAt && row.title.compareTo(newest.title) < 0) {
      newest = row;
    }
  }
  return TitleSuggestion(
    title: newest.title,
    spellings: [for (final row in group) row.title],
    amountMinor: newest.amountMinor,
    currencyCode: newest.currencyCode,
    categoryId: newest.categoryId,
    lastAt: newest.lastAt,
    recent: recent,
  );
}

/// Up to [maxTitleSuggestions] of [history] matching [typed]: titles that
/// start with it first, then ones that contain it; within each by recent
/// uses, then most recent, then folded title. An exact match is listed
/// too. Nothing for blank text.
List<TitleSuggestion> matchTitles(List<TitleSuggestion> history, String typed) {
  final query = foldTitle(typed.trim());
  if (query.isEmpty) return const [];
  final prefix = <TitleSuggestion>[];
  final contains = <TitleSuggestion>[];
  for (final suggestion in history) {
    final folded = foldTitle(suggestion.title);
    if (folded.startsWith(query)) {
      prefix.add(suggestion);
    } else if (folded.contains(query)) {
      contains.add(suggestion);
    }
  }
  prefix.sort(_byRank);
  contains.sort(_byRank);
  return [...prefix, ...contains].take(maxTitleSuggestions).toList();
}

int _byRank(TitleSuggestion a, TitleSuggestion b) {
  final byRecent = b.recent.compareTo(a.recent);
  if (byRecent != 0) return byRecent;
  final byLast = b.lastAt.compareTo(a.lastAt);
  if (byLast != 0) return byLast;
  return foldTitle(a.title).compareTo(foldTitle(b.title));
}
