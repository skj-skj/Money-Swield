import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/app/restore_tools.dart';
import 'package:my_expense_tracker_app/app/startup_cubit.dart';
import 'package:my_expense_tracker_app/data/services/backup/pre_restore_copy.dart';
import 'package:my_expense_tracker_app/data/services/database/app_database.dart';
import 'package:my_expense_tracker_app/domain/models/app_settings.dart';
import 'package:my_expense_tracker_app/ui/features/settings/view_models/settings_cubit.dart';

import '../helpers/fake_document_service.dart';
import '../helpers/file_database.dart';
import '../helpers/test_database.dart';

/// The bin purge at startup (phase-2.md §9.3).
void main() {
  late AppDependencies deps;
  late TestClock clock;

  setUp(() async {
    clock = TestClock();
    deps = await openTestDependencies(clock: clock);
  });

  StartupCubit cubitFor(AppDependencies dependencies) {
    final settings = SettingsCubit(initial: AppSettings.beforeLoad);
    final cubit = StartupCubit(
      openDependencies: () async => dependencies,
      settingsCubit: settings,
    );
    addTearDown(() async {
      await cubit.close();
      await settings.close();
    });
    return cubit;
  }

  test(
    'empties expenses binned more than 30 days ago, keeps the rest',
    () async {
      final day = const Duration(days: 1).inMilliseconds;
      final now = clock.now.millisecondsSinceEpoch;
      final old = await insertExpenseRow(
        deps.database,
        deletedAt: now - 31 * day,
      );
      final recent = await insertExpenseRow(
        deps.database,
        deletedAt: now - 29 * day,
      );
      final active = await insertExpenseRow(deps.database);

      final cubit = cubitFor(deps);
      await cubit.start();

      expect(cubit.value, isA<StartupReady>());
      final ids = [
        for (final row in await deps.database.query('expenses')) row['id'],
      ];
      expect(ids, unorderedEquals([recent, active]));
      expect(ids, isNot(contains(old)));
    },
  );

  test('a failing purge does not block the app', () async {
    // Without the tables the purge throws, but the rest of startup works.
    await deps.database.execute('DROP TABLE expense_events');
    await deps.database.execute('DROP TABLE expenses');

    final cubit = cubitFor(deps);
    await cubit.start();
    expect(cubit.value, isA<StartupReady>());
  });

  group('recurring generator (phase-7a.md R13)', () {
    test(
      'runs before the bin purge, and its report reaches StartupReady',
      () async {
        // Due today (the clock is 2026-10-02): one payment to add.
        await insertRecurringRow(
          deps.database,
          startOn: '2026-09-02',
          nextDueOn: '2026-10-02',
        );
        final day = const Duration(days: 1).inMilliseconds;
        await insertExpenseRow(
          deps.database,
          deletedAt: clock.now.millisecondsSinceEpoch - 31 * day,
        );
        // Writes logged in order: the payment's insert, the purge's delete.
        await deps.database.execute('CREATE TEMP TABLE steps (step TEXT)');
        await deps.database.execute(
          'CREATE TEMP TRIGGER log_insert AFTER INSERT ON expenses '
          "BEGIN INSERT INTO steps VALUES ('generate'); END",
        );
        await deps.database.execute(
          'CREATE TEMP TRIGGER log_delete AFTER DELETE ON expenses '
          "BEGIN INSERT INTO steps VALUES ('purge'); END",
        );
        final cubit = cubitFor(deps);
        await cubit.start();
        final ready = cubit.value as StartupReady;
        expect(ready.recurring.added, 1);
        expect(
          [for (final r in await deps.database.query('steps')) r['step']],
          ['generate', 'purge'],
        );
      },
    );

    test('a failing generator does not block the app', () async {
      await deps.database.execute('PRAGMA foreign_keys = OFF');
      await deps.database.execute('DROP TABLE recurring_expenses');
      final cubit = cubitFor(deps);
      await cubit.start();
      final ready = cubit.value as StartupReady;
      expect(ready.recurring.added, 0);
    });

    test('a backlog older than 31 days is held, not added', () async {
      await insertRecurringRow(
        deps.database,
        startOn: '2026-07-02',
        nextDueOn: '2026-08-02',
      );
      final cubit = cubitFor(deps);
      await cubit.start();
      final ready = cubit.value as StartupReady;
      expect(ready.recurring.added, 0);
      expect(ready.recurring.held.single.count, 3);
    });
  });

  group('leftovers of a cut-short backup or restore', () {
    late FileDatabases files;
    late RestoreTools tools;

    setUp(() async {
      files = await FileDatabases.create();
      tools = RestoreTools(
        appDatabase: files.appDatabase(),
        documents: FakeDocumentService(),
        deviceCurrency: 'INR',
      );
    });

    Future<AppDependencies> fileDependencies({RestoreTools? with_}) async =>
        AppDependencies.forDatabase(
          await files.openLive(),
          deviceCurrency: 'INR',
          restoreTools: with_ ?? tools,
        );

    test('are deleted before the app is ready, and a candidate created '
        'right after StartupReady survives (the cleanup is awaited)', () async {
      final stale = File(files.paths.backupCopy);
      await stale.create(recursive: true);
      final deps = await fileDependencies();
      final cubit = cubitFor(deps);
      final candidate = File(files.paths.candidate);
      // Like a restore started from onboarding the moment it shows.
      cubit.state.subscribe((state) {
        if (state is StartupReady) {
          candidate.parent.createSync(recursive: true);
          candidate.writeAsStringSync('new candidate');
        }
      });

      await cubit.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(cubit.value, isA<StartupReady>());
      expect(stale.existsSync(), isFalse, reason: 'the cleanup ran');
      expect(candidate.existsSync(), isTrue);
    });

    test('a failing cleanup does not block startup', () async {
      final broken = RestoreTools(
        appDatabase: AppDatabase(
          databaseFactory: files.factory,
          databasePath: () async => files.livePath,
          cacheFolder: () async => throw const FileSystemException('no cache'),
        ),
        documents: FakeDocumentService(),
        deviceCurrency: 'INR',
      );
      final cubit = cubitFor(await fileDependencies(with_: broken));
      await cubit.start();
      expect(cubit.value, isA<StartupReady>());
    });
  });

  group("when settings can't be read", () {
    test(
      'the opened connection is closed, so Retry and Undo start clean',
      () async {
        final empty = await openEmptyDatabase();
        final cubit = cubitFor(
          AppDependencies.forDatabase(empty, deviceCurrency: 'INR'),
        );
        await cubit.start();
        expect(cubit.value, isA<StartupFailed>());
        expect(empty.isOpen, isFalse);
      },
    );

    test('the newest pre-restore copy is offered for Undo', () async {
      final copy = PreRestoreCopy(
        path: 'pre-restore-000002-2026-10-03T08-50-00Z.db',
        sequence: 2,
        createdAt: DateTime.utc(2026, 10, 3, 8, 50),
      );
      final settings = SettingsCubit(initial: AppSettings.beforeLoad);
      addTearDown(settings.close);
      final cubit = StartupCubit(
        openDependencies: () async => throw StateError('settings unreadable'),
        settingsCubit: settings,
        newestPreRestoreCopy: () async => copy,
      );
      addTearDown(cubit.close);
      await cubit.start();
      expect((cubit.value as StartupFailed).undoCopy, same(copy));
    });

    test('no Undo when looking for copies fails', () async {
      final settings = SettingsCubit(initial: AppSettings.beforeLoad);
      addTearDown(settings.close);
      final cubit = StartupCubit(
        openDependencies: () async => throw StateError('broken'),
        settingsCubit: settings,
        newestPreRestoreCopy: () async => throw StateError('no folder'),
      );
      addTearDown(cubit.close);
      await cubit.start();
      expect((cubit.value as StartupFailed).undoCopy, isNull);
    });
  });
}
