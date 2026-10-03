import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/backup_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/ui/features/backup/view_models/backup_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/fake_document_service.dart';
import '../../../../helpers/file_database.dart';

void main() {
  late FileDatabases files;
  late Database live;
  late FakeDocumentService documents;
  late BackupCubit cubit;

  final now = DateTime.utc(2026, 10, 3, 8, 35, 12);

  Future<DateTime?> lastBackupAt() =>
      SettingsRepository(live, deviceCurrency: 'INR').lastBackupAt();

  bool tempFilesLeft() => Directory(files.paths.backupWorkFolder).existsSync();

  setUp(() async {
    files = await FileDatabases.create();
    live = await files.openLive();
    documents = FakeDocumentService(version: '3.1.4+15');
    cubit = BackupCubit(
      backups: BackupRepository(
        live,
        appDatabase: files.appDatabase(),
        settings: SettingsRepository(live, deviceCurrency: 'INR'),
        now: () => now,
      ),
      documents: documents,
      appDatabase: files.appDatabase(),
    );
    addTearDown(cubit.close);
  });

  test('a saved backup records its time; the temp files are deleted', () async {
    expect(await cubit.backUp(), BackupResult.saved);

    expect(documents.savedName, BackupRepository.backupFileName(now));
    expect(documents.savedBytes, isNotEmpty);
    expect(await lastBackupAt(), now);
    expect(cubit.value.lastBackupAt, now);
    expect(cubit.value.backingUp, isFalse);
    expect(tempFilesLeft(), isFalse);
  });

  test('a cancelled save writes no last_backup_at and deletes the temp '
      'files', () async {
    documents.onSave = (_) async => false;

    expect(await cubit.backUp(), BackupResult.cancelled);

    expect(await lastBackupAt(), isNull);
    expect(cubit.value.lastBackupAt, isNull);
    expect(cubit.value.failureReport, isNull);
    expect(tempFilesLeft(), isFalse);
  });

  test('a failed save shows a report, records nothing, deletes the temp '
      'files', () async {
    documents.onSave = (_) async =>
        throw const FileSystemException('The saved file differs');

    expect(await cubit.backUp(), BackupResult.failed);

    expect(cubit.value.failureReport, contains('The saved file differs'));
    expect(cubit.value.backingUp, isFalse);
    expect(await lastBackupAt(), isNull);
    expect(tempFilesLeft(), isFalse);
  });

  test('a failed copy (a trigger in the database) shows a report', () async {
    await live.execute(
      'CREATE TRIGGER t AFTER INSERT ON categories BEGIN SELECT 1; END',
    );

    expect(await cubit.backUp(), BackupResult.failed);

    expect(cubit.value.failureReport, contains('trigger'));
    expect(documents.saveCalls, 0, reason: 'no dialog for a failed backup');
    expect(tempFilesLeft(), isFalse);
  });

  test('a second backUp while one runs is ignored: one dialog', () async {
    final release = Completer<bool>();
    documents.onSave = (_) => release.future;

    final first = cubit.backUp();
    // Wait until the first reaches the dialog.
    while (documents.saveCalls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cubit.value.backingUp, isTrue);
    expect(await cubit.backUp(), BackupResult.ignored);
    release.complete(true);

    expect(await first, BackupResult.saved);
    expect(documents.saveCalls, 1);
  });

  test('a saved file is "saved" even if recording its time fails: no '
      'report that would make the user save a second copy', () async {
    final old = DateTime.utc(2026, 9, 21);
    await SettingsRepository(live, deviceCurrency: 'INR').setLastBackupAt(old);
    await cubit.load();
    final failing = BackupCubit(
      backups: _FailingRecordRepository(
        live,
        appDatabase: files.appDatabase(),
        settings: SettingsRepository(live, deviceCurrency: 'INR'),
        now: () => now,
      ),
      documents: documents,
      appDatabase: files.appDatabase(),
    );
    addTearDown(failing.close);
    await failing.load();

    expect(await failing.backUp(), BackupResult.saved);

    expect(documents.savedBytes, isNotEmpty);
    expect(failing.value.failureReport, isNull);
    expect(failing.value.backingUp, isFalse);
    expect(failing.value.lastBackupAt, old, reason: 'not recorded, not shown');
    expect(tempFilesLeft(), isFalse);
  });

  test('a retry after a failure clears the report', () async {
    documents.onSave = (_) async => throw StateError('boom');
    await cubit.backUp();
    expect(cubit.value.failureReport, isNotNull);

    documents.onSave = (_) async => true;
    expect(await cubit.backUp(), BackupResult.saved);
    expect(cubit.value.failureReport, isNull);
  });

  test('load reads the last backup and the newest pre-restore copy', () async {
    await SettingsRepository(
      live,
      deviceCurrency: 'INR',
    ).setLastBackupAt(DateTime.utc(2026, 9, 21));
    await cubit.load();
    expect(cubit.value.lastBackupAt, DateTime.utc(2026, 9, 21));
    expect(cubit.value.newestCopy, isNull);
  });
}

/// Saving works; noting the time fails (e.g. the disk filled up meanwhile).
class _FailingRecordRepository extends BackupRepository {
  _FailingRecordRepository(
    super.db, {
    required super.appDatabase,
    required super.settings,
    super.now,
  });

  @override
  Future<void> recordBackup(DateTime at) async =>
      throw const FileSystemException('No space left on device');
}
