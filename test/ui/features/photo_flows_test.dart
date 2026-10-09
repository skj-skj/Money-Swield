import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/services/photo_store.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/domain/photo_sizing.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_selection_bar.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_thumb.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_viewer.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/home_list_slivers.dart';
import 'package:path/path.dart' as p;

import '../../helpers/fake_photo_service.dart';
import '../../helpers/pump_app.dart' as app;
import '../../helpers/pump_app.dart' show pumpApp;
import '../../helpers/test_database.dart';
import '../../helpers/test_folders.dart';
import '../../helpers/test_images.dart';

/// Photos on the Add / Edit form through the real app (phase-6.md §12,
/// Widgets). Files are real (staging, promotion), so the steps that touch
/// them are pumped with [pumpUntil]; pictures show as memory images (F17).
/// [app.pumpUntil] with a 1 ms fake step: the photo timeouts run on the
/// fake clock.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  String? description,
}) => app.pumpUntil(
  tester,
  condition,
  description: description,
  step: const Duration(milliseconds: 1),
);

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) => pumpUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  description: '$finder',
);

void main() {
  late AppDependencies deps;
  late FakePhotoService service;
  late PhotoStore store;

  Future<void> setUpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      final root = await testFolder('photo_flows');
      service = FakePhotoService();
      store = PhotoStore(
        root: root.path,
        service: service,
        imageFactory: memoryImages(
          isMissing: (path) => !File(path).existsSync(),
        ),
      );
      deps = await openTestDependencies(photos: store);
      await deps.settings.setOnboardingCompleted();
    });
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Finder photoButton() => find.byKey(const ValueKey('photoButton'));

  /// The confirm dialog's Delete, not the bar's.
  final dialogDelete = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(TextButton, 'Delete'),
  );
  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> openAddForm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add expense'));
    await tester.pumpAndSettle();
  }

  /// Gallery: picks [uris] through the chooser and waits until the form
  /// has [total] photos.
  Future<void> pickFromGallery(
    WidgetTester tester,
    List<String> uris, {
    required int total,
    Finder? opener,
    Finder? until,
  }) async {
    for (final uri in uris) {
      service.addPicked(uri);
    }
    service.nextPick = uris;
    await tester.tap(opener ?? photoButton());
    await tester.pumpAndSettle();
    // By its icon, so it works in every language.
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    final label = total == 1 ? '1 photo, open' : '$total photos, open';
    final done = until ?? find.bySemanticsLabel(label);
    await pumpUntil(
      tester,
      () => done.evaluate().isNotEmpty,
      description: '$done',
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillValid(WidgetTester tester, {String title = 'Lunch'}) async {
    await tester.enterText(field('Title'), title);
    await tester.enterText(field('Amount'), '110');
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSaveAndWait(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(TextButton, label));
    await pumpUntil(
      tester,
      () =>
          find.text('Add expense').evaluate().isNotEmpty &&
          find.widgetWithText(TextButton, label).evaluate().isEmpty,
      description: 'back on Home',
    );
    await tester.pumpAndSettle();
  }

  // The owner, after the Oppo run: square, centred on the description.
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('font $scale: the button is 56 × 56 and centred on the '
        'description, also while it grows', (tester) async {
      await setUpApp(tester);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, dependencies: deps);
      await openAddForm(tester);
      final description = field('Description (optional)');
      await tester.ensureVisible(description);
      await tester.pumpAndSettle();
      for (final text in ['', 'one\ntwo\nthree\nfour']) {
        await tester.enterText(description, text);
        await tester.pumpAndSettle();
        final button = tester.getRect(photoButton());
        expect(button.size, const Size(56, 56));
        expect(
          button.center.dy,
          closeTo(tester.getRect(description).center.dy, 0.5),
        );
      }
    });
  }

  testWidgets('the button sits left of the description, centred on it; the '
      'chooser; two picked → two thumbnails and "2"; the sheet with + and '
      '"2 of 10"; a third from inside it', (tester) async {
    await setUpApp(tester);
    await pumpApp(tester, dependencies: deps);
    await openAddForm(tester);

    final button = tester.getRect(photoButton());
    final description = tester.getRect(field('Description (optional)'));
    expect(button.right, lessThan(description.left));
    expect(button.center.dy, closeTo(description.center.dy, 0.5));

    await tester.tap(photoButton());
    await tester.pumpAndSettle();
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await pickFromGallery(tester, ['a', 'b'], total: 2);
    expect(
      find.descendant(of: photoButton(), matching: find.byType(Image)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: photoButton(), matching: find.text('2')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('2 photos, open'), findsOneWidget);

    await tester.tap(photoButton());
    await tester.pumpAndSettle();
    expect(find.text('2 of 10'), findsOneWidget);
    expect(find.byKey(const ValueKey('addPhotoTile')), findsOneWidget);
    await pickFromGallery(
      tester,
      ['c'],
      total: 3,
      opener: find.byKey(const ValueKey('addPhotoTile')),
      // The sheet covers the button: its own count tells.
      until: find.text('3 of 10'),
    );
    expect(find.text('3 of 10'), findsOneWidget);
    expect(find.byType(PhotoThumb), findsNWidgets(3));
  });

  testWidgets('viewer: "1 / 3", swipe, Delete → confirm → "2 / 2"; Save to '
      'Pictures there; then Save → Home row\'s photo icon "2 photos"', (
    tester,
  ) async {
    await setUpApp(tester);
    await pumpApp(tester, dependencies: deps);
    await openAddForm(tester);
    await fillValid(tester);
    await pickFromGallery(tester, ['a', 'b', 'c'], total: 3);
    await tester.tap(photoButton());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photoTile 0')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('viewerSave')));
    await pumpUntil(
      tester,
      () =>
          find.text('Saved to Pictures/Expense Tracker').evaluate().isNotEmpty,
    );
    expect(service.savedPictures.single.name, startsWith('Lunch '));

    // One page: a fast fling may skip one.
    await tester.drag(
      find.descendant(
        of: find.byType(PhotoViewer),
        matching: find.byType(PageView),
      ),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('viewerDelete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this photo?'), findsOneWidget);
    expect(find.textContaining('when you save it'), findsOneWidget);
    await tester.tap(dialogDelete);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('2 of 10'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tapSaveAndWait(tester, 'Save');
    final mark = find.descendant(
      of: find.byType(ExpenseRow),
      matching: find.byKey(const ValueKey('photoMark')),
    );
    expect(mark, findsOneWidget);
    // The row reads it with its title and amount (one merged node).
    expect(find.bySemanticsLabel(RegExp('2 photos')), findsOneWidget);
    final saved = (await tester.runAsync(deps.expenses.page))!.single;
    expect(saved.photoCount, 2);
  });

  testWidgets('selection in the sheet: long press → "1 selected"; toggle; '
      'unselect the last ends it; Select all; Save without a dialog, still '
      'selected; Delete → Cancel keeps all; Delete → confirm → gone, "2 '
      'photos deleted"', (tester) async {
    await setUpApp(tester);
    await pumpApp(tester, dependencies: deps);
    await openAddForm(tester);
    await fillValid(tester);
    await pickFromGallery(tester, ['a', 'b', 'c'], total: 3);
    await tester.tap(photoButton());
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('photoTile 0')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoSelectionBar), findsOneWidget);
    // The 328 dp sheet shortens the title to the number; TalkBack's
    // label is whole.
    expect(find.bySemanticsLabel('1 photo selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('addPhotoTile')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('photoTile 1')));
    await tester.pumpAndSettle();
    // The 328 dp sheet shortens the title to the number; TalkBack's
    // label is whole.
    expect(find.bySemanticsLabel('2 photos selected'), findsOneWidget);
    expect(find.byType(PhotoViewer), findsNothing, reason: 'taps toggle');
    await tester.tap(find.byKey(const ValueKey('photoTile 1')));
    await tester.tap(find.byKey(const ValueKey('photoTile 0')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoSelectionBar), findsNothing);

    await tester.longPress(find.byKey(const ValueKey('photoTile 0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoSelectionBar.selectAllKey));
    await tester.pumpAndSettle();
    // The 328 dp sheet shortens the title to the number; TalkBack's
    // label is whole.
    expect(find.bySemanticsLabel('3 photos selected'), findsOneWidget);

    await tester.tap(find.byKey(PhotoSelectionBar.saveKey));
    await pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey('sheetMessage'))
          .evaluate()
          .isNotEmpty,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('3 photos saved to Pictures/Expense Tracker'),
      findsOneWidget,
    );
    // The 328 dp sheet shortens the title to the number; TalkBack's
    // label is whole.
    expect(find.bySemanticsLabel('3 photos selected'), findsOneWidget);

    await tester.tap(find.byKey(PhotoSelectionBar.deleteKey));
    await tester.pumpAndSettle();
    expect(find.text('Delete 3 photos?'), findsOneWidget);
    expect(find.textContaining('deleted permanently'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoThumb), findsNWidgets(3));
    // The 328 dp sheet shortens the title to the number; TalkBack's
    // label is whole.
    expect(find.bySemanticsLabel('3 photos selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('photoTile 2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoSelectionBar.deleteKey));
    await tester.pumpAndSettle();
    await tester.tap(dialogDelete);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoThumb), findsOneWidget);
    expect(find.byType(PhotoSelectionBar), findsNothing);
    expect(find.text('2 photos deleted'), findsOneWidget);
  });

  testWidgets('Back in selection leaves selection, then closes the sheet', (
    tester,
  ) async {
    await setUpApp(tester);
    await pumpApp(tester, dependencies: deps);
    await openAddForm(tester);
    await pickFromGallery(tester, ['a'], total: 1);
    await tester.tap(photoButton());
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('photoTile 0')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PhotoSelectionBar), findsNothing);
    expect(find.text('1 of 10'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('1 of 10'), findsNothing);
    expect(find.text('Add expense'), findsOneWidget, reason: 'still the form');
  });

  testWidgets('10 photos: no + tile, the "10 photos is the most" line', (
    tester,
  ) async {
    await setUpApp(tester);
    await pumpApp(tester, dependencies: deps);
    await openAddForm(tester);
    await pickFromGallery(tester, [
      for (var i = 0; i < 10; i++) 'u$i',
    ], total: 10);
    await tester.tap(photoButton());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('addPhotoTile')), findsNothing);
    expect(find.text('10 photos is the most for one expense'), findsOneWidget);
  });

  testWidgets('the camera: review → right ×2, left → Use photo → turned '
      'once; Back on a review adds it as shown; Discard adds nothing', (
    tester,
  ) async {
    await setUpApp(tester);
    await pumpApp(tester, dependencies: deps);
    await openAddForm(tester);

    Future<void> takePhoto() async {
      // A shot taken from the sheet's + tile leaves the sheet open (the
      // photo shows up in it); close it first.
      if (find.textContaining(' of 10').evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
      await tester.tap(photoButton());
      await tester.pumpAndSettle();
      // With photos the button opens the sheet; its + tile the chooser.
      final addTile = find.byKey(const ValueKey('addPhotoTile'));
      if (addTile.evaluate().isNotEmpty) {
        await tester.tap(addTile);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Take photo'));
      await pumpUntil(
        tester,
        () => find.byKey(const ValueKey('usePhoto')).evaluate().isNotEmpty,
        description: 'the review',
      );
      await tester.pumpAndSettle();
    }

    await takePhoto();
    await tester.tap(find.byKey(const ValueKey('rotateRight')));
    await tester.tap(find.byKey(const ValueKey('rotateRight')));
    await tester.tap(find.byKey(const ValueKey('rotateLeft')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('usePhoto')));
    await pumpUntil(
      tester,
      () => find.bySemanticsLabel('1 photo, open').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(service.stages.single.quarterTurns, 1);
    expect(
      service.stages.single.plan,
      const Encode(width: 1080, height: 1440, quality: 85),
    );

    await takePhoto();
    await tester.binding.handlePopRoute();
    await pumpUntil(
      tester,
      () => find.bySemanticsLabel('2 photos, open').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(service.stages.last.quarterTurns, 0);

    await takePhoto();
    await tester.tap(find.byKey(const ValueKey('discardPhoto')));
    // The ring spins until the shot's files are deleted (real I/O).
    await pumpUntil(tester, () => !_busy(tester));
    await tester.pump();
    expect(service.stages, hasLength(2));
    expect(find.bySemanticsLabel('2 photos, open'), findsOneWidget);
  });

  testWidgets('Edit: Update off → add → on → Back "Draft saved" → reopen '
      'with the banner → Discard draft → the 2 stored photos', (tester) async {
    await setUpApp(tester);
    final taxi = await tester.runAsync(() async {
      for (final l in ['a', 'b']) {
        final file = File(p.join(store.root, 'photos', '${l * 64}.jpg'));
        await file.parent.create(recursive: true);
        await file.writeAsString(l);
      }
      return deps.expenses.add(
        ExpenseInput(
          title: 'Taxi',
          description: null,
          amount: const Money(50000, 'INR'),
          occurredAt: DateTime.now().toUtc(),
          utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
          categoryId: 1,
          paymentMethodId: 1,
          eventIds: const {},
          photos: [
            for (final l in ['a', 'b'])
              LinkNewPhoto(
                relativePath: 'photos/${l * 64}.jpg',
                sha256: l * 64,
                byteSize: 1,
              ),
          ],
        ),
      );
    });
    await pumpApp(tester, dependencies: deps);
    expect(find.byKey(const ValueKey('photoMark')), findsOneWidget);
    await tester.tap(find.text('Taxi'));
    await pumpUntilFound(tester, find.text('Edit expense'));
    await tester.pumpAndSettle();
    final update = find.widgetWithText(TextButton, 'Update');
    expect(tester.widget<TextButton>(update).onPressed, isNull);
    await tester.tap(photoButton());
    await tester.pumpAndSettle();
    await pickFromGallery(
      tester,
      ['new'],
      total: 3,
      opener: find.byKey(const ValueKey('addPhotoTile')),
      until: find.text('3 of 10'),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(update).onPressed, isNotNull);

    await tester.binding.handlePopRoute();
    await pumpUntilFound(tester, find.text('Draft saved'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(ExpenseRow), matching: find.text('Taxi')),
    );
    await pumpUntilFound(tester, find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('3 photos, open'), findsOneWidget);
    await tester.tap(find.text('Discard draft'));
    await pumpUntil(
      tester,
      () => find.bySemanticsLabel('2 photos, open').evaluate().isNotEmpty,
    );
    expect(tester.widget<TextButton>(update).onPressed, isNull);
    expect(taxi!.photoCount, 2);
  });

  testWidgets('a missing file is "image missing" on the button and in the '
      'sheet, and can be removed', (tester) async {
    await setUpApp(tester);
    await pumpApp(tester, dependencies: deps);
    await openAddForm(tester);
    await pickFromGallery(tester, ['a'], total: 1);
    await tester.runAsync(() async {
      for (final f in Directory(store.stagingPath).listSync()) {
        if (!p.basename(f.path).startsWith('.')) await f.delete();
      }
    });
    await tester.tap(photoButton());
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    // Read with the tile's name: "Photo 1 of 1, Image missing".
    expect(find.bySemanticsLabel(RegExp('Image missing')), findsWidgets);
    await tester.longPress(find.byKey(const ValueKey('photoTile 0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoSelectionBar.deleteKey));
    await tester.pumpAndSettle();
    await tester.tap(dialogDelete);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoThumb), findsNothing);
  });

  testWidgets('with 10 photos the sheet scrolls under its header: the '
      'title row, then the selection bar (Select all, Save, Delete), stay '
      'pinned at the top (owner, 2026-10-09)', (tester) async {
    await setUpApp(tester);
    await pumpApp(tester, dependencies: deps);
    await openAddForm(tester);
    await pickFromGallery(tester, [
      for (var i = 0; i < 10; i++) 'u$i',
    ], total: 10);
    await tester.tap(photoButton());
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('photosSheetHeader'));
    final scroll = find.byKey(const ValueKey('photosSheetScroll'));
    final top = tester.getRect(header);
    final firstTile = tester.getRect(find.byKey(const ValueKey('photoTile 0')));
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(header), top, reason: 'the title row stays');
    expect(
      tester.getRect(find.byKey(const ValueKey('photoTile 0'))).top,
      lessThan(firstTile.top),
      reason: 'the photos scrolled',
    );
    // The photos scroll below the header, never over it.
    final scrollRect = tester.getRect(scroll);
    expect(scrollRect.top, greaterThanOrEqualTo(top.bottom));

    await tester.longPress(find.byKey(const ValueKey('photoTile 8')));
    await tester.pumpAndSettle();
    await tester.drag(scroll, const Offset(0, 400));
    await tester.pumpAndSettle();
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(header), top);
    for (final key in [
      PhotoSelectionBar.selectAllKey,
      PhotoSelectionBar.saveKey,
      PhotoSelectionBar.deleteKey,
    ]) {
      final rect = tester.getRect(find.byKey(key));
      expect(rect.top, greaterThanOrEqualTo(top.top));
      expect(rect.bottom, lessThanOrEqualTo(top.bottom));
    }
    await tester.tap(find.byKey(PhotoSelectionBar.selectAllKey));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('10 photos selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (language, scale) in [('en', 1.0), ('es', 1.6)]) {
    testWidgets('$language at font $scale: starting selection in the sheet '
        "doesn't move the photos (regression: the grid jumped 48 dp and "
        'the next tap missed, seen on the Oppo)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await setUpApp(tester);
      if (language != 'en') {
        await tester.runAsync(() => deps.settings.setLocale(Locale(language)));
      }
      await pumpApp(tester, dependencies: deps);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await pickFromGallery(
        tester,
        ['a', 'b'],
        total: 2,
        until: find.bySemanticsLabel(RegExp('^2 ')),
      );
      await tester.tap(photoButton());
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byKey(const ValueKey('photoTile 1')));
      // The sheet's 16 dp sides (lost once while the bar went full width).
      expect(
        tester.getRect(find.byKey(const ValueKey('photoTile 0'))).left,
        16,
      );
      expect(before.right, 360 - 16);
      await tester.longPress(find.byKey(const ValueKey('photoTile 0')));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoSelectionBar), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('photoTile 1'))), before);
      expect(tester.takeException(), isNull);
    });
  }
}

/// Whether the form's photo button shows its busy ring.
bool _busy(WidgetTester tester) => find
    .descendant(
      of: find.byKey(const ValueKey('photoButton')),
      matching: find.byType(CircularProgressIndicator),
    )
    .evaluate()
    .isNotEmpty;
