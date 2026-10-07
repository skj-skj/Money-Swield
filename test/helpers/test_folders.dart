import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Where tests put real files: the project's own `.dart_tool/test_tmp`
/// (git-ignored), not the system temp folder.
///
/// On Windows the virus scanner checks every file a test writes, which made
/// the database-file tests slow (`dart_test.yaml`). This one folder can be
/// excluded from Windows Defender's real-time scan on its own; excluding
/// all of `%TEMP%` would also stop scanning what browsers and installers
/// drop there.
final testFilesRoot = p.join(Directory.current.path, '.dart_tool', 'test_tmp');

/// A new, empty folder for one test's files, deleted when the test ends.
Future<Directory> testFolder(String prefix) async {
  final root = Directory(testFilesRoot);
  await root.create(recursive: true);
  final folder = await root.createTemp(prefix);
  addTearDown(() async {
    if (folder.existsSync()) await folder.delete(recursive: true);
  });
  return folder;
}
