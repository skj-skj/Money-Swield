import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/domain/models/expense.dart';
import 'package:money_swield/domain/models/money.dart';
import 'package:money_swield/domain/photo_sizing.dart';
import 'package:money_swield/ui/features/settings/view_models/settings_summary_cubit.dart';
import 'package:money_swield/ui/features/settings/views/photo_settings_screen.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

/// Settings → Photos and the tiles' summaries.
void main() {
  late AppDependencies deps;

  setUp(() async {
    deps = await openTestDependencies(deviceCurrency: 'INR');
    await deps.settings.setOnboardingCompleted();
  });

  Future<void> addWithPhotos(List<(String, int)> photos) => deps.expenses.add(
    ExpenseInput(
      title: 'Lunch',
      description: null,
      amount: const Money(100, 'INR'),
      occurredAt: DateTime.utc(2026, 10, 5),
      utcOffsetMinutes: 330,
      categoryId: 1,
      paymentMethodId: 1,
      eventIds: const {},
      photos: [
        for (final (letter, size) in photos)
          LinkNewPhoto(
            relativePath: 'photos/${letter * 64}.jpg',
            sha256: letter * 64,
            byteSize: size,
          ),
      ],
    ),
  );

  Future<void> openPhotos(WidgetTester tester) async {
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settingsPhotos')),
      100,
    );
    await tester.tap(find.byKey(const ValueKey('settingsPhotos')));
    await tester.pumpAndSettle();
  }

  group('SettingsSummaryCubit', () {
    test('reads the last backup and the photo stats', () async {
      await deps.backups.recordBackup(DateTime.utc(2026, 10, 1));
      await addWithPhotos([('a', 1024 * 1024), ('b', 1024)]);
      final cubit = SettingsSummaryCubit(
        backups: deps.backups,
        expenses: deps.expenses,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.value.lastBackupAt, DateTime.utc(2026, 10, 1));
      expect(cubit.value.photoCount, 2);
      expect(cubit.value.photoBytes, 1024 * 1024 + 1024);
    });

    test('a failing read leaves that value unknown, the other read', () async {
      await deps.backups.recordBackup(DateTime.utc(2026, 10, 1));
      await deps.database.execute('DROP TABLE expense_photos');
      final cubit = SettingsSummaryCubit(
        backups: deps.backups,
        expenses: deps.expenses,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.value.lastBackupAt, DateTime.utc(2026, 10, 1));
      expect(cubit.value.photoCount, isNull);
    });
  });

  testWidgets('the tile: "Camera 1080p · Gallery 1080p · 1.0 MB"; Last '
      'backup comes from the same cubit', (tester) async {
    await tester.runAsync(() async {
      await addWithPhotos([('a', 1024 * 1024)]);
      await deps.backups.recordBackup(DateTime.now().toUtc());
    });
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Camera 1080p · Gallery 1080p · 1.0 MB'), findsOneWidget);
    expect(find.textContaining('Last backup: today'), findsOneWidget);
  });

  testWidgets('defaults; Camera → Original: the warning, quality off; Gallery '
      '1440p; Restore defaults → 1080p / 85; the "kept inside" line', (
    tester,
  ) async {
    await openPhotos(tester);
    expect(find.text('1080p (default)'), findsNWidgets(2));
    expect(find.text('85 (default)'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('originalWarning')), findsNothing);
    expect(find.textContaining('Photos are kept inside the app'), findsOne);
    expect(find.text('No photos yet.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cameraSize')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Original (not recommended)').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('originalWarning')), findsOneWidget);
    expect((await deps.settings.load()).cameraPhotos.size, PhotoSize.original);
    // Ignores taps under Original: the tap hits nothing.
    await tester.tap(
      find.byKey(const ValueKey('cameraQuality')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing, reason: 'quality is off');

    await tester.tap(find.byKey(const ValueKey('gallerySize')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1440p').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('galleryQuality')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('70').last);
    await tester.pumpAndSettle();
    expect((await deps.settings.load()).galleryPhotos, (
      size: PhotoSize.p1440,
      quality: 70,
    ));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('restorePhotoDefaults')),
      100,
      // This screen's list, not the Settings grid under it.
      scrollable: find.descendant(
        of: find.byType(PhotoSettingsScreen),
        matching: find.byType(Scrollable),
      ),
    );
    // Clear of the navigation bar under it.
    await tester.drag(
      find.descendant(
        of: find.byType(PhotoSettingsScreen),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('restorePhotoDefaults')));
    await tester.pumpAndSettle();
    expect(find.text('Restore the photo defaults?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Restore defaults'));
    await tester.pumpAndSettle();
    final settings = await deps.settings.load();
    expect(settings.cameraPhotos, defaultPhotoSizing);
    expect(settings.galleryPhotos, defaultPhotoSizing);
  });

  testWidgets('the space photos use, es with a decimal comma', (tester) async {
    await tester.runAsync(
      () => addWithPhotos([('a', (1.5 * 1024 * 1024).round())]),
    );
    await openPhotos(tester);
    expect(find.text('Photos use 1.5 MB (1 photo).'), findsOneWidget);
  });

  testWidgets('fits at 360 dp and font 2.0 in hi', (tester) async {
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await deps.settings.setLocale(const Locale('hi'));
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.byType(NavigationDestination).last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settingsPhotos')),
      100,
    );
    await tester.tap(find.byKey(const ValueKey('settingsPhotos')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
