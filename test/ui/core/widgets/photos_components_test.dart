import 'dart:math' as math;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/data/services/photo_service.dart';
import 'package:my_expense_tracker_app/data/services/photo_store.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/add_photo_sheet.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_grid.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_review_screen.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_selection_bar.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_stack_button.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_thumb.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_viewer.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/saved_to_pictures_message.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/test_images.dart';

/// The shared photo components, each on its own.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {Locale locale = en}) =>
      tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  /// The Oppo: 360 dp wide.
  void useOppoSize(WidgetTester tester, {double textScale = 1}) {
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  group('PhotoThumb', () {
    testWidgets('a picture that fails to load is "Image missing" and still '
        'tappable', (tester) async {
      var taps = 0;
      await pump(
        tester,
        SizedBox.square(
          dimension: 100,
          child: PhotoThumb(image: brokenImage(), onTap: () => taps++),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Image missing'), findsOneWidget);
      await tester.tap(find.byType(PhotoThumb));
      expect(taps, 1);
    });

    testWidgets('selection shows a tick and says Selected / Not '
        'selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        Row(
          children: [
            SizedBox.square(
              dimension: 100,
              child: PhotoThumb(
                image: memoryImage(),
                semanticLabel: 'Photo of Lunch, 5 Oct',
                selected: true,
              ),
            ),
            SizedBox.square(
              dimension: 100,
              child: PhotoThumb(image: memoryImage(), selected: false),
            ),
          ],
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      final node = tester.getSemantics(find.byType(PhotoThumb).first);
      expect(node.label, 'Photo of Lunch, 5 Oct');
      expect(node.value, 'Selected');
      expect(
        tester.getSemantics(find.byType(PhotoThumb).last).value,
        'Not selected',
      );
      handle.dispose();
    });
  });

  group('PhotoStackButton', () {
    testWidgets('empty: "Add photos"; with photos: "3 photos, open", three '
        'thumbnails at most and the count', (tester) async {
      final handle = tester.ensureSemantics();
      var count = 0;
      late StateSetter set;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return PhotoStackButton(
              count: count,
              imageOf: (i, maxPx) => memoryImage(),
              onTap: () {},
            );
          },
        ),
      );
      expect(find.bySemanticsLabel('Add photos'), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      set(() => count = 5);
      await tester.pump();
      expect(find.bySemanticsLabel('5 photos, open'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(3));
      expect(find.text('5'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('is its own node next to the description: it never merges '
        'with the field into one unlabelled button (regression, seen on '
        'the Oppo)', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        ListView(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PhotoStackButton(
                  count: 0,
                  imageOf: (i, maxPx) => memoryImage(),
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Description'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      final button = tester.getSemantics(find.byType(PhotoStackButton));
      expect(button.label, 'Add photos');
      expect(button.rect.width, lessThanOrEqualTo(56 * 1.0 + 1));
      expect(
        find.bySemanticsLabel('Description'),
        findsOneWidget,
        reason: 'the field keeps its own node',
      );
      handle.dispose();
    });

    // The owner, after the Oppo run: fanned out like playing cards, over
    // the outline (a neat pile inside it looked empty, a random one odd).
    testWidgets('a fan of playing cards over the outline: turned evenly '
        'both ways about their bottoms; taps on it reach the button', (
      tester,
    ) async {
      var taps = 0;
      Future<List<Transform>> fanWith(int count) async {
        await pump(
          tester,
          Center(
            child: PhotoStackButton(
              count: count,
              imageOf: (i, maxPx) => memoryImage(),
              onTap: () => taps++,
            ),
          ),
        );
        return tester
            .widgetList<Transform>(
              find.descendant(
                of: find.byType(PhotoStackButton),
                matching: find.byType(Transform),
              ),
            )
            .toList();
      }

      double turnOf(Transform card) =>
          math.atan2(card.transform.entry(1, 0), card.transform.entry(0, 0));

      final three = await fanWith(5);
      expect(three, hasLength(3));
      final turns = three.map(turnOf).toList();
      expect(turns[0], lessThan(0), reason: 'the left card leans left');
      expect(turns[1], closeTo(0, 1e-9));
      expect(turns[2], closeTo(-turns[0], 1e-9));
      final button = tester.getRect(find.byKey(const ValueKey('photoButton')));
      expect(button.size, const Size(56, 56));
      final images = find.descendant(
        of: find.byType(PhotoStackButton),
        matching: find.byType(RawImage),
      );
      // The outer cards' top outer corners, turned, past the button's
      // sides; the middle card past its top.
      expect(tester.getTopLeft(images.at(0)).dx, lessThan(button.left));
      expect(tester.getTopRight(images.at(2)).dx, greaterThan(button.right));
      expect(tester.getTopLeft(images.at(1)).dy, lessThan(button.top));

      final two = (await fanWith(2)).map(turnOf).toList();
      expect(two, hasLength(2));
      expect(two[0], closeTo(-two[1], 1e-9));
      expect(two[0], lessThan(0));
      expect((await fanWith(1)).map(turnOf), [closeTo(0, 1e-9)]);

      await tester.tap(find.byKey(const ValueKey('photoButton')));
      expect(taps, 1);
    });

    testWidgets('busy: a ring and no taps', (tester) async {
      var taps = 0;
      await pump(
        tester,
        PhotoStackButton(
          count: 2,
          busy: true,
          imageOf: (i, maxPx) => memoryImage(),
          onTap: () => taps++,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(PhotoStackButton));
      expect(taps, 0);
    });
  });

  group('PhotoSelectionBar', () {
    for (final locale in [en, es, hi]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('at 360 dp, ${locale.languageCode}, font $scale: Save and '
            'Delete right of the title, 8 dp apart, Delete at the edge, '
            'icons named by tooltips; a tap in the gap does nothing', (
          tester,
        ) async {
          useOppoSize(tester, textScale: scale);
          var saves = 0;
          var deletes = 0;
          await pump(
            tester,
            Align(
              alignment: Alignment.topCenter,
              child: PhotoSelectionBar(
                count: 12,
                onSelectAll: () {},
                onSave: () => saves++,
                onDelete: () => deletes++,
                onClose: () {},
              ),
            ),
            locale: locale,
          );
          expect(tester.takeException(), isNull, reason: 'no overflow');
          final l10n = lookupAppLocalizations(locale);
          final save = tester.getRect(find.byKey(PhotoSelectionBar.saveKey));
          final delete = tester.getRect(
            find.byKey(PhotoSelectionBar.deleteKey),
          );
          final bar = tester.getRect(find.byType(PhotoSelectionBar));
          // Side by side, the gap between their touch targets (8 dp: the
          // owner found 48 too far after the Oppo run).
          expect(save.top, delete.top);
          expect(delete.left - save.right, closeTo(PhotoSelectionBar.gap, 0.5));
          expect(bar.right - delete.right, lessThanOrEqualTo(16));
          final title = tester.getRect(find.textContaining('12'));
          expect(
            title.right <= save.left + 0.5 || save.top >= title.bottom,
            isTrue,
            reason: 'Save is right of the title, or below it',
          );
          // Icons only (owner, after the Oppo run): named by tooltips.
          expect(find.text(l10n.save), findsNothing);
          expect(find.text(l10n.delete), findsNothing);
          expect(find.byTooltip(l10n.saveToPictures), findsOneWidget);
          expect(find.byTooltip(l10n.delete), findsOneWidget);
          expect(save.height, greaterThanOrEqualTo(48));
          await tester.tapAt(
            Offset((save.right + delete.left) / 2, save.center.dy),
          );
          expect((saves, deletes), (0, 0));
          await tester.tap(find.byKey(PhotoSelectionBar.saveKey));
          await tester.tap(find.byKey(PhotoSelectionBar.deleteKey));
          expect((saves, deletes), (1, 1));
        });
      }
    }

    // On the Oppo the icon-only bar showed a bare "1" beside free room.
    // The test font's glyphs are a whole em wide (Roboto's about half), so
    // the width where only the labelled Select all doesn't fit is 480 here.
    testWidgets('room for "1 selected" but not a labelled Select all: '
        '"1 selected" whole beside the Select all icon', (tester) async {
      tester.view.physicalSize = const Size(960, 1612);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: PhotoSelectionBar(
            count: 1,
            onSelectAll: () {},
            onSave: () {},
            onDelete: () {},
            onClose: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.renderObject<RenderParagraph>(
        find.text('1 selected'),
      );
      expect(
        title.size.width,
        greaterThanOrEqualTo(title.getMaxIntrinsicWidth(double.infinity) - 0.5),
        reason: 'not cut',
      );
      expect(find.byIcon(Icons.select_all), findsOneWidget);
    });

    testWidgets('narrow: the title shortens to the number and Select all '
        'becomes an icon before anything else gives', (tester) async {
      useOppoSize(tester, textScale: 1.6);
      await pump(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: PhotoSelectionBar(
            count: 3,
            onSelectAll: () {},
            onSave: () {},
            onDelete: () {},
            onClose: () {},
          ),
        ),
        locale: es,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('3 seleccionadas'), findsNothing);
      expect(find.byIcon(Icons.select_all), findsOneWidget);
    });

    testWidgets('the Bin: Save only; busy turns both off', (tester) async {
      var saves = 0;
      await pump(
        tester,
        PhotoSelectionBar(
          count: 1,
          busy: true,
          onSelectAll: () {},
          onSave: () => saves++,
          onClose: () {},
        ),
      );
      expect(find.byKey(PhotoSelectionBar.deleteKey), findsNothing);
      await tester.tap(find.byKey(PhotoSelectionBar.saveKey));
      expect(saves, 0);
    });

    testWidgets('TalkBack: a header "2 photos selected"', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        PhotoSelectionBar(
          count: 2,
          onSelectAll: () {},
          onSave: () {},
          onDelete: () {},
          onClose: () {},
        ),
      );
      expect(find.bySemanticsLabel('2 photos selected'), findsOneWidget);
      handle.dispose();
    });
  });

  group('confirmPhotoDelete', () {
    for (final (place, words) in [
      (PhotoDeletePlace.photosScreen, 'from their expenses'),
      (PhotoDeletePlace.savedExpense, 'when you tap Update'),
      (PhotoDeletePlace.newExpense, 'when you save it'),
    ]) {
      testWidgets('${place.name}: the permanent warning; Cancel first and '
          'focused; Cancel → false', (tester) async {
        bool? result;
        await pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirmPhotoDelete(
                context,
                count: 3,
                place: place,
              ),
              child: const Text('go'),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(find.text('Delete 3 photos?'), findsOneWidget);
        expect(find.textContaining('deleted permanently'), findsOneWidget);
        expect(find.textContaining(words), findsOneWidget);
        expect(
          find.textContaining('Copies you saved to Pictures stay'),
          findsOneWidget,
        );
        final buttons = tester
            .widgetList<TextButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextButton),
              ),
            )
            .toList();
        expect(buttons.first.autofocus, isTrue);
        expect(
          tester.getCenter(find.text('Cancel')).dx,
          lessThan(tester.getCenter(find.text('Delete')).dx),
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      });
    }

    testWidgets('one photo: "Delete this photo?", "It will…"', (tester) async {
      bool? result;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmPhotoDelete(
              context,
              count: 1,
              place: PhotoDeletePlace.savedExpense,
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this photo?'), findsOneWidget);
      expect(find.textContaining('It will be deleted'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('PhotoReviewScreen', () {
    Future<ReviewDecision?> review(
      WidgetTester tester,
      Future<void> Function() act,
    ) async {
      ReviewDecision? decision;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => decision = await Navigator.push(
              context,
              MaterialPageRoute<ReviewDecision>(
                builder: (_) => PhotoReviewScreen(image: memoryImage()),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await act();
      await tester.pumpAndSettle();
      return decision;
    }

    testWidgets('right ×2, left → Use photo → 1 turn', (tester) async {
      final decision = await review(tester, () async {
        await tester.tap(find.byKey(const ValueKey('rotateRight')));
        await tester.tap(find.byKey(const ValueKey('rotateRight')));
        await tester.tap(find.byKey(const ValueKey('rotateLeft')));
        await tester.pumpAndSettle();
        expect(find.text('Rotated 90 degrees'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('usePhoto')));
      });
      expect(decision, isA<UseReviewedPhoto>());
      expect((decision! as UseReviewedPhoto).quarterTurns, 1);
    });

    testWidgets('left once is 3 turns (−90° = 270°)', (tester) async {
      final decision = await review(tester, () async {
        await tester.tap(find.byKey(const ValueKey('rotateLeft')));
        await tester.tap(find.byKey(const ValueKey('usePhoto')));
      });
      expect((decision! as UseReviewedPhoto).quarterTurns, 3);
    });

    testWidgets('Back uses the photo as shown', (tester) async {
      final decision = await review(tester, () async {
        await tester.tap(find.byKey(const ValueKey('rotateRight')));
        await tester.pumpAndSettle();
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        await navigator.maybePop();
      });
      expect((decision! as UseReviewedPhoto).quarterTurns, 1);
    });

    testWidgets('Discard', (tester) async {
      final decision = await review(tester, () async {
        await tester.tap(find.byKey(const ValueKey('discardPhoto')));
      });
      expect(decision, isA<DiscardReviewedPhoto>());
    });

    testWidgets('fits at 360 dp and font 2.0', (tester) async {
      useOppoSize(tester, textScale: 2);
      await review(tester, () async {
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('usePhoto')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('usePhoto')));
      });
    });
  });

  group('PhotoViewer', () {
    testWidgets('"2 / 3", swipe, Delete → confirm → "2 / 2", the last delete '
        'closes; Save shows its message', (tester) async {
      final deleted = <int>[];
      final saved = <int>[];
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => PhotoViewer.open(
              context,
              count: 3,
              initial: 1,
              imageOf: (i, maxPx) => memoryImage(),
              onSave: (i) async {
                saved.add(i);
                return 'Saved to Pictures/Expense Tracker';
              },
              onDelete: (i) async {
                deleted.add(i);
                return true;
              },
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('viewerSave')));
      await tester.pumpAndSettle();
      expect(saved, [1]);
      expect(find.text('Saved to Pictures/Expense Tracker'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('viewerDelete')));
      await tester.pumpAndSettle();
      expect(deleted, [2]);
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('viewerDelete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('viewerDelete')));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsNothing);
      expect(deleted, [2, 1, 0]);
    });

    testWidgets('no onDelete (the Bin): no Delete; a missing photo says so', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => PhotoViewer.open(
              context,
              count: 1,
              initial: 0,
              imageOf: (i, maxPx) => brokenImage(),
              onSave: (i) async => null,
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('viewerDelete')), findsNothing);
      expect(find.text('Image missing'), findsOneWidget);
    });

    // On the Oppo the counter showed "2 …": Save, the gap and Delete left
    // it ~50 dp.
    for (final locale in [en, es, hi]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('at 360 dp, ${locale.languageCode}, font $scale: "10 / 10" '
            'whole; Save and Delete on screen, 8 dp apart', (tester) async {
          useOppoSize(tester, textScale: scale);
          await pump(
            tester,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => PhotoViewer.open(
                  context,
                  count: 10,
                  initial: 9,
                  imageOf: (i, maxPx) => memoryImage(),
                  onSave: (i) async => null,
                  onDelete: (i) async => false,
                ),
                child: const Text('go'),
              ),
            ),
            locale: locale,
          );
          await tester.tap(find.text('go'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'no overflow');
          final counter = tester.renderObject<RenderParagraph>(
            find.text('10 / 10'),
          );
          expect(
            counter.size.width,
            greaterThanOrEqualTo(
              counter.getMaxIntrinsicWidth(double.infinity) - 0.5,
            ),
            reason: 'not cut',
          );
          final save = tester.getRect(find.byKey(const ValueKey('viewerSave')));
          final delete = tester.getRect(
            find.byKey(const ValueKey('viewerDelete')),
          );
          final counterRect = tester.getRect(find.text('10 / 10'));
          expect(
            counterRect.right <= save.left || save.top >= counterRect.bottom,
            isTrue,
            reason: 'the counter and Save don\'t overlap',
          );
          expect(save.top, delete.top);
          expect(delete.left - save.right, closeTo(PhotoSelectionBar.gap, 0.5));
          expect(delete.right, lessThanOrEqualTo(360));
          expect(save.left, greaterThanOrEqualTo(0));
          final l10n = lookupAppLocalizations(locale);
          expect(find.text(l10n.save), findsNothing);
          expect(find.byTooltip(l10n.saveToPictures), findsOneWidget);
          expect(find.byTooltip(l10n.delete), findsOneWidget);
        });
      }
    }
  });

  group('PhotoGrid', () {
    testWidgets('a + tile last; none while selecting', (tester) async {
      await pump(
        tester,
        PhotoGrid(
          count: 3,
          imageOf: (i, maxPx) => memoryImage(),
          onTap: (_) {},
          semanticsOf: (i) => 'p$i',
          onAdd: () {},
        ),
      );
      expect(find.byType(PhotoThumb), findsNWidgets(3));
      expect(find.byKey(const ValueKey('addPhotoTile')), findsOneWidget);
      await pump(
        tester,
        PhotoGrid(
          count: 3,
          imageOf: (i, maxPx) => memoryImage(),
          onTap: (_) {},
          semanticsOf: (i) => 'p$i',
          onAdd: () {},
          selection: const {0},
        ),
      );
      expect(find.byKey(const ValueKey('addPhotoTile')), findsNothing);
    });

    testWidgets('2 columns of square cells', (tester) async {
      useOppoSize(tester);
      await pump(
        tester,
        PhotoGrid(
          count: 3,
          imageOf: (i, maxPx) => memoryImage(),
          onTap: (_) {},
          semanticsOf: (i) => 'p$i',
        ),
      );
      final a = tester.getRect(find.byKey(const ValueKey('photoTile 0')));
      final b = tester.getRect(find.byKey(const ValueKey('photoTile 1')));
      final c = tester.getRect(find.byKey(const ValueKey('photoTile 2')));
      expect(a.width, closeTo(a.height, 0.01));
      expect(b.top, a.top);
      expect(c.top, greaterThan(a.bottom));
    });

    // The owner, after the Oppo run: a + as big as a photo, filled, read as
    // one more photo.
    testWidgets('the + is a small unfilled circle in the middle of its '
        'cell', (tester) async {
      useOppoSize(tester);
      var adds = 0;
      await pump(
        tester,
        PhotoGrid(
          count: 1,
          imageOf: (i, maxPx) => memoryImage(),
          onTap: (_) {},
          semanticsOf: (i) => 'p$i',
          onAdd: () => adds++,
        ),
      );
      final photo = tester.getRect(find.byKey(const ValueKey('photoTile 0')));
      final add = find.byKey(const ValueKey('addPhotoTile'));
      final plus = tester.getRect(add);
      expect(plus.width, lessThanOrEqualTo(photo.width / 2));
      expect(plus.height, plus.width);
      final cell = photo.shift(Offset(photo.width + 8, 0));
      expect(plus.center.dx, closeTo(cell.center.dx, 0.5));
      expect(plus.center.dy, closeTo(cell.center.dy, 0.5));
      expect(tester.widget<Material>(add).type, MaterialType.transparency);
      await tester.tap(add);
      expect(adds, 1);
    });
  });

  testWidgets('the add chooser: two options and "3 of 10 added"', (
    tester,
  ) async {
    PhotoSource? picked;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              picked = await showAddPhotoSheet(context, count: 3),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 10 added'), findsOneWidget);
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(picked, PhotoSource.gallery);
  });

  test('Save to Pictures messages', () {
    final l10n = l10nFor('en');
    String text(int saved, int missing, int failed, {bool noSpace = false}) =>
        savedToPicturesText(l10n, (
          saved: saved,
          missing: missing,
          failed: failed,
          noSpace: noSpace,
        ));
    expect(text(1, 0, 0), 'Saved to Pictures/Expense Tracker');
    expect(text(3, 0, 0), '3 photos saved to Pictures/Expense Tracker');
    expect(text(2, 0, 1), "2 saved; 1 couldn't be saved");
    expect(text(0, 1, 0), "1 photo is missing and wasn't saved");
    expect(
      text(2, 1, 0),
      '2 photos saved to Pictures/Expense Tracker. 1 photo is missing and '
      "wasn't saved",
    );
    expect(
      text(0, 0, 0, noSpace: true),
      'Not enough space to save these photos',
    );
    // Nothing saved because every one failed: one plain error.
    expect(text(0, 0, 2), "Couldn't save. Please try again.");
    expect(text(0, 1, 1), "Couldn't save. Please try again.");
    // Some failed and some missing: both are said.
    expect(
      text(2, 1, 1),
      "2 saved; 1 couldn't be saved. 1 photo is missing and wasn't saved",
    );
  });

  test("saveToPicturesMessage: the result's text; null when nothing ran; "
      '"Could not save" when the save throws', () async {
    final l10n = l10nFor('en');
    expect(
      await saveToPicturesMessage(
        l10n,
        () async => (saved: 1, missing: 0, failed: 0, noSpace: false),
      ),
      'Saved to Pictures/Expense Tracker',
    );
    expect(await saveToPicturesMessage(l10n, () async => null), isNull);
    expect(
      await saveToPicturesMessage(
        l10n,
        () async => throw const PhotoServiceException(PhotoError.ioError),
      ),
      "Couldn't save. Please try again.",
    );
  });

  test('PhotoStore.none has no folder', () {
    expect(PhotoStore.none.isAvailable, isFalse);
  });
}
