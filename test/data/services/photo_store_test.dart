import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/photo_service.dart';
import 'package:my_expense_tracker_app/data/services/photo_store.dart';
import 'package:my_expense_tracker_app/domain/photo_sizing.dart';
import 'package:my_expense_tracker_app/domain/photos.dart';
import 'package:path/path.dart' as p;

import '../../helpers/fake_photo_service.dart';
import '../../helpers/test_folders.dart';

/// `PhotoStore` on real files (phase-6.md §6.2, §6.6).
void main() {
  late Directory root;
  late FakePhotoService service;
  late PhotoStore store;
  var now = DateTime.utc(2026, 10, 7, 9);

  setUp(() async {
    root = await testFolder('photo_store');
    service = FakePhotoService();
    now = DateTime.utc(2026, 10, 7, 9);
    store = PhotoStore(root: root.path, service: service, now: () => now);
  });

  List<String> namesIn(String folder) =>
      [for (final f in Directory(folder).listSync()) p.basename(f.path)]
        ..sort();

  const p1080 = (size: PhotoSize.p1080, quality: 85);

  group('staging', () {
    test('a picked 1440 × 1080 JPEG is kept byte for byte at 1080p, its '
        'SHA-256 and size read from the staged file', () async {
      final uri = service.addPicked('content://a');
      final staged = await store.stageFromGallery(uri, p1080);
      expect(service.stages.single.plan, const KeepBytes());
      expect(staged.extension, 'jpg');
      final bytes = File(store.stagingFile(staged.stagingName))
          .readAsBytesSync();
      expect(bytes, service.pictures[uri]!.bytes);
      expect(staged.sha256, sha256.convert(bytes).toString());
      expect(staged.byteSize, bytes.length);
      expect(isValidStagingName(staged.stagingName), isTrue);
    });

    test('a picked 4000 × 3000 is encoded to 1440 × 1080 as JPEG; a PNG '
        'becomes .jpg', () async {
      final big = service.addPicked('content://big', width: 4000, height: 3000);
      final png = service.addPicked(
        'content://png',
        width: 600,
        height: 400,
        mimeType: 'image/png',
      );
      await store.stageFromGallery(big, p1080);
      final staged = await store.stageFromGallery(png, p1080);
      expect(service.stages.map((s) => s.plan), [
        const Encode(width: 1440, height: 1080, quality: 85),
        const Encode(width: 600, height: 400, quality: 85),
      ]);
      expect(staged.extension, 'jpg');
    });

    test('Original keeps a PNG as .png', () async {
      final png = service.addPicked('content://p', mimeType: 'image/png');
      final staged = await store.stageFromGallery(png, (
        size: PhotoSize.original,
        quality: 85,
      ));
      expect(staged.extension, 'png');
    });

    test('the camera: one turn plans on the turned size and passes the '
        'turns; the camera file stays for the caller to delete', () async {
      final name = store.newCaptureName();
      expect(await service.capture(store.stagingFile(name)), isTrue);
      final staged = await store.stageCapture(name, p1080, 1);
      final stage = service.stages.single;
      expect(stage.plan, const Encode(width: 1080, height: 1440, quality: 85));
      expect(stage.quarterTurns, 1);
      expect(File(store.stagingFile(name)).existsSync(), isTrue);
      expect(File(store.stagingFile(staged.stagingName)).existsSync(), isTrue);
    });

    test('a failing stage leaves no file behind and throws', () async {
      final uri = service.addPicked('content://x');
      service.failingSources.add(uri);
      await expectLater(
        store.stageFromGallery(uri, p1080),
        throwsA(isA<PhotoServiceException>()),
      );
      expect(
        namesIn(store.stagingPath).where((n) => !n.startsWith('.')),
        isEmpty,
      );
    });

    test('not an image throws notAnImage', () async {
      await expectLater(
        store.stageFromGallery('content://unknown', p1080),
        throwsA(
          isA<PhotoServiceException>().having(
            (e) => e.error,
            'error',
            PhotoError.notAnImage,
          ),
        ),
      );
    });

    test(
      'both folders are made, with no .nomedia (owner, 2026-10-09)',
      () async {
        await store.stageFromGallery(service.addPicked('content://a'), p1080);
        for (final folder in [store.photosPath, store.stagingPath]) {
          expect(Directory(folder).existsSync(), isTrue);
          expect(File(p.join(folder, '.nomedia')).existsSync(), isFalse);
        }
      },
    );

    test('names are v4 UUIDs and differ', () {
      final names = {for (var i = 0; i < 200; i++) store.newStagingName('jpg')};
      expect(names, hasLength(200));
      for (final n in names) {
        expect(isValidStagingName(n), isTrue, reason: n);
        expect(n[14], '4', reason: 'version 4');
      }
      expect(isValidStagingName(store.newCaptureName()), isTrue);
    });

    test('missingStaged: a gone file and an empty one', () async {
      final a = await store.stageFromGallery(service.addPicked('c://a'), p1080);
      final b = await store.stageFromGallery(service.addPicked('c://b'), p1080);
      final c = await store.stageFromGallery(service.addPicked('c://c'), p1080);
      File(store.stagingFile(a.stagingName)).deleteSync();
      File(store.stagingFile(b.stagingName)).writeAsBytesSync([]);
      expect(await store.missingStaged([a, b, c]), {
        a.stagingName,
        b.stagingName,
      });
    });
  });

  group('promote', () {
    Future<StagedPhoto> staged(String uri) =>
        store.stageFromGallery(service.addPicked(uri), p1080);

    test('copies to photos/<sha>.<ext>, no .partial left, the staged file '
        'kept', () async {
      final photo = await staged('c://a');
      final relative = await store.promote(photo);
      expect(relative, 'photos/${photo.sha256}.jpg');
      final saved = File(p.join(root.path, relative));
      expect(saved.readAsBytesSync(), service.pictures['c://a']!.bytes);
      expect(namesIn(store.photosPath), ['${photo.sha256}.jpg']);
      expect(File(store.stagingFile(photo.stagingName)).existsSync(), isTrue);
    });

    test('the same picture twice is copied once', () async {
      final photo = await staged('c://a');
      await store.promote(photo);
      final saved = File(p.join(root.path, photo.savedPath));
      final first = saved.lastModifiedSync();
      saved.setLastModifiedSync(first.subtract(const Duration(days: 1)));
      final stamp = saved.lastModifiedSync();
      await store.promote(photo);
      expect(saved.lastModifiedSync(), stamp, reason: 'not rewritten');
    });

    test('another size at the path is not this picture: replaced', () async {
      final photo = await staged('c://a');
      Directory(store.photosPath).createSync(recursive: true);
      File(p.join(root.path, photo.savedPath)).writeAsStringSync('junk!');
      await store.promote(photo);
      expect(
        File(p.join(root.path, photo.savedPath)).readAsBytesSync(),
        service.pictures['c://a']!.bytes,
      );
    });

    test('a failing copy throws, leaves nothing at the path, and the '
        'staged file intact', () async {
      final photo = await staged('c://a');
      final stagedFile = File(store.stagingFile(photo.stagingName));
      final bytes = stagedFile.readAsBytesSync();
      // A folder where the .partial goes makes the copy fail.
      Directory(store.photosPath).createSync(recursive: true);
      Directory(p.join(root.path, '${photo.savedPath}.partial')).createSync();
      await expectLater(
        store.promote(photo),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(p.join(root.path, photo.savedPath)).existsSync(), isFalse);
      expect(stagedFile.readAsBytesSync(), bytes);
    });
  });

  group('paths', () {
    test('pathOf refuses crafted paths and names', () {
      final crafted = SavedPhoto(
        id: 1,
        relativePath: '../databases/expense_tracker.db',
        sha256: 'a' * 64,
        byteSize: 1,
      );
      expect(store.pathOf(crafted), isNull);
      expect(
        store.pathOf(
          const StagedPhoto(stagingName: '../x.jpg', sha256: 'a', byteSize: 1),
        ),
        isNull,
      );
      expect(() => store.stagingFile('../../x'), throwsArgumentError);
    });

    test('without a photo folder every photo is missing', () {
      final none = PhotoStore(root: null, service: service);
      expect(none.isAvailable, isFalse);
      expect(
        none.pathOf(
          SavedPhoto(
            id: 1,
            relativePath: 'photos/${'a' * 64}.jpg',
            sha256: 'a' * 64,
            byteSize: 1,
          ),
        ),
        isNull,
      );
    });
  });

  group('the camera marker', () {
    test('round trip; cleared', () async {
      final name = store.newCaptureName();
      await store.markPendingCapture(name, 7);
      expect(await store.pendingCapture(), (
        name: name,
        editingExpenseId: 7,
        at: now,
      ));
      await store.markPendingCapture(name, null);
      expect((await store.pendingCapture())!.editingExpenseId, isNull);
      await store.clearPendingCapture();
      expect(await store.pendingCapture(), isNull);
    });

    test('an unreadable or crafted marker reads as none', () async {
      Directory(store.stagingPath).createSync(recursive: true);
      final marker = File(p.join(store.stagingPath, PhotoStore.markerName));
      for (final text in [
        '{',
        '[]',
        jsonEncode({
          'name': '../x.jpg',
          'editing_expense_id': null,
          'at': '2026-10-07T09:00:00Z',
        }),
        jsonEncode({
          'name': 'capture-0f8fad5b-d9cb-469f-a165-70867728950e.jpg',
          'editing_expense_id': 'x',
          'at': '2026',
        }),
      ]) {
        marker.writeAsStringSync(text);
        expect(await store.pendingCapture(), isNull, reason: text);
      }
    });
  });

  group('Save to Pictures (§6.6)', () {
    Future<PictureToSave> item(String uri, String title, String day) async {
      final photo = await store.stageFromGallery(service.addPicked(uri), p1080);
      return (
        photo: photo,
        title: title,
        day: day,
        wallClock: DateTime.utc(2026, 10, 5, 13, 30),
        utcOffsetMinutes: 330,
        moment: DateTime.utc(2026, 10, 5, 8),
      );
    }

    test('three photos: three inserts, in order, named per §5.9, dated on '
        'each expense', () async {
      final items = [
        await item('c://a', 'Lunch', '2026-10-05'),
        await item('c://b', 'Taxi', '2026-10-05'),
        await item('c://c', 'Rent: Oct', '2026-10-01'),
      ];
      final progress = <(int, int)>[];
      final result = await store.saveToPictures(
        items,
        fallbackTitle: 'Expense',
        onProgress: (done, total) => progress.add((done, total)),
      );
      expect(result, (saved: 3, missing: 0, failed: 0, noSpace: false));
      expect(
        [for (final s in service.savedPictures) s.name],
        [
          'Lunch 2026-10-05.jpg',
          'Taxi 2026-10-05.jpg',
          'Rent Oct 2026-10-01.jpg',
        ],
      );
      final first = service.savedPictures.first;
      expect(first.dateTaken, DateTime.utc(2026, 10, 5, 8));
      expect(first.exifDateTime, '2026:10:05 13:30:00');
      expect(first.exifOffset, '+05:30');
      expect(first.mimeType, 'image/jpeg');
      expect(progress.last, (3, 3));
    });

    test('a name already there gets "(1)"; the old one untouched', () async {
      final a = await item('c://a', 'Lunch', '2026-10-05');
      await store.saveToPictures([a], fallbackTitle: 'Expense');
      final before = service.savedPictures.first;
      await store.saveToPictures([a], fallbackTitle: 'Expense');
      expect(service.savedPictures.map((s) => s.name), [
        'Lunch 2026-10-05.jpg',
        'Lunch 2026-10-05 (1).jpg',
      ]);
      expect(service.savedPictures.first, same(before));
    });

    test('a missing file is skipped and counted; a failing insert counted; '
        'the rest saved', () async {
      final a = await item('c://a', 'A', '2026-10-05');
      final b = await item('c://b', 'B', '2026-10-05');
      final c = await item('c://c', 'C', '2026-10-05');
      File(store.pathOf(a.photo)!).deleteSync();
      service.failingSaves.add('B 2026-10-05.jpg');
      final result = await store.saveToPictures([a, b, c], fallbackTitle: 'E');
      expect(result, (saved: 1, missing: 1, failed: 1, noSpace: false));
      expect(service.savedPictures.single.name, 'C 2026-10-05.jpg');
    });

    test('no space: nothing inserted', () async {
      final a = await item('c://a', 'A', '2026-10-05');
      service.free = a.photo.byteSize + PhotoStore.saveMargin;
      final result = await store.saveToPictures([a], fallbackTitle: 'E');
      expect(result.noSpace, isTrue);
      expect(service.calls, isNot(contains('saveToPictures')));
    });

    test("free space that can't be read doesn't stop the save (as for a "
        'backup); a save that then fails is counted', () async {
      final a = await item('c://a', 'A', '2026-10-05');
      final b = await item('c://b', 'B', '2026-10-05');
      service.errors['freeBytes'] = const PhotoServiceException(
        PhotoError.ioError,
      );
      service.failingSaves.add('B 2026-10-05.jpg');
      final result = await store.saveToPictures([a, b], fallbackTitle: 'E');
      expect(result, (saved: 1, missing: 0, failed: 1, noSpace: false));
    });

    test('a staged (unsaved) photo saves too, as stored; an untitled one '
        'is "Expense"', () async {
      final a = await item('c://a', '   ', '2026-10-05');
      await store.saveToPictures([a], fallbackTitle: 'Expense');
      expect(service.savedPictures.single.name, 'Expense 2026-10-05.jpg');
      expect(
        service.savedPictures.single.bytes,
        service.pictures['c://a']!.bytes,
      );
    });
  });
}
