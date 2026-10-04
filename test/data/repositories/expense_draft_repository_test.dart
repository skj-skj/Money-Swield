import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_draft_repository.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/fake_timers.dart';
import '../../helpers/test_database.dart';

ExpenseDraft draft(String title, {int? editing, int at = 1}) => ExpenseDraft(
  editingExpenseId: editing,
  title: title,
  amountExpression: '50+',
  description: '',
  categoryId: null,
  eventIds: const {},
  paymentMethodId: 1,
  currencyCode: 'INR',
  pickedWallClock: null,
  touched: const {DraftField.title},
  itemizeLine: null,
  itemizeLabels: const [],
  itemizeTerms: const [],
  updatedAt: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
);

void main() {
  late Database db;
  late FakeTimers timers;
  late ExpenseDraftRepository drafts;

  setUp(() async {
    db = await openMigratedDatabase();
    timers = FakeTimers();
    drafts = ExpenseDraftRepository(db, timer: timers.call);
  });

  Future<List<Map<String, Object?>>> rows() => db.query('expense_draft');

  Future<String?> rowTitle() async {
    final all = await rows();
    if (all.isEmpty) return null;
    return ExpenseDraft.fromJson(
      all.single['form_json']! as String,
      editingExpenseId: all.single['editing_expense_id'] as int?,
      updatedAt: DateTime.utc(2000),
    )!.title;
  }

  test('the debounce is 500 ms and three updates make one write', () async {
    drafts
      ..update(draft('a'))
      ..update(draft('ab'))
      ..update(draft('abc'));
    expect(timers.made.map((t) => t.duration).toSet(), {
      const Duration(milliseconds: 500),
    });
    expect(timers.active, hasLength(1), reason: 'each update restarts it');
    expect(await rows(), isEmpty, reason: 'nothing before the timer');

    timers.elapse();
    await drafts.settle();
    expect(await rowTitle(), 'abc');
  });

  test('memory is read at once, before the row is written', () async {
    drafts.update(draft('typed'));
    expect((await drafts.read())?.title, 'typed');
  });

  test('flush writes now', () async {
    drafts.update(draft('a'));
    await drafts.flush();
    expect(await rowTitle(), 'a');
    expect(timers.active, isEmpty, reason: 'the timer is cancelled');
  });

  test('flush with nothing due writes nothing', () async {
    await drafts.flush();
    expect(await rows(), isEmpty);
  });

  test('another expense\'s draft replaces the slot: one row, the new '
      'editing_expense_id', () async {
    drafts.update(draft('seven', editing: 7));
    await drafts.flush();
    drafts.update(draft('nine', editing: 9));
    await drafts.flush();

    final all = await rows();
    expect(all, hasLength(1));
    expect(all.single['id'], 1);
    expect(all.single['editing_expense_id'], 9);
    expect((await drafts.read())?.editingExpenseId, 9);
  });

  test(
    'clear with a pending timer: no row, and the timer does nothing',
    () async {
      drafts.update(draft('a'));
      await drafts.clear();
      timers.made.single.fire(); // Even if it fires anyway.
      await drafts.settle();
      expect(await rows(), isEmpty);
    },
  );

  test('clear while a write is in flight: no row', () async {
    drafts.update(draft('a'));
    timers.elapse(); // The write is queued and starts.
    final cleared = drafts.clear(); // Not awaited before.
    await cleared;
    await drafts.settle();
    expect(await rows(), isEmpty);
  });

  test('clear deletes a row written before', () async {
    drafts.update(draft('a'));
    await drafts.flush();
    await drafts.clear();
    expect(await rows(), isEmpty);
  });

  test('a write queued before forget() is dropped', () async {
    drafts.update(draft('a'));
    timers.elapse();
    drafts.forget();
    await drafts.settle();
    expect(await rows(), isEmpty);
  });

  test(
    'read after clear is null without SQL, even if the row came back',
    () async {
      drafts.update(draft('a'));
      await drafts.flush();
      await drafts.clear();
      // Someone else writes the row (e.g. a DELETE failed): memory wins.
      await db.insert('expense_draft', {
        'id': 1,
        'form_json': draft('zombie').toJson(),
        'updated_at': 1,
      });
      expect(await drafts.read(), isNull);
    },
  );

  test('a fresh repository on the same database reads the row (the app was '
      'killed)', () async {
    drafts.update(draft('kept', editing: 4, at: 1234));
    await drafts.flush();

    final restarted = ExpenseDraftRepository(db, timer: timers.call);
    final read = await restarted.read();
    expect(read, draft('kept', editing: 4, at: 1234));
  });

  test('the first read sees the row; a change while it runs wins', () async {
    await db.insert('expense_draft', {
      'id': 1,
      'form_json': draft('old').toJson(),
      'updated_at': 1,
    });
    final reading = drafts.read();
    drafts.update(draft('new'));
    expect((await reading)?.title, 'new');
  });

  test('a row other than id 1 is ignored', () async {
    await db.insert('expense_draft', {
      'id': 2,
      'form_json': draft('other').toJson(),
      'updated_at': 1,
    });
    expect(await drafts.read(), isNull);
  });

  group('a malformed row', () {
    for (final (name, json) in [
      ('not JSON', '{oops'),
      ('a newer version', '{"v": 2}'),
      ('an array', '[]'),
    ]) {
      test('($name) is deleted on the first read and reads as none', () async {
        await db.insert('expense_draft', {
          'id': 1,
          'form_json': json,
          'updated_at': 1,
        });
        expect(await drafts.read(), isNull);
        await drafts.settle();
        expect(await rows(), isEmpty);
      });
    }

    test('is left alone by probe', () async {
      await db.insert('expense_draft', {
        'id': 1,
        'form_json': '{oops',
        'updated_at': 1,
      });
      await ExpenseDraftRepository.probe(db);
      expect(await rows(), hasLength(1));
    });
  });

  test('probe fails when the table is missing', () async {
    await db.execute('DROP TABLE expense_draft');
    await expectLater(
      ExpenseDraftRepository.probe(db),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('a failing write stays due and flush retries it', () async {
    await db.execute('ALTER TABLE expense_draft RENAME TO expense_draft_away');
    drafts.update(draft('a'));
    await drafts.flush(); // Fails, logged.
    await db.execute('ALTER TABLE expense_draft_away RENAME TO expense_draft');

    await drafts.flush();
    expect(await rowTitle(), 'a');
  });

  test('read throws on an SQL error and can be retried', () async {
    await db.execute('ALTER TABLE expense_draft RENAME TO expense_draft_away');
    await expectLater(drafts.read(), throwsA(isA<DatabaseException>()));
    await db.execute('ALTER TABLE expense_draft_away RENAME TO expense_draft');
    expect(await drafts.read(), isNull);
  });

  test('close writes what is due, then refuses changes', () async {
    drafts.update(draft('a'));
    await drafts.close();
    expect(await rowTitle(), 'a');

    drafts.update(draft('after close'));
    await drafts.clear();
    await drafts.flush();
    expect(await rowTitle(), 'a', reason: 'nothing written or deleted');
  });

  test('drafts never bump DataVersion', () async {
    final deps = await openTestDependencies();
    final start = deps.dataVersion.value;
    final repo = ExpenseDraftRepository(deps.database, timer: timers.call);
    repo.update(draft('a'));
    await repo.flush();
    await repo.clear();
    expect(deps.dataVersion.value, start);
  });
}
