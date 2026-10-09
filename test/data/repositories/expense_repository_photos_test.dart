import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/data_version.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

/// Photos in `ExpenseRepository` (phase-6.md §6.4, §6.4a), on SQLite 3.22.
void main() {
  late Database db;
  late TestClock clock;
  late DataVersion version;
  late ExpenseRepository repository;

  setUp(() async {
    db = await openMigratedDatabase();
    clock = TestClock();
    version = DataVersion();
    repository = ExpenseRepository(db, dataVersion: version, now: clock.call);
  });

  String sha(String letter) => letter * 64;
  LinkNewPhoto newPhoto(String letter, {String ext = 'jpg', int size = 10}) =>
      LinkNewPhoto(
        relativePath: 'photos/${sha(letter)}.$ext',
        sha256: sha(letter),
        byteSize: size,
      );

  ExpenseInput input({
    String title = 'Lunch',
    List<PhotoLinkInput> photos = const [],
    int categoryId = 1,
    String day = '2026-10-05',
    int hour = 7,
    Money amount = const Money(11050, 'INR'),
  }) {
    final date = DateTime.parse(day);
    return ExpenseInput(
      title: title,
      description: null,
      amount: amount,
      occurredAt: DateTime.utc(date.year, date.month, date.day, hour),
      utcOffsetMinutes: 0,
      categoryId: categoryId,
      paymentMethodId: 1,
      eventIds: const {},
      photos: photos,
    );
  }

  Future<List<String>> photoLetters(int expenseId) async => [
    for (final p in await repository.photosOf(expenseId)) p.sha256[0],
  ];

  Future<int> count(String table) async =>
      (await db.rawQuery('SELECT count(*) AS n FROM $table')).single['n']!
          as int;

  group('add and update', () {
    test('new photos make rows and links 0, 1, …; photosOf is in order; '
        'photoCount on every read', () async {
      final e = await repository.add(
        input(
          photos: [
            newPhoto('b'),
            newPhoto('a', ext: 'png'),
          ],
        ),
      );
      expect(e.photoCount, 2);
      expect(await photoLetters(e.id), ['b', 'a']);
      final links = await db.query('expense_photos', orderBy: 'sort_order');
      expect([for (final l in links) l['sort_order']], [0, 1]);
      expect((await repository.byId(e.id))!.photoCount, 2);
      expect((await repository.page()).single.photoCount, 2);
      expect((await repository.byIds([e.id])).single.photoCount, 2);
      await repository.moveToBin(e.id);
      expect((await repository.binned()).single.photoCount, 2);
    });

    test('a photo already saved for another expense is one row and two '
        'links (the id is read back after the ignored insert)', () async {
      final a = await repository.add(input(photos: [newPhoto('a')]));
      final b = await repository.add(
        input(title: 'Taxi', photos: [newPhoto('a'), newPhoto('c')]),
      );
      expect(await count('photos'), 2);
      expect(await count('expense_photos'), 3);
      expect(
        (await repository.photosOf(a.id)).single.id,
        (await repository.photosOf(b.id)).first.id,
      );
    });

    test('update reorders, removes and adds; the removed row stays for the '
        'sweep', () async {
      final e = await repository.add(
        input(photos: [newPhoto('a'), newPhoto('b'), newPhoto('c')]),
      );
      final [a, b, _] = await repository.photosOf(e.id);
      final updated = await repository.update(
        e.id,
        input(
          photos: [LinkSavedPhoto(b.id), newPhoto('d'), LinkSavedPhoto(a.id)],
        ),
      );
      expect(await photoLetters(e.id), ['b', 'd', 'a']);
      expect(updated.photoCount, 3);
      expect(await count('photos'), 4, reason: 'c stays until the sweep');
    });

    test('a saved photo whose row vanished is left out; the rest are saved, '
        'and the count says so', () async {
      final e = await repository.add(
        input(photos: [newPhoto('a'), newPhoto('b')]),
      );
      final [a, b] = await repository.photosOf(e.id);
      await db.delete('expense_photos');
      await db.delete('photos', where: 'id = ?', whereArgs: [a.id]);
      final updated = await repository.update(
        e.id,
        input(photos: [LinkSavedPhoto(a.id), LinkSavedPhoto(b.id)]),
      );
      expect(updated.photoCount, 1);
      expect(await photoLetters(e.id), ['b']);
      expect(
        (await db.query('expense_photos')).single['sort_order'],
        0,
        reason: 'no gap left where the vanished one was',
      );
    });

    test('the same photo twice in one input is linked once, never a '
        'primary key failure', () async {
      final e = await repository.add(
        input(photos: [newPhoto('a'), newPhoto('a')]),
      );
      final [a] = await repository.photosOf(e.id);
      await repository.update(
        e.id,
        input(photos: [LinkSavedPhoto(a.id), newPhoto('a')]),
      );
      expect(await photoLetters(e.id), ['a']);
    });

    test('a crafted path is refused and nothing is saved', () async {
      await expectLater(
        repository.add(
          input(
            photos: [
              const LinkNewPhoto(
                relativePath: '../databases/expense_tracker.db',
                sha256: 'x',
                byteSize: 1,
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
      expect(await count('expenses'), 0);
      expect(await count('photos'), 0);
    });

    test('KWD (3 decimals) and JPY (0) keep their exact minor units with '
        'photos', () async {
      final kwd = await repository.add(
        input(amount: const Money(1234567, 'KWD'), photos: [newPhoto('a')]),
      );
      final jpy = await repository.add(
        input(amount: const Money(500, 'JPY'), photos: [newPhoto('b')]),
      );
      expect(
        (await repository.byId(kwd.id))!.amount,
        const Money(1234567, 'KWD'),
      );
      expect((await repository.byId(jpy.id))!.amount, const Money(500, 'JPY'));
    });

    test('photo counts are read in chunks: 1,200 expenses', () async {
      final ids = <int>[];
      await db.transaction((txn) async {
        for (var i = 0; i < 1200; i++) {
          ids.add(await insertExpenseRow(txn));
        }
        final photo = await txn.insert('photos', {
          'relative_path': 'photos/${sha('a')}.jpg',
          'sha256': sha('a'),
          'byte_size': 1,
          'created_at': 0,
          'updated_at': 0,
        });
        for (final id in ids) {
          await txn.insert('expense_photos', {
            'expense_id': id,
            'photo_id': photo,
            'sort_order': 0,
          });
        }
      });
      final all = await repository.byIds(ids);
      expect(all, hasLength(1200));
      expect(all.every((e) => e.photoCount == 1), isTrue);
    });
  });

  group('the bin', () {
    test('moveToBin keeps the links; deletePermanently, emptyBin and '
        'purgeBin drop them and keep the rows', () async {
      final a = await repository.add(input(photos: [newPhoto('a')]));
      final b = await repository.add(input(photos: [newPhoto('b')]));
      final c = await repository.add(input(photos: [newPhoto('c')]));
      for (final e in [a, b, c]) {
        await repository.moveToBin(e.id);
      }
      expect(await count('expense_photos'), 3);
      await repository.deletePermanently(a.id);
      expect(await count('expense_photos'), 2);
      clock.advance(const Duration(days: 31));
      await repository.purgeBin();
      expect(await count('expense_photos'), 0);
      expect(await count('photos'), 3);
      final d = await repository.add(input(photos: [newPhoto('d')]));
      await repository.moveToBin(d.id);
      await repository.emptyBin();
      expect(await count('expense_photos'), 0);
      expect(await count('photos'), 4);
    });
  });

  group('stats and checks', () {
    test('photoStats counts linked rows only, binned included', () async {
      final a = await repository.add(
        input(photos: [newPhoto('a', size: 100), newPhoto('b', size: 50)]),
      );
      await repository.add(input(photos: [newPhoto('a', size: 100)]));
      await repository.moveToBin(a.id);
      expect(await repository.photoStats(), (count: 2, bytes: 150));
      await repository.update((await repository.page()).single.id, input());
      expect(await repository.photoStats(), (
        count: 2,
        bytes: 150,
      ), reason: 'a (binned) still links both');
      await repository.deletePermanently(a.id);
      expect(await repository.photoStats(), (count: 0, bytes: 0));
    });

    test('existingPhotoIds', () async {
      final e = await repository.add(
        input(photos: [newPhoto('a'), newPhoto('b')]),
      );
      final [a, b] = await repository.photosOf(e.id);
      await db.delete('expense_photos');
      await db.delete('photos', where: 'id = ?', whereArgs: [a.id]);
      expect(await repository.existingPhotoIds([a.id, b.id, 999]), {b.id});
      expect(await repository.existingPhotoIds([]), isEmpty);
    });

    test('hasPhotos: none; only binned; active', () async {
      expect(await repository.hasPhotos(), isFalse);
      final e = await repository.add(input(photos: [newPhoto('a')]));
      await repository.moveToBin(e.id);
      expect(await repository.hasPhotos(), isFalse);
      await repository.add(input(title: 'No photo'));
      expect(await repository.hasPhotos(), isFalse);
      await repository.restore(e.id);
      expect(await repository.hasPhotos(), isTrue);
    });

    test('hasMatchingPhotos: a filter matching no photo expense is false '
        'while hasPhotos is true; text is matched in Dart', () async {
      await repository.add(
        input(title: 'Lunch', categoryId: 1, photos: [newPhoto('a')]),
      );
      await repository.add(input(title: 'Taxi', categoryId: 2));
      expect(await repository.hasMatchingPhotos(ExpenseFilter.none), isTrue);
      expect(
        await repository.hasMatchingPhotos(
          const ExpenseFilter(categoryIds: {2}),
        ),
        isFalse,
      );
      expect(await repository.hasPhotos(), isTrue);
      expect(
        await repository.hasMatchingPhotos(const ExpenseFilter(text: 'LUN')),
        isTrue,
      );
      expect(
        await repository.hasMatchingPhotos(const ExpenseFilter(text: 'taxi')),
        isFalse,
        reason: 'Taxi matches but has no photo',
      );
      expect(
        await repository.hasMatchingPhotos(
          const ExpenseFilter(text: 'lunch', categoryIds: {2}),
        ),
        isFalse,
      );
    });
  });

  group('photoExpensesPage', () {
    test('Home\'s order, binned and photo-less left out, photos in order, '
        '30 / 30 / 10 without gap or repeat', () async {
      final expected = <int>[];
      for (var i = 0; i < 75; i++) {
        final day =
            '2026-${(1 + i ~/ 28).toString().padLeft(2, '0')}-'
            '${(1 + i % 28).toString().padLeft(2, '0')}';
        final withPhoto = i % 15 != 7;
        final e = await repository.add(
          input(
            day: day,
            photos: withPhoto
                ? [newPhoto('${i % 10}'), newPhoto('f')]
                : const [],
          ),
        );
        if (i == 3) {
          await repository.moveToBin(e.id);
        } else if (withPhoto) {
          expected.add(e.id);
        }
      }
      final pages = <List<int>>[];
      List<int> ids(List<({Expense expense, List<dynamic> photos})> page) => [
        for (final row in page) row.expense.id,
      ];
      var page = await repository.photoExpensesPage();
      pages.add(ids(page));
      while (page.length == 30) {
        page = await repository.photoExpensesPage(
          after: page.last.expense.cursor,
        );
        pages.add(ids(page));
      }
      expect([for (final p in pages) p.length], [30, 30, 9]);
      final all = pages.expand((p) => p).toList();
      expect(all, expected.reversed.toList());
      final first = (await repository.photoExpensesPage(limit: 1)).single;
      expect(
        [for (final p in first.photos) p.sha256[0]],
        [first.photos.first.sha256[0], 'f'],
      );
    });

    test('the same order as page() for a traveller\'s rows (R1)', () async {
      // Two expenses on the same stored day, the later moment first.
      final early = await repository.add(
        input(day: '2026-10-05', hour: 1, photos: [newPhoto('a')]),
      );
      final late = await repository.add(
        input(day: '2026-10-05', hour: 20, photos: [newPhoto('b')]),
      );
      final order = [
        for (final r in await repository.photoExpensesPage()) r.expense.id,
      ];
      expect(order, [late.id, early.id]);
      expect(order, [for (final e in await repository.page()) e.id]);
    });

    test('an insert between pages: the next page goes on from the cursor, '
        'no repeat', () async {
      for (var d = 1; d <= 3; d++) {
        await repository.add(
          input(day: '2026-10-0$d', photos: [newPhoto('$d')]),
        );
      }
      final first = await repository.photoExpensesPage(limit: 2);
      await repository.add(input(day: '2026-10-09', photos: [newPhoto('9')]));
      final next = await repository.photoExpensesPage(
        after: first.last.expense.cursor,
        limit: 2,
      );
      expect(
        [
          for (final r in [...first, ...next]) r.expense.occurredOn,
        ],
        ['2026-10-03', '2026-10-02', '2026-10-01'],
      );
    });

    test('filters: a category, an event, both; 1,200 category ids', () async {
      final food = await repository.add(
        input(categoryId: 1, photos: [newPhoto('a')]),
      );
      final travel = await repository.add(
        input(categoryId: 2, photos: [newPhoto('b')]),
      );
      await db.insert('expense_events', {
        'expense_id': travel.id,
        'event_id': 1,
      });
      Future<List<int>> page(ExpenseFilter f) async => [
        for (final r in await repository.photoExpensesPage(filter: f))
          r.expense.id,
      ];
      expect(await page(const ExpenseFilter(categoryIds: {1})), [food.id]);
      expect(await page(const ExpenseFilter(eventIds: {1, 2})), [travel.id]);
      expect(
        await page(const ExpenseFilter(categoryIds: {1}, eventIds: {1})),
        isEmpty,
      );
      expect(
        await page(
          ExpenseFilter(categoryIds: {for (var i = 1; i <= 1200; i++) i}),
        ),
        unorderedEquals([food.id, travel.id]),
      );
    });

    test('the text path (ids ∩ with photos, then by ids) gives the same '
        'rows as the category path for a filter both can express', () async {
      final a = await repository.add(
        input(title: 'Lunch A', categoryId: 1, photos: [newPhoto('a')]),
      );
      await repository.add(input(title: 'Lunch B', categoryId: 1));
      await repository.add(
        input(title: 'Taxi', categoryId: 2, photos: [newPhoto('b')]),
      );
      final withPhotos = await repository.expenseIdsWithPhotos();
      final words = searchWords('lunch');
      final matched = [
        for (final entry in await repository.searchEntries())
          if (matchesText(entry, words) && withPhotos.contains(entry.id))
            entry.id,
      ];
      final byText = await repository.photoExpensesByIds(matched);
      final byCategory = await repository.photoExpensesPage(
        filter: const ExpenseFilter(categoryIds: {1}),
      );
      expect(
        [for (final r in byText) r.expense.id],
        [for (final r in byCategory) r.expense.id],
      );
      expect([for (final r in byText) r.expense.id], [a.id]);
    });

    test('a shared photo is under both expenses', () async {
      await repository.add(input(title: 'A', photos: [newPhoto('a')]));
      await repository.add(input(title: 'B', photos: [newPhoto('a')]));
      final page = await repository.photoExpensesPage();
      expect(page, hasLength(2));
      expect(page[0].photos.single.id, page[1].photos.single.id);
    });
  });

  group('removePhotoLinks (§6.4a)', () {
    test('links of two expenses in one transaction; the rest renumbered; '
        'updated_at moves; DataVersion bumped once', () async {
      final taxi = await repository.add(
        input(
          title: 'Taxi',
          photos: [newPhoto('a'), newPhoto('b'), newPhoto('c')],
        ),
      );
      final lunch = await repository.add(
        input(title: 'Lunch', photos: [newPhoto('d'), newPhoto('e')]),
      );
      final [a, _, c] = await repository.photosOf(taxi.id);
      final [d, _] = await repository.photosOf(lunch.id);
      clock.advance(const Duration(hours: 1));
      final before = version.value;
      final removed = await repository.removePhotoLinks([
        (expenseId: taxi.id, photoId: a.id),
        (expenseId: taxi.id, photoId: c.id),
        (expenseId: lunch.id, photoId: d.id),
      ]);
      expect(removed.count, 3);
      expect(removed.expenseIds, {taxi.id, lunch.id});
      expect(version.value, before + 1);
      expect(await photoLetters(taxi.id), ['b']);
      expect(await photoLetters(lunch.id), ['e']);
      final taxiLink = await db.query(
        'expense_photos',
        where: 'expense_id = ?',
        whereArgs: [taxi.id],
      );
      expect(taxiLink.single['sort_order'], 0);
      expect((await repository.byId(taxi.id))!.updatedAt, clock.now);
      expect(await count('photos'), 5, reason: 'rows stay for the sweep');
    });

    test('an expense binned meanwhile is skipped', () async {
      final e = await repository.add(input(photos: [newPhoto('a')]));
      final [a] = await repository.photosOf(e.id);
      await repository.moveToBin(e.id);
      final removed = await repository.removePhotoLinks([
        (expenseId: e.id, photoId: a.id),
      ]);
      expect(removed.count, 0);
      expect(removed.expenseIds, isEmpty);
      expect(await count('expense_photos'), 1);
    });

    test('a shared photo removed from one expense keeps its link and row '
        'for the other', () async {
      final x = await repository.add(input(photos: [newPhoto('a')]));
      final y = await repository.add(input(photos: [newPhoto('a')]));
      final [a] = await repository.photosOf(x.id);
      await repository.removePhotoLinks([(expenseId: x.id, photoId: a.id)]);
      expect(await photoLetters(x.id), isEmpty);
      expect(await photoLetters(y.id), ['a']);
    });

    test('a failure rolls everything back', () async {
      final x = await repository.add(input(photos: [newPhoto('a')]));
      final y = await repository.add(input(photos: [newPhoto('b')]));
      final [a] = await repository.photosOf(x.id);
      final [b] = await repository.photosOf(y.id);
      // A second expense whose update fails: a trigger-free way is a
      // dropped table the transaction needs on its second expense.
      final failing = ExpenseRepository(
        _FailOnSecondUpdate(db),
        dataVersion: version,
        now: clock.call,
      );
      await expectLater(
        failing.removePhotoLinks([
          (expenseId: x.id, photoId: a.id),
          (expenseId: y.id, photoId: b.id),
        ]),
        throwsA(isA<StateError>()),
      );
      expect(await count('expense_photos'), 2);
    });

    test('nothing to remove changes nothing and bumps nothing', () async {
      final before = version.value;
      expect((await repository.removePhotoLinks([])).count, 0);
      expect(version.value, before);
    });
  });
}

/// Fails the second `expenses` update inside a transaction.
class _FailOnSecondUpdate implements Database {
  _FailOnSecondUpdate(this._db);

  final Database _db;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) =>
      _db.transaction((txn) => action(_FailingTxn(txn)), exclusive: exclusive);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingTxn implements Transaction {
  _FailingTxn(this._txn);

  final Transaction _txn;
  int _expenseUpdates = 0;

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    if (table == 'expenses' && ++_expenseUpdates == 2) {
      throw StateError('disk full');
    }
    return _txn.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) => _txn.query(
    table,
    distinct: distinct,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    groupBy: groupBy,
    having: having,
    orderBy: orderBy,
    limit: limit,
    offset: offset,
  );

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      _txn.delete(table, where: where, whereArgs: whereArgs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
