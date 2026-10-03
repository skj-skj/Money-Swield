import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

// archive's own ZLibDecoder buffers its whole output; dart:io's is used.
import 'package:archive/archive_io.dart' hide ZLibDecoder;

import '../../../domain/models/restore_candidate.dart';
import 'backup_manifest.dart';

/// Writes and reads backup zips (phase-3.md §5.1). No SQL here.
///
/// A backup holds exactly two entries, `manifest.json` then
/// `expense_tracker.db`. Reading looks only at those two names, so a
/// crafted entry name (`../../x`) is never written anywhere.
///
/// Extraction is done here rather than with `archive`'s own helpers, on
/// purpose (checked in `archive` 4.3.0):
/// - its `verify:` flag does nothing (the CRC check is commented out), so
///   the CRC is computed here while streaming;
/// - its inflater on `dart:io` collects every decompressed chunk until the
///   end, so a zip bomb would be held in memory as a whole. Here the
///   compressed bytes go through `dart:io`'s chunked [ZLibDecoder] into a
///   sink that counts and stops at the limit;
/// - `Archive.find` silently keeps the first of two entries with the same
///   name; the raw directory is used to refuse such a zip instead.
class BackupArchive {
  const BackupArchive._();

  static const manifestName = 'manifest.json';
  static const databaseName = 'expense_tracker.db';

  /// A real manifest is a few hundred bytes.
  static const maxManifestBytes = 64 * 1024;

  /// A real database is a few MB.
  static const maxDatabaseBytes = 100 * 1024 * 1024;

  static const _chunkSize = 64 * 1024;

  /// Writes [manifest] and the database at [databasePath] into a new zip at
  /// [zipPath]. Runs on another isolate: deflating a few MB would drop
  /// frames on the UI thread.
  static Future<void> write(
    BackupManifest manifest,
    String databasePath,
    String zipPath,
  ) {
    final manifestText = manifest.encode();
    return Isolate.run(() => _writeSync(manifestText, databasePath, zipPath));
  }

  /// Reads the zip at [zipPath], checks it and streams its database entry
  /// to [extractDatabaseTo]. Returns the manifest.
  ///
  /// Throws [RestoreRejected] for a file that isn't a usable backup (and
  /// deletes whatever it had extracted). A [FileSystemException] while
  /// writing [extractDatabaseTo] (a full disk) is rethrown as it is: that is
  /// a failure to report, not a bad backup.
  static Future<BackupManifest> read(
    String zipPath, {
    required String extractDatabaseTo,
    int maxDatabaseBytes = maxDatabaseBytes,
  }) => Isolate.run(
    () => _readSync(zipPath, extractDatabaseTo, maxDatabaseBytes),
  );

  static void _writeSync(String manifest, String databasePath, String zip) {
    final output = OutputFileStream(zip);
    final database = InputFileStream(databasePath);
    try {
      final encoder = ZipEncoder()
        ..startEncode(output, level: DeflateLevel.defaultCompression);
      encoder
        ..add(ArchiveFile.string(manifestName, manifest))
        ..add(ArchiveFile.stream(databaseName, database), autoClose: false)
        ..endEncode();
    } finally {
      database.closeSync();
      output.closeSync();
    }
  }

  static BackupManifest _readSync(String zip, String extractTo, int maxDb) {
    final input = InputFileStream(zip);
    try {
      final (manifestEntry, databaseEntry) = _findEntries(input);
      final manifest = _readManifest(manifestEntry);
      if (manifest.format > BackupManifest.currentFormat) {
        throw RestoreRejected(
          RestoreRejection.tooNew,
          'Backup format ${manifest.format} is newer than '
          '${BackupManifest.currentFormat}',
        );
      }
      _extractToFile(databaseEntry, extractTo, maxDb);
      return manifest;
    } finally {
      input.closeSync();
    }
  }

  /// The single `manifest.json` and `expense_tracker.db` entries. Anything
  /// that keeps the directory from being read is "not a backup".
  static (ZipFileHeader, ZipFileHeader) _findEntries(InputStream input) {
    final List<ZipFileHeader> headers;
    try {
      headers = (ZipDirectory()..read(input)).fileHeaders;
    } catch (error) {
      throw RestoreRejected(RestoreRejection.notABackup, 'Not a zip: $error');
    }
    ZipFileHeader single(String name) {
      final found = [
        for (final header in headers)
          if (header.filename == name) header,
      ];
      if (found.length != 1) {
        throw RestoreRejected(
          RestoreRejection.notABackup,
          'Expected one $name entry, found ${found.length}',
        );
      }
      return found.single;
    }

    return (single(manifestName), single(databaseName));
  }

  static BackupManifest _readManifest(ZipFileHeader entry) {
    final bytes = BytesBuilder(copy: false);
    _inflate(entry, maxManifestBytes, bytes.add);
    try {
      return BackupManifest.decode(utf8.decode(bytes.takeBytes()));
    } on FormatException catch (error) {
      throw RestoreRejected(RestoreRejection.notABackup, error.message);
    }
  }

  static void _extractToFile(ZipFileHeader entry, String path, int maxBytes) {
    final file = File(path);
    final output = file.openSync(mode: FileMode.writeOnly);
    var complete = false;
    try {
      _inflate(entry, maxBytes, output.writeFromSync);
      output.flushSync();
      complete = true;
    } finally {
      output.closeSync();
      if (!complete && file.existsSync()) file.deleteSync();
    }
  }

  /// Streams [entry]'s content to [onChunk], at most [maxBytes] of it, and
  /// checks its CRC at the end.
  static void _inflate(
    ZipFileHeader entry,
    int maxBytes,
    void Function(List<int> chunk) onChunk,
  ) {
    final name = entry.filename;
    final file = entry.file;
    // Bit 0 of the flags: encrypted. We never write one.
    if (file == null || entry.generalPurposeBitFlag & 1 != 0) {
      throw RestoreRejected(RestoreRejection.notABackup, '$name is unreadable');
    }
    // The declared size is checked first, but it can lie: the counting
    // sink below is what really stops a zip bomb.
    if (entry.uncompressedSize > maxBytes) {
      throw RestoreRejected(
        RestoreRejection.notABackup,
        '$name declares ${entry.uncompressedSize} bytes (limit $maxBytes)',
      );
    }
    final sink = _CountingSink(name, maxBytes, onChunk);
    final raw = file.getStream(decompress: false);
    try {
      switch (file.compressionMethod) {
        case CompressionType.none:
          _pump(raw, sink.add);
        case CompressionType.deflate:
          final inflater = ZLibDecoder(raw: true).startChunkedConversion(sink);
          _pump(raw, inflater.add);
          inflater.close();
        default:
          throw RestoreRejected(
            RestoreRejection.notABackup,
            '$name uses compression ${file.compressionMethod}',
          );
      }
    } on RestoreRejected {
      rethrow;
    } on FileSystemException {
      rethrow;
    } catch (error) {
      // Corrupt deflate data, or an entry cut short.
      throw RestoreRejected(
        RestoreRejection.damaged,
        '$name can\'t be read: $error',
      );
    }
    if (sink.crc != entry.crc32) {
      throw RestoreRejected(RestoreRejection.damaged, '$name fails its CRC');
    }
  }

  static void _pump(InputStream raw, void Function(List<int>) add) {
    while (!raw.isEOS) {
      add(raw.readBytes(_chunkSize).toUint8List());
    }
  }
}

/// Counts and checksums inflated bytes on their way to [_onChunk], and
/// stops once more than [_maxBytes] arrive.
class _CountingSink implements Sink<List<int>> {
  _CountingSink(this._name, this._maxBytes, this._onChunk);

  final String _name;
  final int _maxBytes;
  final void Function(List<int> chunk) _onChunk;

  int _length = 0;
  int crc = 0;

  @override
  void add(List<int> chunk) {
    _length += chunk.length;
    if (_length > _maxBytes) {
      throw RestoreRejected(
        RestoreRejection.notABackup,
        '$_name is larger than $_maxBytes bytes',
      );
    }
    crc = getCrc32(chunk, crc);
    _onChunk(chunk);
  }

  @override
  void close() {}
}
