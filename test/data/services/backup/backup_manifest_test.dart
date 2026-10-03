import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/backup/backup_manifest.dart';

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
      'a JSON string': '"expense_tracker"',
      'JSON null': 'null',
      'not JSON': '{"app": "expense_tracker", ',
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
        () =>
            BackupManifest.decode('{"app": "expense_tracker", "format": null}'),
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
    expect(text, contains('"app": "expense_tracker"'));
    expect(text, contains('"includes_photos": false'));
    final back = BackupManifest.decode(text);
    expect(back.createdAt, DateTime.utc(2026, 10, 3, 8, 35, 12));
  });
}
