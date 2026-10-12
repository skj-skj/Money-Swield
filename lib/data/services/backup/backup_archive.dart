import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

// archive's own ZLibDecoder buffers its whole output; dart:io's is used.
import 'package:archive/archive_io.dart' hide ZLibDecoder;
import 'package:path/path.dart' as p;

import '../../../domain/models/restore_candidate.dart';
import '../../../domain/photos.dart';
import '../file_sha256.dart';
import 'backup_manifest.dart';

/// A photo file to put in a backup under its `name` (its relative path).
typedef PhotoEntry = ({String name, String path});

/// What writing a backup's photos back did: `written` new or repaired,
/// `skipped` already there with the right hash, `failed` entries that were
/// damaged (size, CRC, hash, bad data).
typedef PhotosRestored = ({int written, int skipped, int failed});

/// Writes and reads backup zips. No SQL here.
///
/// A backup holds `manifest.json`, `expense_tracker.db` and, with photos, one
/// entry per photo named by its relative path (`photos/<sha256>.jpg`), stored,
/// not deflated (JPEGs don't shrink). Reading looks only at the names the
/// manifest lists, after they passed [isValidPhotoPath], so a crafted entry
/// name (`../../x`) is never written anywhere.
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

  /// A manifest is a few hundred bytes plus ~230 per photo: 16 MB holds about
  /// 70,000 photos (64 KB held only ~280).
  static const maxManifestBytes = 16 * 1024 * 1024;

  /// A real database is a few MB.
  static const maxDatabaseBytes = 100 * 1024 * 1024;

  static const _chunkSize = 64 * 1024;

  /// Writes [manifest] and the database at [databasePath] into a new zip at
  /// [zipPath]. Runs on another isolate: deflating a few MB would drop
  /// frames on the UI thread.
  ///
  /// [photos] follow the database, each stored under its name, its file read as
  /// a stream and closed after its entry (no thousands of open files).
  /// [onProgress] gets the photos done so far. Zip64 records are written when
  /// needed.
  static Future<void> write(
    BackupManifest manifest,
    String databasePath,
    String zipPath, {
    List<PhotoEntry> photos = const [],
    void Function(int done)? onProgress,
  }) {
    final manifestText = manifest.encode();
    return _runWithProgress(
      (report) =>
          _writeSync(manifestText, databasePath, zipPath, photos, report),
      onProgress,
    );
  }

  /// Runs [work] on another isolate; what it reports reaches [onProgress]
  /// on this one.
  static Future<T> _runWithProgress<T>(
    T Function(void Function(int done) report) work,
    void Function(int done)? onProgress,
  ) async {
    final port = ReceivePort();
    final listening = port.listen((done) => onProgress?.call(done as int));
    try {
      return await _runIsolated(work, port.sendPort);
    } finally {
      await listening.cancel();
      port.close();
    }
  }

  /// [work] on another isolate, reporting through [send]. Its own function on
  /// purpose: a closure made in [_runWithProgress] shares its context with the
  /// listener there, and so would carry [_runWithProgress]'s `onProgress` (a
  /// cubit's callback, which can't be sent to an isolate) into the message;
  /// every backup failed with "Illegal argument in isolate message" (found by
  /// the tests).
  static Future<T> _runIsolated<T>(
    T Function(void Function(int done) report) work,
    SendPort send,
  ) => Isolate.run(() => work(send.send));

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

  static void _writeSync(
    String manifest,
    String databasePath,
    String zip,
    List<PhotoEntry> photos,
    void Function(int done) report,
  ) {
    final output = OutputFileStream(zip);
    final database = InputFileStream(databasePath);
    try {
      final encoder = ZipEncoder()
        ..startEncode(output, level: DeflateLevel.defaultCompression);
      encoder
        ..add(ArchiveFile.string(manifestName, manifest))
        ..add(ArchiveFile.stream(databaseName, database), autoClose: false);
      for (final (i, photo) in photos.indexed) {
        final entry = ArchiveFile.stream(
          photo.name,
          InputFileStream(photo.path),
        )..compression = CompressionType.none;
        encoder.add(entry, autoClose: true);
        if (i % 20 == 19) report(i + 1);
      }
      encoder.endEncode();
      report(photos.length);
    } finally {
      database.closeSync();
      output.closeSync();
    }
  }

  static BackupManifest _readSync(String zip, String extractTo, int maxDb) {
    final input = InputFileStream(zip);
    try {
      final entries = _entriesByName(input);
      final manifest = _readManifest(_single(entries, manifestName));
      if (manifest.format > BackupManifest.currentFormat) {
        throw RestoreRejected(
          RestoreRejection.tooNew,
          'Backup format ${manifest.format} is newer than '
          '${BackupManifest.currentFormat}',
        );
      }
      final databaseEntry = _single(entries, databaseName);
      // Every listed photo has exactly one entry under its own name; its bytes
      // are only read when it is written back.
      for (final photo in manifest.photos) {
        _single(entries, photo.relativePath);
      }
      _extractToFile(databaseEntry, extractTo, maxDb);
      return manifest;
    } finally {
      input.closeSync();
    }
  }

  /// The zip's entries by name, read once (not a scan per photo). Anything
  /// that keeps the directory from being read is "not a backup".
  static Map<String, List<ZipFileHeader>> _entriesByName(InputStream input) {
    final List<ZipFileHeader> headers;
    try {
      headers = (ZipDirectory()..read(input)).fileHeaders;
    } catch (error) {
      throw RestoreRejected(RestoreRejection.notABackup, 'Not a zip: $error');
    }
    final byName = <String, List<ZipFileHeader>>{};
    for (final header in headers) {
      byName.putIfAbsent(header.filename, () => []).add(header);
    }
    return byName;
  }

  /// The one entry named [name]; none or two is "not a backup".
  static ZipFileHeader _single(
    Map<String, List<ZipFileHeader>> entries,
    String name,
  ) {
    final found = entries[name] ?? const [];
    if (found.length != 1) {
      throw RestoreRejected(
        RestoreRejection.notABackup,
        'Expected one $name entry, found ${found.length}',
      );
    }
    return found.single;
  }

  /// Writes the [photos] of the (already checked) zip at [zipPath] into [root],
  /// before a restore's swap, on another isolate. [onProgress] gets the photos
  /// done so far.
  ///
  /// For each photo: a file at its path with the same size and SHA-256 is
  /// left alone; otherwise its entry is streamed to `<path>.partial`
  /// (counted against its `byte_size`, CRC and SHA-256 checked on the way)
  /// and renamed over the path. A file there with other bytes isn't that
  /// photo (its name is its hash), so replacing it repairs it. A damaged
  /// entry only fails that photo; a write error (a full disk) stops it all
  /// with a [FileSystemException]: the restore then stops before the swap.
  static Future<PhotosRestored> writePhotos(
    String zipPath,
    List<ManifestPhoto> photos,
    String root, {
    void Function(int done)? onProgress,
  }) => _runWithProgress(
    (report) => _writePhotosSync(zipPath, photos, root, report),
    onProgress,
  );

  static PhotosRestored _writePhotosSync(
    String zip,
    List<ManifestPhoto> photos,
    String root,
    void Function(int done) report,
  ) {
    final input = InputFileStream(zip);
    var written = 0;
    var skipped = 0;
    var failed = 0;
    try {
      final entries = _entriesByName(input);
      for (final (i, photo) in photos.indexed) {
        if (i % 20 == 0) report(i);
        // The manifest's paths were checked when it was read; checked again
        // here, right before a file is written.
        if (!isValidPhotoPath(photo.relativePath)) {
          failed++;
          continue;
        }
        final target = p.join(root, photo.relativePath);
        if (_holds(target, photo)) {
          skipped++;
          continue;
        }
        final found = entries[photo.relativePath] ?? const [];
        if (found.length != 1) {
          failed++;
          continue;
        }
        if (_writePhoto(found.single, photo, target)) {
          written++;
        } else {
          failed++;
        }
      }
      report(photos.length);
      return (written: written, skipped: skipped, failed: failed);
    } finally {
      input.closeSync();
    }
  }

  /// Whether [path] already holds [photo]: same size, then same SHA-256.
  static bool _holds(String path, ManifestPhoto photo) {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() != photo.byteSize) return false;
    return sha256OfFileSync(path) == photo.sha256;
  }

  /// Streams [entry] to `<target>.partial` and renames it over [target]
  /// when its size, CRC and SHA-256 are right. False for a damaged entry
  /// (the partial is deleted). A [FileSystemException] (writing) is
  /// rethrown.
  static bool _writePhoto(
    ZipFileHeader entry,
    ManifestPhoto photo,
    String target,
  ) {
    final partial = File('$target.partial');
    partial.parent.createSync(recursive: true);
    final output = partial.openSync(mode: FileMode.writeOnly);
    final hasher = Sha256Builder();
    var length = 0;
    var ok = false;
    try {
      try {
        _inflate(entry, photo.byteSize, (chunk) {
          length += chunk.length;
          hasher.add(chunk);
          output.writeFromSync(chunk);
        });
      } on RestoreRejected {
        return false;
      }
      if (length != photo.byteSize || hasher.close() != photo.sha256) {
        return false;
      }
      output.flushSync();
      ok = true;
    } finally {
      output.closeSync();
      if (!ok && partial.existsSync()) partial.deleteSync();
    }
    partial.renameSync(target);
    return true;
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
