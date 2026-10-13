import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/photos.dart';

void main() {
  final sha = 'a' * 64;

  group('isValidPhotoPath (every row)', () {
    for (final (path, valid) in [
      ('photos/$sha.jpg', true),
      ('photos/$sha.png', true),
      ('photos/$sha.webp', true),
      ('photos/$sha.gif', true),
      ('photos/$sha.JPG', false),
      ('photos/${'a' * 63}.jpg', false),
      ('photos/${'a' * 65}.jpg', false),
      ('photos/${'A' * 64}.jpg', false),
      ('photos/../databases/x.jpg', false),
      ('../databases/money_swield.db', false),
      ('/storage/emulated/0/photos/$sha.jpg', false),
      (
        r'photos\'
            '$sha.jpg',
        false,
      ),
      ('photos/$sha.heic', false),
      ('photos/sub/$sha.jpg', false),
      ('photos/$sha.jpg\n', false),
      ('photos_staging/$sha.jpg', false),
      ('', false),
    ]) {
      test('${path.replaceAll('\n', r'\n')} → $valid', () {
        expect(isValidPhotoPath(path), valid);
      });
    }
  });

  group('isValidStagingName', () {
    const uuid = '0f8fad5b-d9cb-469f-a165-70867728950e';
    for (final (name, valid) in [
      ('$uuid.jpg', true),
      ('capture-$uuid.jpg', true),
      ('preview-$uuid.jpg', true),
      ('$uuid.png', true),
      ('${uuid.toUpperCase()}.jpg', false),
      ('other-$uuid.jpg', false),
      ('$uuid.jpg.partial', false),
      ('$uuid.heic', false),
      ('../$uuid.jpg', false),
      ('pending_capture.json', false),
      ('.nomedia', false),
      ('', false),
      ('${'a' * 1000}.jpg', false),
    ]) {
      test(
        '${name.length > 60 ? '${name.substring(0, 20)}…' : name} → '
        '$valid',
        () => expect(isValidStagingName(name), valid),
      );
    }
  });

  StagedPhoto p(String letter) => StagedPhoto(
    stagingName: '0f8fad5b-d9cb-469f-a165-70867728950$letter.jpg',
    sha256: letter * 64,
    byteSize: 10,
  );
  List<String> shas(List<FormPhoto> photos) => [
    for (final photo in photos) photo.sha256[0],
  ];

  group('addPhotos (every row)', () {
    test('[] + [A, B] → [A, B]', () {
      final out = addPhotos([], [p('a'), p('b')]);
      expect(shas(out.photos), ['a', 'b']);
      expect((out.duplicates, out.overflow), (0, 0));
    });

    test('[A] + [A] → [A], one duplicate', () {
      final out = addPhotos([p('a')], [p('a')]);
      expect(shas(out.photos), ['a']);
      expect((out.duplicates, out.overflow), (1, 0));
    });

    test('[A] + [B, B] → [A, B], one duplicate', () {
      final out = addPhotos([p('a')], [p('b'), p('b')]);
      expect(shas(out.photos), ['a', 'b']);
      expect((out.duplicates, out.overflow), (1, 0));
    });

    test('9 + [X, Y] → 10 (X), one overflow', () {
      final nine = [for (final c in '012345678'.split('')) p(c)];
      final out = addPhotos(nine, [p('x'), p('y')]);
      expect(out.photos, hasLength(10));
      expect(shas(out.photos).last, 'x');
      expect((out.duplicates, out.overflow), (0, 1));
    });

    test('10 + [X] → unchanged, one overflow', () {
      final ten = [for (final c in '0123456789'.split('')) p(c)];
      final out = addPhotos(ten, [p('x')]);
      expect(shas(out.photos), shas(ten));
      expect(out.overflow, 1);
    });

    test('12 (a damaged draft) + [X] → the 12 kept, never cut', () {
      final twelve = [for (final c in '0123456789ab'.split('')) p(c)];
      final out = addPhotos(twelve, [p('x')]);
      expect(out.photos, hasLength(12));
      expect((out.duplicates, out.overflow), (0, 1));
    });

    test('a saved and a staged photo with the same SHA-256 are the same '
        'picture', () {
      final saved = SavedPhoto(
        id: 3,
        relativePath: 'photos/${'a' * 64}.jpg',
        sha256: 'a' * 64,
        byteSize: 10,
      );
      final out = addPhotos([saved], [p('a')]);
      expect(out.photos, [saved]);
      expect(out.duplicates, 1);
    });
  });

  group('removePhotos', () {
    final abcd = [p('a'), p('b'), p('c'), p('d')];
    test('[A, B, C, D] − {0, 2} → [B, D]', () {
      expect(shas(removePhotos(abcd, {0, 2})), ['b', 'd']);
    });
    test('[A, B] − {} → [A, B]', () {
      expect(shas(removePhotos(abcd.take(2).toList(), {})), ['a', 'b']);
    });
    test('[A] − {5} → RangeError', () {
      expect(() => removePhotos([p('a')], {5}), throwsRangeError);
      expect(() => removePhotos([p('a')], {-1}), throwsRangeError);
    });
  });

  test('remainingPhotoSlots: 10 − n, 0 when full or over', () {
    List<FormPhoto> n(int count) => [
      for (var i = 0; i < count; i++) p(i.toRadixString(16)),
    ];
    expect(remainingPhotoSlots(n(0)), 10);
    expect(remainingPhotoSlots(n(9)), 1);
    expect(remainingPhotoSlots(n(10)), 0);
    expect(remainingPhotoSlots(n(12)), 0);
  });

  test('samePhotos compares SHA-256s in order', () {
    expect(samePhotos([p('a'), p('b')], [p('a'), p('b')]), isTrue);
    expect(samePhotos([p('a'), p('b')], [p('b'), p('a')]), isFalse);
    expect(samePhotos([p('a')], [p('a'), p('b')]), isFalse);
    expect(samePhotos([], []), isTrue);
    final restaged = StagedPhoto(
      stagingName: '1f8fad5b-d9cb-469f-a165-70867728950a.jpg',
      sha256: 'a' * 64,
      byteSize: 10,
    );
    expect(samePhotos([p('a')], [restaged]), isTrue);
  });

  test('extensions and saved paths', () {
    expect(p('a').extension, 'jpg');
    expect(p('a').savedPath, 'photos/${'a' * 64}.jpg');
    expect(
      SavedPhoto(
        id: 1,
        relativePath: 'photos/$sha.webp',
        sha256: sha,
        byteSize: 1,
      ).extension,
      'webp',
    );
  });
}
