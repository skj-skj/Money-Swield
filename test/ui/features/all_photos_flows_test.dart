import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/services/photo_store.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/list_frames.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_selection_bar.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_thumb.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/all_photos_screen.dart';
import 'package:my_expense_tracker_app/ui/features/home/views/home_list_slivers.dart';
import 'package:path/path.dart' as p;

import '../../helpers/fake_photo_service.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';
import '../../helpers/test_folders.dart';
import '../../helpers/test_images.dart';

/// Home's photos icon and the Photos screen (phase-6.md §8.9, §8.10).
/// Today is Wed 7 Oct 2026.
void main() {
  late AppDependencies deps;
  late FakePhotoService service;
  late PhotoStore store;
  final ids = <String, int>{};

  Future<void> setUpApp(
    WidgetTester tester, {
    String language = 'en',
    Future<void> Function()? seed,
  }) async {
    await tester.runAsync(() async {
      final root = await testFolder('all_photos_flows');
      service = FakePhotoService();
      store = PhotoStore(
        root: root.path,
        service: service,
        imageFactory: memoryImages(),
      );
      deps = await openTestDependencies(
        photos: store,
        clock: TestClock(DateTime.utc(2026, 10, 7, 6)),
      );
      await deps.settings.setOnboardingCompleted();
      if (language != 'en') await deps.settings.setLocale(Locale(language));
      await seed?.call();
      for (final row in await deps.database.query('photos')) {
        _photoIds[(row['sha256']! as String)[0]] = row['id']! as int;
      }
    });
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  var minute = 0;
  Future<Expense> add(
    String title,
    String day,
    String letters, {
    int categoryId = 1,
  }) async {
    for (final l in letters.split('')) {
      final file = File(p.join(store.root, 'photos', '${l * 64}.jpg'));
      await file.parent.create(recursive: true);
      await file.writeAsString(l);
    }
    final date = DateTime.parse(day);
    final e = await deps.expenses.add(
      ExpenseInput(
        title: title,
        description: null,
        amount: const Money(100, 'INR'),
        // Later rows first within a day: Lunch before Taxi below.
        occurredAt: DateTime.utc(
          date.year,
          date.month,
          date.day,
          8,
          59 - minute++,
        ),
        utcOffsetMinutes: 330,
        categoryId: categoryId,
        paymentMethodId: 1,
        eventIds: const {},
        photos: [
          for (final l in letters.split(''))
            if (l.isNotEmpty)
              LinkNewPhoto(
                relativePath: 'photos/${l * 64}.jpg',
                sha256: l * 64,
                byteSize: 1,
              ),
        ],
      ),
    );
    ids[title] = e.id;
    return e;
  }

  /// Lunch [a, b] and Taxi [c] on Mon 5 Oct, Rent [d e f 1 2] on Sun 4
  /// Oct, Old [9] on 30 Sep. (A photo's name is hex: the letters are.)
  Future<void> seedStandard() async {
    await add('Lunch', '2026-10-05', 'ab', categoryId: 1);
    await add('Taxi', '2026-10-05', 'c', categoryId: 2);
    await add('Rent', '2026-10-04', 'def12', categoryId: 3);
    await add('Old', '2026-09-30', '9', categoryId: 1);
  }

  Finder tile(String title, String letter) => find.byWidgetPredicate(
    (w) =>
        w is PhotoThumb &&
        w.key == ValueKey('photo ${ids[title]} ${_photoId(letter)}'),
  );

  Future<void> openPhotos(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('photosButton')));
    await pumpUntilFound(tester, find.byType(PhotoThumb));
    await tester.pumpAndSettle();
  }

  setUp(() {
    ids.clear();
    _photoIds.clear();
    minute = 0;
  });

  testWidgets('the icon: none → hidden; photos → enabled, left of the '
      'filter icon; a filter hiding them all → greyed with its tooltip; '
      'filtered → a dot like the filter icon\'s', (tester) async {
    bool photosDot() => tester
        .widget<Badge>(
          find.descendant(
            of: find.byKey(const ValueKey('photosButton')),
            matching: find.byType(Badge),
          ),
        )
        .isLabelVisible;
    await setUpApp(
      tester,
      seed: () async {
        await add('No photo', '2026-10-05', '');
      },
    );
    await pumpApp(tester, dependencies: deps);
    expect(find.byKey(const ValueKey('photosButton')), findsNothing);
    await tester.runAsync(() => add('Lunch', '2026-10-05', 'a'));
    // Back from a form reloads Home when data changed.
    await tester.tap(find.text('No photo'));
    await pumpUntilFound(tester, find.text('Edit expense'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await pumpUntilFound(tester, find.byKey(const ValueKey('photosButton')));
    final photos = tester.getRect(find.byKey(const ValueKey('photosButton')));
    final filter = tester.getRect(find.byKey(const ValueKey('filterButton')));
    expect(photos.right, lessThanOrEqualTo(filter.left));
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('photosButton')))
          .onPressed,
      isNotNull,
    );
    expect(photosDot(), isFalse);

    // A search that only "No photo" matches hides every photo.
    await tester.tap(find.byKey(const ValueKey('filterButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'no photo');
    // The sheet applies its filters on Back (phase-5.md §12b).
    await tester.binding.handlePopRoute();
    await pumpUntilFound(tester, find.byKey(const ValueKey('filterChipText')));
    await tester.pumpAndSettle();
    final greyed = tester.widget<IconButton>(
      find.byKey(const ValueKey('photosButton')),
    );
    expect(greyed.onPressed, isNull);
    expect(greyed.tooltip, 'No photos match the filters');
    expect(photosDot(), isTrue);
  });

  testWidgets('months with the year, day headers, two a row, each day a new '
      'row; no subtotal; tap Taxi\'s photo → its Edit, Back → the same '
      'place', (tester) async {
    await setUpApp(tester, seed: seedStandard);
    await pumpApp(tester, dependencies: deps);
    await openPhotos(tester);
    expect(find.text('Oct 2026'), findsOneWidget);
    // The test device is en_US: "Mon, Oct 5".
    expect(find.text('Mon, Oct 5'), findsOneWidget);
    expect(find.text('Sun, Oct 4'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing, reason: 'no subtotals');

    final a = tester.getRect(tile('Lunch', 'a'));
    final b = tester.getRect(tile('Lunch', 'b'));
    final c = tester.getRect(tile('Taxi', 'c'));
    expect(b.top, a.top);
    expect(c.top, greaterThan(a.bottom));
    expect(c.left, a.left, reason: '[a b] [c _]');
    final nextHeader = tester.getRect(find.text('Sun, Oct 4'));
    expect(nextHeader.top, greaterThan(c.bottom));
    final d = tester.getRect(tile('Rent', 'd'));
    expect(d.left, a.left, reason: 'a day starts a new row');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await tester.pumpAndSettle();
    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .pixels;
    expect(find.byType(FrameTop), findsWidgets, reason: 'sticky');

    await tester.tap(tile('Taxi', 'c'));
    await pumpUntilFound(tester, find.text('Edit expense'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Taxi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels,
      offset,
    );
  });

  testWidgets('remove Taxi\'s only photo in its form, Update, Back → gone; '
      'bin Lunch from its form → "Moved to bin" + Undo here', (tester) async {
    await setUpApp(tester, seed: seedStandard);
    await pumpApp(tester, dependencies: deps);
    await openPhotos(tester);
    await tester.tap(tile('Taxi', 'c'));
    await pumpUntilFound(tester, find.text('Edit expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photoButton')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('photoTile 0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoSelectionBar.deleteKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('when you tap Update'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Update'));
    await pumpUntilFound(tester, find.byType(AllPhotosScreen));
    await pumpUntilGone(tester, tile('Taxi', 'c'));

    await tester.tap(tile('Lunch', 'a'));
    await pumpUntilFound(tester, find.text('Edit expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await pumpUntilFound(tester, find.text('Moved to bin'));
    await pumpUntilGone(tester, tile('Lunch', 'a'));
    // The action itself (its placement is checked on the phone, §12a).
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await pumpUntilFound(tester, tile('Lunch', 'a'));
  });

  testWidgets('selection, the same as the sheet: long press a, tap c → '
      '"2"; taps toggle instead of opening; Save → two names; Delete → the '
      'permanent warning → a and c gone, Lunch keeps b, Taxi\'s row loses its '
      'icon on Home', (tester) async {
    await setUpApp(tester, seed: seedStandard);
    await pumpApp(tester, dependencies: deps);
    await openPhotos(tester);
    await tester.longPress(tile('Lunch', 'a'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoSelectionBar), findsOneWidget);
    expect(find.bySemanticsLabel('1 photo selected'), findsOneWidget);
    await tester.tap(tile('Taxi', 'c'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('2 photos selected'), findsOneWidget);
    expect(find.text('Edit expense'), findsNothing);

    await tester.tap(find.byKey(PhotoSelectionBar.saveKey));
    await pumpUntilFound(
      tester,
      find.text('2 photos saved to Pictures/Expense Tracker'),
    );
    expect(service.savedPictures.map((s) => s.name), [
      'Lunch 2026-10-05.jpg',
      'Taxi 2026-10-05.jpg',
    ]);
    expect(find.bySemanticsLabel('2 photos selected'), findsOneWidget);

    await tester.tap(find.byKey(PhotoSelectionBar.deleteKey));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 photos?'), findsOneWidget);
    expect(
      find.textContaining('deleted permanently from their expenses'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('2 photos selected'), findsOneWidget);
    await tester.tap(find.byKey(PhotoSelectionBar.deleteKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );
    await pumpUntilFound(tester, find.text('2 photos deleted'));
    await tester.pumpAndSettle();
    expect(tile('Lunch', 'a'), findsNothing);
    expect(tile('Taxi', 'c'), findsNothing);
    expect(tile('Lunch', 'b'), findsOneWidget);
    expect(find.byType(PhotoSelectionBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await pumpUntil(
      tester,
      () => find.byType(ExpenseRow).evaluate().isNotEmpty,
    );
    final taxiRow = find.ancestor(
      of: find.text('Taxi'),
      matching: find.byType(ExpenseRow),
    );
    expect(
      find.descendant(
        of: taxiRow,
        matching: find.byKey(const ValueKey('photoMark')),
      ),
      findsNothing,
    );
  });

  testWidgets('Back and ✕ end selection; Back again leaves', (tester) async {
    await setUpApp(tester, seed: seedStandard);
    await pumpApp(tester, dependencies: deps);
    await openPhotos(tester);
    await tester.longPress(tile('Lunch', 'a'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PhotoSelectionBar), findsNothing);
    expect(find.byType(AllPhotosScreen), findsOneWidget);
    await tester.longPress(tile('Lunch', 'a'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoSelectionBar.closeKey));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoSelectionBar), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AllPhotosScreen), findsNothing);
  });

  testWidgets('Home filtered (text "tax"): only the Taxi photo and the '
      'Filtered mark; still months', (tester) async {
    await setUpApp(tester, seed: seedStandard);
    await pumpApp(tester, dependencies: deps);
    // A text filter (the category path is the cubit test's).
    await tester.tap(find.byKey(const ValueKey('filterButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'tax');
    await tester.binding.handlePopRoute();
    await pumpUntilFound(tester, find.byKey(const ValueKey('filterChipText')));
    await tester.pumpAndSettle();
    await openPhotos(tester);
    expect(find.byKey(const ValueKey('photosFiltered')), findsOneWidget);
    expect(find.byType(PhotoThumb), findsOneWidget);
    expect(tile('Taxi', 'c'), findsOneWidget);
    expect(find.text('Oct 2026'), findsOneWidget);
  });

  testWidgets('es: "Oct 2026"; fits at font 2.0', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await setUpApp(tester, language: 'es', seed: seedStandard);
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.byKey(const ValueKey('photosButton')));
    await pumpUntilFound(tester, find.byType(PhotoThumb));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('2026'), findsWidgets);
    await tester.longPress(tile('Lunch', 'a'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

/// The photo ids by letter, read lazily from the rows (each letter is one
/// photo).
final _photoIds = <String, int>{};

int? _photoId(String letter) => _photoIds[letter];
