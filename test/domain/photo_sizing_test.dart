import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/photo_sizing.dart';
import 'package:money_swield/domain/photos.dart';

void main() {
  const mb = 1024 * 1024;
  const p1080 = (size: PhotoSize.p1080, quality: 85);
  const p720 = (size: PhotoSize.p720, quality: 85);
  const original = (size: PhotoSize.original, quality: 85);

  PhotoPlan plan(
    int w,
    int h, {
    ImageType type = ImageType.jpeg,
    int bytes = 5 * mb,
    int turns = 0,
    PhotoSizing sizing = p1080,
  }) => planPhoto(
    width: w,
    height: h,
    type: type,
    bytes: bytes,
    quarterTurns: turns,
    sizing: sizing,
  );

  Encode encode(int w, int h, [int q = 85]) =>
      Encode(width: w, height: h, quality: q);

  group('every size and source', () {
    test('4000 × 3000 camera JPEG at 1080p → 1440 × 1080', () {
      expect(plan(4000, 3000), encode(1440, 1080));
    });
    test('3000 × 4000 → 1080 × 1440', () {
      expect(plan(3000, 4000), encode(1080, 1440));
    });
    test('1920 × 1080 gallery JPEG → kept', () {
      expect(plan(1920, 1080), const KeepBytes());
    });
    test('1921 × 1080 → 1920 × 1079', () {
      expect(plan(1921, 1080), encode(1920, 1079));
    });
    test('1080 × 2400 PNG screenshot → 864 × 1920', () {
      expect(plan(1080, 2400, type: ImageType.png), encode(864, 1920));
    });
    test('600 × 400 PNG → encoded at its own size (the type)', () {
      expect(plan(600, 400, type: ImageType.png), encode(600, 400));
    });
    test('1600 × 1200 at 720p → 960 × 720', () {
      expect(plan(1600, 1200, sizing: p720), encode(960, 720));
    });
    test('12000 × 1000 panorama → 1920 × 160', () {
      expect(plan(12000, 1000), encode(1920, 160));
    });
    test('4000 × 3000 turned once (now 3000 × 4000) → 1080 × 1440', () {
      expect(plan(3000, 4000, turns: 1), encode(1080, 1440));
    });
    test('4000 × 3000 JPEG of 5 MB, Original → kept', () {
      expect(plan(4000, 3000, sizing: original), const KeepBytes());
    });
    test('4000 × 3000 HEIC, Original → JPEG 95 at its size', () {
      expect(
        plan(4000, 3000, type: ImageType.other, sizing: original),
        encode(4000, 3000, 95),
      );
    });
    test('8000 × 6000 JPEG of 70 MB, Original → 4096 × 3072 at 95', () {
      expect(
        plan(8000, 6000, bytes: 70 * mb, sizing: original),
        encode(4096, 3072, 95),
      );
    });
    test('0 × 100 → ArgumentError', () {
      expect(() => plan(0, 100), throwsArgumentError);
      expect(() => plan(100, 0), throwsArgumentError);
      expect(() => plan(-1, 100), throwsArgumentError);
    });
  });

  group('edges', () {
    test('a JPEG that fits but is turned is encoded at its size', () {
      expect(plan(1080, 1920, turns: 1), encode(1080, 1920));
      expect(plan(1080, 1920, turns: 4), const KeepBytes(), reason: '4 = 0');
    });
    test('fits means both edges: 1500 × 1500 is wider than 1080 short', () {
      expect(plan(1500, 1500), encode(1080, 1080));
    });
    test('both orientations of every frame are kept at their exact size', () {
      for (final size in PhotoSize.values) {
        final frame = frameOf(size);
        if (frame == null) continue;
        final sizing = (size: size, quality: 80);
        expect(
          plan(frame.long, frame.short, sizing: sizing),
          const KeepBytes(),
        );
        expect(
          plan(frame.short, frame.long, sizing: sizing),
          const KeepBytes(),
        );
        expect(
          plan(frame.long + 1, frame.short, sizing: sizing),
          isA<Encode>().having((e) => e.width, 'width', frame.long),
        );
      }
    });
    test('the 64 MB edge: Original keeps exactly 64 MB, encodes one byte '
        'more', () {
      expect(
        plan(4000, 3000, bytes: maxPhotoBytes, sizing: original),
        const KeepBytes(),
      );
      expect(
        plan(4000, 3000, bytes: maxPhotoBytes + 1, sizing: original),
        encode(4000, 3000, 95),
      );
      expect(
        plan(100, 100, bytes: maxPhotoBytes + 1),
        encode(100, 100),
        reason: 'a fitting JPEG over 64 MB is encoded too',
      );
    });
    test('Original keeps PNG, WebP and GIF bytes, never a turned one', () {
      for (final type in [ImageType.png, ImageType.webp, ImageType.gif]) {
        expect(plan(500, 500, type: type, sizing: original), const KeepBytes());
      }
      expect(plan(500, 400, turns: 3, sizing: original), encode(500, 400, 95));
    });
    test('the quality is the setting\'s', () {
      expect(
        plan(4000, 3000, sizing: (size: PhotoSize.p1080, quality: 70)),
        encode(1440, 1080, 70),
      );
    });
    test('a 1-pixel-tall panorama never scales to 0', () {
      expect(plan(40000, 1), encode(1920, 1));
    });
  });

  test('frameOf', () {
    expect(frameOf(PhotoSize.p720), (long: 1280, short: 720));
    expect(frameOf(PhotoSize.p1080), (long: 1920, short: 1080));
    expect(frameOf(PhotoSize.p1440), (long: 2560, short: 1440));
    expect(frameOf(PhotoSize.p2160), (long: 3840, short: 2160));
    expect(frameOf(PhotoSize.original), isNull);
  });

  test('addQuarterTurns is always 0..3', () {
    expect(addQuarterTurns(0, 1), 1);
    expect(addQuarterTurns(0, -1), 3);
    expect(addQuarterTurns(3, 1), 0);
    expect(addQuarterTurns(1, 4), 1);
    expect(addQuarterTurns(2, -3), 3);
    expect(addQuarterTurns(0, -9), 3);
  });

  test('ImageType from the MIME type', () {
    expect(ImageType.ofMime('image/jpeg'), ImageType.jpeg);
    expect(ImageType.ofMime('IMAGE/PNG'), ImageType.png);
    expect(ImageType.ofMime('image/webp'), ImageType.webp);
    expect(ImageType.ofMime('image/gif'), ImageType.gif);
    expect(ImageType.ofMime('image/heif'), ImageType.other);
    expect(ImageType.ofMime(''), ImageType.other);
    expect(ImageType.other.extension, isNull);
  });

  test('a stored extension gives back its type and MIME type', () {
    for (final type in [
      ImageType.jpeg,
      ImageType.png,
      ImageType.webp,
      ImageType.gif,
    ]) {
      expect(ImageType.ofExtension(type.extension!), type);
      expect(ImageType.ofMime(type.mimeType!), type);
    }
    expect(ImageType.ofExtension('heic'), ImageType.other);
    expect(ImageType.ofExtension('JPG'), ImageType.other);
    expect(ImageType.other.mimeType, isNull);
  });
}
