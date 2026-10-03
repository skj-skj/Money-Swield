import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/restore_tools.dart';
import 'package:my_expense_tracker_app/data/services/backup/file_operations.dart';
import 'package:my_expense_tracker_app/data/services/backup/pre_restore_copy.dart';
import 'package:my_expense_tracker_app/data/services/database/app_database.dart';
import 'package:my_expense_tracker_app/data/services/database/migration/database_backup.dart';
import 'package:my_expense_tracker_app/data/services/document_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/file_database.dart';
import '../../../helpers/test_database.dart';

/// Real file operations that record each mutating call and can fail one:
/// the [failAt]-th (1-based), or every copy once [diskFullAfter] bytes have
/// been written.
class FaultyFileOperations implements FileOperations {
  FaultyFileOperations({this.failAt, this.diskFullAfter});

  final int? failAt;
  final int? diskFullAfter;
  final calls = <String>[];

  static const _io = IoFileOperations();

  void _count(String call) {
    calls.add(call);
    if (calls.length == failAt) {
      throw FileSystemException('Killed at step ${calls.length}: $call');
    }
  }

  @override
  Future<bool> exists(String path) => _io.exists(path);

  @override
  Future<int> length(String path) => _io.length(path);

  @override
  Future<void> copyAndFlush(String from, String to) async {
    _count('copy ${p.basename(from)} -> ${p.basename(to)}');
    final limit = diskFullAfter;
    if (limit != null) {
      final bytes = await File(from).readAsBytes();
      if (bytes.length > limit) {
        // Half written, then the disk is full.
        await File(to).writeAsBytes(bytes.sublist(0, limit));
        throw const FileSystemException('No space left on device');
      }
    }
    await _io.copyAndFlush(from, to);
  }

  @override
  Future<void> rename(String from, String to) async {
    _count('rename ${p.basename(from)} -> ${p.basename(to)}');
    await _io.rename(from, to);
  }

  @override
  Future<void> delete(String path) async {
    _count('delete ${p.basename(path)}');
    await _io.delete(path);
  }
}

void main() {
  late FileDatabases files;

  setUp(() async => files = await FileDatabases.create());

  AppDatabase appDatabase([FileOperations? operations]) => AppDatabase(
    databaseFactory: files.factory,
    databasePath: () async => files.livePath,
    cacheFolder: () async => files.paths.cacheFolder,
    fileOperations: operations ?? const IoFileOperations(),
  );

  /// A live database with [liveExpenses] expenses (open, like the app's)
  /// and a migrated candidate with [candidateExpenses].
  Future<Database> setUpLiveAndCandidate({
    int liveExpenses = 1,
    int candidateExpenses = 3,
  }) async {
    final live = await files.openLive();
    for (var i = 0; i < liveExpenses; i++) {
      await insertExpenseRow(live);
    }
    await files.migrate(files.paths.candidate);
    await files.withDatabase(files.paths.candidate, (db) async {
      for (var i = 0; i < candidateExpenses; i++) {
        await insertExpenseRow(db);
      }
    });
    return live;
  }

  Future<int> expenseCount(String path) async =>
      (await files.withDatabase(path, (db) => db.query('expenses'))).length;

  List<String> preRestoreFiles() {
    final folder = Directory(files.paths.preRestoreFolder);
    if (!folder.existsSync()) return [];
    return [for (final f in folder.listSync()) p.basename(f.path)]..sort();
  }

  test(
    'swaps in the candidate and keeps an exact copy of the old file',
    () async {
      final live = await setUpLiveAndCandidate();
      final candidateBytes = await File(files.paths.candidate).readAsBytes();
      late List<int> oldBytes;

      await appDatabase().replaceWith(
        files.paths.candidate,
        closeConnection: () async {
          await live.close();
          oldBytes = await File(files.livePath).readAsBytes();
        },
        now: DateTime.utc(2026, 10, 3, 9),
      );

      expect(await File(files.livePath).readAsBytes(), candidateBytes);
      final copies = await appDatabase().preRestoreCopies();
      expect(copies, hasLength(1));
      expect(copies.single.sequence, 1);
      expect(copies.single.createdAt, DateTime.utc(2026, 10, 3, 9));
      expect(await File(copies.single.path).readAsBytes(), oldBytes);
      expect(Directory(files.paths.candidateFolder).existsSync(), isFalse);
      expect(await expenseCount(files.livePath), 3);
    },
  );

  test('live -wal / -journal are copied with the old data, then removed '
      'before the rename', () async {
    final live = await setUpLiveAndCandidate();
    await live.close();
    await File('${files.livePath}-wal').writeAsString('wal bytes');
    await File('${files.livePath}-journal').writeAsString('journal bytes');
    await File('${files.livePath}-shm').writeAsString('shm bytes');

    await appDatabase().replaceWith(
      files.paths.candidate,
      closeConnection: () async {},
    );

    final copy = (await appDatabase().preRestoreCopies()).single.path;
    expect(await File('$copy-wal').readAsString(), 'wal bytes');
    expect(await File('$copy-journal').readAsString(), 'journal bytes');
    expect(File('$copy-shm').existsSync(), isFalse, reason: '-shm not kept');
    for (final suffix in ['-wal', '-journal', '-shm']) {
      expect(
        File('${files.livePath}$suffix').existsSync(),
        isFalse,
        reason: 'a leftover $suffix would be replayed onto the new file',
      );
    }
  });

  test('a close() that throws stops everything: nothing copied, deleted or '
      'renamed; the app still restarts (§6.4 step 4.1)', () async {
    final live = await setUpLiveAndCandidate();
    final operations = FaultyFileOperations();

    await expectLater(
      appDatabase(operations).replaceWith(
        files.paths.candidate,
        closeConnection: () => throw StateError('close failed'),
      ),
      throwsA(
        isA<SwapFailure>().having(
          (e) => e.needsRestart,
          'needsRestart',
          isTrue,
        ),
      ),
    );

    expect(operations.calls, isEmpty);
    expect(preRestoreFiles(), isEmpty);
    expect(File(files.paths.candidate).existsSync(), isTrue);
    expect(await live.query('expenses'), hasLength(1));
  });

  group('killed at every step', () {
    late int steps;

    setUp(() async {
      // Counts the steps of a successful swap, with journals to copy.
      final probe = await FileDatabases.create();
      files = probe;
      final live = await setUpLiveAndCandidate();
      await live.close();
      await File('${files.livePath}-journal').writeAsString('j');
      final counting = FaultyFileOperations();
      await appDatabase(counting)
          .replaceWith(files.paths.candidate, closeConnection: () async {});
      steps = counting.calls.length;
      expect(steps, greaterThan(5));
    });

    test('the database is the old one or the candidate, never anything '
        'else, and the copy is complete or absent', () async {
      for (var failAt = 1; failAt <= steps; failAt++) {
        files = await FileDatabases.create();
        final live = await setUpLiveAndCandidate();
        await live.close();
        await File('${files.livePath}-journal').writeAsString('j');
        final oldBytes = await File(files.livePath).readAsBytes();
        final candidateBytes = await File(files.paths.candidate).readAsBytes();

        final operations = FaultyFileOperations(failAt: failAt);
        Object? failure;
        try {
          await appDatabase(operations)
              .replaceWith(files.paths.candidate, closeConnection: () async {});
        } catch (error) {
          failure = error;
        }
        final where = 'killed at ${operations.calls.last}';

        // The next start.
        await RestoreTools(
          appDatabase: appDatabase(),
          documents: const ChannelDocumentService(),
          deviceCurrency: 'INR',
        ).repository.cleanUpLeftovers();

        final liveBytes = await File(files.livePath).readAsBytes();
        final isOld = _equal(liveBytes, oldBytes);
        final isCandidate = _equal(liveBytes, candidateBytes);
        expect(isOld || isCandidate, isTrue, reason: where);
        if (isOld) {
          expect(failure, isA<SwapFailure>(), reason: where);
        }
        // It opens.
        expect(await expenseCount(files.livePath), isOld ? 1 : 3);

        final copies = await appDatabase().preRestoreCopies();
        if (copies.isNotEmpty) {
          expect(
            await File(copies.single.path).readAsBytes(),
            oldBytes,
            reason: '$where: incomplete copy',
          );
        }
        expect(
          preRestoreFiles().where((f) => f.endsWith('.partial')),
          isEmpty,
          reason: where,
        );
        if (isCandidate) {
          expect(copies, hasLength(1), reason: '$where: old data lost');
        }
      }
    });
  });

  test('disk full while copying the old data: the live file is untouched '
      'and no .partial is left after cleanup', () async {
    final live = await setUpLiveAndCandidate();
    late List<int> oldBytes;

    await expectLater(
      appDatabase(FaultyFileOperations(diskFullAfter: 1000)).replaceWith(
        files.paths.candidate,
        closeConnection: () async {
          await live.close();
          oldBytes = await File(files.livePath).readAsBytes();
        },
      ),
      throwsA(
        isA<SwapFailure>().having(
          (e) => e.needsRestart,
          'needsRestart',
          isTrue,
        ),
      ),
    );
    expect(await File(files.livePath).readAsBytes(), oldBytes);

    await appDatabase().cleanUpPreRestoreFolder();
    expect(preRestoreFiles(), isEmpty);
  });

  test('only the newest 3 copies are kept', () async {
    final live = await files.openLive();
    await live.close();
    final names = <String>[];
    for (var i = 1; i <= 5; i++) {
      await files.migrate(files.paths.candidate);
      await appDatabase().replaceWith(
        files.paths.candidate,
        closeConnection: () async {},
        now: DateTime.utc(2026, 10, i),
      );
      names.add(PreRestoreCopy.fileName(i, DateTime.utc(2026, 10, i)));
    }
    final copies = await appDatabase().preRestoreCopies();
    expect([for (final c in copies) c.sequence], [5, 4, 3]);
    expect(preRestoreFiles(), [names[2], names[3], names[4]]);
  });

  test('with the clock moved back, the newest copy is still the highest '
      'sequence, and pruning keeps it', () async {
    final live = await files.openLive();
    await live.close();
    final times = [
      DateTime.utc(2026, 10, 3),
      DateTime.utc(2026, 10, 4),
      DateTime.utc(2020, 1, 1), // Clock set back.
      DateTime.utc(2019, 1, 1),
    ];
    for (final time in times) {
      await files.migrate(files.paths.candidate);
      await appDatabase().replaceWith(
        files.paths.candidate,
        closeConnection: () async {},
        now: time,
      );
    }
    final copies = await appDatabase().preRestoreCopies();
    expect([for (final c in copies) c.sequence], [4, 3, 2]);
    expect(copies.first.createdAt, DateTime.utc(2019));
  });

  test('two restores within the same second keep both copies', () async {
    final live = await files.openLive();
    await live.close();
    final now = DateTime.utc(2026, 10, 3, 9);
    for (var i = 0; i < 2; i++) {
      await files.migrate(files.paths.candidate);
      await appDatabase().replaceWith(
        files.paths.candidate,
        closeConnection: () async {},
        now: now,
      );
    }
    expect(await appDatabase().preRestoreCopies(), hasLength(2));
  });

  test(
    'a new copy never reuses the sequence of a .partial left behind',
    () async {
      final live = await files.openLive();
      await live.close();
      final stale = p.join(
        files.paths.preRestoreFolder,
        '${PreRestoreCopy.fileName(7, DateTime.utc(2026))}.partial',
      );
      await File(stale).create(recursive: true);
      await files.migrate(files.paths.candidate);

      await appDatabase().replaceWith(
        files.paths.candidate,
        closeConnection: () async {},
      );

      expect((await appDatabase().preRestoreCopies()).single.sequence, 8);
    },
  );

  test('restore A, B, C then Undo: 3 copies kept, and the data from before '
      'A is the one pruned (the documented limit)', () async {
    // Each state is told apart by its number of expenses.
    Future<void> restoreState(int expenses) async {
      await files.migrate(files.paths.candidate);
      await files.withDatabase(files.paths.candidate, (db) async {
        for (var i = 0; i < expenses; i++) {
          await insertExpenseRow(db);
        }
      });
      await appDatabase().replaceWith(
        files.paths.candidate,
        closeConnection: () async {},
      );
    }

    final live = await files.openLive(); // State 0: no expenses.
    await live.close();
    await restoreState(1); // A
    await restoreState(2); // B
    await restoreState(3); // C
    // Undo: the newest copy (B) becomes the candidate.
    final newest = (await appDatabase().preRestoreCopies()).first;
    await Directory(files.paths.candidateFolder).create(recursive: true);
    await File(newest.path).copy(files.paths.candidate);
    await appDatabase().replaceWith(
      files.paths.candidate,
      closeConnection: () async {},
    );

    expect(await expenseCount(files.livePath), 2);
    final copies = await appDatabase().preRestoreCopies();
    expect(copies, hasLength(3));
    final kept = [for (final c in copies) await expenseCount(c.path)];
    expect(kept, [3, 2, 1], reason: 'C, B, A kept; the original 0 pruned');
  });

  test("the migration runner's backup handling leaves pre-restore copies "
      'alone', () async {
    final live = await files.openLive();
    await live.close();
    await files.migrate(files.paths.candidate);
    await appDatabase().replaceWith(
      files.paths.candidate,
      closeConnection: () async {},
    );
    final copy = (await appDatabase().preRestoreCopies()).single.path;

    // What MigrationRunner does around a migration run.
    final backup = await DatabaseBackup.create(
      files.livePath,
      now: DateTime.utc(2026, 11),
    );
    await DatabaseBackup.delete(backup!);

    expect(backup.path, isNot(copy));
    expect(File(copy).existsSync(), isTrue);
  });
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
