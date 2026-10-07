import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/calendar_days.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../core/emit_if_open.dart';

/// Categories, events and payment methods by id, to show a binned
/// expense's emoji and names.
class BinLookups {
  const BinLookups({
    required this.categories,
    required this.events,
    required this.paymentMethods,
  });

  final Map<int, Category> categories;
  final Map<int, Event> events;
  final Map<int, PaymentMethod> paymentMethods;
}

/// What the bin screen shows. States don't override `==`, so every emitted
/// state reaches the screen.
sealed class BinState {
  const BinState();
}

final class BinLoading extends BinState {
  const BinLoading();
}

final class BinLoaded extends BinState {
  const BinLoaded(this.expenses, this.lookups);

  /// Most recently deleted first.
  final List<Expense> expenses;
  final BinLookups lookups;
}

final class BinFailed extends BinState {
  const BinFailed(this.error);

  final Object error;
}

/// How long ago an expense was binned and how long until the purge
/// removes it (phase-2.md §9.2).
typedef BinAge = ({int daysAgo, int? daysLeft});

/// `daysAgo` counts **calendar days** between the device-local dates of
/// [deletedAt] and [now], so something deleted at 23:00 no longer reads
/// "today" at 01:00.
///
/// `daysLeft` counts **24-hour periods** until `deletedAt + 30 days`,
/// rounded up, so it agrees with the purge, which compares milliseconds;
/// null once that moment has passed (removed on the next start, as the
/// purge only runs at startup). So the two can add up to 30 or 31.
BinAge binAge(DateTime deletedAt, DateTime now) {
  final remaining = deletedAt
      .add(ExpenseRepository.binRetention)
      .difference(now)
      .inMilliseconds;
  const day = Duration.millisecondsPerDay;
  return (
    daysAgo: calendarDaysAgo(deletedAt, now),
    daysLeft: remaining <= 0 ? null : (remaining + day - 1) ~/ day,
  );
}

/// The bin: binned expenses with restore and permanent delete
/// (phase-2.md §9.2). Every action reloads the list. Actions rethrow a
/// failed write; the screen tells the user.
class BinCubit extends CubitSignal<BinState> with EmitIfOpen<BinState> {
  BinCubit({
    required this._expenses,
    required this._categories,
    required this._events,
    required this._paymentMethods,
  }) : super(initialState: const BinLoading());

  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final EventRepository _events;
  final PaymentMethodRepository _paymentMethods;

  Future<void> load() async {
    try {
      final expenses = await _expenses.binned();
      final lookups = BinLookups(
        categories: {for (final c in await _categories.all()) c.id: c},
        events: {for (final e in await _events.all()) e.id: e},
        paymentMethods: {for (final m in await _paymentMethods.all()) m.id: m},
      );
      emitIfOpen(BinLoaded(expenses, lookups));
    } catch (error) {
      // A failed reload after an action keeps the old list on screen.
      if (value is! BinLoaded) emitIfOpen(BinFailed(error));
    }
  }

  Future<void> restore(int id) => _then(_expenses.restore(id));

  Future<void> restoreAll() => _then(_expenses.restoreAll());

  Future<void> deletePermanently(int id) =>
      _then(_expenses.deletePermanently(id));

  Future<void> emptyBin() => _then(_expenses.emptyBin());

  Future<void> _then(Future<void> action) async {
    await action;
    await load();
  }
}
