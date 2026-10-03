import 'dart:io';

/// The file operations that replace the live database (phase-3.md §6.4).
/// Behind an interface so tests can make any one of them fail, or "run out
/// of space", and check that the user's data survives. Production uses
/// `dart:io` directly ([IoFileOperations]).
abstract interface class FileOperations {
  Future<bool> exists(String path);
  Future<int> length(String path);

  /// Copies [from] to [to] and forces the copy out to the disk, so a power
  /// cut right after can't leave an empty file behind.
  Future<void> copyAndFlush(String from, String to);

  Future<void> rename(String from, String to);
  Future<void> delete(String path);
}

class IoFileOperations implements FileOperations {
  const IoFileOperations();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<int> length(String path) => File(path).length();

  @override
  Future<void> copyAndFlush(String from, String to) async {
    await File(from).copy(to);
    // File.copy doesn't force the data out of the OS cache.
    final file = await File(to).open(mode: FileMode.append);
    try {
      await file.flush();
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> rename(String from, String to) => File(from).rename(to);

  @override
  Future<void> delete(String path) => File(path).delete();
}

/// Deletes [path] if it is there.
Future<void> deleteFileIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

/// Deletes [path] and everything in it, if it is there.
Future<void> deleteFolderIfExists(String path) async {
  final folder = Directory(path);
  if (await folder.exists()) await folder.delete(recursive: true);
}

/// Whether the files at [a] and [b] hold the same bytes. Reads in chunks,
/// never a whole file at once.
Future<bool> filesEqual(String a, String b) async {
  final first = await File(a).open();
  final second = await File(b).open();
  try {
    if (await first.length() != await second.length()) return false;
    const chunk = 64 * 1024;
    while (true) {
      final x = await first.read(chunk);
      final y = await second.read(chunk);
      if (x.length != y.length) return false;
      if (x.isEmpty) return true;
      for (var i = 0; i < x.length; i++) {
        if (x[i] != y[i]) return false;
      }
    }
  } finally {
    await first.close();
    await second.close();
  }
}
