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
    this.photoCount = 0,
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

  /// How many photos it has (phase-6.md §6.4): rows show an icon for them.
  /// The photos themselves are read with `ExpenseRepository.photosOf`.
  final int photoCount;

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
      other.deletedAt == deletedAt &&
      other.photoCount == photoCount;

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
    photoCount,
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
    this.photos = const [],
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

  /// The photos, in order (phase-6.md §6.4). Saving replaces the
  /// expense's links with exactly these.
  final List<PhotoLinkInput> photos;
}

/// One photo an [ExpenseInput] links (phase-6.md §6.4).
sealed class PhotoLinkInput {
  const PhotoLinkInput();
}

/// A photo already in the `photos` table.
final class LinkSavedPhoto extends PhotoLinkInput {
  const LinkSavedPhoto(this.photoId);

  final int photoId;
}

/// A photo just promoted to `photos/`: its row is made if it isn't there.
final class LinkNewPhoto extends PhotoLinkInput {
  const LinkNewPhoto({
    required this.relativePath,
    required this.sha256,
    required this.byteSize,
  });

  final String relativePath;
  final String sha256;
  final int byteSize;
}
