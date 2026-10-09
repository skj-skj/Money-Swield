import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/services/photo_store.dart';
import 'package:my_expense_tracker_app/domain/models/expense.dart';
import 'package:my_expense_tracker_app/domain/models/money.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_selection_bar.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_thumb.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/photos/photo_viewer.dart';
import 'package:my_expense_tracker_app/ui/features/bin/view_models/expense_photos_cubit.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fake_photo_service.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_folders.dart';
import '../../../helpers/test_images.dart';

/// A binned expense's photos (phase-6.md §8.5, P6-24, P6-43).
void main() {
  late AppDependencies deps;
  late FakePhotoService service;
  late PhotoStore store;

  Future<void> setUpDeps() async {
    final root = await testFolder('bin_photos');
    service = FakePhotoService();
    store = PhotoStore(
      root: root.path,
      service: service,
      imageFactory: memoryImages(),
    );
    deps = await openTestDependencies(photos: store);
    await deps.settings.setOnboardingCompleted();
  }

  Future<Expense> binnedWithPhotos(List<String> letters) async {
    for (final l in letters) {
      final file = File(p.join(store.root, 'photos', '${l * 64}.jpg'));
      await file.parent.create(recursive: true);
      await file.writeAsString(l);
    }
    final e = await deps.expenses.add(
      ExpenseInput(
        title: 'Taxi',
        description: null,
        amount: const Money(500, 'INR'),
        occurredAt: DateTime.utc(2026, 10, 5, 8),
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
    await deps.expenses.moveToBin(e.id);
    return (await deps.expenses.binned()).single;
  }

  test('ExpensePhotosCubit: load, select, save two named by the expense; '
      'nothing about the expense changes', () async {
    await setUpDeps();
    final taxi = await binnedWithPhotos(['a', 'b']);
    final cubit = ExpensePhotosCubit(
      expenses: deps.expenses,
      store: store,
      expense: taxi,
      fallbackTitle: 'Expense',
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.value.photos, hasLength(2));
    cubit
      ..startSelection(0)
      ..selectAll();
    final result = await cubit.saveSelected();
    expect(result!.saved, 2);
    expect(service.savedPictures.map((s) => s.name), [
      'Taxi 2026-10-05.jpg',
      'Taxi 2026-10-05 (1).jpg',
    ]);
    expect(service.savedPictures.first.exifDateTime, '2026:10:05 13:30:00');
    expect(cubit.value.selection, {0, 1});
    expect((await deps.expenses.binned()).single, taxi);
  });

  testWidgets('the Bin row has the photo icon; the detail shows the photos '
      'without a + tile; a long press gives the bar with Save only; the '
      'viewer has Save, no Delete; Restore brings it back', (tester) async {
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await setUpDeps();
      await binnedWithPhotos(['a', 'b']);
    });
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settingsBin')),
      100,
    );
    await tester.tap(find.byKey(const ValueKey('settingsBin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('photoMark')), findsOneWidget);

    await tester.tap(find.text('Taxi'));
    await pumpUntilFound(tester, find.byType(PhotoThumb));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoThumb), findsNWidgets(2));
    expect(find.byKey(const ValueKey('addPhotoTile')), findsNothing);
    // Each tile says which photo it is (it said nothing on the Oppo).
    expect(find.bySemanticsLabel('Photo 2 of 2'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('photoTile 0')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoSelectionBar), findsOneWidget);
    expect(find.byKey(PhotoSelectionBar.deleteKey), findsNothing);
    await tester.tap(find.byKey(PhotoSelectionBar.saveKey));
    await pumpUntilFound(
      tester,
      find.text('Saved to Pictures/Expense Tracker'),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byType(PhotoSelectionBar),
      findsNothing,
      reason: 'Back ends it',
    );

    await tester.tap(find.byKey(const ValueKey('photoTile 1')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(find.byKey(const ValueKey('viewerSave')), findsOneWidget);
    expect(find.byKey(const ValueKey('viewerDelete')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Restore'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Restore'));
    await pumpUntilGone(tester, find.byType(PhotoThumb));
    final active = (await tester.runAsync(deps.expenses.page))!;
    expect(active.single.photoCount, 2);
  });
}
