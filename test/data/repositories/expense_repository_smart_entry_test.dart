import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/data_version.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/title_suggestions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

/// Phase 4's reads and writes on `expenses` (phase-4.md §6.1–§6.3, §6.5,
/// R14). Phase 2's are in `expense_repository_test.dart`.
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

  /// Today on the device, as the repository sees it.
  DateTime today() {
    final local = clock.now.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// An expense dated [daysAgo] days before today (negative = future), at
  /// [hour] with offset 0, so `occurred_on` is exactly that date.
  Future<Expense> add(
    String title, {
    int daysAgo = 0,
    int hour = 12,
    int amount = 11050,
    String currency = 'INR',
    int categoryId = 1,
    String? expression,
    Set<int> eventIds = const {},
  }) => repository.add(
    ExpenseInput(
      title: title,
      description: null,
      amount: Money(amount, currency),
      amountExpression: expression,
      occurredAt: today()
          .subtract(Duration(days: daysAgo))
          .add(Duration(hours: hour)),
      utcOffsetMinutes: 0,
      categoryId: categoryId,
      paymentMethodId: 1,
      eventIds: eventIds,
    ),
  );

  Future<void> putDraftRow({String title = 'ZZDRAFT'}) =>
      db.insert('expense_draft', {
        'id': 1,
        'editing_expense_id': null,
        'form_json': '{"v":1,"title":"$title","amount":"99999"}',
        'updated_at': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> draftRows() async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM expense_draft'))
              .single['n']!
          as int;

  group('titleHistory', () {
    test('no expenses → nothing', () async {
      expect(await repository.titleHistory(), isEmpty);
    });

    test('one row per exact spelling, grouped in Dart', () async {
      await add('Lunch', daysAgo: 3);
      await add('lunch', daysAgo: 2);
      await add('Lunch', daysAgo: 1);
      final rows = await repository.titleHistory();
      expect(
        rows.map((r) => (r.title, r.recent)),
        unorderedEquals([('Lunch', 2), ('lunch', 1)]),
      );
      final grouped = groupTitleHistory(rows).single;
      expect(grouped.recent, 3);
      expect(grouped.title, 'Lunch', reason: 'the newest spelling');
    });

    test(
      'counts uses in the last 180 days, but lists older titles too',
      () async {
        await add('Tea', daysAgo: 180);
        await add('Tea', daysAgo: 181);
        await add('Old', daysAgo: 400);
        final rows = {
          for (final r in await repository.titleHistory()) r.title: r,
        };
        expect(rows['Tea']!.recent, 1);
        expect(rows['Old']!.recent, 0);
      },
    );

    test('the last amount and category come from the newest row', () async {
      await add('Lunch', daysAgo: 5, amount: 100, categoryId: 2);
      await add('Lunch', daysAgo: 1, amount: 300, categoryId: 3);
      await add('Lunch', daysAgo: 3, amount: 200, categoryId: 4);
      final row = (await repository.titleHistory()).single;
      expect((row.amountMinor, row.categoryId), (300, 3));
      expect(
        row.lastAt,
        today()
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 12)),
      );
    });

    test('the newest "Lunch" is binned → the older amount shows', () async {
      await add('Lunch', daysAgo: 5, amount: 100);
      final newest = await add('Lunch', daysAgo: 1, amount: 300);
      await repository.moveToBin(newest.id);
      final row = (await repository.titleHistory()).single;
      expect(row.amountMinor, 100);
      expect(row.recent, 1, reason: 'the binned use is not counted');
    });

    test('future-dated rows are neither counted nor the last amount '
        '(P4-17)', () async {
      await add('Rent', daysAgo: 10, amount: 100);
      await add('Rent', daysAgo: -5, amount: 999);
      await add('Trip', daysAgo: -30);
      final rows = await repository.titleHistory();
      expect(rows.map((r) => r.title), ['Rent']);
      expect(rows.single.amountMinor, 100);
      expect(rows.single.recent, 1);
    });

    test('today counts (occurred_on == today)', () async {
      await add('Now', hour: 23);
      expect((await repository.titleHistory()).single.recent, 1);
    });
  });

  group('prefillSource', () {
    test('the newest row of any spelling, with its events', () async {
      await add('lunch', daysAgo: 3);
      final newest = await add('LUNCH', daysAgo: 1, eventIds: {1, 2});
      await add('Lunch', daysAgo: 2);
      expect(
        await repository.prefillSource(['lunch', 'LUNCH', 'Lunch']),
        newest,
      );
    });

    test('a tie on occurred_at goes to the highest id (R3)', () async {
      await add('Tea', amount: 100);
      final second = await add('Tea', amount: 200);
      await add('Other');
      expect((await repository.prefillSource(['Tea']))!.id, second.id);
    });

    test('binned and future-dated rows are left out', () async {
      final kept = await add('Tea', daysAgo: 5);
      final binned = await add('Tea', daysAgo: 1);
      await repository.moveToBin(binned.id);
      await add('Tea', daysAgo: -1);
      expect((await repository.prefillSource(['Tea']))!.id, kept.id);
    });

    test('exact spellings only: no case folding in SQL', () async {
      await add('Tea');
      expect(await repository.prefillSource(['TEA']), isNull);
      expect(await repository.prefillSource([]), isNull);
    });

    test('a title with SQL wildcards matches only itself', () async {
      await add('50%_off');
      await add('50xxoff');
      expect((await repository.prefillSource(['50%_off']))!.title, '50%_off');
    });

    test('keeps the stored expression', () async {
      await add('Veg', amount: 17000, expression: '50+60*2');
      expect(
        (await repository.prefillSource(['Veg']))!.amountExpression,
        '50+60*2',
      );
    });
  });

  group('amountChipStats', () {
    test('needs at least 2 uses', () async {
      await add('a', amount: 5000);
      await add('b', amount: 5000);
      await add('c', amount: 7000);
      expect(await repository.amountChipStats('INR'), [5000]);
    });

    test('only the given currency', () async {
      await add('a', amount: 500, currency: 'USD');
      await add('b', amount: 500, currency: 'USD');
      await add('c', amount: 500);
      await add('d', amount: 500);
      expect(await repository.amountChipStats('USD'), [500]);
      expect(await repository.amountChipStats('EUR'), isEmpty);
    });

    test('the last 90 days only, future excluded', () async {
      await add('a', amount: 100, daysAgo: 90);
      await add('b', amount: 100, daysAgo: 0);
      await add('c', amount: 200, daysAgo: 91);
      await add('d', amount: 200, daysAgo: 1);
      await add('e', amount: 300, daysAgo: -1);
      await add('f', amount: 300, daysAgo: 2);
      expect(await repository.amountChipStats('INR'), [100]);
    });

    test('binned rows don\'t count', () async {
      await add('a', amount: 100);
      final binned = await add('b', amount: 100);
      await repository.moveToBin(binned.id);
      expect(await repository.amountChipStats('INR'), isEmpty);
    });

    test(
      'ordered by uses, then most recent, then smallest; at most 6',
      () async {
        // 900 × 3 uses; 800 and 700 × 2 with 700 more recent; 100–500 × 2,
        // all on the same day (tie → smallest first).
        for (var i = 0; i < 3; i++) {
          await add('x', amount: 900, daysAgo: 10);
        }
        await add('x', amount: 800, daysAgo: 5);
        await add('x', amount: 800, daysAgo: 5);
        await add('x', amount: 700, daysAgo: 1);
        await add('x', amount: 700, daysAgo: 1);
        for (final amount in [500, 400, 300, 200, 100]) {
          await add('x', amount: amount, daysAgo: 20);
          await add('x', amount: amount, daysAgo: 20);
        }
        expect(await repository.amountChipStats('INR'), [
          900,
          700,
          800,
          100,
          200,
          300,
        ]);
      },
    );
  });

  group('clearDraft (phase-4.md §6.3)', () {
    ExpenseInput input() => ExpenseInput(
      title: 'Lunch',
      description: null,
      amount: const Money(100, 'INR'),
      occurredAt: DateTime.utc(2026, 10, 1),
      utcOffsetMinutes: 0,
      categoryId: 1,
      paymentMethodId: 1,
      eventIds: const {},
    );

    test(
      'add, update and moveToBin leave the draft row alone by default',
      () async {
        await putDraftRow();
        final added = await repository.add(input());
        await repository.update(added.id, input());
        await repository.moveToBin(added.id);
        expect(await draftRows(), 1);
      },
    );

    test('add(clearDraft: true) deletes the row', () async {
      await putDraftRow();
      await repository.add(input(), clearDraft: true);
      expect(await draftRows(), 0);
    });

    test('update(clearDraft: true) deletes the row', () async {
      final added = await repository.add(input());
      await putDraftRow();
      await repository.update(added.id, input(), clearDraft: true);
      expect(await draftRows(), 0);
    });

    test('moveToBin(clearDraft: true) deletes the row', () async {
      final added = await repository.add(input());
      await putDraftRow();
      await repository.moveToBin(added.id, clearDraft: true);
      expect(await draftRows(), 0);
    });

    test('a failing save (foreign key) keeps the draft row: same '
        'transaction', () async {
      await putDraftRow();
      final broken = ExpenseInput(
        title: 'x',
        description: null,
        amount: const Money(100, 'INR'),
        occurredAt: DateTime.utc(2026),
        utcOffsetMinutes: 0,
        categoryId: 1,
        paymentMethodId: 1,
        eventIds: const {9999},
      );
      await expectLater(
        repository.add(broken, clearDraft: true),
        throwsA(isA<DatabaseException>()),
      );
      expect(await draftRows(), 1);
      expect(await db.query('expenses'), isEmpty);
    });

    test('update of a binned expense throws and keeps the draft row', () async {
      final added = await repository.add(input());
      await repository.moveToBin(added.id);
      await putDraftRow();
      await expectLater(
        repository.update(added.id, input(), clearDraft: true),
        throwsA(isA<ExpenseNotFound>()),
      );
      expect(await draftRows(), 1);
    });
  });

  group('moveToBin (R14)', () {
    test('a binned expense throws ExpenseNotFound and keeps its first '
        'deletion time', () async {
      final added = await add('Tea');
      await repository.moveToBin(added.id);
      final first = (await repository.binned()).single.deletedAt;
      clock.advance(const Duration(days: 1));
      await expectLater(
        repository.moveToBin(added.id),
        throwsA(isA<ExpenseNotFound>()),
      );
      expect((await repository.binned()).single.deletedAt, first);
    });

    test(
      'a missing id throws ExpenseNotFound and keeps the draft row',
      () async {
        await putDraftRow();
        await expectLater(
          repository.moveToBin(12345, clearDraft: true),
          throwsA(isA<ExpenseNotFound>()),
        );
        expect(await draftRows(), 1);
      },
    );
  });

  test('drafts are invisible to every expense read (§6.5)', () async {
    await add('Real', amount: 100);
    await add('Real', amount: 100);
    final binned = await add('Binned');
    await repository.moveToBin(binned.id);
    await putDraftRow(title: 'ZZDRAFT');

    final page = await repository.page();
    expect(page.map((e) => e.title), isNot(contains('ZZDRAFT')));
    expect(page, hasLength(2));
    final history = await repository.titleHistory();
    expect(history.map((r) => r.title), ['Real']);
    expect(await repository.prefillSource(['ZZDRAFT']), isNull);
    expect(await repository.amountChipStats('INR'), [100]);
    expect((await repository.binned()).map((e) => e.title), ['Binned']);
    expect(await repository.recentCurrencies(), ['INR']);
    expect((await repository.categoryUsage())[1]!.recentCount, 2);
  });

  test('none of the new reads bump DataVersion', () async {
    await add('Tea');
    final start = version.value;
    await repository.titleHistory();
    await repository.prefillSource(['Tea']);
    await repository.amountChipStats('INR');
    expect(version.value, start);
  });
}
