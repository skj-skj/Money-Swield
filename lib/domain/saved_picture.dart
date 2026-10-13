/// Names of the pictures Save to Pictures writes (owner rev 5). Pure Dart.
library;

import 'package:characters/characters.dart';

/// The longest title part of a saved picture's name, in grapheme clusters.
const savedPictureTitleLength = 60;

/// The folder under `Pictures/` that saved pictures go to. Not translated: it
/// is the app's name, and only new saves follow a later rename.
const savedPicturesFolder = 'Money Swield';

/// Characters a file name can't hold on Android's shared storage or a PC.
final _forbidden = RegExp(r'[/\\:*?"<>|\x00-\x1F\x7F]');
final _spaces = RegExp(r'\s+');

/// `Lunch 2026-10-05.jpg`: the expense's [title] and its stored local [day]
/// (`occurred_on`), so the picture can be found in a gallery. The title loses
/// characters a file name can't hold, control characters and leading dots (a
/// hidden file), its spaces collapse, and it is cut to
/// [savedPictureTitleLength] grapheme clusters (an emoji is never split). An
/// empty result is [fallbackTitle] ("Expense", translated). MediaStore adds "
/// (1)" when the name is taken.
String savedPictureName({
  required String title,
  required String day,
  required String extension,
  required String fallbackTitle,
}) {
  var cleaned = title
      .replaceAll(_forbidden, '')
      .replaceAll(_spaces, ' ')
      .trim();
  while (cleaned.startsWith('.')) {
    cleaned = cleaned.substring(1).trimLeft();
  }
  final chars = cleaned.characters;
  if (chars.length > savedPictureTitleLength) {
    cleaned = chars.take(savedPictureTitleLength).toString().trimRight();
  }
  if (cleaned.isEmpty) cleaned = fallbackTitle;
  return '$cleaned $day.$extension';
}

/// `2026:10:05 12:30:00`, the EXIF `DateTimeOriginal` a saved picture gets from
/// the expense's wall-clock time (MediaStore drops an app's own `DATE_TAKEN`,
/// galleries read EXIF).
String exifDateTime(DateTime wallClock) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${wallClock.year.toString().padLeft(4, '0')}:${two(wallClock.month)}'
      ':${two(wallClock.day)} ${two(wallClock.hour)}:${two(wallClock.minute)}'
      ':${two(wallClock.second)}';
}

/// `+05:30`, the EXIF `OffsetTimeOriginal` for [utcOffsetMinutes].
String exifOffset(int utcOffsetMinutes) {
  final sign = utcOffsetMinutes < 0 ? '-' : '+';
  final minutes = utcOffsetMinutes.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  return '$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}
