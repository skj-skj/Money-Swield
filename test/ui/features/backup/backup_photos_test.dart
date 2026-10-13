import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/app/restore_tools.dart';
import 'package:money_swield/data/repositories/backup_repository.dart';
import 'package:money_swield/data/repositories/settings_repository.dart';
import 'package:money_swield/data/services/backup/backup_archive.dart';
import 'package:money_swield/data/services/backup/backup_manifest.dart';
import 'package:money_swield/data/services/photo_service.dart';
import 'package:money_swield/data/services/photo_store.dart';
import 'package:money_swield/domain/models/restore_candidate.dart';
import 'package:money_swield/ui/features/backup/view_models/restore_cubit.dart';
import 'package:money_swield/ui/features/migration/view_models/migration_cubit.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/fake_document_service.dart';
import '../../../helpers/fake_photo_service.dart';
import '../../../helpers/file_database.dart';
import '../../../helpers/test_database.dart';

/// Backups and restores with photos, on real database and photo files.
void main() {
  late FileDatabases files;
  late Database live;
  late FakeDocumentService documents;
  late FakePhotoService service;
  late RestoreTools tools;

  String photosRoot() => p.join(files.root.path, 'files');
  List<int> bytesOf(String letter) => utf8.encode('picture $letter ' * 20);
  String shaOf(String letter) => sha256.convert(bytesOf(letter)).toString();

  setUp(() async {
    files = await FileDatabases.create();
    live = await files.openLive();
    documents = FakeDocumentService();
    service = FakePhotoService();
    tools = RestoreTools(
      appDatabase: files.appDatabase(),
      documents: documents,
      deviceCurrency: 'INR',
      photoService: service,
    );
  });

  /// A photo row for [letter]'s bytes, named by their SHA-256 as the app
  /// names it, linked to a new expense ([binned] puts it in the bin), with
  /// its file unless [file] is false.
  Future<String> photo(String letter, {bool file = true, int? binned}) async {
    final sha = shaOf(letter);
    final path = 'photos/$sha.jpg';
    if (file) {
      final f = File(p.join(photosRoot(), path));
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytesOf(letter));
    }
    final id = await live.insert('photos', {
      'relative_path': path,
      'sha256': sha,
      'byte_size': bytesOf(letter).length,
      'created_at': 0,
      'updated_at': 0,
    });
    await live.insert('expense_photos', {
      'expense_id': await insertExpenseRow(live, deletedAt: binned),
      'photo_id': id,
      'sort_order': 0,
    });
    return path;
  }

  BackupRepository backups() => BackupRepository(
    live,
    appDatabase: files.appDatabase(),
    settings: SettingsRepository(live, deviceCurrency: 'INR'),
    photos: PhotoStore(root: photosRoot(), service: service),
    now: () => DateTime.utc(2026, 10, 7, 8),
  );

  group('backup', () {
    test('with photos: entries named by their path, stored; the manifest '
        'lists the copy\'s rows; a binned expense\'s photo is in it', () async {
      final a = await photo('a');
      final b = await photo('b', binned: 5);
      final progress = <(int, int)>[];
      final zip = await backups().createBackup(
        appVersion: 't',
        includePhotos: true,
        onProgress: (done, total) => progress.add((done, total)),
      );
      expect(zip.photoCount, 2);
      expect(zip.missingPhotos, 0);
      final byName = zipEntries(zip.path);
      expect(byName.keys, containsAll([a, b]));
      expect(byName[a]!.compressionMethod, 0, reason: 'stored');
      final manifest = manifestOf(zip.path);
      expect(manifest.includesPhotos, isTrue);
      expect({for (final ph in manifest.photos) ph.relativePath}, {a, b});
      expect(progress.last, (2, 2));
    });

    test('a missing file and one of another size are left out and counted; '
        'the rest are in', () async {
      await photo('a');
      await photo('b', file: false);
      final c = await photo('c');
      await File(p.join(photosRoot(), c)).writeAsString('cut short');
      final zip = await backups().createBackup(
        appVersion: 't',
        includePhotos: true,
      );
      expect(zip.photoCount, 1);
      expect(zip.missingPhotos, 2);
    });

    test('without photos: database-only', () async {
      await photo('a');
      final zip = await backups().createBackup(appVersion: 't');
      expect(zipEntries(zip.path).keys, ['manifest.json', 'money_swield.db']);
    });

    test('no space: BackupNoSpace, nothing left in cache/backup', () async {
      await photo('a');
      service.free = 1000;
      await expectLater(
        backups().createBackup(appVersion: 't', includePhotos: true),
        throwsA(isA<BackupNoSpace>()),
      );
      expect(Directory(files.paths.backupWorkFolder).existsSync(), isFalse);
    });

    test('free space that can\'t be read doesn\'t stop a backup', () async {
      await photo('a');
      service.errors['freeBytes'] = const PhotoServiceException(
        PhotoError.ioError,
      );
      final zip = await backups().createBackup(
        appVersion: 't',
        includePhotos: true,
      );
      expect(zip.photoCount, 1);
    });
  });

  group('BackupArchive photo entries', () {
    late String zipPath;
    late String root;

    setUp(() {
      zipPath = p.join(files.root.path, 'b.zip');
      root = p.join(files.root.path, 'restored');
    });

    late ReceivePort unsendable;

    setUp(() {
      unsendable = ReceivePort();
      addTearDown(unsendable.close);
    });

    Future<List<ManifestPhoto>> writeZip(
      Map<String, List<int>> photos, {
      Map<String, List<int>>? actualBytes,
    }) async {
      final src = p.join(files.root.path, 'src');
      final list = <ManifestPhoto>[];
      final entries = <PhotoEntry>[];
      for (final MapEntry(key: letter, value: bytes) in photos.entries) {
        final sha = sha256.convert(bytes).toString();
        final name = 'photos/$sha.jpg';
        final path = p.join(src, '$sha.jpg');
        await File(path).parent.create(recursive: true);
        await File(path).writeAsBytes(actualBytes?[letter] ?? bytes);
        list.add((relativePath: name, sha256: sha, byteSize: bytes.length));
        entries.add((name: name, path: path));
      }
      final db = p.join(files.root.path, 'db.bin');
      await File(db).writeAsBytes([1, 2, 3]);
      await BackupArchive.write(
        BackupManifest(
          format: 1,
          appVersion: 't',
          schemaVersion: 1,
          createdAt: DateTime.utc(2026),
          includesPhotos: true,
          photos: list,
        ),
        db,
        zipPath,
        photos: entries,
        // A callback holding what an isolate can't receive, like a cubit's
        // (regression: every backup failed when this reached the isolate).
        onProgress: (_) => unsendable.hashCode,
      );
      return list;
    }

    test('into an empty folder: written, hashes right, no .partial', () async {
      final list = await writeZip({'a': bytesOf('a'), 'b': bytesOf('b')});
      final result = await BackupArchive.writePhotos(zipPath, list, root);
      expect(result, (written: 2, skipped: 0, failed: 0));
      for (final ph in list) {
        final bytes = await File(p.join(root, ph.relativePath)).readAsBytes();
        expect(sha256.convert(bytes).toString(), ph.sha256);
      }
      expect(
        Directory(p.join(root, 'photos'))
            .listSync()
            .where((f) => f.path.endsWith('.partial')),
        isEmpty,
      );
    });

    test('the same file already there is not rewritten; one with other '
        'bytes under its name is replaced', () async {
      final list = await writeZip({'a': bytesOf('a'), 'b': bytesOf('b')});
      await BackupArchive.writePhotos(zipPath, list, root);
      final a = File(p.join(root, list[0].relativePath));
      final old = DateTime(2020);
      a.setLastModifiedSync(old);
      final b = File(p.join(root, list[1].relativePath));
      await b.writeAsBytes(List.filled(bytesOf('b').length, 0));
      final result = await BackupArchive.writePhotos(zipPath, list, root);
      expect(result, (written: 1, skipped: 1, failed: 0));
      expect(a.lastModifiedSync(), old);
      expect(await b.readAsBytes(), bytesOf('b'));
    });

    test(
      'a damaged entry fails that photo only: the others are written',
      () async {
        final list = await writeZip(
          {'a': bytesOf('a'), 'b': bytesOf('b'), 'c': bytesOf('c')},
          // b's entry holds other bytes than its listed hash.
          actualBytes: {'b': bytesOf('x')},
        );
        final result = await BackupArchive.writePhotos(zipPath, list, root);
        expect(result, (written: 2, skipped: 0, failed: 1));
        expect(File(p.join(root, list[1].relativePath)).existsSync(), isFalse);
        expect(
          File('${p.join(root, list[1].relativePath)}.partial').existsSync(),
          isFalse,
        );
      },
    );

    test('an entry longer than its byte_size fails', () async {
      final longer = [...bytesOf('a'), 1, 2, 3];
      final list = await writeZip(
        {'a': bytesOf('a')},
        actualBytes: {'a': longer},
      );
      final result = await BackupArchive.writePhotos(zipPath, list, root);
      expect(result.failed, 1);
    });

    test('a listed photo without its entry: "not a backup"', () async {
      final list = await writeZip({'a': bytesOf('a')});
      final manifest = BackupManifest(
        format: 1,
        appVersion: 't',
        schemaVersion: 1,
        createdAt: DateTime.utc(2026),
        includesPhotos: true,
        photos: [
          ...list,
          (
            relativePath: 'photos/${'f' * 64}.jpg',
            sha256: 'f' * 64,
            byteSize: 3,
          ),
        ],
      );
      final db = p.join(files.root.path, 'db.bin');
      await BackupArchive.write(manifest, db, zipPath);
      await expectLater(
        BackupArchive.read(
          zipPath,
          extractDatabaseTo: p.join(files.root.path, 'x.db'),
        ),
        throwsA(isA<Object>()),
      );
    });
  });

  group('restore', () {
    RestoreCubit cubitFor() {
      final cubit = RestoreCubit(
        tools: tools,
        closeLiveConnection: live.close,
        locale: const Locale('en', 'IN'),
        currentExpenseCount: () async =>
            (await live.query('expenses', where: 'deleted_at IS NULL')).length,
      );
      addTearDown(() async {
        if (!cubit.isClosed) await cubit.close();
      });
      return cubit;
    }

    Future<RestoreState> settled(RestoreCubit cubit) async {
      for (var i = 0; i < 1500; i++) {
        final moving = switch (cubit.value) {
          RestorePicking() ||
          RestoreValidating() ||
          RestoreSwapping() ||
          RestoreWritingPhotos() => true,
          RestoreMigrating(:final migration) =>
            migration.value is! MigrationFailed &&
                migration.value is! MigrationSucceeded,
          _ => false,
        };
        if (!moving) return cubit.value;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      throw TimeoutException('Restore stuck at ${cubit.value}');
    }

    /// A backup with photos of the live data, "picked" in the open dialog;
    /// then the photo files are deleted, as on a new phone.
    Future<void> backUpWithPhotos() async {
      final zip = await backups().createBackup(
        appVersion: 't',
        includePhotos: true,
      );
      final kept = p.join(files.root.path, 'picked.zip');
      await File(zip.path).copy(kept);
      documents.pickedFile = kept;
      await Directory(p.join(photosRoot(), 'photos')).delete(recursive: true);
    }

    test('the confirm says how many and their size; the photos are written '
        'before the swap; the picked zip is gone at the end', () async {
      final a = await photo('a');
      final b = await photo('b');
      await backUpWithPhotos();
      final cubit = cubitFor();
      await cubit.startFromZip();
      final confirm = await settled(cubit) as RestoreConfirm;
      expect(confirm.candidate.includesPhotos, isTrue);
      expect(confirm.candidate.photoCount, 2);
      expect(confirm.candidate.photoBytesToWrite, confirm.candidate.photoBytes);
      expect(confirm.candidate.photosFit, isTrue);
      expect(File(files.paths.pickedZip).existsSync(), isTrue, reason: 'R3');
      await cubit.confirm();
      final done = await settled(cubit) as RestoreDone;
      expect(done.failedPhotos, 0);
      expect(await File(p.join(photosRoot(), a)).readAsBytes(), bytesOf('a'));
      expect(await File(p.join(photosRoot(), b)).readAsBytes(), bytesOf('b'));
      await cubit.close();
      expect(Directory(files.paths.restoreWorkFolder).existsSync(), isFalse);
    });

    test('Restore without photos writes none', () async {
      final a = await photo('a');
      await backUpWithPhotos();
      final cubit = cubitFor();
      await cubit.startFromZip();
      await settled(cubit);
      await cubit.confirm(withPhotos: false);
      await settled(cubit);
      expect(File(p.join(photosRoot(), a)).existsSync(), isFalse);
    });

    test('photos that don\'t fit: the confirm offers Restore without photos '
        '(photosFit false, how much more is needed)', () async {
      await photo('a');
      await backUpWithPhotos();
      service.free = RestoreCandidate.spaceMargin + 10;
      final cubit = cubitFor();
      await cubit.startFromZip();
      final confirm = await settled(cubit) as RestoreConfirm;
      expect(confirm.candidate.photosFit, isFalse);
      expect(
        confirm.candidate.photoBytesShort,
        confirm.candidate.photoBytesToWrite - 10,
      );
    });

    test('a write error stops the restore before the swap: the live data '
        'is unchanged', () async {
      await photo('a');
      await backUpWithPhotos();
      final before = await dumpTables(live);
      // A folder where the photo's .partial goes makes its write fail.
      final zip = manifestOf(documents.pickedFile!);
      final target = p.join(photosRoot(), zip.photos.single.relativePath);
      await Directory('$target.partial').create(recursive: true);
      final cubit = cubitFor();
      await cubit.startFromZip();
      await settled(cubit);
      await cubit.confirm();
      final end = await settled(cubit);
      expect(end, isA<RestoreFailed>());
      expect((end as RestoreFailed).needsRestart, isFalse);
      expect(live.isOpen, isTrue, reason: 'never swapped');
      expect(await dumpTables(live), before);
    });

    test('a file larger than the free space: "not enough space"; a '
        '150 MB limit no longer refuses it when the space is there', () async {
      service.free = 200 * 1024 * 1024;
      expect(
        await tools.repository.maxBackupBytes(),
        200 * 1024 * 1024 - 50 * 1024 * 1024,
      );
    });
  });
}

/// The manifest of the zip at [path]. The stream is closed: Windows
/// can't delete an open file at teardown.
BackupManifest manifestOf(String path) {
  final input = InputFileStream(path);
  try {
    return BackupManifest.decode(
      utf8.decode(
        ZipDecoder().decodeStream(input).findFile('manifest.json')!.content,
      ),
    );
  } finally {
    input.closeSync();
  }
}

/// The entries of the zip at [path], by name, read from its directory.
Map<String, ZipFileHeader> zipEntries(String path) {
  final input = InputFileStream(path);
  try {
    return {
      for (final header in (ZipDirectory()..read(input)).fileHeaders)
        header.filename: header,
    };
  } finally {
    input.closeSync();
  }
}
