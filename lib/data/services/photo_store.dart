import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import '../../domain/models/expense.dart';
import '../../domain/photo_sizing.dart';
import '../../domain/photos.dart';
import '../../domain/saved_picture.dart';
import 'file_sha256.dart';
import 'photo_service.dart';

/// Builds the image a [FileImage] would, for one file at [maxPx] at most; tests
/// swap in memory images, which load in a widget test's fake-async zone where a
/// file never does.
typedef PhotoImageFactory = ImageProvider Function(String path, int maxPx);

/// A camera shot taken but not yet used or discarded: the camera's file in
/// staging, the form it is for, and when the camera opened. Kept in
/// `photos_staging/pending_capture.json`, outside the draft slot, so opening
/// the camera never replaces another expense's draft.
typedef PendingCapture = ({String name, int? editingExpenseId, DateTime at});

/// One photo to save to Pictures, with what names and dates it: the expense's
/// title and stored day, its wall-clock time and offset (for EXIF) and its
/// moment.
typedef PictureToSave = ({
  FormPhoto photo,
  String title,
  String day,
  DateTime wallClock,
  int utcOffsetMinutes,
  DateTime moment,
});

/// [photo] of the saved [expense] to save, named and dated by it: the Photos
/// screen and the Bin detail. The form, whose expense may not be saved yet,
/// builds its own from its fields.
PictureToSave pictureOf(Expense expense, FormPhoto photo) => (
  photo: photo,
  title: expense.title,
  day: expense.occurredOn,
  wallClock: expense.wallClock,
  utcOffsetMinutes: expense.utcOffsetMinutes,
  moment: expense.occurredAt,
);

/// What a Save to Pictures did: `saved` written, `missing` skipped because
/// the app's file is gone, `failed` that MediaStore refused; `noSpace`
/// when nothing was tried because the phone is full.
typedef SaveToPicturesResult = ({
  int saved,
  int missing,
  int failed,
  bool noSpace,
});

/// The app's photo files: `photos/` (saved, named by SHA-256) and
/// `photos_staging/` (added to a form, not saved yet), both in the app's own
/// external files folder next to `databases/`. No SQL here: the repository owns
/// the rows.
///
/// Every path from the database, a draft or a marker is checked with
/// [isValidPhotoPath] / [isValidStagingName] before a file is touched.
/// Every write goes through `.partial`, is flushed and renamed, so a file
/// with its final name is always complete.
///
/// [root] is null where the app has no photo folder (tests that never
/// touch photos): every photo then reads as missing.
class PhotoStore {
  PhotoStore({
    required this._root,
    required this.service,
    PhotoImageFactory? imageFactory,
    DateTime Function()? now,
    Random? random,
  }) : _imageFactory = imageFactory ?? _fileImage,
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  /// A store without a photo folder: every photo reads as missing and
  /// nothing can be added (forms built without photos, tests).
  static final none = PhotoStore(
    root: null,
    service: const ChannelPhotoService(),
  );

  final String? _root;
  final PhotoService service;
  final PhotoImageFactory _imageFactory;
  final DateTime Function() _now;
  final Random _random;

  /// The marker's file name in staging.
  static const markerName = 'pending_capture.json';

  /// Room kept free on top of what Save to Pictures writes.
  static const saveMargin = 20 * 1024 * 1024;

  /// The app's external files folder.
  String get root =>
      _root ?? (throw StateError('This app has no photo folder'));

  bool get isAvailable => _root != null;

  String get photosPath => p.join(root, photosFolder);
  String get stagingPath => p.join(root, photosStagingFolder);

  // Names.

  /// A new staging name `<uuid>.<extension>` for a staged photo.
  String newStagingName(String extension) => '${_uuid()}.$extension';

  /// A new name for the camera's target file.
  String newCaptureName() => 'capture-${_uuid()}.jpg';

  /// A version 4 UUID from [Random.secure] (no `uuid` package).
  String _uuid() {
    final bytes = [for (var i = 0; i < 16; i++) _random.nextInt(256)];
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10).join()}';
  }

  /// The absolute path of the staging file [name]; throws for a name that isn't
  /// one of ours.
  String stagingFile(String name) {
    if (!isValidStagingName(name)) {
      throw ArgumentError.value(name, 'name', 'not a staging name');
    }
    return p.join(stagingPath, name);
  }

  /// The checked absolute path of [photo]'s file, or null when its path
  /// or name isn't one of ours, or there is no photo folder. The file may
  /// still be missing: the UI then shows "image missing".
  String? pathOf(FormPhoto photo) {
    if (!isAvailable) return null;
    return switch (photo) {
      SavedPhoto(:final relativePath) when isValidPhotoPath(relativePath) =>
        p.join(root, relativePath),
      StagedPhoto(:final stagingName) when isValidStagingName(stagingName) =>
        p.join(stagingPath, stagingName),
      _ => null,
    };
  }

  /// [photo] decoded at [maxPx] at most (`ResizeImage`), so a thumbnail of an
  /// original never becomes a full-size bitmap. A missing file fails to load;
  /// the widget then shows "image missing".
  ImageProvider image(FormPhoto photo, int maxPx) =>
      _imageFactory(pathOf(photo) ?? '', maxPx);

  /// The file at [path] (the review's preview) as [image] gives a photo.
  ImageProvider imageAt(String path, int maxPx) => _imageFactory(path, maxPx);

  static ImageProvider _fileImage(String path, int maxPx) => ResizeImage(
    FileImage(File(path)),
    width: maxPx,
    height: maxPx,
    policy: ResizeImagePolicy.fit,
  );

  // Staging.

  /// Processes the picked [uri] into staging under [sizing].
  Future<StagedPhoto> stageFromGallery(String uri, PhotoSizing sizing) =>
      _stage(uri, sizing, quarterTurns: 0);

  /// Processes the camera's file [captureName] under [sizing], turned by
  /// [quarterTurns]. Its EXIF orientation is applied first (Android's decoder
  /// does it), then the turns: one encode, from the camera's own file.
  ///
  /// The camera's file stays: the caller deletes it (with the marker) only
  /// once the draft row names the staged copy. Until then a kill brings
  /// the shot back in the review instead of losing it.
  Future<StagedPhoto> stageCapture(
    String captureName,
    PhotoSizing sizing,
    int quarterTurns,
  ) => _stage(stagingFile(captureName), sizing, quarterTurns: quarterTurns);

  /// The review screen's small copy of the camera's file [captureName]:
  /// returns its absolute path.
  Future<String> preview(String captureName) async {
    final destination = p.join(stagingPath, 'preview-${_uuid()}.jpg');
    await service.preview(stagingFile(captureName), destination);
    return destination;
  }

  Future<StagedPhoto> _stage(
    String source,
    PhotoSizing sizing, {
    required int quarterTurns,
  }) async {
    await _ensureFolders();
    final facts = await service.inspect(source);
    final type = ImageType.ofMime(facts.mimeType);
    final turned = quarterTurns.isOdd;
    final plan = planPhoto(
      width: turned ? facts.height : facts.width,
      height: turned ? facts.width : facts.height,
      type: type,
      bytes: facts.bytes,
      quarterTurns: quarterTurns,
      sizing: sizing,
    );
    final extension = switch (plan) {
      KeepBytes() => type.extension!,
      Encode() => 'jpg',
    };
    final name = newStagingName(extension);
    final destination = p.join(stagingPath, name);
    try {
      await service.stage(
        source: source,
        destination: destination,
        plan: plan,
        quarterTurns: quarterTurns,
      );
      final file = File(destination);
      return StagedPhoto(
        stagingName: name,
        sha256: await sha256OfFile(destination),
        byteSize: await file.length(),
      );
    } catch (_) {
      await _deleteQuietly(destination);
      rethrow;
    }
  }

  /// The staged photos among [photos] whose file is gone or empty, by name (the
  /// form's draft check). No `dart:io` in the cubit.
  Future<Set<String>> missingStaged(Iterable<StagedPhoto> photos) async => {
    for (final photo in photos)
      if (!await _hasBytes(pathOf(photo))) photo.stagingName,
  };

  /// Whether the camera's file [captureName] is there and not empty.
  Future<bool> captureExists(String captureName) => _hasBytes(
    isValidStagingName(captureName) ? stagingFile(captureName) : null,
  );

  /// Deletes staged files, best effort: after a save, or a capture
  /// discarded. A file a draft still names is never passed here.
  Future<void> deleteStaged(Iterable<String> names) async {
    for (final name in names) {
      if (isValidStagingName(name)) await _deleteQuietly(stagingFile(name));
    }
  }

  // The camera marker.

  /// Records that the camera is about to write [captureName] for the form
  /// editing [editingExpenseId] (null for Add). Written before the camera
  /// opens, so a shot survives the app being killed meanwhile.
  Future<void> markPendingCapture(
    String captureName,
    int? editingExpenseId,
  ) async {
    await _ensureFolders();
    final json = jsonEncode({
      'name': captureName,
      'editing_expense_id': editingExpenseId,
      'at': _now().toUtc().toIso8601String(),
    });
    await writeFileAtomically(
      p.join(stagingPath, markerName),
      utf8.encode(json),
    );
  }

  /// The pending camera shot, or null when there is none or the marker
  /// can't be read (then it is ignored; the sweep keeps nothing for it).
  Future<PendingCapture?> pendingCapture() async {
    if (!isAvailable) return null;
    final file = File(p.join(stagingPath, markerName));
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return switch (json) {
        {
          'name': final String name,
          'editing_expense_id': final int? editing,
          'at': final String at,
        }
            when isValidStagingName(name) && DateTime.tryParse(at) != null =>
          (name: name, editingExpenseId: editing, at: DateTime.parse(at)),
        _ => null,
      };
    } catch (error) {
      debugPrint('Reading the camera marker failed: $error');
      return null;
    }
  }

  /// Forgets the pending shot, after Use photo or Discard.
  Future<void> clearPendingCapture() async {
    if (!isAvailable) return;
    await _deleteQuietly(p.join(stagingPath, markerName));
  }

  // Saving.

  /// Copies the staged [photo] to `photos/<sha256>.<ext>` and returns that
  /// relative path. A file of the same size already there is the same picture
  /// (named by its hash) and is kept; one of another size isn't, and is
  /// replaced. The staged file stays: the draft still names it until the save
  /// commits.
  Future<String> promote(StagedPhoto photo) async {
    final relative = photo.savedPath;
    if (!isValidPhotoPath(relative)) {
      throw ArgumentError.value(relative, 'photo', 'not a photo path');
    }
    final destination = p.join(root, relative);
    final existing = File(destination);
    if (await existing.exists() && await existing.length() == photo.byteSize) {
      return relative;
    }
    await _ensureFolders();
    await copyFileAtomically(stagingFile(photo.stagingName), destination);
    return relative;
  }

  /// Free bytes on the storage holding the photos.
  Future<int> freeBytes() => service.freeBytes(root);

  /// [freeBytes], or null when it can't be read (the channel failed).
  Future<int?> _freeBytesOrNull() async {
    try {
      return await freeBytes();
    } catch (error) {
      debugPrint('Reading the free space failed: $error');
      return null;
    }
  }

  // Save to Pictures (owner rev 5).

  /// Copies [items] into `Pictures/Expense Tracker/`, one at a time, in order.
  /// Not linked to anything: no row, setting or draft changes, and the app
  /// never touches the copies again. A missing file is skipped and counted, a
  /// failed one counted, and the rest go on. When the phone hasn't room for all
  /// of them and 20 MB more, nothing is saved. Free space that can't be read
  /// doesn't stop it (as for a backup): each save then fails on its own if the
  /// phone is full.
  Future<SaveToPicturesResult> saveToPictures(
    List<PictureToSave> items, {
    required String fallbackTitle,
    void Function(int done, int total)? onProgress,
  }) async {
    final total = items.fold(0, (sum, item) => sum + item.photo.byteSize);
    if (await _freeBytesOrNull() case final free?
        when free <= total + saveMargin) {
      return (saved: 0, missing: 0, failed: 0, noSpace: true);
    }
    var saved = 0;
    var missing = 0;
    var failed = 0;
    for (final (i, item) in items.indexed) {
      onProgress?.call(i, items.length);
      final path = pathOf(item.photo);
      if (path == null || !await _hasBytes(path)) {
        missing++;
        continue;
      }
      try {
        await service.saveToPictures(
          sourcePath: path,
          folder: savedPicturesFolder,
          displayName: savedPictureName(
            title: item.title,
            day: item.day,
            extension: item.photo.extension,
            fallbackTitle: fallbackTitle,
          ),
          // Every stored photo is one of ours; JPEG for safety.
          mimeType:
              ImageType.ofExtension(item.photo.extension).mimeType ??
              'image/jpeg',
          dateTaken: item.moment,
          exifDateTime: exifDateTime(item.wallClock),
          exifOffset: exifOffset(item.utcOffsetMinutes),
        );
        saved++;
      } catch (error) {
        debugPrint('Saving a picture to Pictures failed: $error');
        failed++;
      }
    }
    onProgress?.call(items.length, items.length);
    return (saved: saved, missing: missing, failed: failed, noSpace: false);
  }

  /// Creates both folders. No `.nomedia` (owner, 2026-10-09): they are in the
  /// app's own storage, which gallery apps don't index; only the copies saved
  /// to Pictures are meant for them.
  Future<void> _ensureFolders() async {
    for (final folder in [photosPath, stagingPath]) {
      await Directory(folder).create(recursive: true);
    }
  }

  static Future<bool> _hasBytes(String? path) async {
    if (path == null) return false;
    final file = File(path);
    return await file.exists() && await file.length() > 0;
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Deleting $path failed: $error');
    }
  }
}

/// Writes [bytes] to [path] through `<path>.partial`, flushed, then
/// renamed: a file at [path] is always complete.
Future<void> writeFileAtomically(String path, List<int> bytes) async {
  final partial = File('$path.partial');
  try {
    final file = await partial.open(mode: FileMode.writeOnly);
    try {
      await file.writeFrom(bytes);
      await file.flush();
    } finally {
      await file.close();
    }
    await partial.rename(path);
  } catch (_) {
    if (await partial.exists()) await partial.delete();
    rethrow;
  }
}

/// Copies [from] to [to] through `<to>.partial`, flushed, then renamed
/// over [to].
Future<void> copyFileAtomically(String from, String to) async {
  final partial = File('$to.partial');
  try {
    await File(from).copy(partial.path);
    // File.copy doesn't force the data out of the OS cache.
    final file = await partial.open(mode: FileMode.append);
    try {
      await file.flush();
    } finally {
      await file.close();
    }
    await partial.rename(to);
  } catch (_) {
    if (await partial.exists()) await partial.delete();
    rethrow;
  }
}
