import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/photo_sweep.dart';

void main() {
  final a = '${'a' * 64}.jpg';
  final b = '${'b' * 64}.png';
  const uuid = '0f8fad5b-d9cb-469f-a165-70867728950e';

  SweepPlan plan({
    List<String> photos = const [],
    List<String> staging = const [],
    Set<String> paths = const {},
    Set<String> staged = const {},
  }) => sweepPlan(
    photoFilesOnDisk: photos,
    stagingFilesOnDisk: staging,
    referencedPaths: paths,
    referencedStaging: staged,
  );

  test('an unreferenced photo is deleted, a referenced one kept', () {
    final out = plan(photos: [a, b], paths: {'photos/$a'});
    expect(out.photoFiles, [b]);
    expect(out.stagingFiles, isEmpty);
  });

  test('files we did not name are left alone', () {
    final out = plan(
      photos: ['.nomedia', 'README.txt', '${'a' * 64}.JPG', '${'a' * 63}.jpg'],
      staging: ['.nomedia', 'pending_capture.json', 'notes.txt'],
    );
    expect(out.photoFiles, isEmpty);
    expect(out.stagingFiles, isEmpty);
  });

  test('.partial files are deleted in both folders', () {
    final out = plan(
      photos: ['$a.partial'],
      staging: ['$uuid.jpg.partial', 'pending_capture.json.partial'],
      paths: {'photos/$a'},
    );
    expect(out.photoFiles, ['$a.partial']);
    expect(out.stagingFiles, [
      '$uuid.jpg.partial',
      'pending_capture.json.partial',
    ]);
  });

  test('staging: an unreferenced name goes; a referenced one (the draft, '
      'the capture marker) stays; a preview always goes', () {
    final out = plan(
      staging: [
        '$uuid.jpg',
        'capture-$uuid.jpg',
        'preview-$uuid.jpg',
        '1f8fad5b-d9cb-469f-a165-70867728950e.jpg',
      ],
      staged: {'$uuid.jpg', 'capture-$uuid.jpg'},
    );
    expect(out.stagingFiles, [
      'preview-$uuid.jpg',
      '1f8fad5b-d9cb-469f-a165-70867728950e.jpg',
    ]);
  });

  test('a reference by another folder\'s name does not keep a file', () {
    final out = plan(photos: [a], staging: [a], paths: {a}, staged: {a});
    expect(out.photoFiles, [a], reason: 'references are photos/<name>');
    expect(out.stagingFiles, isEmpty, reason: 'not a staging name');
  });
}
