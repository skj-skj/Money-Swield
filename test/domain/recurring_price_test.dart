import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/recurring_price.dart';

void main() {
  const points = <PricePoint>[
    (from: '2026-06-15', amountMinor: 300),
    (from: '2026-01-31', amountMinor: 100),
    (from: '2026-04-01', amountMinor: 200),
  ];

  test('priceOn: before, on, between and after changes, in any order', () {
    expect(priceOn(points, '2026-01-30'), isNull);
    expect(priceOn(points, '2026-01-31'), 100);
    expect(priceOn(points, '2026-03-31'), 100);
    expect(priceOn(points, '2026-04-01'), 200);
    expect(priceOn(points, '2026-06-14'), 200);
    expect(priceOn(points, '2026-06-15'), 300);
    expect(priceOn(points, '2099-01-01'), 300);
    expect(priceOn(const [], '2026-01-01'), isNull);
  });

  group('priceChangeFor (today 2026-10-09)', () {
    const today = '2026-10-09';
    const start = '2026-01-31';
    const withScheduled = [...points, (from: '2027-01-09', amountMinor: 699)];
    PriceChange change(String from) =>
        priceChangeFor(withScheduled, startOn: start, from: from, today: today);

    test('before the start: refused', () {
      expect(change('2026-01-30'), PriceChange.beforeStart);
    });

    test('up to today, no price there: a new price', () {
      expect(change('2026-09-01'), PriceChange.add);
      expect(change(today), PriceChange.add);
    });

    test('up to today with a price there, the first too: in force', () {
      expect(change('2026-04-01'), PriceChange.inForce);
      expect(change(start), PriceChange.inForce);
    });

    test('after today: new, or replaces the scheduled one', () {
      expect(change('2026-11-09'), PriceChange.add);
      expect(change('2027-01-09'), PriceChange.replace);
    });

    test('an item starting after today: its first price can be replaced', () {
      expect(
        priceChangeFor(
          const [(from: '2026-12-25', amountMinor: 1)],
          startOn: '2026-12-25',
          from: '2026-12-25',
          today: today,
        ),
        PriceChange.replace,
      );
    });
  });

  group('canRemovePrice', () {
    const today = '2026-10-09';
    test('only a scheduled one that is not the first', () {
      const list = [...points, (from: '2027-01-09', amountMinor: 699)];
      expect(canRemovePrice(list, from: '2027-01-09', today: today), isTrue);
      expect(canRemovePrice(list, from: '2026-04-01', today: today), isFalse);
      expect(canRemovePrice(list, from: '2026-01-31', today: today), isFalse);
      expect(canRemovePrice(list, from: '2027-02-01', today: today), isFalse);
    });

    test('the first price of a future item stays', () {
      expect(
        canRemovePrice(
          const [(from: '2026-12-25', amountMinor: 1)],
          from: '2026-12-25',
          today: today,
        ),
        isFalse,
      );
    });
  });
}
