import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/photos.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';

import '../../helpers/recurring_fixture.dart';

/// Home's Only recurring filter (phase-7b.md §6.4, P7b-11): every reader of
/// the filter gets it, and Home's plan stays on its index (F3).
void main() {
  late RecurringFixture f;

  setUp(() async => f = await RecurringFixture.open());

  const only = ExpenseFilter(onlyRecurring: true);

  /// Plain Lunch, Netflix (payment 0 + 1 earlier), an archived Gym's
  /// payment, a deleted Old item's payment, and a binned Netflix payment.
  Future<Map<String, int>> seed() async {
    final lunch = await f.expenses.add(
      f.input(title: 'Lunch', day: '2026-10-08', categoryId: 1, eventIds: {}),
    );
    final (expense: netflix, pastAdded: _) = await f.addRepeating(
      input: f.input(day: '2026-09-09'),
    );
    final (expense: gym, pastAdded: _) = await f.addRepeating(
      input: f.input(title: 'Gym', day: '2026-10-01', categoryId: 11),
      choice: const RepeatChoice(frequency: Frequency.yearly),
    );
    await f.recurring.archive(gym.recurringExpenseId!);
    final (expense: old, pastAdded: _) = await f.addRepeating(
      input: f.input(title: 'Old', day: '2026-10-02'),
      choice: const RepeatChoice(frequency: Frequency.yearly),
    );
    await f.recurring.archive(old.recurringExpenseId!);
    await f.recurring.delete(old.recurringExpenseId!);
    final binned = (await f.recurring.payments(
      netflix.recurringExpenseId!,
      limit: 1,
    )).single;
    await f.expenses.moveToBin(binned.id);
    return {
      'lunch': lunch.id,
      'netflix': netflix.id,
      'gym': gym.id,
      'old': old.id,
      'binned': binned.id,
    };
  }

  Future<List<String>> titlesOf(ExpenseFilter filter) async => [
    for (final e in await f.expenses.page(filter: filter)) e.title,
  ];

  test('page: payment 0 and an archived item\'s payment in; plain, a '
      'deleted item\'s (link gone) and binned out', () async {
    final ids = await seed();
    final page = await f.expenses.page(filter: only);
    expect({for (final e in page) e.id}, {ids['netflix'], ids['gym']});
    expect(await titlesOf(ExpenseFilter.none), hasLength(4));
  });

  test('amountsIn (totals, trend) and searchEntries follow it', () async {
    await seed();
    final rows = await f.expenses.amountsIn(
      from: '2026-09-01',
      to: '2026-10-31',
      filter: only,
    );
    expect([for (final r in rows) r.$1]..sort(), ['2026-09-09', '2026-10-01']);
    final entries = await f.expenses.searchEntries(filter: only);
    expect(entries, hasLength(2));
  });

  test('combines by AND with categories, events and text', () async {
    final ids = await seed();
    expect(
      {
        for (final e in await f.expenses.page(
          filter: const ExpenseFilter(onlyRecurring: true, categoryIds: {11}),
        ))
          e.id,
      },
      {ids['gym']},
    );
    expect(
      await f.expenses.page(
        filter: const ExpenseFilter(onlyRecurring: true, categoryIds: {1}),
      ),
      isEmpty,
      reason: 'Lunch is plain',
    );
    expect(
      await f.expenses.page(
        filter: const ExpenseFilter(onlyRecurring: true, eventIds: {2}),
      ),
      hasLength(2),
    );
    expect(
      await f.expenses.page(
        filter: const ExpenseFilter(onlyRecurring: true, eventIds: {9}),
      ),
      isEmpty,
    );
    // The text part is matched in Dart on the SQL part's entries.
    final words = searchWords('gym');
    final matches = [
      for (final e in await f.expenses.searchEntries(
        filter: const ExpenseFilter(
          text: 'gym',
          onlyRecurring: true,
        ).withoutText,
      ))
        if (matchesText(e, words)) e.id,
    ];
    expect(matches, [ids['gym']]);
  });

  test('photos: the icon and the Photos screen follow it', () async {
    final ids = await seed();
    await f.db.insert('photos', {
      'relative_path': 'photos/${'a' * 64}.jpg',
      'sha256': 'a' * 64,
      'byte_size': 1,
      'created_at': 0,
      'updated_at': 0,
    });
    await f.db.insert('expense_photos', {
      'expense_id': ids['lunch'],
      'photo_id': 1,
      'sort_order': 0,
    });
    expect(await f.expenses.hasMatchingPhotos(ExpenseFilter.none), isTrue);
    expect(await f.expenses.hasMatchingPhotos(only), isFalse);
    expect(await f.expenses.photoExpensesPage(filter: only), isEmpty);
    expect(isValidPhotoPath('photos/${'a' * 64}.jpg'), isTrue);
  });

  test('plan (F3): Home\'s page, its next page and the totals stay on the '
      'date index, no temp B-tree', () async {
    const where =
        'WHERE +deleted_at IS NULL AND recurring_expense_id IS NOT NULL';
    const order = 'ORDER BY occurred_on DESC, occurred_at DESC, id DESC';
    const cursor = '(occurred_on, occurred_at, id) < (?, ?, ?)';
    for (final sql in [
      'SELECT * FROM expenses $where $order LIMIT 30',
      'SELECT * FROM expenses $where AND $cursor $order LIMIT 30',
      'SELECT occurred_on FROM expenses $where AND occurred_on BETWEEN ? AND ?',
    ]) {
      final args = List.filled('?'.allMatches(sql).length, 'x');
      final details = [
        for (final row in await f.db.rawQuery('EXPLAIN QUERY PLAN $sql', args))
          row['detail']! as String,
      ];
      expect(
        details.join('\n'),
        contains('index_expenses_on_occurred_on_and_occurred_at_and_id'),
        reason: '$details',
      );
      expect(details.any((d) => d.contains('TEMP B-TREE')), isFalse);
    }
  });
}
