import 'package:material_ui/material_ui.dart';

import '../../../../domain/photos.dart';
import '../../../../l10n/app_localizations.dart';
import '../app_sheet.dart';

/// Where a new photo comes from.
enum PhotoSource { camera, gallery }

/// Asks **Take photo** or **Choose from gallery** (phase-6.md §8.2, P6-4),
/// with "3 of 10 added" when the expense has some. Null when dismissed.
Future<PhotoSource?> showAddPhotoSheet(
  BuildContext context, {
  required int count,
}) => showAppSheet<PhotoSource>(
  context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (count > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.photosAddedOf(count, maxPhotosPerExpense),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.takePhoto),
            onTap: () => Navigator.pop(context, PhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.chooseFromGallery),
            onTap: () => Navigator.pop(context, PhotoSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  },
);
