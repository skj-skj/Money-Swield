/// Home's filters and text matching (phase-5.md §5.6).
///
/// They combine as: **any** chosen category, **and** at least **one**
/// chosen event, **and** every word of the text (P5-32). The category and
/// event parts are SQL (`ExpenseRepository`); the text part is matched
/// here, in Dart, because SQL's `LIKE` folds ASCII only in tests and
/// Unicode on phones (sqlite.md §5.4).
library;

import 'package:characters/characters.dart';

/// The longest search text used, in characters (grapheme clusters, as
/// `TextField.maxLength` counts them, P5-19).
const maxSearchLength = 100;

class ExpenseFilter {
  const ExpenseFilter({
    this.text = '',
    this.categoryIds = const {},
    this.eventIds = const {},
  });

  static const none = ExpenseFilter();

  /// As typed; '' (or only whitespace) is no text filter.
  final String text;

  /// Empty = every category.
  final Set<int> categoryIds;

  /// Empty = with or without events.
  final Set<int> eventIds;

  bool get hasText => searchWords(text).isNotEmpty;

  bool get isEmpty => !hasText && categoryIds.isEmpty && eventIds.isEmpty;

  /// The category and event part only, the one SQL applies.
  ExpenseFilter get withoutText =>
      ExpenseFilter(categoryIds: categoryIds, eventIds: eventIds);

  ExpenseFilter copyWith({
    String? text,
    Set<int>? categoryIds,
    Set<int>? eventIds,
  }) => ExpenseFilter(
    text: text ?? this.text,
    categoryIds: categoryIds ?? this.categoryIds,
    eventIds: eventIds ?? this.eventIds,
  );

  @override
  bool operator ==(Object other) =>
      other is ExpenseFilter &&
      other.text == text &&
      _sameSet(other.categoryIds, categoryIds) &&
      _sameSet(other.eventIds, eventIds);

  @override
  int get hashCode => Object.hash(
    text,
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(eventIds),
  );

  @override
  String toString() =>
      'ExpenseFilter("$text", categories: $categoryIds, events: $eventIds)';

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// One active expense as the text filter sees it: what a subtotal and the
/// card need, plus its title and description, folded (`foldForSearch`).
typedef SearchEntry = ({
  int id,
  String day,
  int occurredAtMs,
  int amountMinor,
  String currencyCode,
  String folded,
});

/// The text a search looks in: title and description, lower-cased
/// (Unicode-aware: `CAFÉ` → `café`). The `\n` keeps a word from matching
/// across the two.
String foldForSearch(String title, String? description) =>
    '$title\n${description ?? ''}'.toLowerCase();

/// The words of [text], lower-cased, split on any whitespace (the no-break
/// space too), from its first [maxSearchLength] characters, so an emoji is
/// never cut in half. Empty for no text filter.
List<String> searchWords(String text) => text.characters
    .take(maxSearchLength)
    .toString()
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .toList();

/// Whether every one of [words] is in [entry]'s title or description, as
/// part of a word. No wildcards: `%`, `_`, `*` are plain characters. No
/// accent folding (P5-25) and no Unicode normalization.
bool matchesText(SearchEntry entry, List<String> words) =>
    words.every(entry.folded.contains);
