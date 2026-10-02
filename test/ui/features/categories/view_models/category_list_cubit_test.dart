import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/category_repository.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/builtin_names.dart';
import 'package:my_expense_tracker_app/ui/features/categories/view_models/category_list_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late Database db;
  late CategoryRepository repository;

  setUp(() async {
    db = await openMigratedDatabase();
    repository = CategoryRepository(db);
  });

  CategoryListCubit cubitFor(AppLocalizations l10n) {
    final cubit = CategoryListCubit(repository: repository, l10n: l10n);
    addTearDown(cubit.close);
    return cubit;
  }

  List<String> namesOf(CategoryListCubit cubit, AppLocalizations l10n) => [
    for (final c in (cubit.value as CategoryListLoaded).categories)
      categoryName(l10n, c),
  ];

  test('starts loading, then shows every category', () async {
    final cubit = cubitFor(l10nFor('en'));
    expect(cubit.value, isA<CategoryListLoading>());
    await cubit.load();
    expect((cubit.value as CategoryListLoaded).categories, hasLength(20));
  });

  test(
    'sorts by display name in the current language, ignoring case',
    () async {
      await repository.add(name: 'apples', emoji: '🍎');
      await repository.add(name: 'Zoo', emoji: '🦁');

      for (final code in ['en', 'es', 'hi']) {
        final l10n = l10nFor(code);
        final cubit = cubitFor(l10n);
        await cubit.load();
        final names = namesOf(cubit, l10n);
        final sorted = [...names]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        expect(names, sorted, reason: code);
      }
    },
  );

  test('a renamed built-in is sorted by its new name', () async {
    final food = (await repository.all()).firstWhere(
      (c) => c.builtinKey == 'food',
    );
    await repository.update(food.copyWith(name: 'Zzz food'));
    final l10n = l10nFor('en');
    final cubit = cubitFor(l10n);
    await cubit.load();
    expect(namesOf(cubit, l10n).last, 'Zzz food');
  });

  test('same names keep a stable order by id', () async {
    final first = await repository.add(name: 'Same', emoji: '1️⃣');
    final second = await repository.add(name: 'same', emoji: '2️⃣');
    final cubit = cubitFor(l10nFor('en'));
    await cubit.load();
    final ids = [
      for (final c in (cubit.value as CategoryListLoaded).categories) c.id,
    ];
    expect(ids.indexOf(first.id), lessThan(ids.indexOf(second.id)));
  });

  test('a reload shows changes without going back to loading', () async {
    final cubit = cubitFor(l10nFor('en'));
    await cubit.load();
    await repository.add(name: 'Pets', emoji: '🐶');

    final reload = cubit.load();
    expect(
      cubit.value,
      isA<CategoryListLoaded>(),
      reason: 'old list stays while reloading',
    );
    await reload;
    expect((cubit.value as CategoryListLoaded).categories, hasLength(21));
  });

  test('a failing read shows the failure, and a retry can succeed', () async {
    await db.execute('ALTER TABLE categories RENAME TO categories_gone');
    final cubit = cubitFor(l10nFor('en'));
    await cubit.load();
    expect(cubit.value, isA<CategoryListFailed>());

    await db.execute('ALTER TABLE categories_gone RENAME TO categories');
    await cubit.load();
    expect(cubit.value, isA<CategoryListLoaded>());
  });

  test('closing while loading does not throw', () async {
    final cubit = cubitFor(l10nFor('en'));
    final loading = cubit.load();
    await cubit.close();
    await loading;
  });
}
