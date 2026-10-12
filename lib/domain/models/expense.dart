import 'money.dart';

/// The longest title, in characters (grapheme clusters). In the domain, not the
/// form, because the SMS title rule cuts a payee to it too.
const maxTitleLength = 100;

/// The longest description, in characters.
const maxExpenseDescriptionLength = 1000;

/// Where `ExpenseRepository.page` continues from: the last loaded row's
/// `occurred_on`, `occurred_at` and id (keyset pagination).
typedef ExpenseCursor = ({String occurredOn, int occurredAtMs, int id});

/// A recorded expense.
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
    this.recurringExpenseId,
    this.recurringDueOn,
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

  /// How many photos it has: rows show an icon for them. The photos themselves
  /// are read with `ExpenseRepository.photosOf`.
  final int photoCount;

  /// The recurring item it is a payment of: added by the generator, or the
  /// first payment a Save with Repeats made. Null for a plain expense, and once
  /// the item was deleted for good (the foreign key sets it to NULL).
  final int? recurringExpenseId;

  /// Which payment of the item it is, `YYYY-MM-DD`. Kept when an Edit
  /// re-dates the expense, so it is still that payment.
  final String? recurringDueOn;

  /// Whether a recurring item owns it: rows show the repeat mark.
  bool get isRecurring => recurringExpenseId != null;

  bool get isInBin => deletedAt != null;

  /// The time as it was on the clock where it was recorded, as a UTC `DateTime`
  /// whose fields are that wall-clock time. Shown instead of the device's
  /// current zone, so a trip abroad keeps its local times.
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
      other.photoCount == photoCount &&
      other.recurringExpenseId == recurringExpenseId &&
      other.recurringDueOn == recurringDueOn;

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
    recurringExpenseId,
    recurringDueOn,
  );

  @override
  String toString() =>
      'Expense($id, $title, $amount, $occurredOn'
      '${isRecurring ? ', payment $recurringDueOn of $recurringExpenseId' : ''}'
      '${isInBin ? ', in bin' : ''})';
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

  /// The photos, in order. Saving replaces the expense's links with exactly
  /// these.
  final List<PhotoLinkInput> photos;
}

/// A payment the recurring generator, or a Save with Repeats, adds: an ordinary
/// expense row that also says which item and which due date it is. Its events
/// are the item's, copied in the same transaction; it has no amount expression
/// and no photos.
class PaymentInput {
  const PaymentInput({
    required this.recurringExpenseId,
    required this.dueOn,
    required this.title,
    required this.description,
    required this.amount,
    required this.occurredAt,
    required this.utcOffsetMinutes,
    required this.categoryId,
    required this.paymentMethodId,
  });

  final int recurringExpenseId;

  /// Which payment it is, `YYYY-MM-DD`.
  final String dueOn;

  final String title;
  final String? description;
  final Money amount;

  /// UTC.
  final DateTime occurredAt;
  final int utcOffsetMinutes;
  final int categoryId;
  final int paymentMethodId;
}

/// One photo an [ExpenseInput] links.
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
