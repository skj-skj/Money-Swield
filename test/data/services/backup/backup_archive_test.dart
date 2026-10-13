import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/data/services/backup/backup_archive.dart';
import 'package:money_swield/data/services/backup/backup_manifest.dart';
import 'package:money_swield/domain/models/restore_candidate.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/test_folders.dart';
import 'zip_test_helpers.dart';

void main() {
  late Directory folder;
  late String zipPath;
  late String extractTo;

  setUp(() async {
    folder = await testFolder('backup_archive_test');
    zipPath = p.join(folder.path, 'backup.zip');
    // Nested, so an entry named "../evil" would land inside [folder].
    final extractFolder = Directory(p.join(folder.path, 'out', 'restore'));
    await extractFolder.create(recursive: true);
    extractTo = p.join(extractFolder.path, 'candidate.db');
  });

  final databaseBytes = Uint8List.fromList([
    for (var i = 0; i < 5000; i++) i * 7 % 251,
  ]);

  Future<void> writeZip(List<ZipEntry> entries) =>
      File(zipPath).writeAsBytes(buildZip(entries));

  Future<BackupManifest> read({int? maxDatabaseBytes}) => BackupArchive.read(
    zipPath,
    extractDatabaseTo: extractTo,
    maxDatabaseBytes: maxDatabaseBytes ?? BackupArchive.maxDatabaseBytes,
  );

  /// Expects [read] to reject the zip for [reason] and to leave no
  /// extracted file behind.
  Future<void> expectRejected(
    RestoreRejection reason, {
    int? maxDatabaseBytes,
  }) async {
    await expectLater(
      read(maxDatabaseBytes: maxDatabaseBytes),
      throwsA(isA<RestoreRejected>().having((e) => e.reason, 'reason', reason)),
    );
    expect(File(extractTo).existsSync(), isFalse, reason: 'partial file left');
  }

  group('round trip', () {
    test('write then read gives the manifest and the same bytes', () async {
      final source = p.join(folder.path, 'source.db');
      await File(source).writeAsBytes(databaseBytes);
      final createdAt = DateTime.utc(2026, 10, 3, 8, 35, 12);
      await BackupArchive.write(
        BackupManifest(
          format: 1,
          appVersion: '1.0.0+1',
          schemaVersion: 42,
          createdAt: createdAt,
        ),
        source,
        zipPath,
      );

      final manifest = await read();

      expect(manifest.format, 1);
      expect(manifest.appVersion, '1.0.0+1');
      expect(manifest.schemaVersion, 42);
      expect(manifest.createdAt, createdAt);
      expect(await File(extractTo).readAsBytes(), databaseBytes);
    });

    test('entries are manifest.json then money_swield.db', () async {
      final source = p.join(folder.path, 'source.db');
      await File(source).writeAsBytes(databaseBytes);
      await BackupArchive.write(
        BackupManifest(
          format: 1,
          appVersion: 'x',
          schemaVersion: null,
          createdAt: DateTime.utc(2026),
        ),
        source,
        zipPath,
      );
      final bytes = await File(zipPath).readAsBytes();
      expect(
        dataOffsetOf(bytes, 'manifest.json'),
        lessThan(dataOffsetOf(bytes, 'money_swield.db')),
      );
    });

    test('unknown entries are ignored; "../evil" is never written', () async {
      await writeZip([
        textEntry('../evil', 'x'),
        textEntry('manifest.json', manifestJson()),
        textEntry('notes.txt', 'hello'),
        entry('money_swield.db', databaseBytes),
        textEntry('../../evil2', 'y'),
      ]);

      await read();

      expect(await File(extractTo).readAsBytes(), databaseBytes);
      final written = folder
          .listSync(recursive: true)
          .map((e) => p.basename(e.path))
          .toSet();
      expect(written, isNot(contains('evil')));
      expect(written, isNot(contains('evil2')));
      expect(written, isNot(contains('notes.txt')));
    });

    test('an uncompressed (stored) database entry reads too', () async {
      await writeZip([
        textEntry('manifest.json', manifestJson()),
        entry('money_swield.db', databaseBytes, stored: true),
      ]);
      await read();
      expect(await File(extractTo).readAsBytes(), databaseBytes);
    });
  });

  group('limits', () {
    test('a manifest.json over 64 KB is refused', () async {
      await writeZip([
        textEntry(
          'manifest.json',
          manifestJson({'padding': 'x' * BackupArchive.maxManifestBytes}),
        ),
        entry('money_swield.db', databaseBytes),
      ]);
      await expectRejected(RestoreRejection.notABackup);
    });

    test('a database entry declaring more than the limit is refused', () async {
      await writeZip([
        textEntry('manifest.json', manifestJson()),
        entry('money_swield.db', databaseBytes),
      ]);
      await expectRejected(RestoreRejection.notABackup, maxDatabaseBytes: 4999);
    });

    test('a database entry that lies about its size is stopped while '
        'streaming, and the partial file is deleted', () async {
      // Highly compressible, like a zip bomb: 2 MB of zeros declared as 10
      // bytes.
      final bomb = Uint8List(2 * 1024 * 1024);
      final zip = buildZip([
        textEntry('manifest.json', manifestJson()),
        entry('money_swield.db', bomb),
      ]);
      patchDeclaredSize(zip, 'money_swield.db', 10);
      await File(zipPath).writeAsBytes(zip);

      await expectRejected(
        RestoreRejection.notABackup,
        maxDatabaseBytes: 1024 * 1024,
      );
    });

    test('a manifest that lies about its size is stopped too', () async {
      final zip = buildZip([
        textEntry(
          'manifest.json',
          // Over the limit (16 MB).
          manifestJson({'padding': ' ' * BackupArchive.maxManifestBytes}),
        ),
        entry('money_swield.db', databaseBytes),
      ]);
      patchDeclaredSize(zip, 'manifest.json', 10);
      await File(zipPath).writeAsBytes(zip);
      await expectRejected(RestoreRejection.notABackup);
    });

    test('two money_swield.db entries are refused', () async {
      await writeZip([
        textEntry('manifest.json', manifestJson()),
        entry('money_swield.db', databaseBytes),
        entry('money_swield.db', [1, 2, 3]),
      ]);
      await expectRejected(RestoreRejection.notABackup);
    });

    test('two manifest.json entries are refused', () async {
      await writeZip([
        textEntry('manifest.json', manifestJson()),
        textEntry('manifest.json', manifestJson({'format': 9})),
        entry('money_swield.db', databaseBytes),
      ]);
      await expectRejected(RestoreRejection.notABackup);
    });
  });

  group('damage', () {
    Future<void> flipDatabaseByte({required bool stored}) async {
      final zip = buildZip([
        textEntry('manifest.json', manifestJson()),
        entry('money_swield.db', databaseBytes, stored: stored),
      ]);
      zip[dataOffsetOf(zip, 'money_swield.db') + 3] ^= 0x40;
      await File(zipPath).writeAsBytes(zip);
    }

    test('one flipped byte in a stored database entry fails the CRC', () async {
      await flipDatabaseByte(stored: true);
      await expectRejected(RestoreRejection.damaged);
    });

    test('one flipped byte in a deflated database entry is damage', () async {
      await flipDatabaseByte(stored: false);
      await expectRejected(RestoreRejection.damaged);
    });

    test('a zip cut short is not read as a backup', () async {
      final zip = buildZip([
        textEntry('manifest.json', manifestJson()),
        entry('money_swield.db', databaseBytes),
      ]);
      await File(zipPath).writeAsBytes(zip.sublist(0, zip.length ~/ 2));
      await expectLater(read(), throwsA(isA<RestoreRejected>()));
      expect(File(extractTo).existsSync(), isFalse);
    });
  });

  group('not a backup', () {
    test('random bytes', () async {
      await File(zipPath).writeAsBytes(databaseBytes);
      await expectRejected(RestoreRejection.notABackup);
    });

    test('an empty file', () async {
      await File(zipPath).writeAsBytes([]);
      await expectRejected(RestoreRejection.notABackup);
    });

    test('a zip without manifest.json', () async {
      await writeZip([entry('money_swield.db', databaseBytes)]);
      await expectRejected(RestoreRejection.notABackup);
    });

    test('a zip without money_swield.db', () async {
      await writeZip([textEntry('manifest.json', manifestJson())]);
      await expectRejected(RestoreRejection.notABackup);
    });

    test('a manifest from another app', () async {
      await writeZip([
        textEntry('manifest.json', manifestJson({'app': 'other_app'})),
        entry('money_swield.db', databaseBytes),
      ]);
      await expectRejected(RestoreRejection.notABackup);
    });
  });

  test('format 2 is "made by a newer version"', () async {
    await writeZip([
      textEntry('manifest.json', manifestJson({'format': 2})),
      entry('money_swield.db', databaseBytes),
    ]);
    await expectRejected(RestoreRejection.tooNew);
  });
}
