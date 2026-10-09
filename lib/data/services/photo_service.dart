import 'package:flutter/services.dart';

import '../../domain/photo_sizing.dart';

/// Why a photo call failed, one per thing the user can be told.
enum PhotoError {
  /// No app on the phone takes pictures.
  noCamera,

  /// The camera or the picker is already open (a double tap).
  busy,

  /// The app isn't in front.
  noActivity,

  /// The picked file isn't a picture Android can decode.
  notAnImage,

  /// Decoding it needs more memory than the phone gives the app.
  tooLarge,

  /// The phone's storage is full.
  noSpace,

  /// Anything else that went wrong reading or writing.
  ioError,
}

class PhotoServiceException implements Exception {
  const PhotoServiceException(this.error, [this.detail = '']);

  final PhotoError error;

  /// English, for logs.
  final String detail;

  @override
  String toString() => 'PhotoServiceException(${error.name}): $detail';
}

/// A picture's header: its size as shown (EXIF orientation applied), its
/// MIME type and its length in bytes.
typedef ImageFacts = ({int width, int height, String mimeType, int bytes});

/// Android's camera, photo picker, image decoding and encoding, MediaStore
/// and free space, behind an interface so tests can stand in for them
/// (phase-6.md §6.1). Paths are absolute; a `source` is a picker's
/// `content://` URI or a file path. Throws [PhotoServiceException].
abstract interface class PhotoService {
  /// Opens the camera app, which writes its picture to [path]. True when a
  /// picture was taken, false when cancelled.
  Future<bool> capture(String path);

  /// Opens the photo picker for at most [maxItems] pictures. The picked
  /// URIs in order (more than [maxItems] with the document picker); empty
  /// when cancelled.
  Future<List<String>> pick(int maxItems);

  /// Reads [source]'s header, without decoding it.
  Future<ImageFacts> inspect(String source);

  /// Writes the review screen's small JPEG of [source] to [destination].
  Future<void> preview(String source, String destination);

  /// Writes [source] to [destination] per [plan], after [quarterTurns]
  /// clockwise turns (an [Encode] plan's size is after them). Returns the
  /// bytes written. [destination] is complete or absent: written through
  /// `.partial`, flushed, renamed.
  Future<int> stage({
    required String source,
    required String destination,
    required PhotoPlan plan,
    required int quarterTurns,
  });

  /// Copies [sourcePath] into `Pictures/<folder>/` as a new picture named
  /// [displayName] (only ever inserting, P6-46), dated by EXIF on the
  /// expense's moment (§12a). Returns the name MediaStore gave it.
  Future<String> saveToPictures({
    required String sourcePath,
    required String folder,
    required String displayName,
    required String mimeType,
    required DateTime dateTaken,
    required String exifDateTime,
    required String exifOffset,
  });

  /// The bytes free on the storage holding [path].
  Future<int> freeBytes(String path);
}

/// [PhotoService] over the `expense_tracker/photos` channel that
/// `MainActivity` registers.
class ChannelPhotoService implements PhotoService {
  const ChannelPhotoService();

  static const _channel = MethodChannel('expense_tracker/photos');

  @override
  Future<bool> capture(String path) => _call(
    () async =>
        await _channel.invokeMethod<bool>('capture', {'path': path}) ?? false,
  );

  @override
  Future<List<String>> pick(int maxItems) => _call(
    () async =>
        await _channel.invokeListMethod<String>('pick', {
          'maxItems': maxItems,
        }) ??
        const [],
  );

  @override
  Future<ImageFacts> inspect(String source) => _call(() async {
    final map = (await _channel.invokeMapMethod<String, Object?>('inspect', {
      'source': source,
    }))!;
    return (
      width: map['width']! as int,
      height: map['height']! as int,
      mimeType: map['mimeType']! as String,
      bytes: map['bytes']! as int,
    );
  });

  @override
  Future<void> preview(String source, String destination) => _call(
    () => _channel.invokeMethod<void>('preview', {
      'source': source,
      'destination': destination,
    }),
  );

  @override
  Future<int> stage({
    required String source,
    required String destination,
    required PhotoPlan plan,
    required int quarterTurns,
  }) => _call(() async {
    final map = (await _channel.invokeMapMethod<String, Object?>('stage', {
      'source': source,
      'destination': destination,
      'quarterTurns': quarterTurns,
      if (plan case Encode(:final width, :final height, :final quality)) ...{
        'width': width,
        'height': height,
        'quality': quality,
      },
    }))!;
    return map['bytes']! as int;
  });

  @override
  Future<String> saveToPictures({
    required String sourcePath,
    required String folder,
    required String displayName,
    required String mimeType,
    required DateTime dateTaken,
    required String exifDateTime,
    required String exifOffset,
  }) => _call(
    () async => (await _channel.invokeMethod<String>('saveToPictures', {
      'sourcePath': sourcePath,
      'folder': folder,
      'displayName': displayName,
      'mimeType': mimeType,
      'dateTakenMs': dateTaken.millisecondsSinceEpoch,
      'exifDateTime': exifDateTime,
      'exifOffset': exifOffset,
    }))!,
  );

  @override
  Future<int> freeBytes(String path) => _call(
    () async =>
        (await _channel.invokeMethod<int>('freeBytes', {'path': path}))!,
  );

  /// Runs [call], turning the channel's error codes into
  /// [PhotoServiceException]s.
  static Future<T> _call<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      final error = PhotoError.values.asNameMap()[e.code] ?? PhotoError.ioError;
      throw PhotoServiceException(error, e.message ?? '');
    }
  }
}
