import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/models/recurring_item.dart';
import 'package:my_expense_tracker_app/domain/recurrence.dart';
import 'package:my_expense_tracker_app/domain/recurring_price.dart';
import 'package:my_expense_tracker_app/domain/upcoming.dart';

const today = '2026-10-09';

/// An item as the repository reads it.
RecurringItem item(
  int id,
  String title, {
  Frequency frequency = Frequency.monthly,
  required String start,
  String? cursor,
  String? end,
  List<PricePoint>? prices,
  bool archived = false,
}) => RecurringItem(
  id: id,
  title: title,
  description: null,
  currencyCode: 'INR',
  categoryId: 1,
  paymentMethodId: 1,
  eventIds: const {},
  schedule: Schedule(
    frequency: frequency,
    interval: 1,
    startOn: start,
    endOn: end,
  ),
  timeOfDayMinutes: 600,
  nextDueOn: cursor,
  archivedAt: archived ? DateTime.utc(2026, 10, 1) : null,
  archivedOn: archived ? '2026-10-01' : null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  priceMinor: 64900,
  paymentCount: 1,
  hold: null,
  prices: prices ?? [(from: start, amountMinor: 64900)],
);

List<String> days(List<UpcomingPayment> payments) => [
  for (final p in payments) p.day,
];

List<UpcomingPayment> upcoming(
  List<RecurringItem> items, {
  Set<SkipKey> skips = const {},
}) => upcomingPayments(
  items,
  skips,
  today: today,
  through: upcomingThrough(today),
);

void main() {
  group('upcoming (today 2026-10-09)', () {
    test('Netflix monthly from 10-09: 11-09 … 2027-10-09 (12)', () {
      final list = upcoming([
        item(1, 'Netflix', start: today, cursor: '2026-11-09'),
      ]);
      expect(list, hasLength(12));
      expect(list.first.day, '2026-11-09');
      expect(list.last.day, '2027-10-09');
    });

    test('Gym weekly from Mon 10-05, 10-19 skipped: 10-12, 10-19 '
        '(skipped), 10-26 …', () {
      final list = upcoming(
        [
          item(
            2,
            'Gym',
            frequency: Frequency.weekly,
            start: '2026-10-05',
            cursor: '2026-10-12',
          ),
        ],
        skips: {(itemId: 2, day: '2026-10-19')},
      );
      expect(days(list).take(3), ['2026-10-12', '2026-10-19', '2026-10-26']);
      expect([for (final p in list.take(3)) p.skipped], [false, true, false]);
    });

    test('Rent monthly, ends 2026-12-31: 11-01, 12-01', () {
      final list = upcoming([
        item(
          3,
          'Rent',
          start: '2026-01-01',
          cursor: '2026-11-01',
          end: '2026-12-31',
        ),
      ]);
      expect(days(list), ['2026-11-01', '2026-12-01']);
    });

    test('an archived item: none; no payment left: none', () {
      expect(
        upcoming([
          item(4, 'Old', start: today, cursor: '2026-11-09', archived: true),
          item(5, 'Done', start: '2026-01-01', end: '2026-12-31'),
        ]),
        isEmpty,
      );
    });

    test('a held item: only its dates after today', () {
      final list = upcoming([
        item(6, 'Held', start: '2026-06-09', cursor: '2026-07-09'),
      ]);
      expect(list.first.day, '2026-11-09');
    });

    test('an item starting 2027-01-15: from 2027-01-15', () {
      final list = upcoming([
        item(7, 'Later', start: '2027-01-15', cursor: '2027-01-15'),
      ]);
      expect(list.first.day, '2027-01-15');
    });

    test('Netflix ₹649, ₹699 from 2027-01-09: each at the price on its '
        'date', () {
      final list = upcoming([
        item(
          1,
          'Netflix',
          start: today,
          cursor: '2026-11-09',
          prices: [
            (from: today, amountMinor: 64900),
            (from: '2027-01-09', amountMinor: 69900),
          ],
        ),
      ]);
      expect(list[1].day, '2026-12-09');
      expect(list[1].amountMinor, 64900);
      expect(list[2].day, '2027-01-09');
      expect(list[2].amountMinor, 69900);
    });

    test('two items on one day: one day, both rows, by title then id', () {
      final list = upcoming([
        item(9, 'netflix', start: today, cursor: '2026-11-09'),
        item(8, 'Gym', start: today, cursor: '2026-11-09'),
        item(7, 'Gym', start: today, cursor: '2026-11-09'),
      ]);
      final groups = upcomingGroups(list);
      final first = groups.first.days.first;
      expect(first.day, '2026-11-09');
      expect([for (final p in first.payments) p.itemId], [7, 8, 9]);
    });

    test('a cursor of today (today\'s payment not added yet) is not '
        'upcoming: from tomorrow', () {
      final list = upcoming([
        item(
          1,
          'Milk',
          frequency: Frequency.daily,
          start: '2026-10-01',
          cursor: today,
        ),
      ]);
      expect(list.first.day, '2026-10-10');
      expect(list, hasLength(365));
    });
  });

  group('the 12-month end', () {
    test('31 Jan → 31 Jan; 29 Feb → 28 Feb; 31 Oct → 31 Oct', () {
      expect(upcomingThrough('2027-01-31'), '2028-01-31');
      expect(upcomingThrough('2028-02-29'), '2029-02-28');
      expect(upcomingThrough('2026-10-31'), '2027-10-31');
      expect(upcomingThrough(today), '2027-10-09');
    });

    test('pages: the rest of this month, then each month to the end', () {
      final pages = upcomingPages(today);
      expect(pages.first.from, '2026-10-10');
      expect(pages.first.to, '2026-10-31');
      expect(pages[1].from, '2026-11-01');
      expect(pages.last.from, '2027-10-01');
      expect(pages.last.to, '2027-10-09');
      expect(pages, hasLength(13));
      // Today the month's last day: no empty first page.
      final fromEnd = upcomingPages('2026-10-31');
      expect(fromEnd.first.from, '2026-11-01');
      expect(fromEnd.last.to, '2027-10-31');
      expect(fromEnd, hasLength(12));
    });

    test('pages cover every payment exactly once', () {
      final items = [
        item(
          1,
          'Milk',
          frequency: Frequency.daily,
          start: '2026-01-01',
          cursor: '2026-10-09',
        ),
        item(2, 'Netflix', start: '2026-01-31', cursor: '2026-10-31'),
      ];
      final all = upcoming(items);
      final paged = [
        for (final page in upcomingPages(today))
          ...upcomingPayments(
            items,
            const {},
            today: today,
            from: page.from,
            through: page.to,
          ),
      ];
      expect(paged, all);
    });
  });

  test('hasUpcomingPayment: only an item Upcoming lists a payment of', () {
    bool has(RecurringItem i) => hasUpcomingPayment(i, today: today);
    expect(has(item(1, 'Netflix', start: today, cursor: '2026-11-09')), isTrue);
    // Its first payment on the last day shown (12 months on), and the day
    // after.
    expect(
      has(item(2, 'Late', start: '2027-10-09', cursor: '2027-10-09')),
      isTrue,
    );
    expect(
      has(item(3, 'Later', start: '2027-10-10', cursor: '2027-10-10')),
      isFalse,
    );
    // Held, its end passed: nothing to come.
    expect(
      has(
        item(
          4,
          'Held',
          start: '2026-07-01',
          cursor: '2026-08-01',
          end: '2026-10-01',
        ),
      ),
      isFalse,
    );
    expect(
      has(item(5, 'Ended', start: '2026-07-01')),
      isFalse,
      reason: 'no cursor',
    );
    expect(
      has(
        item(6, 'Stopped', start: today, cursor: '2026-11-09', archived: true),
      ),
      isFalse,
    );
  });

  group('upcomingItemMatches (owner, 2026-10-10: Home\'s filters apply)', () {
    RecurringItem gym() => RecurringItem(
      id: 1,
      title: 'Gym membership',
      description: 'Downtown club',
      currencyCode: 'INR',
      categoryId: 11,
      paymentMethodId: 1,
      eventIds: const {2, 5},
      schedule: const Schedule(
        frequency: Frequency.monthly,
        interval: 1,
        startOn: today,
      ),
      timeOfDayMinutes: 600,
      nextDueOn: '2026-11-09',
      archivedAt: null,
      archivedOn: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      priceMinor: 1,
      paymentCount: 1,
      hold: null,
    );

    test('no filter, Only recurring: every item, and not "Filtered"', () {
      const onlyRecurring = ExpenseFilter(onlyRecurring: true);
      expect(upcomingItemMatches(gym(), ExpenseFilter.none), isTrue);
      expect(upcomingItemMatches(gym(), onlyRecurring), isTrue);
      expect(upcomingFiltered(ExpenseFilter.none), isFalse);
      expect(upcomingFiltered(onlyRecurring), isFalse);
      expect(
        upcomingFiltered(onlyRecurring.copyWith(text: 'gym')),
        isTrue,
        reason: 'the text narrows it',
      );
    });

    test('categories: any chosen one', () {
      expect(
        upcomingItemMatches(gym(), const ExpenseFilter(categoryIds: {3, 11})),
        isTrue,
      );
      expect(
        upcomingItemMatches(gym(), const ExpenseFilter(categoryIds: {3})),
        isFalse,
      );
    });

    test('events: at least one chosen', () {
      expect(
        upcomingItemMatches(gym(), const ExpenseFilter(eventIds: {5, 9})),
        isTrue,
      );
      expect(
        upcomingItemMatches(gym(), const ExpenseFilter(eventIds: {9})),
        isFalse,
      );
    });

    test('text: every word in the title or description, any case', () {
      for (final text in ['gym', 'MEMBER club', 'down', '  ']) {
        expect(
          upcomingItemMatches(gym(), ExpenseFilter(text: text)),
          isTrue,
          reason: text,
        );
      }
      expect(
        upcomingItemMatches(gym(), const ExpenseFilter(text: 'gym pool')),
        isFalse,
      );
    });

    test('combined by AND', () {
      expect(
        upcomingItemMatches(
          gym(),
          const ExpenseFilter(text: 'gym', categoryIds: {3}),
        ),
        isFalse,
      );
    });
  });

  test('groups: nearest month first, days in order', () {
    final groups = upcomingGroups(
      upcoming([
        item(1, 'A', start: today, cursor: '2026-11-09'),
        item(
          2,
          'B',
          frequency: Frequency.weekly,
          start: '2026-10-05',
          cursor: '2026-10-12',
        ),
      ]),
    );
    expect(groups.first.month, '2026-10-01');
    expect(groups[1].month, '2026-11-01');
    expect(
      [for (final d in groups.first.days) d.day],
      ['2026-10-12', '2026-10-19', '2026-10-26'],
    );
    expect(groups.last.month, '2027-10-01');
  });
}
