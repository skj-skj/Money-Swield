import 'dart:convert';
import 'dart:io';

import 'package:money_swield/data/services/photo_service.dart';
import 'package:money_swield/domain/photo_sizing.dart';
import 'package:path/path.dart' as p;

/// A picture the fake knows: its header and the bytes a kept copy has.
typedef FakePicture = ({
  int width,
  int height,
  String mimeType,
  List<int> bytes,
});

/// One `saveToPictures` call, as MediaStore would have stored it.
typedef SavedPicture = ({
  String name,
  String mimeType,
  DateTime dateTaken,
  String exifDateTime,
  String exifOffset,
  List<int> bytes,
});

/// Stands in for the photos channel. Records every call.
///
/// Sources are names in [pictures] (a picker's URIs) or real files the fake
/// wrote itself (the camera's file). Staging writes real files: [KeepBytes]
/// copies the source's bytes; [Encode] writes bytes that name the source, size,
/// quality and turns, so two different plans never give the same SHA-256.
/// "Pictures" is insert-only and renames a name already there to "name
/// (1).jpg", like MediaStore.
class FakePhotoService implements PhotoService {
  /// What the picker and the files know, by source.
  final pictures = <String, FakePicture>{};

  /// What the picker returns next; empty means cancelled.
  List<String> nextPick = [];

  /// Whether the camera "takes" a picture (writes one) or is cancelled.
  bool cameraTakes = true;

  /// What the camera writes.
  FakePicture cameraPicture = (
    width: 4000,
    height: 3000,
    mimeType: 'image/jpeg',
    bytes: utf8.encode('camera'),
  );

  /// Thrown by the call of that name, once set.
  final errors = <String, PhotoServiceException>{};

  /// Sources whose stage fails with [PhotoError.ioError].
  final failingSources = <String>{};

  /// Display names whose save fails.
  final failingSaves = <String>{};

  int free = 1 << 40;

  final calls = <String>[];
  final pickLimits = <int>[];
  final stages = <({String source, PhotoPlan plan, int quarterTurns})>[];

  /// "Pictures/Money Swield", by final name, in the order inserted.
  final savedPictures = <SavedPicture>[];

  void _call(String name) {
    calls.add(name);
    if (errors[name] case final error?) throw error;
  }

  @override
  Future<bool> capture(String path) async {
    _call('capture');
    if (!cameraTakes) return false;
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(cameraPicture.bytes);
    pictures[path] = cameraPicture;
    return true;
  }

  @override
  Future<List<String>> pick(int maxItems) async {
    _call('pick');
    pickLimits.add(maxItems);
    final picked = nextPick;
    nextPick = [];
    return picked;
  }

  @override
  Future<ImageFacts> inspect(String source) async {
    _call('inspect');
    final picture = pictures[source];
    if (picture == null) {
      throw const PhotoServiceException(PhotoError.notAnImage, 'unknown');
    }
    return (
      width: picture.width,
      height: picture.height,
      mimeType: picture.mimeType,
      bytes: picture.bytes.length,
    );
  }

  @override
  Future<void> preview(String source, String destination) async {
    _call('preview');
    await File(destination).parent.create(recursive: true);
    await File(destination).writeAsBytes(utf8.encode('preview of $source'));
  }

  @override
  Future<int> stage({
    required String source,
    required String destination,
    required PhotoPlan plan,
    required int quarterTurns,
  }) async {
    _call('stage');
    stages.add((source: source, plan: plan, quarterTurns: quarterTurns));
    if (failingSources.contains(source)) {
      throw const PhotoServiceException(PhotoError.ioError, 'failing');
    }
    final picture = pictures[source];
    if (picture == null) {
      throw const PhotoServiceException(PhotoError.notAnImage, 'unknown');
    }
    final bytes = switch (plan) {
      KeepBytes() => picture.bytes,
      Encode(:final width, :final height, :final quality) => utf8.encode(
        'jpeg of ${p.basename(source)} ${width}x$height q$quality '
        't$quarterTurns ${picture.bytes.length}',
      ),
    };
    await File(destination).parent.create(recursive: true);
    await File(destination).writeAsBytes(bytes);
    return bytes.length;
  }

  @override
  Future<String> saveToPictures({
    required String sourcePath,
    required String folder,
    required String displayName,
    required String mimeType,
    required DateTime dateTaken,
    required String exifDateTime,
    required String exifOffset,
  }) async {
    _call('saveToPictures');
    if (failingSaves.contains(displayName)) {
      throw const PhotoServiceException(PhotoError.ioError, 'refused');
    }
    final dot = displayName.lastIndexOf('.');
    final (stem, extension) = (
      displayName.substring(0, dot),
      displayName.substring(dot),
    );
    var name = displayName;
    for (var n = 1; savedPictures.any((s) => s.name == name); n++) {
      name = '$stem ($n)$extension';
    }
    savedPictures.add((
      name: name,
      mimeType: mimeType,
      dateTaken: dateTaken,
      exifDateTime: exifDateTime,
      exifOffset: exifOffset,
      bytes: await File(sourcePath).readAsBytes(),
    ));
    return name;
  }

  @override
  Future<int> freeBytes(String path) async {
    _call('freeBytes');
    return free;
  }

  /// A picked picture of [width] × [height] (1080p: kept as it is by
  /// default) named [uri], with its own
  /// bytes, so each has another SHA-256.
  String addPicked(
    String uri, {
    int width = 1440,
    int height = 1080,
    String mimeType = 'image/jpeg',
  }) {
    pictures[uri] = (
      width: width,
      height: height,
      mimeType: mimeType,
      bytes: utf8.encode('picked $uri'),
    );
    return uri;
  }
}
