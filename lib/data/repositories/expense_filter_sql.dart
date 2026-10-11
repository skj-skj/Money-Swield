/// The SQL part of a filter (phase-5.md §6.1, phase-7b.md §6.4), shared by
/// Home's reads (`ExpenseRepository`) and the report's
/// (`ReportRepository`, phase-8.md R10). The text part is matched in Dart
/// (`matchesText`).
library;

import '../../domain/expense_filter.dart';

/// [filter]'s category, event and recurring part as SQL terms on
/// `expenses`. The ids are written into the SQL as literals, so a long
/// selection never meets the 999-variable limit; they're `int`s from the
/// app's own models, never text, so nothing can be injected.
List<String> expenseFilterSql(ExpenseFilter filter) => [
  if (filter.categoryIds.isNotEmpty)
    'category_id IN (${sqlIdList(filter.categoryIds)})',
  if (filter.eventIds.isNotEmpty) withAnyEventSql(filter.eventIds),
  // On 3.22 this keeps Home's plan on its date index (phase-7b.md F3; the
  // unique index isn't picked for IS NOT NULL): a plan test pins it.
  if (filter.onlyRecurring) recurringOnlySql,
];

/// A payment of a recurring item (phase-7b.md §6.4).
const recurringOnlySql = 'recurring_expense_id IS NOT NULL';

/// Any one of [eventIds]: an expense with two of them is still one row.
String withAnyEventSql(Set<int> eventIds) =>
    'id IN (SELECT expense_id FROM expense_events '
    'WHERE event_id IN (${sqlIdList(eventIds)}))';

/// [ids] sorted and comma-separated, for `IN (…)` as literals.
String sqlIdList(Iterable<int> ids) => (ids.toList()..sort()).join(', ');
