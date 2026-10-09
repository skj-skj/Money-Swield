/// How a picture becomes the app's photo (phase-6.md §5.3): kept as it is,
/// or resized and JPEG-encoded by native code. Pure Dart; the Kotlin side
/// only carries out the plan.
library;

import 'dart:math' as math;

import 'photos.dart';

/// The largest frame a photo is resized to fit, either way round, or
/// [original] to keep it (P6-2).
enum PhotoSize { p720, p1080, p1440, p2160, original }

/// A source's size setting and JPEG quality (Settings → Photos, §4.2).
typedef PhotoSizing = ({PhotoSize size, int quality});

/// The defaults for camera and gallery photos alike (owner rev 7): a
/// picture larger than 1080p is resized to it at quality 85.
const defaultPhotoSizing = (size: PhotoSize.p1080, quality: 85);

/// The qualities Settings offers.
const photoQualities = [70, 80, 85, 90, 95];

/// What Original re-encodes at when it can't keep the bytes (P6-3).
const originalQuality = 95;

/// The longest edge an Original re-encode keeps: 8192 needed 192 MB of
/// bitmap (§3.1 review), 4096 at most 48 MB.
const originalMaxEdge = 4096;

/// The frame [size] fits a picture in, either way round: p720 is 1280 ×
/// 720 or 720 × 1280. Null for [PhotoSize.original].
({int long, int short})? frameOf(PhotoSize size) => switch (size) {
  PhotoSize.p720 => (long: 1280, short: 720),
  PhotoSize.p1080 => (long: 1920, short: 1080),
  PhotoSize.p1440 => (long: 2560, short: 1440),
  PhotoSize.p2160 => (long: 3840, short: 2160),
  PhotoSize.original => null,
};

/// A picture's format, from the MIME type Android reads in its header.
enum ImageType {
  jpeg,
  png,
  webp,
  gif,

  /// HEIC, DNG, BMP and the like: always re-encoded (P6-3).
  other;

  static ImageType ofMime(String mimeType) => switch (mimeType.toLowerCase()) {
    'image/jpeg' || 'image/jpg' => jpeg,
    'image/png' => png,
    'image/webp' => webp,
    'image/gif' => gif,
    _ => other,
  };

  /// The type of a file the app saved with [extension] (`jpg`, `png`,
  /// `webp`, `gif`); [other] for anything else.
  static ImageType ofExtension(String extension) => switch (extension) {
    'jpg' => jpeg,
    'png' => png,
    'webp' => webp,
    'gif' => gif,
    _ => other,
  };

  /// The MIME type of a file of this type; null for [other], which the
  /// app never stores.
  String? get mimeType => switch (this) {
    jpeg => 'image/jpeg',
    png => 'image/png',
    webp => 'image/webp',
    gif => 'image/gif',
    other => null,
  };

  /// The extension a file of this type is saved with; null for [other],
  /// which is never kept as it is.
  String? get extension => switch (this) {
    jpeg => 'jpg',
    png => 'png',
    webp => 'webp',
    gif => 'gif',
    other => null,
  };
}

/// What to do with one picture.
sealed class PhotoPlan {
  const PhotoPlan();
}

/// Copy the bytes as they are.
final class KeepBytes extends PhotoPlan {
  const KeepBytes();

  @override
  bool operator ==(Object other) => other is KeepBytes;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'KeepBytes';
}

/// Decode, turn, scale to [width] × [height] and write a JPEG at
/// [quality]. The size is after turning.
final class Encode extends PhotoPlan {
  const Encode({
    required this.width,
    required this.height,
    required this.quality,
  });

  final int width;
  final int height;
  final int quality;

  @override
  bool operator ==(Object other) =>
      other is Encode &&
      other.width == width &&
      other.height == height &&
      other.quality == quality;

  @override
  int get hashCode => Object.hash(width, height, quality);

  @override
  String toString() => 'Encode($width × $height, q$quality)';
}

/// The plan for a picture of [width] × [height] as shown (EXIF orientation
/// applied, then [quarterTurns] turns), of [type] and [bytes] long, under
/// [sizing] (§5.3):
///
/// - Original keeps JPEG, PNG, WebP and GIF bytes when unturned and at
///   most [maxPhotoBytes]; otherwise it encodes at [originalQuality],
///   no larger than [originalMaxEdge].
/// - A frame keeps a JPEG that fits it, unturned (a photo within its size
///   is left alone); anything else is encoded, scaled down to fit (never
///   up) at the setting's quality.
///
/// "Fits" means the long edge ≤ the frame's long one **and** the short
/// edge ≤ its short one. A side of 0 is an [ArgumentError]: Kotlin reports
/// an undecodable picture before it gets here.
PhotoPlan planPhoto({
  required int width,
  required int height,
  required ImageType type,
  required int bytes,
  required int quarterTurns,
  required PhotoSizing sizing,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('A picture of $width × $height');
  }
  final turned = addQuarterTurns(quarterTurns, 0) != 0;
  final frame = frameOf(sizing.size);
  if (frame == null) {
    if (type != ImageType.other && !turned && bytes <= maxPhotoBytes) {
      return const KeepBytes();
    }
    final (w, h) = _fit(width, height, originalMaxEdge, originalMaxEdge);
    return Encode(width: w, height: h, quality: originalQuality);
  }
  final long = math.max(width, height);
  final short = math.min(width, height);
  final fits = long <= frame.long && short <= frame.short;
  if (fits && type == ImageType.jpeg && !turned && bytes <= maxPhotoBytes) {
    return const KeepBytes();
  }
  final (w, h) = width >= height
      ? _fit(width, height, frame.long, frame.short)
      : _fit(width, height, frame.short, frame.long);
  return Encode(width: w, height: h, quality: sizing.quality);
}

/// [width] × [height] scaled by the smaller of the two ratios to fit a
/// [maxWidth] × [maxHeight] box, never enlarged, whole pixels, at least 1.
(int, int) _fit(int width, int height, int maxWidth, int maxHeight) {
  final scale = math.min(1.0, math.min(maxWidth / width, maxHeight / height));
  if (scale == 1.0) return (width, height);
  return (
    math.max(1, (width * scale).round()),
    math.max(1, (height * scale).round()),
  );
}

/// [turns] quarter turns plus [delta], always 0..3 (§5.3).
int addQuarterTurns(int turns, int delta) => (turns + delta) % 4;
