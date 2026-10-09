import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_draft_repository.dart';
import 'package:my_expense_tracker_app/data/services/photo_store.dart';
import 'package:my_expense_tracker_app/data/services/photo_sweeper.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/photos.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/fake_photo_service.dart';
import '../../helpers/test_database.dart';
import '../../helpers/test_folders.dart';

/// `PhotoSweeper` (phase-6.md §6.5) on real files and SQLite 3.22.
void main() {
  late Database db;
  late Directory root;
  late PhotoStore store;
  late ExpenseDraftRepository drafts;
  late List<String> copies;
  var now = DateTime.utc(2026, 10, 7, 9);

  const uuid = '0f8fad5b-d9cb-469f-a165-70867728950e';
  const uuid2 = '1f8fad5b-d9cb-469f-a165-70867728950e';

  setUp(() async {
    db = await openMigratedDatabase();
    root = await testFolder('sweeper');
    now = DateTime.utc(2026, 10, 7, 9);
    store = PhotoStore(
      root: root.path,
      service: FakePhotoService(),
      now: () => now,
    );
    drafts = ExpenseDraftRepository(db);
    copies = [];
    Directory(store.photosPath).createSync(recursive: true);
    Directory(store.stagingPath).createSync(recursive: true);
  });

  PhotoSweeper sweeper({ExpenseDraftRepository? draftRepository}) =>
      PhotoSweeper(
        db: db,
        drafts: draftRepository ?? drafts,
        store: store,
        preRestoreCopies: () async => copies,
        openReadOnly: (path) => databaseFactoryFfiNoIsolate.openDatabase(
          path,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        ),
        now: () => now,
      );

  String file(String letter) => '${letter * 64}.jpg';

  /// A photo file on disk, and its row (linked to a new expense unless
  /// [linked] is false).
  Future<int> photo(String letter, {bool linked = true, Database? into}) async {
    final target = into ?? db;
    File(p.join(store.photosPath, file(letter))).writeAsStringSync(letter);
    final id = await target.insert('photos', {
      'relative_path': 'photos/${file(letter)}',
      'sha256': letter * 64,
      'byte_size': 1,
      'created_at': 0,
      'updated_at': 0,
    });
    if (linked) {
      await target.insert('expense_photos', {
        'expense_id': await insertExpenseRow(target),
        'photo_id': id,
        'sort_order': 0,
      });
    }
    return id;
  }

  void staged(String name) =>
      File(p.join(store.stagingPath, name)).writeAsStringSync('x');

  List<String> onDisk(String folder) =>
      [for (final f in Directory(folder).listSync()) p.basename(f.path)]
        ..sort();

  Future<List<int>> rowIds() async => [
    for (final r in await db.query('photos', orderBy: 'id')) r['id']! as int,
  ];

  ExpenseDraft draftWith(List<FormPhoto> photos, {int? editing}) =>
      ExpenseDraft(
        editingExpenseId: editing,
        title: 'Lunch',
        amountExpression: '',
        description: '',
        categoryId: null,
        eventIds: const {},
        paymentMethodId: null,
        currencyCode: 'INR',
        pickedWallClock: null,
        touched: const {},
        itemizeLine: null,
        itemizeLabels: const [],
        itemizeTerms: const [],
        updatedAt: now,
        photos: photos,
      );

  SavedPhoto saved(int id, String letter) => SavedPhoto(
    id: id,
    relativePath: 'photos/${file(letter)}',
    sha256: letter * 64,
    byteSize: 1,
  );

  /// A pre-restore copy: a migrated file with [rows] and [draft].
  Future<String> copy({
    List<String> rows = const [],
    ExpenseDraft? draft,
    bool phase5 = false,
  }) async {
    final path = p.join(root.path, 'copy${copies.length}.db');
    final copyDb = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    if (phase5) {
      await copyDb.execute('CREATE TABLE expenses (id INTEGER PRIMARY KEY)');
    } else {
      await copyDb.execute(
        'CREATE TABLE photos (id INTEGER PRIMARY KEY, relative_path TEXT)',
      );
      for (final letter in rows) {
        await copyDb.insert('photos', {
          'relative_path': 'photos/${file(letter)}',
        });
      }
      await copyDb.execute(
        'CREATE TABLE expense_draft (id INTEGER PRIMARY KEY, '
        'editing_expense_id INTEGER, form_json TEXT, updated_at INTEGER)',
      );
      if (draft != null) {
        await copyDb.insert('expense_draft', {
          'id': 1,
          'editing_expense_id': draft.editingExpenseId,
          'form_json': draft.toJson(),
          'updated_at': 0,
        });
      }
    }
    await copyDb.close();
    copies.add(path);
    return path;
  }

  test('rows: an unlinked row goes, one only the live draft names stays, '
      'linked ones stay; files follow the rows', () async {
    final linked = await photo('a');
    final orphan = await photo('b', linked: false);
    final inDraft = await photo('c', linked: false);
    drafts.update(draftWith([saved(inDraft, 'c')]));

    final result = await sweeper().sweep();
    expect(result, (rows: 1, files: 1, filesSkipped: false));
    expect(await rowIds(), [linked, inDraft]);
    expect(orphan, isNot(linked));
    expect(onDisk(store.photosPath), [file('a'), file('c')]);
  });

  test('staged files: the draft\'s and the camera\'s stay; the rest, '
      'previews and partials go; .nomedia and the marker stay', () async {
    staged('$uuid.jpg');
    staged('$uuid2.jpg');
    staged('capture-$uuid.jpg');
    staged('preview-$uuid.jpg');
    staged('$uuid2.jpg.partial');
    staged('.nomedia');
    await store.markPendingCapture('capture-$uuid.jpg', null);
    drafts.update(
      draftWith([
        const StagedPhoto(stagingName: '$uuid.jpg', sha256: 'x', byteSize: 1),
      ]),
    );
    await sweeper().sweep();
    expect(onDisk(store.stagingPath), [
      '.nomedia',
      '$uuid.jpg',
      'capture-$uuid.jpg',
      PhotoStore.markerName,
    ]);
  });

  test('a camera marker older than 30 days is dropped with its file', () async {
    staged('capture-$uuid.jpg');
    await store.markPendingCapture('capture-$uuid.jpg', 3);
    now = now.add(const Duration(days: 31));
    await sweeper().sweep();
    expect(await store.pendingCapture(), isNull);
    expect(onDisk(store.stagingPath), isEmpty);
  });

  test('a pre-restore copy\'s rows and draft keep their files; a copy '
      'from before Phase 6 adds nothing', () async {
    await photo('a', linked: false);
    await photo('b', linked: false);
    await photo('d', linked: false);
    staged('$uuid.jpg');
    staged('$uuid2.jpg');
    await copy(rows: ['a']);
    await copy(
      draft: draftWith([
        saved(99, 'b'),
        StagedPhoto(stagingName: '$uuid.jpg', sha256: 'e' * 64, byteSize: 1),
      ]),
    );
    await copy(phase5: true);
    final result = await sweeper().sweep();
    expect(result.rows, 3, reason: 'the live rows are unlinked');
    expect(result.filesSkipped, isFalse);
    expect(onDisk(store.photosPath), [file('a'), file('b')]);
    expect(onDisk(store.stagingPath), ['$uuid.jpg']);
  });

  test('a copy that is not a database: no file deleted, rows still '
      'swept', () async {
    await photo('a', linked: false);
    final bad = p.join(root.path, 'bad.db');
    File(bad).writeAsStringSync('not a database at all, just some text');
    copies.add(bad);
    final result = await sweeper().sweep();
    expect(result.filesSkipped, isTrue);
    expect(result.rows, 1);
    expect(onDisk(store.photosPath), [file('a')]);
  });

  test('a draft read that throws: no file and no row deleted (stricter '
      'than §6.5, §12a)', () async {
    await photo('a', linked: false);
    staged('$uuid.jpg');
    final failing = ExpenseDraftRepository(_ThrowingDb());
    final result = await sweeper(draftRepository: failing).sweep();
    expect(result, (rows: 0, files: 0, filesSkipped: true));
    expect(await rowIds(), hasLength(1));
    expect(onDisk(store.photosPath), [file('a')]);
    expect(onDisk(store.stagingPath), ['$uuid.jpg']);
  });

  test('files we did not name, and the Pictures folder, are never '
      'touched', () async {
    File(p.join(store.photosPath, 'README.txt')).writeAsStringSync('x');
    File(p.join(store.photosPath, '${'a' * 64}.JPG')).writeAsStringSync('x');
    final pictures = Directory(p.join(root.path, 'Pictures'))..createSync();
    File(p.join(pictures.path, 'Lunch.jpg')).writeAsStringSync('x');
    await sweeper().sweep();
    expect(
      onDisk(store.photosPath),
      unorderedEquals(['${'a' * 64}.JPG', 'README.txt']),
    );
    expect(onDisk(pictures.path), ['Lunch.jpg']);
  });

  test('a shared photo survives while any expense links it', () async {
    final shared = await photo('a');
    await db.insert('expense_photos', {
      'expense_id': await insertExpenseRow(db),
      'photo_id': shared,
      'sort_order': 0,
    });
    await db.delete(
      'expenses',
      where: 'id = (SELECT min(expense_id) FROM expense_photos)',
    );
    await sweeper().sweep();
    expect(await rowIds(), [shared]);
    expect(onDisk(store.photosPath), [file('a')]);
  });

  test('without a photo folder it does nothing', () async {
    store = PhotoStore(root: null, service: FakePhotoService());
    await photo('a', linked: false).catchError((_) => 0);
    expect((await sweeper().sweep()).filesSkipped, isTrue);
  });

  test('10,000 files: the plan and deletes finish (time logged)', () async {
    for (var i = 0; i < 10000; i++) {
      File(
        p.join(store.photosPath, '${i.toRadixString(16).padLeft(64, '0')}.jpg'),
      ).writeAsStringSync('');
    }
    final watch = Stopwatch()..start();
    final result = await sweeper().sweep();
    // The time is the point of this test; there is no logger in tests.
    // ignore: avoid_print
    print('swept 10,000 unreferenced files in ${watch.elapsedMilliseconds} ms');
    expect(result.files, 10000);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

class _ThrowingDb implements Database {
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async => throw StateError('disk I/O error');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
