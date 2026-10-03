import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/home_screen.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Expense on(String day, int id) => Expense(
    id: id,
    title: 'E$id',
    description: null,
    amount: const Money(100, 'INR'),
    amountExpression: null,
    occurredAt: DateTime.utc(2026),
    utcOffsetMinutes: 0,
    occurredOn: day,
    categoryId: 1,
    paymentMethodId: 1,
    eventIds: const {},
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    deletedAt: null,
  );

  test('homeListItems puts a header before each day', () {
    final items = homeListItems([
      on('2026-10-02', 3),
      on('2026-10-02', 2),
      on('2026-09-30', 1),
    ]);
    expect(
      [
        for (final item in items)
          switch (item) {
            HomeDayHeader(:final occurredOn) => occurredOn,
            HomeExpenseRow(:final expense) => expense.title,
          },
      ],
      ['2026-10-02', 'E3', 'E2', '2026-09-30', 'E1'],
    );
  });

  group('dayHeaderText', () {
    final today = DateTime(2026, 10, 2, 0, 30);
    final en = l10nFor('en');

    test('today and yesterday by name', () {
      expect(dayHeaderText(en, 'en', '2026-10-02', today), 'Today');
      expect(dayHeaderText(en, 'en', '2026-10-01', today), 'Yesterday');
      expect(
        dayHeaderText(en, 'en', '2026-02-28', DateTime(2026, 3, 1)),
        'Yesterday',
        reason: 'across a month end',
      );
    });

    test('other days with the weekday, and the year when not this one', () {
      expect(dayHeaderText(en, 'en', '2026-09-28', today), 'Mon, 28 Sep');
      expect(dayHeaderText(en, 'en', '2025-12-31', today), 'Wed, 31 Dec 2025');
      expect(
        dayHeaderText(en, 'en', '2026-10-05', today),
        'Mon, 5 Oct',
        reason: 'a future date is just a date',
      );
    });

    test('in the app language', () {
      expect(dayHeaderText(l10nFor('es'), 'es', '2026-10-02', today), 'Hoy');
      expect(dayHeaderText(l10nFor('hi'), 'hi', '2026-10-01', today), 'कल');
    });
  });
}
