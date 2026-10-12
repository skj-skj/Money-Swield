import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;
import 'package:my_expense_tracker_app/app/restore_tools.dart';
import 'package:my_expense_tracker_app/data/repositories/backup_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/restore_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/data/services/database/app_database.dart';
import 'package:my_expense_tracker_app/data/services/database/migrations/all_migrations.dart';
import 'package:my_expense_tracker_app/domain/models/restore_candidate.dart';
import 'package:my_expense_tracker_app/ui/features/backup/view_models/restore_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/migration/view_models/migration_cubit.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../data/services/database/migration/test_helpers.dart';
import '../../../../helpers/fake_document_service.dart';
import '../../../../helpers/file_database.dart';
import '../../../../helpers/test_database.dart';

/// A restore repository whose validation waits for [gate], so a test can
/// act while it runs.
class _GatedRestoreRepository extends RestoreRepository {
  _GatedRestoreRepository({
    required super.appDatabase,
    required super.probe,
    required this.gate,
  });

  final Future<void> gate;

  @override
  Future<RestoreCandidate> prepareFromZip() async {
    await gate;
    return super.prepareFromZip();
  }
}

class _GatedRestoreTools extends RestoreTools {
  _GatedRestoreTools({
    required super.appDatabase,
    required super.documents,
    required this.gate,
  }) : super(deviceCurrency: 'INR');

  final Future<void> gate;

  late final _gated = _GatedRestoreRepository(
    appDatabase: appDatabase,
    probe: (_) async {},
    gate: gate,
  );

  @override
  RestoreRepository get repository => _gated;
}

void main() {
  late FileDatabases files;
  late Database live;
  late FakeDocumentService documents;
  late RestoreTools tools;

  setUp(() async {
    files = await FileDatabases.create();
    live = await files.openLive();
    documents = FakeDocumentService();
    tools = RestoreTools(
      appDatabase: files.appDatabase(),
      documents: documents,
      deviceCurrency: 'INR',
    );
  });

  RestoreCubit cubitFor(
    RestoreTools tools, {
    Future<void> Function()? closeLiveConnection,
    MigrationCubit Function(AppDatabase candidate)? migrationCubitFor,
  }) {
    final cubit = RestoreCubit(
      tools: tools,
      closeLiveConnection: closeLiveConnection ?? live.close,
      locale: const Locale('en', 'IN'),
      currentExpenseCount: () async =>
          (await live.query('expenses', where: 'deleted_at IS NULL')).length,
      migrationCubitFor: migrationCubitFor,
    );
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });
    return cubit;
  }

  /// A backup zip of the live database as it is now, saved where the
  /// open dialog will "pick" it.
  Future<String> backUpLive() async {
    final zip = await BackupRepository(
      live,
      appDatabase: files.appDatabase(),
      settings: SettingsRepository(live, deviceCurrency: 'INR'),
      now: () => DateTime.utc(2026, 10, 3, 8, 35, 12),
    ).createBackup(appVersion: 'test');
    final kept = p.join(files.root.path, 'picked-backup.zip');
    await File(zip.path).copy(kept);
    documents.pickedFile = kept;
    return kept;
  }

  /// Waits until the cubit stops moving: a state the user has to act on, or
  /// an end state.
  Future<RestoreState> settled(RestoreCubit cubit) async {
    for (var i = 0; i < 1000; i++) {
      final state = cubit.value;
      final moving = switch (state) {
        RestorePicking() || RestoreValidating() || RestoreSwapping() => true,
        RestoreMigrating(:final migration) =>
          migration.value is! MigrationFailed &&
              migration.value is! MigrationSucceeded,
        _ => false,
      };
      if (!moving) return state;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw TimeoutException('Restore stuck at ${cubit.value}');
  }

  bool candidateLeft() => Directory(files.paths.candidateFolder).existsSync();

  Future<List<int>> liveBytesAfterClose() async {
    if (live.isOpen) await live.close();
    return File(files.livePath).readAsBytes();
  }

  group('a zip restore', () {
    test('goes picking → validating → confirm → migrating → swapping → done, '
        'and replaces the data', () async {
      await insertExpenseRow(live);
      await backUpLive();
      final added = await insertExpenseRow(live);

      final cubit = cubitFor(tools);
      final states = <String>[];
      cubit.state.subscribe((s) => states.add(s.runtimeType.toString()));
      await cubit.startFromZip();

      final confirm = await settled(cubit) as RestoreConfirm;
      expect(confirm.candidate.activeExpenses, 1);
      expect(confirm.currentExpenses, 2);
      await cubit.confirm();
      final done = await settled(cubit) as RestoreDone;
      expect(done.settingsReset, isFalse);

      expect(states, [
        'RestorePicking',
        'RestoreValidating',
        'RestoreConfirm',
        'RestoreMigrating',
        'RestoreSwapping',
        'RestoreDone',
      ]);
      expect(live.isOpen, isFalse, reason: 'the app connection was closed');
      await files.withDatabase(files.livePath, (db) async {
        final ids = [for (final r in await db.query('expenses')) r['id']];
        expect(ids, isNot(contains(added)));
        expect(
          await SettingsRepository(db, deviceCurrency: 'INR').lastBackupAt(),
          DateTime.utc(2026, 10, 3, 8, 35, 12),
          reason: 'stamped with the backup\'s own time',
        );
      });
      expect(await tools.appDatabase.preRestoreCopies(), hasLength(1));
      expect(candidateLeft(), isFalse);
    });

    test('then Undo brings the replaced data back', () async {
      await backUpLive();
      final added = await insertExpenseRow(live);
      final restore = cubitFor(tools);
      await restore.startFromZip();
      await settled(restore);
      await restore.confirm();
      expect(await settled(restore), isA<RestoreDone>());
      await restore.close();

      // The app restarts on the restored file.
      live = await files.open(files.livePath);
      final copy = (await tools.appDatabase.preRestoreCopies()).first;
      final undo = cubitFor(tools);
      await undo.startFromCopy(copy);
      final confirm = await settled(undo) as RestoreConfirm;
      expect(confirm.candidate.source, RestoreSource.preRestoreCopy);
      expect(confirm.candidate.activeExpenses, 1);
      await undo.confirm();
      expect(await settled(undo), isA<RestoreDone>());

      final ids = await files.withDatabase(
        files.livePath,
        (db) async => [for (final r in await db.query('expenses')) r['id']],
      );
      expect(ids, [added]);
      // Undo is a restore too: it kept a copy of what it replaced.
      expect(await tools.appDatabase.preRestoreCopies(), hasLength(2));
    });
  });

  group('cancel and leave', () {
    test('a cancelled open dialog ends at once and creates nothing', () async {
      final cubit = cubitFor(tools);
      await cubit.startFromZip();
      expect(cubit.value, isA<RestoreCancelled>());
      expect(candidateLeft(), isFalse);
    });

    test('Cancel on the confirm dialog deletes the candidate; the live data '
        'is untouched', () async {
      await backUpLive();
      final before = await File(files.livePath).readAsBytes();
      final cubit = cubitFor(tools);
      await cubit.startFromZip();
      expect(await settled(cubit), isA<RestoreConfirm>());
      expect(candidateLeft(), isTrue);

      await cubit.cancel();

      expect(cubit.value, isA<RestoreCancelled>());
      expect(candidateLeft(), isFalse);
      expect(live.isOpen, isTrue);
      expect(await liveBytesAfterClose(), before);
    });

    test(
      'leaving (close) at the confirm dialog deletes the candidate',
      () async {
        await backUpLive();
        final cubit = cubitFor(tools);
        await cubit.startFromZip();
        expect(await settled(cubit), isA<RestoreConfirm>());

        await cubit.close();

        expect(candidateLeft(), isFalse);
      },
    );

    test('close() while validation still runs: once both finish, no '
        'candidate is left', () async {
      await backUpLive();
      final gate = Completer<void>();
      final gated = _GatedRestoreTools(
        appDatabase: files.appDatabase(),
        documents: documents,
        gate: gate.future,
      );
      final cubit = cubitFor(gated);
      final starting = cubit.startFromZip();
      while (cubit.value is! RestoreValidating) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final closing = cubit.close();
      gate.complete();
      await closing;
      await starting;

      expect(candidateLeft(), isFalse);
    });
  });

  group('refused', () {
    test('a file larger than the free space can\'t be opened: "not enough '
        'space" (not "not a backup")', () async {
      documents.pickedTooLarge = true;
      final cubit = cubitFor(tools);
      await cubit.startFromZip();
      expect(cubit.value, isA<RestoreFailedNoSpace>());
    });

    test(
      'a file that isn\'t a zip is "not a backup", and leaves nothing',
      () async {
        final photo = p.join(files.root.path, 'photo.jpg');
        await File(photo).writeAsBytes(List.filled(3000, 0xFF));
        documents.pickedFile = photo;
        final cubit = cubitFor(tools);
        await cubit.startFromZip();
        expect(
          (await settled(cubit) as RestoreRefused).reason,
          RestoreRejection.notABackup,
        );
        expect(candidateLeft(), isFalse);
        expect(Directory(files.paths.restoreWorkFolder).existsSync(), isFalse);
      },
    );

    test(
      'a backup that can\'t start the app is refused before the swap',
      () async {
        await live.execute('DROP TABLE expense_events');
        // Photo links point at expenses too, and so do the SMS
        // suggestions (`expense_id`).
        await live.execute('DROP TABLE expense_photos');
        await live.execute('DROP TABLE sms_suggestions');
        await live.execute('DROP TABLE expenses');
        await backUpLive();
        final before = await liveBytesAfterClose();
        live = await files.open(files.livePath);

        final cubit = cubitFor(tools);
        await cubit.startFromZip();
        await settled(cubit);
        await cubit.confirm();

        expect(
          (await settled(cubit) as RestoreRefused).reason,
          RestoreRejection.damaged,
        );
        expect(live.isOpen, isTrue, reason: 'never closed: nothing swapped');
        expect(await liveBytesAfterClose(), before);
        await cubit.close();
        expect(candidateLeft(), isFalse);
      },
    );
  });

  test('a second start while the first runs is ignored: one dialog', () async {
    await backUpLive();
    final cubit = cubitFor(tools);
    final first = cubit.startFromZip();
    await cubit.startFromZip();
    await first;
    expect(documents.openCalls, 1);
  });

  test('a failing migration of the candidate leaves the live data untouched, '
      'and leaving deletes the candidate', () async {
    await backUpLive();
    final before = await File(files.livePath).readAsBytes();
    final failing = TestMigration(
      9000000000,
      'breaks',
      (m) async => throw StateError('migration broke'),
    );
    final cubit = cubitFor(
      tools,
      migrationCubitFor: (candidate) => MigrationCubit(
        database: AppDatabase(
          databaseFactory: candidate.databaseFactory,
          databasePath: () async => files.paths.candidate,
          migrations: [...allMigrations, failing],
        ),
        locale: const Locale('en', 'IN'),
      ),
    );
    await cubit.startFromZip();
    await settled(cubit);
    await cubit.confirm();

    final state = await settled(cubit) as RestoreMigrating;
    final failure = (state.migration.value as MigrationFailed).failure;
    expect(failure.report, contains('migration broke'));
    expect(live.isOpen, isTrue);
    expect(await liveBytesAfterClose(), before);

    await cubit.close();
    expect(candidateLeft(), isFalse);
  });

  test('a close() of the live connection that throws: failed, the app '
      'restarts, nothing swapped', () async {
    await backUpLive();
    final before = await File(files.livePath).readAsBytes();
    final cubit = cubitFor(
      tools,
      closeLiveConnection: () async => throw StateError('busy'),
    );
    await cubit.startFromZip();
    await settled(cubit);
    await cubit.confirm();

    final failed = await settled(cubit) as RestoreFailed;
    expect(failed.needsRestart, isTrue);
    expect(failed.report, contains('Closing the database'));
    expect(await tools.appDatabase.preRestoreCopies(), isEmpty);
    expect(await liveBytesAfterClose(), before);
  });

  test('an open dialog that fails (e.g. the copy, "ioError") shows a report '
      'instead of spinning forever; nothing is left', () async {
    documents.openError = PlatformException(
      code: 'ioError',
      message: "java.io.IOException: Can't read the chosen file",
    );
    final cubit = cubitFor(tools);

    await cubit.startFromZip(); // Must not throw.

    final failed = cubit.value as RestoreFailed;
    expect(failed.needsRestart, isFalse);
    expect(failed.report, contains('Opening the backup file'));
    expect(failed.report, contains('ioError'));
    expect(live.isOpen, isTrue);
    expect(candidateLeft(), isFalse);
  });

  test('a second confirm() while the first starts is ignored: one migration '
      'on the candidate', () async {
    await backUpLive();
    var built = 0;
    final cubit = cubitFor(
      tools,
      migrationCubitFor: (candidate) {
        built++;
        return MigrationCubit(
          database: candidate,
          locale: const Locale('en', 'IN'),
        );
      },
    );
    await cubit.startFromZip();
    expect(await settled(cubit), isA<RestoreConfirm>());

    await Future.wait([cubit.confirm(), cubit.confirm(), cubit.cancel()]);

    expect(await settled(cubit), isA<RestoreDone>());
    expect(built, 1);
  });

  group('a backup whose settings are missing or unreadable', () {
    Future<void> restoreAndExpectReset() async {
      final expense = await insertExpenseRow(live);
      await backUpLive();
      final cubit = cubitFor(tools);
      await cubit.startFromZip();
      expect(await settled(cubit), isA<RestoreConfirm>());
      await cubit.confirm();

      final done = await settled(cubit) as RestoreDone;
      expect(done.settingsReset, isTrue);
      await files.withDatabase(files.livePath, (db) async {
        expect(
          [for (final r in await db.query('expenses')) r['id']],
          [expense],
          reason: 'the expenses are restored',
        );
        final settings = SettingsRepository(db, deviceCurrency: 'INR');
        final loaded = await settings.load();
        expect(
          loaded.onboardingCompleted,
          isTrue,
          reason: 'lands on Home, where it says why',
        );
        expect(loaded.locale, isNull, reason: 'defaults: follow the device');
        expect(
          await settings.lastBackupAt(),
          DateTime.utc(2026, 10, 3, 8, 35, 12),
          reason: 'still stamped with the backup time',
        );
      });
    }

    test('missing: restored with default settings', () async {
      await live.execute('DROP TABLE settings');
      await restoreAndExpectReset();
    });

    test("a value that isn't text: restored with default settings", () async {
      // A blob: TEXT affinity would have turned a number into text.
      await live.insert('settings', {
        'key': 'theme',
        'value': Uint8List.fromList([1, 2, 3]),
      });
      await restoreAndExpectReset();
    });
  });
}
