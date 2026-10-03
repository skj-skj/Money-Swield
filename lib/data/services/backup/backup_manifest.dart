import 'dart:convert';

import '../database/database_files.dart';

/// `manifest.json` inside a backup zip (phase-3.md §5.1).
///
/// `created_at` is ISO-8601 UTC text, not epoch ms like the database: people
/// do open these zips (P3-11).
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
  });

  /// Marks the zip as one of ours, so restore can say "this isn't a backup"
  /// instead of a generic error.
  static const appId = 'expense_tracker';

  /// The zip layout this app writes and the newest it can read. Not the
  /// database schema: that is decided by the database's own migrations.
  static const currentFormat = 1;

  final int format;
  final String appVersion;

  /// The newest applied migration. Informative only (shown in reports).
  final int? schemaVersion;

  /// When the backup was made. Null when a backup's `created_at` is missing
  /// or unreadable: that doesn't reject it (§5.1).
  final DateTime? createdAt;

  /// Photos arrive in Phase 6; until then every backup is database-only.
  bool get includesPhotos => false;

  Map<String, Object?> toJson() => {
    'app': appId,
    'format': format,
    'app_version': appVersion,
    'schema_version': schemaVersion,
    'created_at': _isoSeconds(createdAt),
    'includes_photos': includesPhotos,
    'photos': const <Object>[],
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
    return BackupManifest(
      format: format,
      appVersion: appVersion is String ? appVersion : '',
      schemaVersion: schemaVersion is int ? schemaVersion : null,
      createdAt: _parseUtc(json['created_at']),
    );
  }

  /// `2026-10-03T08:35:12Z`: whole seconds, easier to read than
  /// Dart's microseconds for someone opening the zip.
  static String? _isoSeconds(DateTime? at) =>
      at == null ? null : '${utcSeconds(at)}Z';

  static DateTime? _parseUtc(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
