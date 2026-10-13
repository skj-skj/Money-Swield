import 'dart:convert';

import '../../../domain/photos.dart';
import '../database/database_files.dart';

/// A photo inside a backup. Its zip entry is named by its `relativePath`
/// itself.
typedef ManifestPhoto = ({String relativePath, String sha256, int byteSize});

/// `manifest.json` inside a backup zip.
///
/// `created_at` is ISO-8601 UTC text, not epoch ms like the database: people do
/// open these zips.
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    this.includesPhotos = false,
    this.photos = const [],
  });

  /// Marks the zip as one of ours, so restore can say "this isn't a backup"
  /// instead of a generic error.
  static const appId = 'money_swield';

  /// The zip layout this app writes and the newest it can read. Not the
  /// database schema: that is decided by the database's own migrations.
  static const currentFormat = 1;

  final int format;
  final String appVersion;

  /// The newest applied migration. Informative only (shown in reports).
  final int? schemaVersion;

  /// When the backup was made. Null when a backup's `created_at` is missing or
  /// unreadable: that doesn't reject it.
  final DateTime? createdAt;

  /// Whether the zip holds the photos ("Include photos"). A database-only
  /// backup still lists none.
  final bool includesPhotos;

  /// The photos in the zip, each under its own path; empty unless
  /// [includesPhotos].
  final List<ManifestPhoto> photos;

  Map<String, Object?> toJson() => {
    'app': appId,
    'format': format,
    'app_version': appVersion,
    'schema_version': schemaVersion,
    'created_at': _isoSeconds(createdAt),
    'includes_photos': includesPhotos,
    'photos': [
      for (final photo in photos)
        {
          'relative_path': photo.relativePath,
          'sha256': photo.sha256,
          'byte_size': photo.byteSize,
        },
    ],
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Parses [text] defensively: anything that isn't one of our manifests
  /// (not JSON, not an object, a wrong `app`, a field of the wrong type)
  /// throws [FormatException], never a type error.
  ///
  /// A `format` newer than [currentFormat] parses: the caller rejects it
  /// with its own message ("made by a newer version").
  static BackupManifest decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException('manifest.json is not JSON');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('manifest.json is not an object');
    }
    if (json['app'] != appId) {
      throw const FormatException('manifest.json is not from this app');
    }
    // `is int` rejects "1" and 1.5; jsonDecode gives an int for 1.
    final format = json['format'];
    if (format is! int) {
      throw const FormatException('manifest.json has no valid format');
    }
    final appVersion = json['app_version'];
    final schemaVersion = json['schema_version'];
    // Missing (an older, database-only backup) is false; anything but a bool isn't ours.
    final includesPhotos = json['includes_photos'] ?? false;
    if (includesPhotos is! bool) {
      throw const FormatException('manifest.json has no valid includes_photos');
    }
    return BackupManifest(
      format: format,
      appVersion: appVersion is String ? appVersion : '',
      schemaVersion: schemaVersion is int ? schemaVersion : null,
      createdAt: _parseUtc(json['created_at']),
      includesPhotos: includesPhotos,
      // A database-only backup's list is never read, whatever it holds.
      photos: includesPhotos ? _decodePhotos(json['photos']) : const [],
    );
  }

  /// The photo list of a backup with photos. Every entry must be a valid path
  /// whose name is its SHA-256, with a size from 1 byte to [maxPhotoBytes], and
  /// no path twice: **any** bad entry makes the whole file "not a backup", so a
  /// crafted path never reaches a file.
  static List<ManifestPhoto> _decodePhotos(Object? value) {
    if (value is! List<Object?>) {
      throw const FormatException('manifest.json has no valid photos list');
    }
    final paths = <String>{};
    return [
      for (final item in value)
        switch (item) {
          {
            'relative_path': final String path,
            'sha256': final String sha,
            'byte_size': final int size,
          }
              when isValidPhotoPath(path) &&
                  isValidSha256(sha) &&
                  path.startsWith('$photosFolder/$sha.') &&
                  size > 0 &&
                  size <= maxPhotoBytes &&
                  paths.add(path) =>
            (relativePath: path, sha256: sha, byteSize: size),
          _ => throw FormatException('manifest.json has a bad photo: $item'),
        },
    ];
  }

  /// `2026-10-03T08:35:12Z`: whole seconds, easier to read than
  /// Dart's microseconds for someone opening the zip.
  static String? _isoSeconds(DateTime? at) =>
      at == null ? null : '${utcSeconds(at)}Z';

  static DateTime? _parseUtc(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
