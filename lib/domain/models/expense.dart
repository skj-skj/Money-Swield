import 'money.dart';

/// Where `ExpenseRepository.page` continues from: the last loaded row's
/// `occurred_on`, `occurred_at` and id (keyset pagination, database.md §4;
/// phase-5.md §4.1).
typedef ExpenseCursor = ({String occurredOn, int occurredAtMs, int id});

/// A recorded expense (database.md §3.5).
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.amountExpression,
    required this.occurredAt,
    required this.utcOffsetMinutes,
    required this.occurredOn,
    required this.categoryId,
    required this.paymentMethodId,
    required this.eventIds,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final int id;

  /// Trimmed, never empty.
  final String title;

  /// Null when there is none (never empty text).
  final String? description;

  final Money amount;

  /// What was typed, e.g. `50+60`; null for a plain number.
  final String? amountExpression;

  /// The moment it happened, UTC.
  final DateTime occurredAt;

  /// The device's offset from UTC at [occurredAt] when it was recorded.
  final int utcOffsetMinutes;

  /// The local date it happened on, `YYYY-MM-DD`. Derived by the
  /// repository from [occurredAt] and [utcOffsetMinutes].
  final String occurredOn;

  final int categoryId;
  final int paymentMethodId;

  /// Every event of the expense. Always loaded in full, so an expense whose
  /// events are "not loaded" can't exist.
  final Set<int> eventIds;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// When it was moved to the bin, or null while it is active.
  final DateTime? deletedAt;

  bool get isInBin => deletedAt != null;

  /// The time as it was on the clock where it was recorded, as a UTC
  /// `DateTime` whose fields are that wall-clock time. Shown instead of the
  /// device's current zone, so a trip abroad keeps its local times
  /// (database.md §1).
  DateTime get wallClock => occurredAt.add(Duration(minutes: utcOffsetMinutes));

  /// The cursor that continues a page after this expense.
  ExpenseCursor get cursor => (
    occurredOn: occurredOn,
    occurredAtMs: occurredAt.millisecondsSinceEpoch,
    id: id,
  );

  @override
  bool operator ==(Object other) =>
      other is Expense &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.amount == amount &&
      other.amountExpression == amountExpression &&
      other.occurredAt == occurredAt &&
      other.utcOffsetMinutes == utcOffsetMinutes &&
      other.occurredOn == occurredOn &&
      other.categoryId == categoryId &&
      other.paymentMethodId == paymentMethodId &&
      other.eventIds.length == eventIds.length &&
      other.eventIds.containsAll(eventIds) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    amount,
    amountExpression,
    occurredAt,
    utcOffsetMinutes,
    occurredOn,
    categoryId,
    paymentMethodId,
    Object.hashAllUnordered(eventIds),
    createdAt,
    updatedAt,
    deletedAt,
  );

  @override
  String toString() =>
      'Expense($id, $title, $amount, $occurredOn${isInBin ? ', in bin' : ''})';
}

/// What the Add/Edit form saves. The repository derives the rest (id,
/// timestamps, `occurredOn`, `deletedAt`).
class ExpenseInput {
  const ExpenseInput({
    required this.title,
    required this.description,
    required this.amount,
    this.amountExpression,
    required this.occurredAt,
    required this.utcOffsetMinutes,
    required this.categoryId,
    required this.paymentMethodId,
    required this.eventIds,
  });

  /// Already trimmed by the form.
  final String title;

  /// Already trimmed by the form; null when empty.
  final String? description;

  final Money amount;
  final String? amountExpression;

  /// UTC.
  final DateTime occurredAt;
  final int utcOffsetMinutes;
  final int categoryId;
  final int paymentMethodId;
  final Set<int> eventIds;
}
