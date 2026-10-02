import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/migration_runner.dart';
import 'package:my_expense_tracker_app/ui/features/migration/view_models/migration_cubit.dart';

import '../../../../helpers/fake_app_database.dart';

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
}
