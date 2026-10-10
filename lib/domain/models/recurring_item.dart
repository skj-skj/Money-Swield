import '../recurrence.dart';
import '../recurring_plan.dart';
import 'money.dart';

/// Why an item is in the Archive (P7a-12).
enum ArchiveReason {
  /// Stop was tapped.
  stopped,

  /// Its end date passed with no payment left.
  expired,
}

/// A recurring item as the lists and its page show it (phase-7a.md §6.1).
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
  });

  final int id;
  final String title;
  final String? description;

  /// Fixed (P7a-10): prices are minor units of it.
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

  /// The backlog waiting for Add all / Skip them (§5.3); null when none.
  final HoldPayments? hold;

  bool get isArchived => archivedAt != null;

  bool get isBroken => schedule == null || priceMinor == null;

  /// The current price as money; null when broken.
  Money? get price => switch (priceMinor) {
    final int minor => Money(minor, currencyCode),
    null => null,
  };

  /// Stopped or expired; null while running. Expired = archived with no
  /// payment left and an end before the day it was archived: the expiry
  /// does exactly that, while Stop can also archive an item with no
  /// payment left whose end is still ahead (§12a; the doc's "cursor NULL"
  /// alone would call that one expired).
  ArchiveReason? get archiveReason {
    final on = archivedOn;
    if (on == null) return null;
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

/// What the Edit screen saves (phase-7a.md §7.4). The schedule and the
/// currency are never edited (P7a-10; changing how often is 7b's).
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

/// An item a run held back (§5.3).
typedef HeldItem = ({int id, String title, int count, String from, String to});

/// What a generator run did (§6.3).
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
