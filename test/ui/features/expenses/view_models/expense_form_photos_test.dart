import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_draft_repository.dart';
import 'package:my_expense_tracker_app/data/services/photo_service.dart';
import 'package:my_expense_tracker_app/data/services/photo_store.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/photo_sizing.dart';
import 'package:my_expense_tracker_app/domain/photos.dart';
import 'package:my_expense_tracker_app/ui/features/expenses/view_models/expense_form_cubit.dart';
import 'package:path/path.dart' as p;

import '../../../../helpers/fake_photo_service.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/test_folders.dart';

/// Photos in the Add / Edit form (phase-6.md §7.1), on real files.
void main() {
  late AppDependencies deps;
  late TestClock clock;
  late FakePhotoService service;
  late PhotoStore store;

  const camera = (size: PhotoSize.p1080, quality: 90);
  const gallery = (size: PhotoSize.p720, quality: 70);

  setUp(() async {
    clock = TestClock();
    final root = await testFolder('form_photos');
    service = FakePhotoService();
    store = PhotoStore(root: root.path, service: service, now: clock.call);
    deps = await openTestDependencies(clock: clock);
  });

  Future<ExpenseFormCubit> openForm({
    int? expenseId,
    ExpenseDraft? draft,
  }) async {
    final cubit = ExpenseFormCubit(
      expenses: deps.expenses,
      categories: deps.categories,
      events: deps.events,
      paymentMethods: deps.paymentMethods,
      drafts: deps.drafts,
      l10n: l10nFor('en'),
      defaultCurrency: 'INR',
      defaultPaymentMethodId: 1,
      photos: store,
      cameraSizing: camera,
      gallerySizing: gallery,
      expenseId: expenseId,
      openingDraft: draft,
      now: clock.call,
    );
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  ExpenseFormReady ready(ExpenseFormCubit c) => c.value as ExpenseFormReady;
  List<FormPhoto> photos(ExpenseFormCubit c) => ready(c).fields.photos;

  Future<ExpenseFormCubit> validForm() async => (await openForm())
    ..titleChanged('Lunch')
    ..amountChanged('110.50')
    ..categorySelected(1);

  /// Picks [uris] (added to the fake) through the gallery.
  Future<PhotoAddReport?> pick(ExpenseFormCubit c, List<String> uris) {
    for (final uri in uris) {
      if (!service.pictures.containsKey(uri)) {
        service.addPicked(uri, width: 1280, height: 720);
      }
    }
    service.nextPick = uris;
    return c.addFromGallery();
  }

  Future<Expense> seedWithPhotos(List<String> letters) => deps.expenses.add(
    ExpenseInput(
      title: 'Taxi',
      description: null,
      amount: const Money(500, 'INR'),
      occurredAt: clock.now.subtract(const Duration(days: 1)),
      utcOffsetMinutes: 330,
      categoryId: 1,
      paymentMethodId: 1,
      eventIds: const {},
      photos: [
        for (final l in letters)
          LinkNewPhoto(
            relativePath: 'photos/${l * 64}.jpg',
            sha256: l * 64,
            byteSize: 1,
          ),
      ],
    ),
  );

  group('gallery', () {
    test('3 picked → staged with the gallery sizing, added in order, the '
        'form dirty and in the draft', () async {
      final c = await validForm();
      final report = await pick(c, ['u1', 'u2', 'u3']);
      expect(report, (
        added: 3,
        duplicates: 0,
        overflow: 0,
        failed: 0,
        error: null,
      ));
      expect(photos(c), hasLength(3));
      expect(service.stages.map((s) => s.plan).toSet(), {
        const KeepBytes(),
      }, reason: '1280 × 720 fits 720p');
      expect(service.pickLimits, [10]);
      expect(ready(c).photoWork, isA<PhotoIdle>());
      expect((await deps.drafts.read())!.photos, photos(c));
    });

    test('a 4000 × 3000 pick is encoded at the gallery quality', () async {
      final c = await validForm();
      service.addPicked('big', width: 4000, height: 3000);
      await pick(c, ['big']);
      expect(
        service.stages.single.plan,
        const Encode(width: 960, height: 720, quality: 70),
      );
    });

    test('9 photos + pick asks for 1; 10 refuses to open the picker', () async {
      final c = await validForm();
      await pick(c, [for (var i = 0; i < 9; i++) 'u$i']);
      await pick(c, ['x']);
      expect(service.pickLimits, [10, 1]);
      expect(photos(c), hasLength(10));
      expect(c.canAddPhotos, isFalse);
      expect(await pick(c, ['y']), isNull);
      expect(service.pickLimits, hasLength(2));
    });

    test('the document picker returning 5 for 2 slots: 2 staged, 3 '
        'overflow', () async {
      final c = await validForm();
      await pick(c, [for (var i = 0; i < 8; i++) 'u$i']);
      service.stages.clear();
      final report = await pick(c, ['a', 'b', 'c', 'd', 'e']);
      expect(service.stages.map((s) => s.source), ['a', 'b']);
      expect(report!.added, 2);
      expect(report.overflow, 3);
      expect(photos(c), hasLength(10));
    });

    test('a duplicate is reported and its staged file deleted', () async {
      final c = await validForm();
      await pick(c, ['u1']);
      final report = await pick(c, ['u1']);
      expect(report!.duplicates, 1);
      expect(photos(c), hasLength(1));
      await pumpEventQueue();
      final staged = Directory(store.stagingPath)
          .listSync()
          .map((f) => p.basename(f.path))
          .where(isValidStagingName);
      expect(staged, hasLength(1));
    });

    test('one failing photo: the others go in', () async {
      final c = await validForm();
      service.addPicked('bad');
      service.failingSources.add('bad');
      final report = await pick(c, ['u1', 'bad', 'u2']);
      expect(report!.failed, 1);
      expect(report.added, 2);
    });

    test('cancelled: nothing changes', () async {
      final c = await validForm();
      expect(await pick(c, []), isNull);
      expect(photos(c), isEmpty);
      expect(ready(c).photoWork, isA<PhotoIdle>());
    });

    test('a second call while picking is ignored (double tap)', () async {
      final c = await validForm();
      service.addPicked('u1');
      service.nextPick = ['u1'];
      final first = c.addFromGallery();
      final second = c.addFromGallery();
      expect(await second, isNull);
      await first;
      expect(service.calls.where((x) => x == 'pick'), hasLength(1));
    });

    test('Save and Update are off while picking; Back waits', () async {
      final c = await validForm();
      final gate = Completer<List<String>>();
      final slow = _SlowPick(service, gate.future);
      final s2 = PhotoStore(root: store.root, service: slow);
      final cubit = ExpenseFormCubit(
        expenses: deps.expenses,
        categories: deps.categories,
        events: deps.events,
        paymentMethods: deps.paymentMethods,
        drafts: deps.drafts,
        l10n: l10nFor('en'),
        defaultCurrency: 'INR',
        defaultPaymentMethodId: 1,
        photos: s2,
        now: clock.call,
      );
      addTearDown(cubit.close);
      await cubit.load();
      cubit
        ..titleChanged('Lunch')
        ..amountChanged('5')
        ..categorySelected(1);
      final picking = cubit.addFromGallery();
      expect(cubit.canSave, isFalse);
      expect(cubit.photosBusy, isTrue);
      expect(await cubit.save(), isNull);
      gate.complete([]);
      await picking;
      expect(cubit.canSave, isTrue);
      expect(c.photosBusy, isFalse);
    });
  });

  group('camera', () {
    test('the marker is written and the draft flushed before the camera '
        'opens', () async {
      final c = await validForm();
      final seen = <String>[];
      service.cameraTakes = true;
      final probe = _BeforeCapture(service, () async {
        final marker = await store.pendingCapture();
        seen.add('marker ${marker?.editingExpenseId}');
        seen.add('draft ${(await deps.drafts.read())?.title}');
      });
      final s2 = PhotoStore(root: store.root, service: probe, now: clock.call);
      final cubit = ExpenseFormCubit(
        expenses: deps.expenses,
        categories: deps.categories,
        events: deps.events,
        paymentMethods: deps.paymentMethods,
        drafts: deps.drafts,
        l10n: l10nFor('en'),
        defaultCurrency: 'INR',
        defaultPaymentMethodId: 1,
        photos: s2,
        now: clock.call,
      );
      addTearDown(cubit.close);
      await cubit.load();
      cubit.titleChanged('Typed');
      await cubit.addFromCamera();
      expect(seen, ['marker null', 'draft Typed']);
      final rows = await deps.database.query('expense_draft');
      expect(rows, hasLength(1), reason: 'flushed, not only in memory');
      expect(c.isClosed, isFalse);
    });

    test('cancel: the file and the marker are gone', () async {
      final c = await validForm();
      service.cameraTakes = false;
      await c.addFromCamera();
      expect(await store.pendingCapture(), isNull);
      expect(ready(c).photoWork, isA<PhotoIdle>());
      final files = Directory(store.stagingPath)
          .listSync()
          .map((f) => p.basename(f.path))
          .where((n) => n.startsWith('capture-'));
      expect(files, isEmpty);
    });

    test('taken → review → Use photo with 1 turn: staged with the camera '
        'sizing and the turn; marker, camera file and preview gone', () async {
      final c = await validForm();
      await c.addFromCamera();
      final review = ready(c).photoWork as PhotoReviewing;
      expect(File(review.previewPath).existsSync(), isTrue);
      expect(c.canSave, isFalse);
      final report = await c.useCapture(1);
      expect(report!.added, 1);
      final stage = service.stages.single;
      expect(stage.quarterTurns, 1);
      expect(
        stage.plan,
        const Encode(width: 1080, height: 1440, quality: 90),
        reason: '4000 × 3000 turned once, at the camera sizing',
      );
      expect(await store.pendingCapture(), isNull);
      expect(File(review.previewPath).existsSync(), isFalse);
      expect(photos(c), hasLength(1));
      expect(c.canSave, isTrue);
    });

    test('Use photo: the draft row names the staged shot before the marker '
        'and the camera file go (regression: the marker went first, so a '
        'kill within the draft debounce lost the shot)', () async {
      final c = await validForm();
      await c.addFromCamera();
      final capture = (ready(c).photoWork as PhotoReviewing).captureName;
      await c.useCapture(0);
      // What a restarted app would find, without the form's memory.
      final row = await ExpenseDraftRepository(deps.database).read();
      expect(row!.photos, photos(c));
      expect(await store.pendingCapture(), isNull);
      expect(File(store.stagingFile(capture)).existsSync(), isFalse);
    });

    test('Use photo while the draft row can\'t be written: the marker and '
        'the camera file stay, so the shot comes back', () async {
      final c = await validForm();
      await c.addFromCamera();
      final capture = (ready(c).photoWork as PhotoReviewing).captureName;
      await deps.database.execute('DROP TABLE expense_draft');
      final report = await c.useCapture(0);
      expect(report!.added, 1);
      expect((await store.pendingCapture())!.name, capture);
      expect(File(store.stagingFile(capture)).existsSync(), isTrue);
    });

    test('Discard: nothing added, nothing left', () async {
      final c = await validForm();
      await c.addFromCamera();
      await c.discardCapture();
      expect(photos(c), isEmpty);
      expect(await store.pendingCapture(), isNull);
      final left = Directory(store.stagingPath)
          .listSync()
          .map((f) => p.basename(f.path))
          .where(isValidStagingName);
      expect(left, isEmpty);
    });

    test('a clean Add form keeps another expense\'s Edit draft through '
        'camera + cancel', () async {
      final taxi = await seedWithPhotos(['a']);
      deps.drafts.update(
        ExpenseDraft(
          editingExpenseId: taxi.id,
          title: 'Taxi edited',
          amountExpression: '5',
          description: '',
          categoryId: 1,
          eventIds: const {},
          paymentMethodId: 1,
          currencyCode: 'INR',
          pickedWallClock: null,
          touched: const {},
          itemizeLine: null,
          itemizeLabels: const [],
          itemizeTerms: const [],
          updatedAt: clock.now,
        ),
      );
      final c = await openForm();
      service.cameraTakes = false;
      await c.addFromCamera();
      await c.flushDraft();
      expect((await deps.drafts.read())!.title, 'Taxi edited');
    });

    test('a marker for Add: the next Add form opens the review (recovered), '
        'the next Edit of #7 doesn\'t', () async {
      final first = await validForm();
      await first.addFromCamera();
      await first.close();
      final taxi = await seedWithPhotos(['a']);
      final edit = await openForm(expenseId: taxi.id);
      expect(ready(edit).photoWork, isA<PhotoIdle>());
      final add = await openForm();
      final work = ready(add).photoWork;
      expect(work, isA<PhotoReviewing>());
      expect((work as PhotoReviewing).recovered, isTrue);
      await add.useCapture(0);
      expect(photos(add), hasLength(1));
    });

    test('a shot back on a form that is full: Use photo adds nothing and '
        'keeps the shot; removing a photo offers it again', () async {
      final first = await validForm();
      await first.addFromCamera();
      final capture = (ready(first).photoWork as PhotoReviewing).captureName;
      await first.close();
      final full = await seedWithPhotos([
        for (final l in '0123456789'.split('')) l,
      ]);
      final ten = await deps.expenses.photosOf(full.id);
      final add = await openForm(
        draft: ExpenseDraft(
          editingExpenseId: null,
          title: 'Ten',
          amountExpression: '',
          description: '',
          categoryId: null,
          eventIds: const {},
          paymentMethodId: 1,
          currencyCode: 'INR',
          pickedWallClock: null,
          touched: const {},
          itemizeLine: null,
          itemizeLabels: const [],
          itemizeTerms: const [],
          updatedAt: DateTime.utc(2026),
          photos: ten,
        ),
      );
      expect(ready(add).photoWork, isA<PhotoReviewing>());
      final report = await add.useCapture(0);
      expect(report!.overflow, 1);
      expect(photos(add), ten);
      expect(ready(add).photoWork, isA<PhotoIdle>());
      expect((await store.pendingCapture())!.name, capture);
      expect(File(store.stagingFile(capture)).existsSync(), isTrue);

      add.removePhotoAt(0);
      // The offer reads the marker and writes a preview: real file I/O.
      for (var i = 0; i < 200 && ready(add).photoWork is PhotoIdle; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final again = ready(add).photoWork;
      expect(again, isA<PhotoReviewing>());
      expect((again as PhotoReviewing).captureName, capture);
      await add.useCapture(0);
      expect(photos(add), hasLength(10));
      expect(await store.pendingCapture(), isNull);
    });

    test('a marker whose file is gone is cleared, no review', () async {
      final first = await validForm();
      await first.addFromCamera();
      final review = ready(first).photoWork as PhotoReviewing;
      await first.close();
      File(store.stagingFile(review.captureName)).deleteSync();
      final add = await openForm();
      expect(ready(add).photoWork, isA<PhotoIdle>());
      expect(await store.pendingCapture(), isNull);
    });

    test('no camera app: the error, nothing left', () async {
      final c = await validForm();
      service.errors['capture'] = const PhotoServiceException(
        PhotoError.noCamera,
      );
      expect(await c.addFromCamera(), PhotoError.noCamera);
      expect(await store.pendingCapture(), isNull);
      expect(ready(c).photoWork, isA<PhotoIdle>());
    });

    test('Use photo failing for space keeps the shot and its marker, to be '
        'offered again', () async {
      final c = await validForm();
      await c.addFromCamera();
      final review = ready(c).photoWork as PhotoReviewing;
      service.failingSources.add(store.stagingFile(review.captureName));
      final report = await c.useCapture(0);
      expect(report!.error, PhotoError.ioError);
      expect(await store.pendingCapture(), isNotNull);
      expect(File(store.stagingFile(review.captureName)).existsSync(), isTrue);
    });
  });

  group('selection and Save to Pictures', () {
    test(
      'long press → 1; toggle; select all; unselect the last ends',
      () async {
        final c = await validForm();
        await pick(c, ['u1', 'u2', 'u3']);
        c.startSelection(1);
        expect(ready(c).selection, {1});
        c.toggleSelected(2);
        expect(ready(c).selection, {1, 2});
        c.toggleSelected(1);
        c.toggleSelected(2);
        expect(ready(c).selection, isNull);
        c.startSelection(0);
        c.selectAll();
        expect(ready(c).selection, {0, 1, 2});
        c.clearSelection();
        expect(ready(c).selection, isNull);
      },
    );

    test('remove 2 selected → the list, dirtiness and the draft', () async {
      final c = await validForm();
      await pick(c, ['u1', 'u2', 'u3']);
      final [a, b, cc] = photos(c);
      c
        ..startSelection(0)
        ..toggleSelected(2);
      expect(c.removeSelected(), 2);
      expect(photos(c), [b]);
      expect(ready(c).selection, isNull);
      expect((await deps.drafts.read())!.photos, [b]);
      expect([a, cc], isNot(contains(b)));
    });

    test('Save to Pictures of 2: the form\'s title and date, nothing dirty, '
        'Update still off on an untouched Edit, selection kept', () async {
      final taxi = await seedWithPhotos(['a', 'b']);
      final dir = Directory(p.join(store.root, 'photos'))
        ..createSync(recursive: true);
      for (final l in ['a', 'b']) {
        File(p.join(dir.path, '${l * 64}.jpg')).writeAsStringSync(l);
      }
      final c = await openForm(expenseId: taxi.id);
      c
        ..startSelection(0)
        ..toggleSelected(1);
      final result = await c.saveSelectedToPictures();
      expect(result, (saved: 2, missing: 0, failed: 0, noSpace: false));
      final day = taxi.occurredOn;
      expect(service.savedPictures.map((s) => s.name), [
        'Taxi $day.jpg',
        'Taxi $day (1).jpg',
      ]);
      expect(service.savedPictures.first.exifOffset, '+05:30');
      expect(c.isDirty, isFalse);
      expect(c.canSave, isFalse);
      expect(ready(c).selection, {0, 1});
      expect(await deps.drafts.read(), isNull, reason: 'not an edit');
    });

    test('viewer: save one; a missing one says so', () async {
      final c = await validForm();
      await pick(c, ['u1', 'u2']);
      File(store.pathOf(photos(c)[1])!).deleteSync();
      expect((await c.savePhotoToPictures(0))!.saved, 1);
      expect((await c.savePhotoToPictures(1))!.missing, 1);
      expect(service.savedPictures.single.name, startsWith('Lunch '));
    });

    test('removePhotoAt from the viewer', () async {
      final c = await validForm();
      await pick(c, ['u1', 'u2']);
      final second = photos(c)[1];
      c.removePhotoAt(0);
      expect(photos(c), [second]);
    });
  });

  group('saving', () {
    test('Add with 2 photos: promoted, linked in order, staged files gone, '
        'the draft gone', () async {
      final c = await validForm();
      await pick(c, ['u1', 'u2']);
      final staged = [...photos(c).cast<StagedPhoto>()];
      final saved = await c.save();
      expect(saved!.photoCount, 2);
      final stored = await deps.expenses.photosOf(saved.id);
      expect(
        [for (final p in stored) p.sha256],
        [for (final p in staged) p.sha256],
      );
      for (final p in stored) {
        expect(File(store.pathOf(p)!).existsSync(), isTrue);
      }
      for (final s in staged) {
        expect(File(store.stagingFile(s.stagingName)).existsSync(), isFalse);
      }
      expect(await deps.drafts.read(), isNull);
      expect(c.lastPhotosNotKept, 0);
    });

    test('Edit: add → Update on; remove → Update; Discard draft brings the '
        'stored photos back; no change → off', () async {
      final taxi = await seedWithPhotos(['a', 'b']);
      final c = await openForm(expenseId: taxi.id);
      expect(c.canSave, isFalse);
      await pick(c, ['u1']);
      expect(c.canSave, isTrue);
      c.removePhotoAt(2);
      expect(c.canSave, isFalse, reason: 'back to the stored photos');
      c.removePhotoAt(0);
      expect(c.canSave, isTrue);
      final updated = await c.save();
      expect(updated!.photoCount, 1);
      expect((await deps.expenses.photosOf(taxi.id)).single.sha256, 'b' * 64);
    });

    test('Discard draft: an Edit draft with an added photo goes back to '
        'the stored photos; Undo brings the added one back', () async {
      final taxi = await seedWithPhotos(['a']);
      final first = await openForm(expenseId: taxi.id);
      await pick(first, ['u1']);
      await first.flushDraft();
      await first.close();
      final draft = await deps.drafts.read();
      final c = await openForm(expenseId: taxi.id, draft: draft);
      expect(photos(c), hasLength(2));
      await c.discardDraft();
      expect(photos(c), hasLength(1));
      c.undoReset();
      expect(photos(c), hasLength(2));
    });

    test('Clear → Undo → saved with the photos', () async {
      final c = await validForm();
      await pick(c, ['u1']);
      await c.clear();
      expect(photos(c), isEmpty);
      c.undoReset();
      expect(photos(c), hasLength(1));
      final saved = await c.save();
      expect(saved!.photoCount, 1);
    });

    test('a failing promote: nothing saved, the draft and staged files '
        'untouched, PhotoSaveFailed', () async {
      final c = await validForm();
      await pick(c, ['u1']);
      await c.flushDraft();
      final staged = photos(c).single as StagedPhoto;
      Directory(store.photosPath).createSync(recursive: true);
      Directory(p.join(store.root, '${staged.savedPath}.partial')).createSync();
      await expectLater(c.save(), throwsA(isA<PhotoSaveFailed>()));
      expect(await deps.expenses.page(), isEmpty);
      expect((await deps.drafts.read())!.photos, [staged]);
      expect(File(store.stagingFile(staged.stagingName)).existsSync(), isTrue);
      expect(ready(c).saving, isFalse);
    });

    test('killed between promote and commit: reopened from the draft, the '
        'photos are there', () async {
      final c = await validForm();
      await pick(c, ['u1']);
      await c.flushDraft();
      final staged = photos(c).single as StagedPhoto;
      await store.promote(staged); // …and the app dies here.
      await c.close();
      final draft = await deps.drafts.read();
      final again = await openForm(draft: draft);
      expect(photos(again), [staged]);
      expect((await again.save())!.photoCount, 1);
    });

    test('a draft with a vanished row and a gone staged file: both dropped, '
        'one count', () async {
      final taxi = await seedWithPhotos(['a', 'b']);
      final [a, b] = await deps.expenses.photosOf(taxi.id);
      final c0 = await openForm(expenseId: taxi.id);
      await pick(c0, ['u1']);
      await c0.flushDraft();
      await c0.close();
      final draft = (await deps.drafts.read())!;
      final staged = draft.photos.last as StagedPhoto;
      File(store.stagingFile(staged.stagingName)).deleteSync();
      await deps.database.delete('expense_photos');
      await deps.database.delete('photos', where: 'id = ?', whereArgs: [a.id]);
      await deps.database.insert('expense_photos', {
        'expense_id': taxi.id,
        'photo_id': b.id,
        'sort_order': 0,
      });
      final c = await openForm(expenseId: taxi.id, draft: draft);
      expect(ready(c).droppedDraftPhotos, 2);
      expect(photos(c), [b]);
    });

    test('a photo row gone between the draft and Update: saved without it, '
        'and the count says 1', () async {
      final taxi = await seedWithPhotos(['a', 'b']);
      final c = await openForm(expenseId: taxi.id);
      c.titleChanged('Taxi 2');
      final [a, _] = await deps.expenses.photosOf(taxi.id);
      await deps.database.delete(
        'expense_photos',
        where: 'photo_id = ?',
        whereArgs: [a.id],
      );
      await deps.database.delete('photos', where: 'id = ?', whereArgs: [a.id]);
      final updated = await c.save();
      expect(updated!.photoCount, 1);
      expect(c.lastPhotosNotKept, 1);
    });

    test('Update of an expense binned meanwhile keeps the photos in the Add '
        'draft', () async {
      final taxi = await seedWithPhotos(['a']);
      final c = await openForm(expenseId: taxi.id);
      await pick(c, ['u1']);
      await deps.expenses.moveToBin(taxi.id);
      expect(await c.save(), isNull);
      final draft = (await deps.drafts.read())!;
      expect(draft.isAdd, isTrue);
      expect(draft.photos, hasLength(2));
    });

    test(
      '12 photos in a damaged draft: Save refused, says 2 too many',
      () async {
        final staged = [
          for (var i = 0; i < 12; i++)
            StagedPhoto(
              stagingName: store.newStagingName('jpg'),
              sha256: i.toRadixString(16).padLeft(64, '0'),
              byteSize: 1,
            ),
        ];
        Directory(store.stagingPath).createSync(recursive: true);
        for (final s in staged) {
          File(store.stagingFile(s.stagingName)).writeAsStringSync('x');
        }
        final c = await openForm(
          draft: ExpenseDraft(
            editingExpenseId: null,
            title: 'Lunch',
            amountExpression: '5',
            description: '',
            categoryId: 1,
            eventIds: const {},
            paymentMethodId: 1,
            currencyCode: 'INR',
            pickedWallClock: null,
            touched: null,
            itemizeLine: null,
            itemizeLabels: const [],
            itemizeTerms: const [],
            updatedAt: clock.now,
            photos: staged,
          ),
        );
        expect(photos(c), hasLength(12));
        expect(await c.save(), isNull);
        expect(c.photosOverLimit, 2);
        c.removePhotoAt(0);
        c.removePhotoAt(0);
        expect((await c.save())!.photoCount, 10);
      },
    );

    test('a title pick keeps the photos, also on a second pick after a '
        'photo was added (regression)', () async {
      await deps.expenses.add(
        ExpenseInput(
          title: 'Coffee',
          description: 'Latte',
          amount: const Money(15000, 'INR'),
          occurredAt: clock.now.subtract(const Duration(days: 2)),
          utcOffsetMinutes: 330,
          categoryId: 2,
          paymentMethodId: 1,
          eventIds: const {},
        ),
      );
      final c = await openForm();
      await Future<void>.delayed(Duration.zero);
      c.titleChanged('Cof');
      final suggestion = ready(c).suggestions
          .firstWhere((s) => s.title == 'Coffee');
      await c.pickSuggestion(suggestion);
      await pick(c, ['u1']);
      expect(photos(c), hasLength(1));
      c.titleChanged('Cof');
      expect(
        ready(c).suggestions,
        isNotEmpty,
        reason: 'a photo is not a field a suggestion fills',
      );
      await c.pickSuggestion(
        ready(c).suggestions.firstWhere((s) => s.title == 'Coffee'),
      );
      expect(photos(c), hasLength(1), reason: 'the second pick kept it');
      expect(fieldsDescription(c), 'Latte');
    });
  });
}

String fieldsDescription(ExpenseFormCubit c) =>
    (c.value as ExpenseFormReady).fields.description;

/// A service whose picker waits for `_result`.
class _SlowPick extends FakePhotoService {
  _SlowPick(this._inner, this._result);

  final FakePhotoService _inner;
  final Future<List<String>> _result;

  @override
  Future<List<String>> pick(int maxItems) => _result;

  @override
  Future<ImageFacts> inspect(String source) => _inner.inspect(source);
}

/// A service that runs `_before` when the camera is asked to open.
class _BeforeCapture extends FakePhotoService {
  _BeforeCapture(this._inner, this._before);

  final FakePhotoService _inner;
  final Future<void> Function() _before;

  @override
  Future<bool> capture(String path) async {
    await _before();
    return _inner.capture(path);
  }

  @override
  Future<void> preview(String source, String destination) =>
      _inner.preview(source, destination);
}
