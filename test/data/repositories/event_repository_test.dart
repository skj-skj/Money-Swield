import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/event_repository.dart';
import 'package:my_expense_tracker_app/domain/models/event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;
  late TestClock clock;
  late EventRepository repository;

  setUp(() async {
    db = await openMigratedDatabase();
    clock = TestClock();
    repository = EventRepository(db, now: clock.call);
  });

  Future<Event> byId(int id) async =>
      (await repository.all()).singleWhere((e) => e.id == id);

  test('all returns the 5 seeded built-ins, none archived', () async {
    final events = await repository.all();
    expect(events.map((e) => e.builtinKey), [
      'birthday',
      'anniversary',
      'party',
      'festival',
      'trip',
    ]);
    expect(events.any((e) => e.isArchived), isFalse);
  });

  group('add', () {
    test('returns exactly what all() reads back', () async {
      final added = await repository.add(
        name: 'Goa 2026',
        description: 'With friends',
        emoji: '🏖️',
      );
      expect(added.archivedAt, isNull);
      expect(added.createdAt, clock.now);
      expect(await byId(added.id), added);
    });
  });

  group('update', () {
    test('saves the fields and moves updated_at only', () async {
      final added = await repository.add(name: 'Goa', emoji: '🏖️');
      clock.advance(const Duration(minutes: 1));

      final saved = await repository.update(
        added.copyWith(name: 'Goa trip', description: 'Beach'),
      );
      expect(saved.name, 'Goa trip');
      expect(saved.description, 'Beach');
      expect(saved.updatedAt, clock.now);
      expect(saved.createdAt, added.createdAt);
      expect(await byId(added.id), saved);
    });

    test('does not undo an archive made after the form was opened', () async {
      final added = await repository.add(name: 'Goa', emoji: '🏖️');
      final openedInForm = await byId(added.id); // not archived
      await repository.setArchived(added.id, true);

      final saved = await repository.update(openedInForm.copyWith(emoji: '🌴'));
      expect(
        saved.isArchived,
        isTrue,
        reason: 'the returned event reflects the database',
      );
      expect((await byId(added.id)).isArchived, isTrue);
    });

    test('does not unarchive by saving a model without archivedAt', () async {
      final added = await repository.add(name: 'Goa', emoji: '🏖️');
      await repository.setArchived(added.id, true);
      await repository.update(added); // added.archivedAt is null
      expect((await byId(added.id)).isArchived, isTrue);
    });

    test('throws when the event no longer exists', () async {
      final added = await repository.add(name: 'Goa', emoji: '🏖️');
      await repository.delete(added.id);
      expect(() => repository.update(added), throwsStateError);
    });
  });

  group('archive', () {
    test('sets archived_at and updated_at to now', () async {
      final trip = (await repository.all()).last;
      clock.advance(const Duration(days: 1));
      await repository.setArchived(trip.id, true);

      final archived = await byId(trip.id);
      expect(archived.archivedAt, clock.now);
      expect(archived.updatedAt, clock.now);
      expect(archived.isArchived, isTrue);
    });

    test('unarchiving clears archived_at', () async {
      final trip = (await repository.all()).last;
      await repository.setArchived(trip.id, true);
      clock.advance(const Duration(days: 1));
      await repository.setArchived(trip.id, false);

      final restored = await byId(trip.id);
      expect(restored.archivedAt, isNull);
      expect(restored.updatedAt, clock.now);
    });

    test('archiving twice keeps the first archive date', () async {
      final trip = (await repository.all()).last;
      await repository.setArchived(trip.id, true);
      final firstDate = (await byId(trip.id)).archivedAt;
      clock.advance(const Duration(days: 3));
      await repository.setArchived(trip.id, true);
      expect((await byId(trip.id)).archivedAt, firstDate);
    });

    test(
      'unarchiving an active event changes nothing, not even updated_at',
      () async {
        final trip = (await repository.all()).last;
        clock.advance(const Duration(days: 3));
        await repository.setArchived(trip.id, false);
        expect(await byId(trip.id), trip);
      },
    );

    test('archived events are still returned by all()', () async {
      final trip = (await repository.all()).last;
      await repository.setArchived(trip.id, true);
      expect(await repository.all(), hasLength(5));
    });
  });

  test('delete removes only that event, archived or not', () async {
    final events = await repository.all();
    await repository.setArchived(events.first.id, true);
    await repository.delete(events.first.id);
    await repository.delete(events.last.id);
    expect((await repository.all()).map((e) => e.builtinKey), [
      'anniversary',
      'party',
      'festival',
    ]);
  });
}
