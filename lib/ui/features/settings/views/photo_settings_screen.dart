import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/app_settings.dart';
import '../../../../domain/photo_sizing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/byte_size_text.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/widgets/choice_setting_tile.dart';
import '../../../core/widgets/confirm_then_save.dart';
import '../../../core/widgets/section_heading.dart';
import '../view_models/settings_cubit.dart';
import '../view_models/settings_summary_cubit.dart';

/// Settings → Photos (phase-6.md §8.6, P6-20): how camera and gallery
/// photos are kept (size and JPEG quality each), what photos use, and
/// where they live. Changes apply to photos added from now on (P6-28).
class PhotoSettingsScreen extends StatelessWidget {
  const PhotoSettingsScreen({super.key, required this.summary});

  /// For the space photos use.
  final SettingsSummaryCubit summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.photos)),
      body: BlocSignalBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SectionHeading(l10n.cameraPhotos),
            ),
            ..._sizingTiles(
              context,
              keyPrefix: 'camera',
              sizing: settings.cameraPhotos,
              save: cubit.setCameraPhotos,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SectionHeading(l10n.galleryPhotos),
            ),
            ..._sizingTiles(
              context,
              keyPrefix: 'gallery',
              sizing: settings.galleryPhotos,
              save: cubit.setGalleryPhotos,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(l10n.photoResizedAbove, style: muted),
            ),
            if (settings.cameraPhotos.size == PhotoSize.original ||
                settings.galleryPhotos.size == PhotoSize.original)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  l10n.originalWarning,
                  key: const ValueKey('originalWarning'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BlocSignalBuilder<SettingsSummaryCubit, SettingsSummary>(
                bloc: summary,
                builder: (context, summary) => Text(
                  _usage(context, summary),
                  key: const ValueKey('photosUse'),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(l10n.photosKeptInApp, style: muted),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l10n.photoChangesApplyToNew, style: muted),
            ),
            ListTile(
              key: const ValueKey('restorePhotoDefaults'),
              leading: const Icon(Icons.settings_backup_restore),
              title: Text(l10n.restorePhotoDefaults),
              onTap: () => confirmThenSave(
                context,
                title: l10n.restorePhotoDefaultsTitle,
                message: l10n.restorePhotoDefaultsMessage,
                confirmLabel: l10n.restorePhotoDefaults,
                action: cubit.restorePhotoDefaults,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Size, and Quality (off under Original: nothing is encoded then).
  List<Widget> _sizingTiles(
    BuildContext context, {
    required String keyPrefix,
    required PhotoSizing sizing,
    required Future<void> Function(PhotoSizing sizing) save,
  }) {
    final l10n = AppLocalizations.of(context);
    final original = sizing.size == PhotoSize.original;
    return [
      ChoiceSettingTile<PhotoSize>(
        key: ValueKey('${keyPrefix}Size'),
        icon: Icons.photo_size_select_large,
        title: l10n.photoSizeLabel,
        values: PhotoSize.values,
        current: sizing.size,
        label: (size) => photoSizeName(l10n, size),
        onSave: (size) => save((size: size, quality: sizing.quality)),
      ),
      IgnorePointer(
        ignoring: original,
        child: Opacity(
          opacity: original ? 0.38 : 1,
          child: ChoiceSettingTile<int>(
            key: ValueKey('${keyPrefix}Quality'),
            icon: Icons.high_quality_outlined,
            title: l10n.photoQualityLabel,
            values: photoQualities,
            current: sizing.quality,
            label: (quality) => quality == defaultPhotoSizing.quality
                ? l10n.settingDefaultValue('$quality')
                : '$quality',
            onSave: (quality) => save((size: sizing.size, quality: quality)),
          ),
        ),
      ),
    ];
  }

  String _usage(BuildContext context, SettingsSummary summary) {
    final l10n = AppLocalizations.of(context);
    final count = summary.photoCount;
    final bytes = summary.photoBytes;
    if (count == null || bytes == null) return '';
    if (count == 0) return l10n.noPhotosYet;
    return l10n.photosUse(
      byteSizeText(l10n, formattingLocaleOf(context), bytes),
      count,
    );
  }
}

/// "1080p (default)", "Original (not recommended)", "4K".
String photoSizeName(AppLocalizations l10n, PhotoSize size) {
  final name = photoSizeShortName(l10n, size);
  return switch (size) {
    PhotoSize.original => l10n.photoSizeNotRecommended(name),
    _ when size == defaultPhotoSizing.size => l10n.settingDefaultValue(name),
    _ => name,
  };
}

/// "1080p", without "(default)", for the tile's summary. The sizes aren't
/// translated (§10).
String photoSizeShortName(AppLocalizations l10n, PhotoSize size) =>
    switch (size) {
      PhotoSize.p720 => '720p',
      PhotoSize.p1080 => '1080p',
      PhotoSize.p1440 => '1440p',
      PhotoSize.p2160 => '4K',
      PhotoSize.original => l10n.photoSizeOriginal,
    };
