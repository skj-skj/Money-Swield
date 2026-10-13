import 'dart:io';

import 'package:money_swield/data/services/document_service.dart';

/// Stands in for the system save and open dialogs. By default saving
/// "saves" (keeps a copy of the bytes) and opening cancels.
class FakeDocumentService implements DocumentService {
  FakeDocumentService({this.version = '1.0.0+1'});

  final String version;

  /// The file the open dialog "picks": copied to the destination. Null
  /// means the user cancels.
  String? pickedFile;

  /// Makes the open dialog refuse the file as too large.
  bool pickedTooLarge = false;

  /// Makes the open dialog fail with this error, as the channel does for
  /// `busy`, `noActivity` or a copy that fails (`ioError`).
  Exception? openError;

  /// What the save dialog answers: true saves, false cancels; a throw
  /// fails the copy.
  Future<bool> Function(String sourcePath) onSave = (_) async => true;

  int openCalls = 0;
  int saveCalls = 0;
  String? savedName;
  List<int>? savedBytes;

  @override
  Future<String?> openDocument({
    required List<String> mimeTypes,
    required String destinationPath,
    required int maxBytes,
  }) async {
    openCalls++;
    if (pickedTooLarge) throw const DocumentTooLarge();
    if (openError case final error?) throw error;
    final picked = pickedFile;
    if (picked == null) return null;
    await File(destinationPath).parent.create(recursive: true);
    await File(picked).copy(destinationPath);
    return 'backup.zip';
  }

  @override
  Future<bool> saveDocument({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  }) async {
    saveCalls++;
    final saved = await onSave(sourcePath);
    if (saved) {
      savedName = suggestedName;
      savedBytes = await File(sourcePath).readAsBytes();
    }
    return saved;
  }

  @override
  Future<String> appVersion() async => version;
}
