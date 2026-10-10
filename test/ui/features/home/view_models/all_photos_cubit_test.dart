import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_repository.dart';
import 'package:my_expense_tracker_app/data/services/photo_store.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/ui/features/home/view_models/all_photos_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/home/view_models/expense_list_cubit.dart';
import 'package:path/path.dart' as p;

import '../../../../helpers/fake_photo_service.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/test_folders.dart';

/// The Photos screen's cubit and Home's icon (phase-6.md §7.4).
void main() {
  late AppDependencies deps;
  late FakePhotoService service;
  late PhotoStore store;

  setUp(() async {
    final root = await testFolder('all_photos');
    service = FakePhotoService();
    store = PhotoStore(root: root.path, service: service);
    deps = await openTestDependencies(photos: store);
  });

  var next = 0;

  /// An expense on [day] with one new photo per letter (its SHA-256 the
  /// letter 64 times; [shas] for longer lists); files written.
  Future<Expense> add(
    String title,
    String day,
    String letters, {
    int categoryId = 1,
    List<String>? shas,
  }) async {
    final hashes =
        shas ??
        [
          for (final l in letters.split(''))
            if (l.isNotEmpty) l * 64,
        ];
    for (final sha in hashes) {
      final file = File(p.join(store.root, 'photos', '$sha.jpg'));
      await file.parent.create(recursive: true);
      await file.writeAsString(sha);
    }
    final date = DateTime.parse(day);
    return deps.expenses.add(
      ExpenseInput(
        title: title,
        description: null,
        amount: const Money(100, 'INR'),
        occurredAt: DateTime.utc(date.year, date.month, date.day, 8, next++),
        utcOffsetMinutes: 330,
        categoryId: categoryId,
        paymentMethodId: 1,
        eventIds: const {},
        photos: [
          for (final sha in hashes)
            LinkNewPhoto(
              relativePath: 'photos/$sha.jpg',
              sha256: sha,
              byteSize: 1,
            ),
        ],
      ),
    );
  }

  Future<AllPhotosCubit> open({
    ExpenseFilter filter = ExpenseFilter.none,
    int pageSize = 30,
  }) async {
    final cubit = AllPhotosCubit(
      expenses: deps.expenses,
      drafts: deps.drafts,
      dataVersion: deps.dataVersion,
      store: store,
      filter: filter,
      fallbackTitle: 'Expense',
      pageSize: pageSize,
    );
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  AllPhotosLoaded loaded(AllPhotosCubit c) => c.value as AllPhotosLoaded;
  List<String> letters(AllPhotosCubit c) => [
    for (final t in loaded(c).tiles) t.photo.sha256[0],
  ];

  test('months and days in Home\'s order; binned and photo-less expenses '
      'left out', () async {
    await add('Rent', '2026-10-04', 'd');
    await add('Lunch', '2026-10-05', 'ab');
    await add('Taxi', '2026-10-05', 'c');
    await add('Old', '2026-09-30', 'e');
    await add('No photo', '2026-10-05', '');
    final binned = await add('Binned', '2026-10-05', 'f');
    await deps.expenses.moveToBin(binned.id);
    final c = await open();
    final months = loaded(c).months;
    expect(
      [for (final m in months) m.range.from],
      ['2026-10-01', '2026-09-01'],
    );
    expect(
      [for (final d in months.first.days) d.day],
      ['2026-10-05', '2026-10-04'],
    );
    expect(letters(c), ['c', 'a', 'b', 'd', 'e']);
  });

  test('a Food filter, a text filter; an edit that stops a match is gone '
      'after reloadIfChanged', () async {
    await add('Lunch', '2026-10-05', 'a', categoryId: 1);
    final taxi = await add('Taxi', '2026-10-05', 'b', categoryId: 2);
    final food = await open(filter: const ExpenseFilter(categoryIds: {1}));
    expect(letters(food), ['a']);
    final text = await open(filter: const ExpenseFilter(text: 'TAX'));
    expect(letters(text), ['b']);
    await deps.expenses.update(
      taxi.id,
      ExpenseInput(
        title: 'Bus',
        description: null,
        amount: const Money(100, 'INR'),
        occurredAt: taxi.occurredAt,
        utcOffsetMinutes: 330,
        categoryId: 2,
        paymentMethodId: 1,
        eventIds: const {},
        photos: [
          LinkSavedPhoto((await deps.expenses.photosOf(taxi.id)).single.id),
        ],
      ),
    );
    expect(await text.reloadIfChanged(), isTrue);
    expect(loaded(text).rows, isEmpty);
    expect(await text.reloadIfChanged(), isFalse, reason: 'nothing new');
  });

  test('paging: 70 expenses in pages of 30 into the open month, no gap or '
      'repeat; the text path pages too', () async {
    for (var i = 0; i < 70; i++) {
      await add(
        'E$i',
        '2026-10-${(1 + i % 28).toString().padLeft(2, '0')}',
        '',
        shas: [i.toRadixString(16).padLeft(64, '0')],
      );
    }
    for (final filter in [ExpenseFilter.none, const ExpenseFilter(text: 'e')]) {
      final c = await open(filter: filter);
      expect(loaded(c).rows, hasLength(30));
      expect(loaded(c).months.last.open, isTrue);
      await c.loadMore();
      await c.loadMore();
      expect(loaded(c).hasMore, isFalse);
      final ids = [for (final r in loaded(c).rows) r.expense.id];
      expect(ids, hasLength(70));
      expect(ids.toSet(), hasLength(70));
      expect(loaded(c).months.single.open, isFalse);
    }
  });

  test('a second loadMore while one runs is ignored', () async {
    for (var i = 0; i < 40; i++) {
      await add(
        'E$i',
        '2026-10-05',
        '',
        shas: [i.toRadixString(16).padLeft(64, '0')],
      );
    }
    final c = await open();
    await Future.wait([c.loadMore(), c.loadMore()]);
    expect(loaded(c).rows, hasLength(40));
  });

  test('selection: long press, toggle, select all (the loaded tiles), '
      'unselect the last ends it', () async {
    final lunch = await add('Lunch', '2026-10-05', 'ab');
    final c = await open();
    final [a, b] = await deps.expenses.photosOf(lunch.id);
    c.startSelection((expenseId: lunch.id, photoId: a.id));
    c.toggleSelected((expenseId: lunch.id, photoId: b.id));
    expect(loaded(c).selection, hasLength(2));
    c.toggleSelected((expenseId: lunch.id, photoId: a.id));
    c.toggleSelected((expenseId: lunch.id, photoId: b.id));
    expect(loaded(c).selection, isNull);
    c.startSelection((expenseId: lunch.id, photoId: a.id));
    c.selectAll();
    expect(loaded(c).selection, hasLength(2));
  });

  test('Save across two expenses: two names from two titles, dated on '
      'each', () async {
    final lunch = await add('Lunch', '2026-10-05', 'a');
    final taxi = await add('Taxi', '2026-10-04', 'c');
    final c = await open();
    c
      ..startSelection((
        expenseId: lunch.id,
        photoId: (await deps.expenses.photosOf(lunch.id)).single.id,
      ))
      ..toggleSelected((
        expenseId: taxi.id,
        photoId: (await deps.expenses.photosOf(taxi.id)).single.id,
      ));
    final result = await c.saveSelectedToPictures();
    expect(result!.saved, 2);
    expect(service.savedPictures.map((s) => s.name), [
      'Lunch 2026-10-05.jpg',
      'Taxi 2026-10-04.jpg',
    ]);
    expect(loaded(c).selection, hasLength(2), reason: 'selection stays');
  });

  test('Delete: two of Taxi and one of Lunch in one transaction; Taxi\'s '
      'last photo renumbered 0; DataVersion once; Taxi\'s Edit draft loses '
      'them; an expense binned meanwhile is skipped; selection ends', () async {
    final taxi = await add('Taxi', '2026-10-05', 'abc');
    final lunch = await add('Lunch', '2026-10-05', 'de');
    final rent = await add('Rent', '2026-10-04', 'f');
    final [a, b, c3] = await deps.expenses.photosOf(taxi.id);
    final [d, _] = await deps.expenses.photosOf(lunch.id);
    final [f] = await deps.expenses.photosOf(rent.id);
    deps.drafts.update(
      ExpenseDraft(
        editingExpenseId: taxi.id,
        title: 'Taxi edited',
        amountExpression: '1',
        description: '',
        categoryId: 1,
        eventIds: const {},
        paymentMethodId: 1,
        currencyCode: 'INR',
        pickedWallClock: null,
        touched: const {},
        itemizeLine: null,
        itemizeLabels: const [],
        itemizeTerms: const [],
        updatedAt: DateTime.utc(2026),
        photos: [a, b, c3],
      ),
    );
    final cubit = await open();
    cubit
      ..startSelection((expenseId: taxi.id, photoId: a.id))
      ..toggleSelected((expenseId: taxi.id, photoId: b.id))
      ..toggleSelected((expenseId: lunch.id, photoId: d.id))
      ..toggleSelected((expenseId: rent.id, photoId: f.id));
    await deps.expenses.moveToBin(rent.id);
    final before = deps.dataVersion.value;
    final removed = await cubit.deleteSelected();
    expect(removed, 3);
    expect(deps.dataVersion.value, before + 1);
    final taxiPhotos = await deps.expenses.photosOf(taxi.id);
    expect(taxiPhotos, [c3]);
    expect((await deps.drafts.read())!.photos, [c3]);
    expect(loaded(cubit).selection, isNull);
    expect([
      for (final r in loaded(cubit).rows) r.expense.id,
    ], [lunch.id, taxi.id].reversed.toList()..sort((x, y) => y.compareTo(x)));
    expect(await deps.expenses.photosOf(rent.id), [f], reason: 'binned: kept');
  });

  test('the Edit draft of an expense binned meanwhile keeps its photos: '
      'the expense kept them (regression: the draft lost them)', () async {
    final rent = await add('Rent', '2026-10-04', 'f');
    final [f] = await deps.expenses.photosOf(rent.id);
    final draft = ExpenseDraft(
      editingExpenseId: rent.id,
      title: 'Rent edited',
      amountExpression: '1',
      description: '',
      categoryId: 1,
      eventIds: const {},
      paymentMethodId: 1,
      currencyCode: 'INR',
      pickedWallClock: null,
      touched: const {},
      itemizeLine: null,
      itemizeLabels: const [],
      itemizeTerms: const [],
      updatedAt: DateTime.utc(2026),
      photos: [f],
    );
    deps.drafts.update(draft);
    final cubit = await open();
    cubit.startSelection((expenseId: rent.id, photoId: f.id));
    await deps.expenses.moveToBin(rent.id);
    expect(await cubit.deleteSelected(), 0);
    expect((await deps.drafts.read())!.photos, [f]);
  });

  test('an Add draft keeps its photos through a Delete', () async {
    final taxi = await add('Taxi', '2026-10-05', 'a');
    final [a] = await deps.expenses.photosOf(taxi.id);
    final draft = ExpenseDraft(
      editingExpenseId: null,
      title: 'New',
      amountExpression: '',
      description: '',
      categoryId: null,
      eventIds: const {},
      paymentMethodId: 1,
      currencyCode: 'INR',
      pickedWallClock: null,
      touched: const {},
      itemizeLine: null,
      itemizeLabels: const [],
      itemizeTerms: const [],
      updatedAt: DateTime.utc(2026),
      photos: [a],
    );
    deps.drafts.update(draft);
    final cubit = await open();
    cubit.startSelection((expenseId: taxi.id, photoId: a.id));
    await cubit.deleteSelected();
    expect(await deps.drafts.read(), draft);
  });

  test('a reload drops selected tiles that are gone', () async {
    final taxi = await add('Taxi', '2026-10-05', 'ab');
    final [a, b] = await deps.expenses.photosOf(taxi.id);
    final cubit = await open();
    cubit
      ..startSelection((expenseId: taxi.id, photoId: a.id))
      ..toggleSelected((expenseId: taxi.id, photoId: b.id));
    await deps.expenses.removePhotoLinks([(expenseId: taxi.id, photoId: a.id)]);
    await cubit.reloadIfChanged();
    expect(loaded(cubit).selection, {(expenseId: taxi.id, photoId: b.id)});
  });

  test('restore (the bin Undo) brings the expense back', () async {
    final taxi = await add('Taxi', '2026-10-05', 'a');
    final cubit = await open();
    await deps.expenses.moveToBin(taxi.id);
    await cubit.reload();
    expect(loaded(cubit).rows, isEmpty);
    await cubit.restore(taxi.id);
    expect(loaded(cubit).rows, hasLength(1));
  });

  group('Home\'s photos icon (ExpenseListCubit)', () {
    Future<ExpenseListCubit> list() async {
      final cubit = ExpenseListCubit(
        expenses: deps.expenses,
        categories: deps.categories,
        paymentMethods: deps.paymentMethods,
        events: deps.events,
        drafts: deps.drafts,
        dataVersion: deps.dataVersion,
        defaultCurrency: 'INR',
      );
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    FilteredScreenIcon icon(ExpenseListCubit c) =>
        (c.value as ExpenseListLoaded).photosIcon;

    test('none → hidden; photos → enabled; a filter hiding them all → '
        'disabled; a text filter; cleared → enabled', () async {
      await add('No photo', '2026-10-05', '');
      final c = await list();
      expect(icon(c), FilteredScreenIcon.hidden);
      await add('Lunch', '2026-10-05', 'a', categoryId: 1);
      await c.reload();
      expect(icon(c), FilteredScreenIcon.enabled);
      await c.setFilter(const ExpenseFilter(categoryIds: {2}));
      expect(icon(c), FilteredScreenIcon.disabled);
      await c.setFilter(const ExpenseFilter(text: 'photo'));
      expect(icon(c), FilteredScreenIcon.disabled, reason: 'matches, no photo');
      await c.setFilter(const ExpenseFilter(text: 'lun'));
      expect(icon(c), FilteredScreenIcon.enabled);
      await c.setFilter(ExpenseFilter.none);
      expect(icon(c), FilteredScreenIcon.enabled);
    });

    test('only a binned expense has photos → hidden', () async {
      final e = await add('Lunch', '2026-10-05', 'a');
      await deps.expenses.moveToBin(e.id);
      await add('Other', '2026-10-05', '');
      expect(icon(await list()), FilteredScreenIcon.hidden);
    });

    test('a failing read hides the icon; the list loads', () async {
      await add('Lunch', '2026-10-05', 'a');
      final cubit = ExpenseListCubit(
        expenses: _NoPhotoChecks(deps),
        categories: deps.categories,
        paymentMethods: deps.paymentMethods,
        events: deps.events,
        drafts: deps.drafts,
        dataVersion: deps.dataVersion,
        defaultCurrency: 'INR',
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.value, isA<ExpenseListLoaded>());
      expect(icon(cubit), FilteredScreenIcon.hidden);
    });
  });
}

/// A repository whose photo checks fail.
class _NoPhotoChecks extends ExpenseRepository {
  _NoPhotoChecks(AppDependencies deps)
    : super(deps.database, dataVersion: deps.dataVersion);

  @override
  Future<bool> hasPhotos() async => throw StateError('disk I/O error');
}
