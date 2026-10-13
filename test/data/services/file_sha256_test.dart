import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/data/services/file_sha256.dart';
import 'package:path/path.dart' as p;

import '../../helpers/test_folders.dart';

/// The one SHA-256 of staging, backups and restores.
void main() {
  test(
    'a file larger than one chunk: its hash, sync and on an isolate',
    () async {
      final folder = await testFolder('file_sha256');
      final path = p.join(folder.path, 'big.bin');
      final bytes = [for (var i = 0; i < 200 * 1024 + 7; i++) i % 251];
      await File(path).writeAsBytes(bytes);
      final expected = sha256.convert(bytes).toString();
      expect(sha256OfFileSync(path), expected);
      expect(await sha256OfFile(path), expected);
    },
  );

  test('Sha256Builder: chunks added in order hash like the whole', () {
    final builder = Sha256Builder()
      ..add(utf8.encode('picture '))
      ..add(utf8.encode('a'));
    expect(
      builder.close(),
      sha256.convert(utf8.encode('picture a')).toString(),
    );
  });

  test('an empty file is the hash of nothing', () async {
    final folder = await testFolder('file_sha256_empty');
    final path = p.join(folder.path, 'empty.bin');
    await File(path).writeAsBytes(const []);
    expect(sha256OfFileSync(path), sha256.convert(const []).toString());
  });
}
