import 'package:flutter/services.dart';

/// The picked document is larger than the limit given to
/// [DocumentService.openDocument]. No file was left behind.
class DocumentTooLarge implements Exception {
  const DocumentTooLarge();
}

/// The system save and open dialogs, and the app version. An interface so tests
/// can stand in for the dialogs.
abstract interface class DocumentService {
  /// Opens the save dialog with [suggestedName], copies the file at
  /// [sourcePath] into the chosen document and reads it back to compare.
  /// True when saved, false when the user cancelled. Throws on a failed
  /// copy (the half-written document is deleted).
  Future<bool> saveDocument({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  });

  /// Opens the open dialog for [mimeTypes] and copies the picked document
  /// to [destinationPath]. Returns its display name, or null when the user
  /// cancelled. Throws [DocumentTooLarge] above [maxBytes].
  Future<String?> openDocument({
    required List<String> mimeTypes,
    required String destinationPath,
    required int maxBytes,
  });

  /// `versionName+versionCode`, e.g. `1.0.0+1`.
  Future<String> appVersion();
}

/// [DocumentService] over the `money_swield/documents` channel that
/// `MainActivity` registers.
class ChannelDocumentService implements DocumentService {
  const ChannelDocumentService();

  static const _channel = MethodChannel('money_swield/documents');

  @override
  Future<bool> saveDocument({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  }) async =>
      await _channel.invokeMethod<bool>('saveDocument', {
        'sourcePath': sourcePath,
        'suggestedName': suggestedName,
        'mimeType': mimeType,
      }) ??
      false;

  @override
  Future<String?> openDocument({
    required List<String> mimeTypes,
    required String destinationPath,
    required int maxBytes,
  }) async {
    try {
      return await _channel.invokeMethod<String>('openDocument', {
        'mimeTypes': mimeTypes,
        'destinationPath': destinationPath,
        'maxBytes': maxBytes,
      });
    } on PlatformException catch (error) {
      if (error.code == 'tooLarge') throw const DocumentTooLarge();
      rethrow;
    }
  }

  @override
  Future<String> appVersion() async =>
      await _channel.invokeMethod<String>('appVersion') ?? '';
}
