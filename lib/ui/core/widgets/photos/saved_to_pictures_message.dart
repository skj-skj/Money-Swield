import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/services/photo_store.dart';
import '../../../../domain/saved_picture.dart';
import '../../../../l10n/app_localizations.dart';

/// What to say after a Save to Pictures, shared by the form, the viewer, the
/// Bin and the Photos screen: where they went, how many failed or were missing,
/// or that there was no room. Nothing saved because every one failed is
/// "Couldn't save".
String savedToPicturesText(AppLocalizations l10n, SaveToPicturesResult result) {
  const folder = 'Pictures/$savedPicturesFolder';
  if (result.noSpace) return l10n.noSpaceToSavePhotos;
  if (result.saved == 0 && result.failed > 0) return l10n.saveFailed;
  if (result.missing > 0 && result.saved == 0) {
    return l10n.photosMissingNotSaved(result.missing);
  }
  final saved = result.failed > 0
      ? l10n.photosSavedSomeFailed(result.saved, result.failed)
      : result.saved == 1
      ? l10n.savedToPictures(folder)
      : l10n.photosSavedToPictures(result.saved, folder);
  return result.missing > 0
      ? '$saved. ${l10n.photosMissingNotSaved(result.missing)}'
      : saved;
}

/// Runs [save] and returns what to say about it: [savedToPicturesText],
/// null when nothing ran (a save already running), and "Couldn't save"
/// when it threw. Every Save to Pictures button goes through here, so an
/// error is never silent.
Future<String?> saveToPicturesMessage(
  AppLocalizations l10n,
  Future<SaveToPicturesResult?> Function() save,
) async {
  try {
    final result = await save();
    return result == null ? null : savedToPicturesText(l10n, result);
  } catch (error, stackTrace) {
    debugPrint('Saving to Pictures failed: $error\n$stackTrace');
    return l10n.saveFailed;
  }
}
