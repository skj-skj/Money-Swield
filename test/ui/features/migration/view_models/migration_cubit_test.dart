import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;
import 'package:money_swield/data/services/database/app_database.dart';
import 'package:money_swield/data/services/database/migration/migration_runner.dart';
import 'package:money_swield/ui/features/migration/view_models/migration_cubit.dart';
import 'package:path/path.dart' as p;

import '../../../../data/services/database/migration/test_helpers.dart';
import '../../../../helpers/fake_app_database.dart';
import '../../../../helpers/test_folders.dart';

void main() {
  const progress = MigrationProgress(
    stage: MigrationStage.migrating,
    completed: 1,
    total: 3,
  );

  test(
    'a question keeps the progress and returns to it once answered',
    () async {
      final asked = Completer<void>();
      final answered = Completer<String>();
      final cubit = cubitFor(
        FakeAppDatabase((prompter, onProgress) async {
          onProgress(progress);
          final answer = prompter.askText('Name?');
          asked.complete();
          answered.complete(await answer);
        }),
      );

      final run = cubit.run();
      await asked.future;
      final asking = cubit.value as MigrationAsking;
      expect(asking.question.text, 'Name?');
      expect(asking.progress, same(progress));

      cubit.answer('Sam');
      expect((cubit.value as MigrationInProgress).progress, same(progress));
      expect(await answered.future, 'Sam');

      await run;
      expect(cubit.value, isA<MigrationDone>());
    },
  );

  test('run is ignored while running and after it is done', () async {
    var attempts = 0;
    final release = Completer<void>();
    final cubit = cubitFor(
      FakeAppDatabase((prompter, onProgress) async {
        attempts++;
        await release.future;
      }),
    );

    final first = cubit.run();
    await cubit.run();
    release.complete();
    await first;
    await cubit.run();

    expect(attempts, 1);
    expect(cubit.value, isA<MigrationDone>());
  });

  test(
    'an unexpected error becomes a failure, and a retry can succeed',
    () async {
      var attempts = 0;
      final cubit = cubitFor(
        FakeAppDatabase((prompter, onProgress) async {
          if (++attempts == 1) throw StateError('disk full');
        }),
      );

      await cubit.run();
      final failed = cubit.value as MigrationFailed;
      expect(failed.failure.step, 'Starting database');
      expect(failed.failure.error, isA<StateError>());

      await cubit.run();
      expect(cubit.value, isA<MigrationDone>());
    },
  );

  test('answer is ignored when no question is waiting', () async {
    final cubit = cubitFor(
      FakeAppDatabase((prompter, onProgress) async => onProgress(progress)),
    );
    final before = cubit.value;

    cubit.answer('Sam');
    expect(cubit.value, same(before));

    await cubit.run();
    cubit.answer('Sam');
    expect(cubit.value, isA<MigrationDone>());
  });

  test('a migration failure is shown as it was thrown', () async {
    final failure = MigrationFailure(
      step: 'Running 1_add_currency',
      error: StateError('bad row'),
      stackTrace: StackTrace.current,
    );
    final cubit = cubitFor(
      FakeAppDatabase((prompter, onProgress) async => throw failure),
    );

    await cubit.run();

    expect((cubit.value as MigrationFailed).failure, same(failure));
  });

  test(
    'a retry can ask again after a run failed with a question unanswered',
    () async {
      var attempts = 0;
      final cubit = cubitFor(
        FakeAppDatabase((prompter, onProgress) async {
          // The first attempt fails without waiting for its answer.
          if (++attempts == 1) {
            unawaited(prompter.askText('Name?'));
            throw StateError('disk full');
          }
          await prompter.askText('Name?');
        }),
      );

      await cubit.run();
      expect(cubit.value, isA<MigrationFailed>());

      final retry = cubit.run();
      expect((cubit.value as MigrationAsking).question.text, 'Name?');
      cubit.answer('Sam');
      await retry;
      expect(cubit.value, isA<MigrationDone>());
    },
  );

  group('when it is done', () {
    test('nothing pending opens the app at once', () async {
      final cubit = cubitFor(FakeAppDatabase((prompter, onProgress) async {}));
      await cubit.run();
      expect(cubit.value, isA<MigrationDone>());
    });

    for (final outcome in [
      MigrationOutcome.installed,
      MigrationOutcome.updated,
    ]) {
      test('${outcome.name} waits for Continue', () async {
        final cubit = cubitFor(
          FakeAppDatabase((prompter, onProgress) async {}, outcome: outcome),
        );
        await cubit.run();
        expect(
          cubit.value,
          isA<MigrationSucceeded>().having(
            (s) => s.outcome,
            'outcome',
            outcome,
          ),
        );

        await cubit.run(); // A second run while waiting does nothing.
        expect(cubit.value, isA<MigrationSucceeded>());

        cubit.acknowledge();
        expect(cubit.value, isA<MigrationDone>());
      });
    }

    test(
      'a new install that failed and was retried still says installed',
      () async {
        // The real runner on a real file: a fresh install whose second
        // migration fails once (e.g. the database was locked), then Try again.
        final folder = await testFolder('migration_cubit');
        var failOnce = true;
        final database = AppDatabase(
          databaseFactory: testDatabaseFactory(),
          databasePath: () async => p.join(folder.path, 'app.db'),
          migrations: [
            TestMigration(
              1,
              'create_a',
              (m) => m.createTable('a', (t) => t.text('name')),
            ),
            TestMigration(2, 'create_b', (m) async {
              if (failOnce) {
                failOnce = false;
                throw StateError('database is locked');
              }
              await m.createTable('b', (t) => t.text('name'));
            }),
          ],
        );
        final cubit = MigrationCubit(
          database: database,
          locale: const Locale('en', 'IN'),
        );
        addTearDown(cubit.close);

        await cubit.run();
        expect(cubit.value, isA<MigrationFailed>());
        await cubit.run();
        expect(
          cubit.value,
          isA<MigrationSucceeded>().having(
            (s) => s.outcome,
            'outcome',
            MigrationOutcome.installed,
          ),
        );
      },
    );

    test('acknowledge does nothing before it is done', () {
      final cubit = cubitFor(FakeAppDatabase((prompter, onProgress) async {}));
      cubit.acknowledge();
      expect(cubit.value, isA<MigrationInProgress>());
    });
  });

  group('restart (after a restore swapped the file)', () {
    test('runs the migrations again once done', () async {
      var runs = 0;
      final cubit = cubitFor(
        FakeAppDatabase((prompter, onProgress) async => runs++),
      );
      await cubit.run();
      await cubit.run(); // Ignored: done.
      expect(runs, 1);

      final restart = cubit.restart();
      expect(
        cubit.value,
        isA<MigrationInProgress>(),
        reason: 'at once, so the old tree is not shown again',
      );
      await restart;

      expect(runs, 2);
      expect(cubit.value, isA<MigrationDone>());
    });

    test('is ignored while a run is going on', () async {
      final release = Completer<void>();
      var runs = 0;
      final cubit = cubitFor(
        FakeAppDatabase((prompter, onProgress) async {
          runs++;
          await release.future;
        }),
      );
      final run = cubit.run();
      await cubit.restart();
      release.complete();
      await run;
      expect(runs, 1);
    });

    test('after a failure, runs again too', () async {
      var runs = 0;
      final cubit = cubitFor(
        FakeAppDatabase((prompter, onProgress) async {
          if (++runs == 1) throw StateError('first run fails');
        }),
      );
      await cubit.run();
      expect(cubit.value, isA<MigrationFailed>());
      await cubit.restart();
      expect(cubit.value, isA<MigrationDone>());
    });
  });
}
