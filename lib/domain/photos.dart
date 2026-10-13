/// The photos of an expense as the form holds them, and the checks every photo
/// path passes before a file is touched. Pure Dart.
library;

/// At most this many photos per expense (owner note 1).
const maxPhotosPerExpense = 10;

/// The largest picture the app keeps as it is, or a backup may hold: larger
/// ones are re-encoded or refused.
const maxPhotoBytes = 64 * 1024 * 1024;

/// The file extensions the app writes; always lower case.
const photoExtensions = {'jpg', 'png', 'webp', 'gif'};

/// The folder of the app's photos, relative to its external files folder
/// (the one holding `databases/`).
const photosFolder = 'photos';

/// Photos added but not saved yet (a form's draft), next to [photosFolder].
const photosStagingFolder = 'photos_staging';

final _sha256 = RegExp(r'^[0-9a-f]{64}$');
final _photoPath = RegExp(r'^photos/[0-9a-f]{64}\.(jpg|png|webp|gif)$');
final _stagingName = RegExp(
  r'^(capture-|preview-)?'
  r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
  r'\.(jpg|png|webp|gif)$',
);

/// A SHA-256 as the app writes it: 64 lower-case hex digits.
bool isValidSha256(String text) => _sha256.hasMatch(text);

/// `photos/<sha256>.<ext>`, the only shape of a saved photo's path. Every path
/// from the database, a draft, a manifest or a zip passes this before any file
/// is read, written or deleted, so a crafted `../databases/money_swield.db`
/// can never reach a file.
bool isValidPhotoPath(String relativePath) => _photoPath.hasMatch(relativePath);

/// A file name in [photosStagingFolder]: a v4-style UUID, optionally
/// `capture-` or `preview-` before it, and an extension of ours.
bool isValidStagingName(String name) => _stagingName.hasMatch(name);

/// Where a photo with [sha256] and [extension] is saved.
String photoRelativePath(String sha256, String extension) =>
    '$photosFolder/$sha256.$extension';

/// One photo on the form: saved already, or staged.
sealed class FormPhoto {
  const FormPhoto({required this.sha256, required this.byteSize});

  final String sha256;
  final int byteSize;

  /// `jpg`, `png`, `webp` or `gif`.
  String get extension;
}

/// A photo in the `photos` table: on an Edit, or in a draft made from one.
final class SavedPhoto extends FormPhoto {
  const SavedPhoto({
    required this.id,
    required this.relativePath,
    required super.sha256,
    required super.byteSize,
  });

  final int id;

  /// `photos/<sha256>.<ext>`; checked with [isValidPhotoPath] before use.
  final String relativePath;

  @override
  String get extension =>
      relativePath.substring(relativePath.lastIndexOf('.') + 1);

  @override
  bool operator ==(Object other) =>
      other is SavedPhoto &&
      other.id == id &&
      other.relativePath == relativePath &&
      other.sha256 == sha256 &&
      other.byteSize == byteSize;

  @override
  int get hashCode => Object.hash(id, relativePath, sha256, byteSize);

  @override
  String toString() => 'SavedPhoto($id, $relativePath)';
}

/// A photo processed into [photosStagingFolder] and not saved yet: Save or
/// Update copies it into [photosFolder].
final class StagedPhoto extends FormPhoto {
  const StagedPhoto({
    required this.stagingName,
    required super.sha256,
    required super.byteSize,
  });

  /// `<uuid>.<ext>`; checked with [isValidStagingName] before use.
  final String stagingName;

  @override
  String get extension =>
      stagingName.substring(stagingName.lastIndexOf('.') + 1);

  /// Where it goes when saved.
  String get savedPath => photoRelativePath(sha256, extension);

  @override
  bool operator ==(Object other) =>
      other is StagedPhoto &&
      other.stagingName == stagingName &&
      other.sha256 == sha256 &&
      other.byteSize == byteSize;

  @override
  int get hashCode => Object.hash(stagingName, sha256, byteSize);

  @override
  String toString() => 'StagedPhoto($stagingName)';
}

/// What adding photos to the form did.
typedef AddOutcome = ({List<FormPhoto> photos, int duplicates, int overflow});

/// [added] appended to [current] in order, leaving out a photo already there
/// (by SHA-256: the same picture twice would break the link's primary key) and
/// whatever doesn't fit in [maxPhotosPerExpense]. A list already over the limit
/// (a damaged draft) is kept as it is, never cut: Save then asks the user to
/// remove some.
AddOutcome addPhotos(List<FormPhoto> current, List<FormPhoto> added) {
  final photos = [...current];
  final seen = {for (final p in current) p.sha256};
  var duplicates = 0;
  var overflow = 0;
  for (final photo in added) {
    if (!seen.add(photo.sha256)) {
      duplicates++;
    } else if (photos.length >= maxPhotosPerExpense) {
      overflow++;
    } else {
      photos.add(photo);
    }
  }
  return (photos: photos, duplicates: duplicates, overflow: overflow);
}

/// [photos] without the ones at [indexes]. An index outside the list is a
/// bug in the caller: [RangeError].
List<FormPhoto> removePhotos(List<FormPhoto> photos, Set<int> indexes) {
  for (final i in indexes) {
    RangeError.checkValidIndex(i, photos, 'indexes');
  }
  return [
    for (final (i, photo) in photos.indexed)
      if (!indexes.contains(i)) photo,
  ];
}

/// How many more photos fit: 0 when full or over the limit.
int remainingPhotoSlots(List<FormPhoto> photos) =>
    photos.length >= maxPhotosPerExpense
    ? 0
    : maxPhotosPerExpense - photos.length;

/// Whether [a] and [b] are the same pictures in the same order: the form's
/// dirtiness. By SHA-256, so the same photo staged again (a draft resumed)
/// isn't a change.
bool samePhotos(List<FormPhoto> a, List<FormPhoto> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].sha256 != b[i].sha256) return false;
  }
  return true;
}
