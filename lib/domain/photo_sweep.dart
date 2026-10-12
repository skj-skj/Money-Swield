/// Which photo files the startup sweep deletes. Pure Dart: the sweeper lists
/// the folders and gathers the references.
library;

import 'photos.dart';

/// What [sweepPlan] deletes, as names inside each folder.
typedef SweepPlan = ({List<String> photoFiles, List<String> stagingFiles});

/// The files to delete from `photos/` ([photoFilesOnDisk], names only) and
/// `photos_staging/` ([stagingFilesOnDisk]):
///
/// - `.partial` files in either folder (a write cut short);
/// - in `photos/`, a file whose `photos/<name>` passes [isValidPhotoPath]
///   and isn't in [referencedPaths];
/// - in staging, a file whose name passes [isValidStagingName] and isn't
///   in [referencedStaging] (a `preview-` file never is).
///
/// Anything else (an old `.nomedia`, `pending_capture.json`, a file we
/// didn't name, `photos/<sha>.JPG`) is left alone: the sweep only deletes
/// what it can tell is ours and unused. Saved pictures in `Pictures/` are never
/// looked at: they are the user's.
SweepPlan sweepPlan({
  required List<String> photoFilesOnDisk,
  required List<String> stagingFilesOnDisk,
  required Set<String> referencedPaths,
  required Set<String> referencedStaging,
}) => (
  photoFiles: [
    for (final name in photoFilesOnDisk)
      if (_isPartial(name) ||
          (isValidPhotoPath('$photosFolder/$name') &&
              !referencedPaths.contains('$photosFolder/$name')))
        name,
  ],
  stagingFiles: [
    for (final name in stagingFilesOnDisk)
      if (_isPartial(name) ||
          (isValidStagingName(name) && !referencedStaging.contains(name)))
        name,
  ],
);

bool _isPartial(String name) => name.endsWith('.partial');
