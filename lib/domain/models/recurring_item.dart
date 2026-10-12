import '../recurrence.dart';
import '../recurring_plan.dart';
import '../recurring_price.dart';
import 'money.dart';

/// Why an item is in the Archive.
enum ArchiveReason {
  /// Stop was tapped.
  stopped,

  /// Its end date passed with no payment left.
  expired,

  /// How often changed: a new item was made from it.
  replaced,
}

/// A recurring item as the lists and its page show it.
class RecurringItem {
  const RecurringItem({
    required this.id,
    required this.title,
    required this.description,
    required this.currencyCode,
    required this.categoryId,
    required this.paymentMethodId,
    required this.eventIds,
    required this.schedule,
    required this.timeOfDayMinutes,
    required this.nextDueOn,
    required this.archivedAt,
    required this.archivedOn,
    required this.createdAt,
    required this.updatedAt,
    required this.priceMinor,
    required this.paymentCount,
    required this.hold,
    this.replacesId,
    this.replaced = false,
    this.prices = const [],
  });

  /// Its prices, any order: Upcoming shows each payment at the price on its
  /// date.
  final List<PricePoint> prices;

  final int id;
  final String title;
  final String? description;

  /// Fixed: prices are minor units of it.
  final String currencyCode;
  final int categoryId;
  final int paymentMethodId;
  final Set<int> eventIds;

  /// Null when the stored rule can't be read (an unknown frequency, a
  /// damaged date): the item is **broken**, adds nothing, and its page
  /// says so. Never thrown, so one bad row can't hide the others.
  final Schedule? schedule;

  /// The time put on added payments, minutes past local midnight.
  final int timeOfDayMinutes;

  /// The next payment not yet handled (`next_due_on`); null when none is
  /// left before the end.
  final String? nextDueOn;

  /// Set when archived (stopped or expired).
  final DateTime? archivedAt;

  /// The device-local date it was archived on, for "Stopped 9 Oct".
  final String? archivedOn;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// The price in force today (the first price for an item that hasn't
  /// started); null when it has none (broken).
  final int? priceMinor;

  /// Active payments: binned ones aren't counted.
  final int paymentCount;

  /// The backlog waiting for Add all / Skip them; null when none.
  final HoldPayments? hold;

  /// The item this one was made from when its schedule changed (`replaces_id`);
  /// null otherwise.
  final int? replacesId;

  /// Archived by a change of how often: an item made from it was created
  /// in the same write (its `created_at` is this one's `archived_at`), so
  /// a later Stop of a restored item isn't called "replaced".
  final bool replaced;

  bool get isArchived => archivedAt != null;

  bool get isBroken => schedule == null || priceMinor == null;

  /// The current price as money; null when broken.
  Money? get price => switch (priceMinor) {
    final int minor => Money(minor, currencyCode),
    null => null,
  };

  /// Stopped or expired; null while running. Expired = archived with no payment
  /// left and an end before the day it was archived: the expiry does exactly
  /// that, while Stop can also archive an item with no payment left whose end
  /// is still ahead (the doc's "cursor NULL" alone would call that one
  /// expired).
  ArchiveReason? get archiveReason {
    final on = archivedOn;
    if (on == null) return null;
    if (replaced) return ArchiveReason.replaced;
    final endOn = schedule?.endOn;
    return nextDueOn == null && endOn != null && endOn.compareTo(on) < 0
        ? ArchiveReason.expired
        : ArchiveReason.stopped;
  }

  @override
  String toString() =>
      'RecurringItem($id, $title, $schedule, next $nextDueOn'
      '${isArchived ? ', archived' : ''}${isBroken ? ', broken' : ''})';
}

/// What the Edit screen saves. The currency is never edited; changing how often
/// makes a new item instead (`RecurringRepository.replaceSchedule`).
class RecurringEdit {
  const RecurringEdit({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.paymentMethodId,
    required this.eventIds,
    required this.timeOfDayMinutes,
    required this.endOn,
  });

  /// Trimmed by the form.
  final String title;

  /// Trimmed by the form; null when empty.
  final String? description;
  final int categoryId;
  final int paymentMethodId;
  final Set<int> eventIds;
  final int timeOfDayMinutes;

  /// Null = never ends.
  final String? endOn;
}

/// What Undo after Stop needs: the item and when Stop wrote it, so Undo
/// does nothing if the item changed since.
typedef ArchiveUndo = ({int id, int updatedAtMs});

/// An item a run held back.
typedef HeldItem = ({int id, String title, int count, String from, String to});

/// What a generator run did.
class GenerateReport {
  const GenerateReport({
    this.added = 0,
    this.held = const [],
    this.failed = const {},
    this.expired = 0,
  });

  static const none = GenerateReport();

  /// Payments added, over all items.
  final int added;

  /// Items whose backlog is waiting for the user.
  final List<HeldItem> held;

  /// Items that couldn't be run (logged; tried again next run).
  final Set<int> failed;

  /// Items archived because their end passed.
  final int expired;

  @override
  String toString() =>
      'GenerateReport(added $added, held ${held.length}, '
      'failed ${failed.length}, expired $expired)';
}
