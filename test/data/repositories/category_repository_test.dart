import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/category_repository.dart';
import 'package:my_expense_tracker_app/domain/models/category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;
  late TestClock clock;
  late CategoryRepository repository;

  setUp(() async {
    db = await openMigratedDatabase();
    clock = TestClock();
    repository = CategoryRepository(db, now: clock.call);
  });

  Future<Category> byId(int id) async =>
      (await repository.all()).singleWhere((c) => c.id == id);

  group('all', () {
    test('returns the 20 seeded built-ins with no name of their own', () async {
      final categories = await repository.all();
      expect(categories, hasLength(20));
      expect(
        categories.every((c) => c.builtinKey != null && c.name == null),
        isTrue,
      );
      expect(categories.first.emoji, '🍽️');
    });

    test('reads timestamps back as UTC', () async {
      final category = (await repository.all()).first;
      expect(category.createdAt.isUtc, isTrue);
      expect(category.updatedAt.isUtc, isTrue);
    });
  });

  group('add', () {
    test(
      'stores a user category and returns exactly what all() reads back',
      () async {
        final added = await repository.add(
          name: 'Pets',
          description: 'Food and vet',
          emoji: '🐶',
        );

        expect(added.builtinKey, isNull);
        expect(added.name, 'Pets');
        expect(added.createdAt, clock.now);
        expect(added.updatedAt, clock.now);
        // Same instant AND same isUtc flag, or DateTime == fails.
        expect(await byId(added.id), added);
      },
    );

    test('keeps a NULL description as NULL, not as empty text', () async {
      final added = await repository.add(name: 'Pets', emoji: '🐶');
      final row = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [added.id],
      );
      expect(row.single['description'], isNull);
    });

    test(
      'round-trips multi-code-point emoji and Hindi text unchanged',
      () async {
        final added = await repository.add(name: 'परिवार', emoji: '👨‍👩‍👧');
        final read = await byId(added.id);
        expect(read.name, 'परिवार');
        expect(read.emoji, '👨‍👩‍👧');
      },
    );

    test('never reuses the id of a deleted category', () async {
      final first = await repository.add(name: 'A', emoji: '🅰️');
      await repository.delete(first.id);
      final second = await repository.add(name: 'B', emoji: '🅱️');
      expect(second.id, greaterThan(first.id));
    });
  });

  group('update', () {
    test(
      'saves name, description and emoji and moves updated_at only',
      () async {
        final added = await repository.add(name: 'Pets', emoji: '🐶');
        clock.advance(const Duration(minutes: 5));

        final saved = await repository.update(
          Category(
            id: added.id,
            builtinKey: null,
            name: 'Animals',
            description: 'Vet',
            emoji: '🐱',
            createdAt: added.createdAt,
            updatedAt: added.updatedAt,
          ),
        );

        expect(saved.updatedAt, clock.now);
        expect(saved.createdAt, added.createdAt);
        expect(await byId(added.id), saved);
      },
    );

    test(
      'can clear a renamed built-in back to NULL so it follows the language',
      () async {
        final food = (await repository.all()).firstWhere(
          (c) => c.builtinKey == 'food',
        );
        await repository.update(food.copyWith(name: 'Khana'));
        expect((await byId(food.id)).name, 'Khana');

        final reset = await repository.update(
          Category(
            id: food.id,
            builtinKey: food.builtinKey,
            name: null,
            description: null,
            emoji: food.emoji,
            createdAt: food.createdAt,
            updatedAt: food.updatedAt,
          ),
        );
        expect(reset.name, isNull);
        expect((await byId(food.id)).name, isNull);
      },
    );

    test(
      'never changes builtin_key or created_at, whatever the model says',
      () async {
        final food = (await repository.all()).firstWhere(
          (c) => c.builtinKey == 'food',
        );
        await repository.update(
          Category(
            id: food.id,
            builtinKey: 'hacked',
            name: null,
            description: null,
            emoji: '🍕',
            createdAt: DateTime.utc(2000),
            updatedAt: food.updatedAt,
          ),
        );
        final read = await byId(food.id);
        expect(read.builtinKey, 'food');
        expect(read.createdAt, food.createdAt);
        expect(read.emoji, '🍕');
      },
    );

    test('throws when the category no longer exists, instead of silently doing nothing', () async {
      final added = await repository.add(name: 'Pets', emoji: '🐶');
      await repository.delete(added.id);
      expect(
        () => repository.update(added.copyWith(name: 'Gone')),
        throwsStateError,
      );
    });

    test('only touches the edited row', () async {
      final before = await repository.all();
      final food = before.firstWhere((c) => c.builtinKey == 'food');
      clock.advance(const Duration(hours: 1));
      await repository.update(food.copyWith(emoji: '🍕'));

      final after = await repository.all();
      for (final category in after.where((c) => c.id != food.id)) {
        expect(category, before.firstWhere((c) => c.id == category.id));
      }
    });
  });

  group('delete', () {
    test(
      'removes only that category, built-ins included, and does not re-seed it',
      () async {
        final food = (await repository.all()).firstWhere(
          (c) => c.builtinKey == 'food',
        );
        await repository.delete(food.id);

        final after = await repository.all();
        expect(after, hasLength(19));
        expect(after.any((c) => c.builtinKey == 'food'), isFalse);
      },
    );

    test('of a missing id does nothing', () async {
      await repository.delete(999999);
      expect(await repository.all(), hasLength(20));
    });
  });
}
