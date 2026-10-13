import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:money_swield/data/services/photo_store.dart';

/// A 1 × 1 PNG.
final onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// An image that loads in a widget test's fake-async zone, where a file never
/// does.
ImageProvider memoryImage() => MemoryImage(onePixelPng);

/// An image that fails to decode, like a missing file: shows "image
/// missing".
ImageProvider brokenImage() => MemoryImage(utf8.encode('not a picture'));

/// A [PhotoImageFactory] for widget tests: memory images, broken for a
/// path whose file is missing according to [isMissing].
PhotoImageFactory memoryImages({bool Function(String path)? isMissing}) =>
    (path, maxPx) => path.isEmpty || (isMissing?.call(path) ?? false)
    ? brokenImage()
    : MemoryImage(onePixelPng);
