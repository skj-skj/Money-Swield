import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/category_repository.dart';
import 'package:my_expense_tracker_app/domain/models/category.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/form_validation.dart';
import 'package:my_expense_tracker_app/ui/features/categories/view_models/category_form_cubit.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late CategoryRepository repository;
  late List<Category> existing;

  setUp(() async {
    final deps = await openTestDependencies();
    repository = deps.categories;
    existing = await repository.all();
  });

  CategoryFormCubit formFor({Category? original, AppLocalizations? l10n}) {
    final cubit = CategoryFormCubit(
      repository: repository,
      l10n: l10n ?? l10nFor('en'),
      original: original,
      existing: existing,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Category builtin(String key) =>
      existing.firstWhere((c) => c.builtinKey == key);

  /// Fills a valid new category, then applies [change].
  CategoryFormCubit validForm({
    String name = 'Pets',
    String emoji = '🐶',
    String description = '',
  }) => formFor()
    ..nameChanged(name)
    ..emojiChanged(emoji)
    ..descriptionChanged(description);

  group('initial state', () {
    test('a new form is empty and shows no errors yet', () {
      final cubit = formFor();
      expect(cubit.value.name, '');
      expect(cubit.value.emoji, '');
      expect(cubit.nameError, isNull);
      expect(cubit.emojiError, isNull);
      expect(cubit.isEditing, isFalse);
    });

    test('editing a built-in prefills its localized name', () {
      expect(formFor(original: builtin('food')).value.name, 'Food');
      expect(
        formFor(original: builtin('food'), l10n: l10nFor('hi')).value.name,
        'खाना',
      );
    });
  });

  group('validation', () {
    Future<void> expectNameError(
      String name,
      NameError error, {
      AppLocalizations? l10n,
    }) async {
      final cubit = formFor(l10n: l10n)
        ..nameChanged(name)
        ..emojiChanged('🐶');
      expect(await cubit.save(), isNull, reason: '"$name" must not save');
      expect(cubit.nameError, error, reason: '"$name"');
    }

    test(
      'nothing is saved and errors are shown when fields are empty',
      () async {
        final cubit = formFor();
        expect(await cubit.save(), isNull);
        expect(cubit.nameError, NameError.required);
        expect(cubit.emojiError, EmojiError.required);
        expect(await repository.all(), hasLength(20));
      },
    );

    test(
      'a name of only spaces is empty',
      () => expectNameError('   ', NameError.required),
    );

    test('a name over 40 characters is too long; exactly 40 is fine', () async {
      await expectNameError('a' * 41, NameError.tooLong);
      final cubit = validForm(name: 'a' * 40);
      expect(await cubit.save(), isNotNull);
    });

    test('length counts what the user sees, not UTF-16 units', () async {
      // 40 emoji are 40 characters on screen but 80+ UTF-16 code units.
      final cubit = validForm(name: '🍕' * 40);
      expect(await cubit.save(), isNotNull);
    });

    test('surrounding spaces do not count toward the length', () async {
      final cubit = validForm(name: '  ${'a' * 40}  ');
      expect((await cubit.save())!.name, 'a' * 40);
    });

    test('a duplicate in a different case is refused', () async {
      await repository.add(name: 'Pets', emoji: '🐶');
      existing = await repository.all();
      await expectNameError('pETS', NameError.duplicate);
    });

    test(
      'a duplicate of a built-in in the current language is refused',
      () async {
        await expectNameError('food', NameError.duplicate);
        await expectNameError('  FOOD ', NameError.duplicate);
        await expectNameError(
          'comida',
          NameError.duplicate,
          l10n: l10nFor('es'),
        );
        await expectNameError('खाना', NameError.duplicate, l10n: l10nFor('hi'));
      },
    );

    test('a built-in name from another language is not a duplicate', () async {
      // "Comida" is only taken while the app is in Spanish.
      final cubit = validForm(name: 'Comida');
      expect(await cubit.save(), isNotNull);
    });

    test('a renamed built-in no longer blocks its old name, but blocks its new one', () async {
      final food = builtin('food');
      await repository.update(food.copyWith(name: 'Khana'));
      existing = await repository.all();

      await expectNameError('khana', NameError.duplicate);
      expect(await validForm(name: 'Food').save(), isNotNull);
    });

    test('an emoji must be exactly one grapheme', () async {
      for (final (emoji, error) in [
        ('🍕🍔', EmojiError.notSingle),
        ('ab', EmojiError.notSingle),
        ('  ', EmojiError.required),
        ('', EmojiError.required),
      ]) {
        final cubit = validForm(emoji: emoji);
        expect(await cubit.save(), isNull, reason: '"$emoji"');
        expect(cubit.emojiError, error, reason: '"$emoji"');
      }
    });

    test('a multi-code-point emoji counts as one', () async {
      for (final emoji in ['👨‍👩‍👧', '🇮🇳', '👍🏽', '❤️', '🍽️']) {
        expect(
          await validForm(name: 'Test $emoji', emoji: emoji).save(),
          isNotNull,
          reason: emoji,
        );
      }
    });

    test('a description over 200 characters is refused; 200 is fine', () async {
      final tooLong = validForm(description: 'x' * 201);
      expect(await tooLong.save(), isNull);
      expect(tooLong.descriptionError, DescriptionError.tooLong);

      expect(
        await validForm(name: 'Other pets', description: 'x' * 200).save(),
        isNotNull,
      );
    });

    test('errors update as the user types once they are shown', () async {
      final cubit = formFor();
      await cubit.save();
      expect(cubit.nameError, NameError.required);

      cubit.nameChanged('Pets');
      expect(cubit.nameError, isNull);
      expect(
        cubit.emojiError,
        EmojiError.required,
        reason: 'other errors stay',
      );
    });
  });

  group('save', () {
    test(
      'adds a trimmed category, storing an empty description as NULL',
      () async {
        final saved = await validForm(
          name: '  Pets ',
          emoji: ' 🐶 ',
          description: '   ',
        ).save();

        expect(saved!.name, 'Pets');
        expect(saved.emoji, '🐶');
        expect(saved.description, isNull);
        expect(await repository.all(), contains(saved));
      },
    );

    test('editing a user category keeps its own name unchanged', () async {
      final pets = await repository.add(name: 'Pets', emoji: '🐶');
      existing = await repository.all();
      final cubit = formFor(original: pets)..emojiChanged('🐱');

      final saved = await cubit.save();
      expect(saved!.name, 'Pets');
      expect(saved.emoji, '🐱');
    });

    test('editing yourself is not a duplicate of yourself', () async {
      final cubit = formFor(original: builtin('food'))..emojiChanged('🍕');
      expect(await cubit.save(), isNotNull);
    });

    test('a built-in saved with its localized name keeps NULL, so it follows the language', () async {
      final cubit = formFor(original: builtin('food'))..emojiChanged('🍕');
      final saved = await cubit.save();
      expect(saved!.name, isNull);
      expect(saved.emoji, '🍕');
    });

    test(
      'a built-in saved in Hindi with its Hindi name also keeps NULL',
      () async {
        final cubit = formFor(original: builtin('food'), l10n: l10nFor('hi'))
          ..descriptionChanged('रोज़');
        expect((await cubit.save())!.name, isNull);
      },
    );

    test('renaming a built-in stores the new name', () async {
      final cubit = formFor(original: builtin('food'))..nameChanged('Khana');
      expect((await cubit.save())!.name, 'Khana');
    });

    test('a different case of the localized name is a rename', () async {
      final cubit = formFor(original: builtin('food'))..nameChanged('food');
      expect((await cubit.save())!.name, 'food');
    });

    test(
      'reset to default name puts the localized name back and saves NULL',
      () async {
        final khana = await repository.update(
          builtin('food').copyWith(name: 'Khana'),
        );
        existing = await repository.all();
        final cubit = formFor(original: khana);
        expect(cubit.value.name, 'Khana');
        expect(cubit.canResetName, isTrue);

        cubit.resetName();
        expect(cubit.value.name, 'Food');
        expect(cubit.canResetName, isFalse);
        expect((await cubit.save())!.name, isNull);
      },
    );

    test('reset is never offered for a user category', () async {
      final pets = await repository.add(name: 'Pets', emoji: '🐶');
      final cubit = formFor(original: pets);
      expect(cubit.canResetName, isFalse);
      cubit.resetName();
      expect(cubit.value.name, 'Pets');
    });

    test('a second save while the first is running is ignored', () async {
      final cubit = validForm();
      final first = cubit.save();
      final second = cubit.save();
      expect(await second, isNull);
      expect(await first, isNotNull);
      expect(
        (await repository.all()).where((c) => c.name == 'Pets'),
        hasLength(1),
      );
    });

    test('a database error reaches the caller and re-enables saving', () async {
      final pets = await repository.add(name: 'Pets', emoji: '🐶');
      await repository.delete(
        pets.id,
      ); // Deleted meanwhile, e.g. in another screen.
      final cubit = formFor(original: pets)..emojiChanged('🐱');

      await expectLater(cubit.save(), throwsStateError);
      expect(cubit.value.saving, isFalse);
    });

    test('closing the form while saving does not throw', () async {
      final cubit = validForm();
      final saving = cubit.save();
      await cubit.close();
      expect(await saving, isNotNull);
    });
  });

  group('delete', () {
    test('deletes the edited category', () async {
      final food = builtin('food');
      await formFor(original: food).delete();
      expect((await repository.all()).any((c) => c.id == food.id), isFalse);
    });

    test('does nothing on a new form', () async {
      await formFor().delete();
      expect(await repository.all(), hasLength(20));
    });
  });
}
