/// The category suggested for an SMS (phase-9a.md §5.4, P9a-11). Pure
/// Dart: the repository reads the rows, this picks.
library;

import '../title_suggestions.dart';

/// What the payee's newest SMS-added, still active expense was saved as.
typedef SmsLearned = ({String title, int categoryId});

/// The suggested category, the first that gives one:
///
/// 1. [learned]: the category of the payee's newest SMS-added expense;
/// 2. by title: the newest active, not future-dated expense of the last
///    180 days whose folded title equals the folded [title] ([history] is
///    `ExpenseRepository.titleHistoryOn`: active rows up to today, `recent`
///    counting the 180 days, so a row with `recent == 0` is older);
/// 3. [ai]: the on-device model's pick among the user's categories, for a
///    payee with no history (phase-9b.md §5.3; owner: "if not then AI
///    should judge");
/// 4. null.
int? suggestedCategory({
  SmsLearned? learned,
  String? title,
  List<TitleHistoryRow> history = const [],
  int? ai,
}) {
  if (learned != null) return learned.categoryId;
  return _byTitle(title, history) ?? ai;
}

int? _byTitle(String? title, List<TitleHistoryRow> history) {
  if (title == null) return null;
  final folded = foldTitle(title.trim());
  if (folded.isEmpty) return null;
  TitleHistoryRow? newest;
  for (final row in history) {
    if (row.recent == 0 || foldTitle(row.title) != folded) continue;
    if (newest == null || row.lastAt.isAfter(newest.lastAt)) newest = row;
  }
  return newest?.categoryId;
}
