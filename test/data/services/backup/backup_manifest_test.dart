import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/data/services/backup/backup_manifest.dart';

import 'zip_test_helpers.dart';

void main() {
  group('decode refuses what isn\'t one of our manifests', () {
    final cases = <String, String>{
      'format as text': manifestJson({'format': '1'}),
      'format as a fraction': manifestJson({'format': 1.5}),
      'format missing': manifestJson({'format': null}),
      'app as a number': manifestJson({'app': 7}),
      'app missing': manifestJson({'app': null}),
      'app of another program': manifestJson({'app': 'something_else'}),
      'a JSON array': '[1, 2, 3]',
      'a JSON string': '"money_swield"',
      'JSON null': 'null',
      'not JSON': '{"app": "money_swield", ',
      'empty': '',
    };
    for (final MapEntry(key: name, value: text) in cases.entries) {
      test(name, () {
        expect(
          () => BackupManifest.decode(text),
          throwsA(isA<FormatException>()),
        );
      });
    }

    test('"format": null (present but null)', () {
      expect(
        () => BackupManifest.decode('{"app": "money_swield", "format": null}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('a missing or unreadable created_at still decodes, as null', () {
    expect(
      BackupManifest.decode(manifestJson({'created_at': null})).createdAt,
      isNull,
    );
    expect(
      BackupManifest.decode(manifestJson({'created_at': 'yesterday'}))
          .createdAt,
      isNull,
    );
    expect(
      BackupManifest.decode(manifestJson({'created_at': 12345})).createdAt,
      isNull,
    );
  });

  test('a created_at in the future is kept as it is', () {
    final manifest = BackupManifest.decode(
      manifestJson({'created_at': '2099-01-01T00:00:00Z'}),
    );
    expect(manifest.createdAt, DateTime.utc(2099));
  });

  test('created_at with an offset is read as the same moment in UTC', () {
    final manifest = BackupManifest.decode(
      manifestJson({'created_at': '2026-10-03T14:05:12+05:30'}),
    );
    expect(manifest.createdAt, DateTime.utc(2026, 10, 3, 8, 35, 12));
    expect(manifest.createdAt!.isUtc, isTrue);
  });

  test('a newer format still decodes (the caller rejects it)', () {
    expect(BackupManifest.decode(manifestJson({'format': 2})).format, 2);
  });

  test('wrong types in optional fields are dropped, not fatal', () {
    final manifest = BackupManifest.decode(
      manifestJson({'app_version': 3, 'schema_version': '17'}),
    );
    expect(manifest.appVersion, '');
    expect(manifest.schemaVersion, isNull);
  });

  test('encode writes created_at as ISO-8601 UTC text', () {
    final text = BackupManifest(
      format: 1,
      appVersion: '1.0.0+1',
      schemaVersion: 5,
      // A local time: must still be written in UTC.
      // With milliseconds, which aren't written.
      createdAt: DateTime.utc(2026, 10, 3, 8, 35, 12, 345).toLocal(),
    ).encode();
    expect(text, contains('"created_at": "2026-10-03T08:35:12Z"'));
    expect(text, contains('"app": "money_swield"'));
    expect(text, contains('"includes_photos": false'));
    final back = BackupManifest.decode(text);
    expect(back.createdAt, DateTime.utc(2026, 10, 3, 8, 35, 12));
  });

  group('photos', () {
    final a = 'a' * 64;
    final b = 'b' * 64;
    Map<String, Object?> entry(String sha, {String? path, Object? size = 10}) =>
        {
          'relative_path': path ?? 'photos/$sha.jpg',
          'sha256': sha,
          'byte_size': size,
        };

    test('round trip', () {
      final manifest = BackupManifest(
        format: 1,
        appVersion: '1.0.0+1',
        schemaVersion: 1,
        createdAt: DateTime.utc(2026, 10, 7),
        includesPhotos: true,
        photos: [
          (relativePath: 'photos/$a.jpg', sha256: a, byteSize: 10),
          (
            relativePath: 'photos/$b.png',
            sha256: b,
            byteSize: 64 * 1024 * 1024,
          ),
        ],
      );
      final back = BackupManifest.decode(manifest.encode());
      expect(back.includesPhotos, isTrue);
      expect(back.photos, manifest.photos);
    });

    test('an older manifest (no includes_photos) is database-only', () {
      final back = BackupManifest.decode(
        manifestJson({'includes_photos': null}),
      );
      expect(back.includesPhotos, isFalse);
      expect(back.photos, isEmpty);
    });

    test('includes_photos false with junk in photos is accepted, the list '
        'ignored', () {
      final back = BackupManifest.decode(
        manifestJson({
          'includes_photos': false,
          'photos': [5, 'x', entry('nope')],
        }),
      );
      expect(back.photos, isEmpty);
    });

    final rejections = <String, Map<String, Object?>>{
      'includes_photos not a bool': {'includes_photos': 'yes'},
      'photos not a list': {'includes_photos': true, 'photos': 'x'},
      'photos missing': {'includes_photos': true, 'photos': null},
      'an entry not an object': {
        'includes_photos': true,
        'photos': ['photos/$a.jpg'],
      },
      'a crafted path': {
        'includes_photos': true,
        'photos': [entry(a, path: '../databases/money_swield.db')],
      },
      'a path that names another hash': {
        'includes_photos': true,
        'photos': [entry(a, path: 'photos/$b.jpg')],
      },
      'an upper-case hash': {
        'includes_photos': true,
        'photos': [entry('A' * 64, path: 'photos/${'A' * 64}.jpg')],
      },
      'a size of 0': {
        'includes_photos': true,
        'photos': [entry(a, size: 0)],
      },
      'a size over 64 MB': {
        'includes_photos': true,
        'photos': [entry(a, size: 64 * 1024 * 1024 + 1)],
      },
      'a size as text': {
        'includes_photos': true,
        'photos': [entry(a, size: '10')],
      },
      'the same path twice': {
        'includes_photos': true,
        'photos': [entry(a), entry(a)],
      },
    };
    for (final MapEntry(key: name, value: fields) in rejections.entries) {
      test('refused: $name', () {
        expect(
          () => BackupManifest.decode(manifestJson(fields)),
          throwsA(isA<FormatException>()),
        );
      });
    }

    test('1,000 entries stay far below 16 MB', () {
      final manifest = BackupManifest(
        format: 1,
        appVersion: '1.0.0+1',
        schemaVersion: 1,
        createdAt: DateTime.utc(2026),
        includesPhotos: true,
        photos: [
          for (var i = 0; i < 1000; i++)
            (
              relativePath:
                  'photos/${i.toRadixString(16).padLeft(64, '0')}.jpg',
              sha256: i.toRadixString(16).padLeft(64, '0'),
              byteSize: 5 * 1024 * 1024,
            ),
        ],
      );
      expect(manifest.encode().length, lessThan(16 * 1024 * 1024));
      expect(BackupManifest.decode(manifest.encode()).photos, hasLength(1000));
    });
  });
}
