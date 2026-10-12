import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/event_repository.dart';
import 'package:my_expense_tracker_app/domain/models/event.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/form_validation.dart';
import 'package:my_expense_tracker_app/ui/features/events/view_models/event_form_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/events/view_models/event_list_cubit.dart';

import '../../../../helpers/test_database.dart';

/// Validation itself is covered in depth by the category form tests (same
/// rules, shared code). These focus on what events add or do differently.
void main() {
  late EventRepository repository;
  late List<Event> existing;

  setUp(() async {
    repository = (await openTestDependencies()).events;
    existing = await repository.all();
  });

  EventFormCubit formFor({Event? original, AppLocalizations? l10n}) {
    final cubit = EventFormCubit(
      repository: repository,
      l10n: l10n ?? l10nFor('en'),
      original: original,
      existing: existing,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Event builtin(String key) => existing.firstWhere((e) => e.builtinKey == key);

  group('validation', () {
    test('a translated built-in event name is taken', () async {
      final cubit = formFor()
        ..nameChanged('TRIP')
        ..emojiChanged('🧳');
      expect(await cubit.save(), isNull);
      expect(cubit.nameError, NameError.duplicate);
    });

    test('an archived event still blocks its name', () async {
      final goa = await repository.add(name: 'Goa', emoji: '🏖️');
      await repository.setArchived(goa.id, true);
      existing = await repository.all();
      final cubit = formFor()
        ..nameChanged('goa')
        ..emojiChanged('🌴');
      expect(await cubit.save(), isNull);
      expect(cubit.nameError, NameError.duplicate);
    });

    test('a category name is not an event name', () async {
      // "Travel" is a built-in category, not an event.
      final cubit = formFor()
        ..nameChanged('Travel')
        ..emojiChanged('✈️');
      expect(await cubit.save(), isNotNull);
    });
  });

  group('save', () {
    test('a built-in saved with its localized name keeps NULL', () async {
      final cubit = formFor(original: builtin('trip'))
        ..descriptionChanged('Yearly');
      final saved = await cubit.save();
      expect(saved!.name, isNull);
      expect(saved.description, 'Yearly');
    });

    test('saving an archived event keeps it archived', () async {
      await repository.setArchived(builtin('trip').id, true);
      existing = await repository.all();
      final saved = await (formFor(
        original: builtin('trip'),
      )..emojiChanged('🚗')).save();
      expect(saved!.isArchived, isTrue);
    });
  });

  group('archive', () {
    test('archives an active event and unarchives an archived one', () async {
      final trip = builtin('trip');
      await formFor(original: trip).toggleArchived();
      existing = await repository.all();
      expect(builtin('trip').isArchived, isTrue);

      await formFor(original: builtin('trip')).toggleArchived();
      existing = await repository.all();
      expect(builtin('trip').isArchived, isFalse);
    });

    test('does not save unsaved edits', () async {
      final cubit = formFor(original: builtin('trip'))
        ..nameChanged('Road trip');
      await cubit.toggleArchived();
      existing = await repository.all();
      expect(builtin('trip').name, isNull);
    });

    test('does nothing on a new form', () async {
      await formFor().toggleArchived();
      expect((await repository.all()).any((e) => e.isArchived), isFalse);
    });
  });

  group('list', () {
    test('splits archived events into their own sorted section', () async {
      await repository.setArchived(builtin('trip').id, true);
      await repository.setArchived(builtin('birthday').id, true);
      final l10n = l10nFor('en');
      final cubit = EventListCubit(repository: repository, l10n: l10n);
      addTearDown(cubit.close);
      await cubit.load();

      final loaded = cubit.value as EventListLoaded;
      // Seven seeded events, sorted by English name.
      expect(loaded.active.map((e) => e.builtinKey), [
        'anniversary',
        'dining_out',
        'festival',
        'party',
        'wedding',
      ]);
      expect(loaded.archived.map((e) => e.builtinKey), ['birthday', 'trip']);
      expect(loaded.all, hasLength(7));
    });
  });

  group('initialName', () {
    EventFormCubit formWith({Event? original, required String name}) {
      final cubit = EventFormCubit(
        repository: repository,
        l10n: l10nFor('en'),
        original: original,
        existing: existing,
        initialName: name,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('prefills the name of a new event', () async {
      final cubit = formWith(name: 'chai')..emojiChanged('☕');
      expect(cubit.value.name, 'chai');
      expect((await cubit.save())!.name, 'chai');
    });

    test('is ignored when editing: the saved name wins', () {
      final trip = existing.firstWhere((e) => e.builtinKey == 'trip');
      expect(formWith(original: trip, name: 'chai').value.name, 'Trip');
    });
  });
}
