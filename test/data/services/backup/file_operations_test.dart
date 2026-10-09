import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/backup/file_operations.dart';

void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('file_ops'));
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  // Seen on the Oppo after a restore: the restarted app's leftover cleanup
  // and the closing restore screen both deleted cache/restore, and the
  // loser logged "Deletion failed … No such file or directory".
  test('two deletes of one folder at once both succeed', () async {
    final folder = Directory('${temp.path}/restore')..createSync();
    File('${folder.path}/picked.zip').writeAsBytesSync([1, 2, 3]);
    await Future.wait([
      deleteFolderIfExists(folder.path),
      deleteFolderIfExists(folder.path),
    ]);
    expect(folder.existsSync(), isFalse);
  });

  test('two deletes of one file at once both succeed', () async {
    final file = File('${temp.path}/a.db')..writeAsBytesSync([1]);
    await Future.wait([
      deleteFileIfExists(file.path),
      deleteFileIfExists(file.path),
    ]);
    expect(file.existsSync(), isFalse);
  });

  test('a missing folder or file is fine', () async {
    await deleteFolderIfExists('${temp.path}/none');
    await deleteFileIfExists('${temp.path}/none.db');
  });
}
