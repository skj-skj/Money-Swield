import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/photo_groups.dart';
import 'package:my_expense_tracker_app/domain/photos.dart';

void main() {
  var nextId = 100;
  var nextPhoto = 1;

  /// An expense on [day] with one photo per letter of [photos].
  PhotoExpense on(String day, String photos, {String? title, int? atMs}) {
    final id = nextId--;
    return (
      expense: Expense(
        id: id,
        title: title ?? 'E$id',
        description: null,
        amount: const Money(100, 'INR'),
        amountExpression: null,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(atMs ?? 0, isUtc: true),
        utcOffsetMinutes: 0,
        occurredOn: day,
        categoryId: 1,
        paymentMethodId: 1,
        eventIds: const {},
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        deletedAt: null,
      ),
      photos: [
        for (final letter in photos.split(''))
          SavedPhoto(
            id: nextPhoto++,
            relativePath: 'photos/${letter * 64}.jpg',
            sha256: letter * 64,
            byteSize: 1,
          ),
      ],
    );
  }

  /// `month: day[ab] day[c] …` per month, each day's photo letters.
  List<String> shape(List<PhotoExpense> loaded, {bool hasMore = false}) => [
    for (final m in photoGroups(loaded, hasMore: hasMore))
      '${m.range.from.substring(0, 7)}${m.open ? ' open' : ''}: ${[for (final d in m.days) '${d.day.substring(5)}[${d.tiles.map((t) => t.photo.sha256[0]).join()}]'].join(' ')}',
  ];

  test('Lunch [a, b] and Taxi [c] on 5 Oct, Rent [d] on 4 Oct', () {
    expect(
      shape([
        on('2026-10-05', 'ab', title: 'Lunch'),
        on('2026-10-05', 'c', title: 'Taxi'),
        on('2026-10-04', 'd', title: 'Rent'),
      ]),
      ['2026-10: 10-05[abc] 10-04[d]'],
    );
  });

  test('1 Oct and 30 Sep are two months', () {
    expect(shape([on('2026-10-01', 'a'), on('2026-09-30', 'b')]), [
      '2026-10: 10-01[a]',
      '2026-09: 09-30[b]',
    ]);
  });

  test('five photos of one expense stay in order on one day', () {
    expect(shape([on('2026-10-05', 'abcde')]), ['2026-10: 10-05[abcde]']);
  });

  test('a page that ends inside a day leaves the month open', () {
    expect(shape([on('2026-10-05', 'a')], hasMore: true), [
      '2026-10 open: 10-05[a]',
    ]);
  });

  test('31 Dec 2025 and 1 Jan 2026 (newest first) are two months', () {
    expect(shape([on('2026-01-01', 'b'), on('2025-12-31', 'a')]), [
      '2026-01: 01-01[b]',
      '2025-12: 12-31[a]',
    ]);
  });

  test('a traveller\'s day (the R1 rows) is one day: the stored local date '
      'decides, not the moment', () {
    // Recorded in Honolulu late on the 5th (already the 6th in UTC), then
    // on the 5th in India: both on 5 Oct, in list order.
    expect(
      shape([
        on(
          '2026-10-05',
          'a',
          atMs: DateTime.utc(2026, 10, 6, 7).millisecondsSinceEpoch,
        ),
        on(
          '2026-10-05',
          'b',
          atMs: DateTime.utc(2026, 10, 5, 3).millisecondsSinceEpoch,
        ),
      ]),
      ['2026-10: 10-05[ab]'],
    );
  });

  test('a photo on two expenses is a tile under each; the keys differ', () {
    final lunch = on('2026-10-05', 'a');
    final taxi = on('2026-10-05', '');
    final shared = (expense: taxi.expense, photos: lunch.photos);
    final tiles = photoGroups([
      lunch,
      shared,
    ], hasMore: false).single.days.single.tiles;
    expect(tiles, hasLength(2));
    expect(tileKeyOf(tiles[0]), isNot(tileKeyOf(tiles[1])));
  });

  test('nothing loaded is no month', () {
    expect(photoGroups([], hasMore: false), isEmpty);
  });
}
