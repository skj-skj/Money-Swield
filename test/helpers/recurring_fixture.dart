import 'package:money_swield/data/repositories/data_version.dart';
import 'package:money_swield/data/repositories/expense_repository.dart';
import 'package:money_swield/data/repositories/recurring_repository.dart';
import 'package:money_swield/domain/models/expense.dart';
import 'package:money_swield/domain/models/money.dart';
import 'package:money_swield/domain/recurring_moment.dart';
import 'package:money_swield/domain/repeat_input.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

/// A migrated database with the expense and recurring repositories on a
/// hand-moved clock ("the clock is TestClock"). The clock starts at noon,
/// device time, on 2026-10-09, so "today" is that date in whatever zone the
/// tests run.
class RecurringFixture {
  RecurringFixture._(this.db, this.clock, this.dataVersion, this.localMoment)
    : expenses = ExpenseRepository(
        db,
        dataVersion: dataVersion,
        now: clock.call,
        localMoment: localMoment,
      ),
      recurring = RecurringRepository(
        db,
        dataVersion: dataVersion,
        now: clock.call,
        localMoment: localMoment,
      );

  static Future<RecurringFixture> open({
    ZonedMoment Function(int, int, int, int, int)? localMoment,
  }) async => RecurringFixture._(
    await openMigratedDatabase(),
    TestClock(DateTime(2026, 10, 9, 12)),
    DataVersion(),
    localMoment ?? deviceMoment,
  );

  final Database db;
  final TestClock clock;
  final DataVersion dataVersion;
  final ZonedMoment Function(int, int, int, int, int) localMoment;
  final ExpenseRepository expenses;
  final RecurringRepository recurring;

  /// Moves the clock to noon, device time, on [day] (`YYYY-MM-DD`).
  void setToday(String day) => clock.now = DateTime(
    int.parse(day.substring(0, 4)),
    int.parse(day.substring(5, 7)),
    int.parse(day.substring(8, 10)),
    12,
  );

  /// An expense input on [day] at 10:00 device time.
  ExpenseInput input({
    String title = 'Netflix',
    String day = '2026-10-09',
    Money amount = const Money(64900, 'INR'),
    String? expression,
    Set<int> eventIds = const {2},
    int categoryId = 17,
    int paymentMethodId = 4,
    String? description = 'Family plan',
  }) {
    final local = DateTime(
      int.parse(day.substring(0, 4)),
      int.parse(day.substring(5, 7)),
      int.parse(day.substring(8, 10)),
      10,
    );
    return ExpenseInput(
      title: title,
      description: description,
      amount: amount,
      amountExpression: expression,
      occurredAt: local.toUtc(),
      utcOffsetMinutes: local.timeZoneOffset.inMinutes,
      categoryId: categoryId,
      paymentMethodId: paymentMethodId,
      eventIds: eventIds,
    );
  }

  /// Save with Repeats of [input] (default: Netflix today, monthly).
  Future<({Expense expense, int pastAdded})> addRepeating({
    ExpenseInput? input,
    RepeatChoice choice = const RepeatChoice(),
  }) => expenses.addRepeating(input ?? this.input(), choice);

  /// Every expense row, raw, in id order.
  Future<List<Map<String, Object?>>> expenseRows() =>
      db.query('expenses', orderBy: 'id');

  /// Every payment row of [itemId], in due order: its due date, whether it
  /// is binned, and its amount.
  Future<List<(String?, bool, int)>> paymentsOf(int itemId) async => [
    for (final row in await db.query(
      'expenses',
      where: 'recurring_expense_id = ?',
      whereArgs: [itemId],
      orderBy: 'recurring_due_on',
    ))
      (
        row['recurring_due_on'] as String?,
        row['deleted_at'] != null,
        row['amount_minor']! as int,
      ),
  ];

  Future<Map<String, Object?>> itemRow(int id) async => (await db.query(
    'recurring_expenses',
    where: 'id = ?',
    whereArgs: [id],
  )).single;

  Future<String?> cursorOf(int id) async =>
      (await itemRow(id))['next_due_on'] as String?;
}
