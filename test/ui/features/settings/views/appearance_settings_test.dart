import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/app/shell.dart';
import 'package:money_swield/domain/models/item_shape.dart';
import 'package:money_swield/ui/core/themes.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

/// Settings → Theme color and Settings → Customize tiles.
void main() {
  const blue = 0xFF1565C0;
  const wallpaper = 0xFF8E24AA;

  Future<AppDependencies> onboarded({int? wallpaperSeed}) async {
    final deps = await openTestDependencies(wallpaperSeed: wallpaperSeed);
    await deps.settings.setOnboardingCompleted();
    return deps;
  }

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  /// Settings → Look, where these rows live.
  Future<void> openSettings(WidgetTester tester, AppDependencies deps) async {
    await pumpApp(tester, dependencies: deps);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settingsLook')));
    await tester.pumpAndSettle();
  }

  Color primary(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Shell, skipOffstage: false)))
          .colorScheme
          .primary;

  Color primaryFrom(int seed) =>
      ColorScheme.fromSeed(seedColor: Color(seed)).primary;

  group('theme color', () {
    testWidgets('without wallpaper colors the default color is used', (
      tester,
    ) async {
      final deps = await onboarded();
      await openSettings(tester, deps);
      expect(primary(tester), primaryFrom(defaultSeedColor.toARGB32()));
      expect(find.text('Purple'), findsOneWidget, reason: 'the subtitle');

      await tester.tap(find.text('Theme color'));
      await tester.pumpAndSettle();
      expect(
        find.text('Wallpaper colors'),
        findsNothing,
        reason: 'not offered without them',
      );
    });

    testWidgets('picking a color retints the app and is saved', (tester) async {
      final deps = await onboarded();
      await openSettings(tester, deps);
      await tester.tap(find.text('Theme color'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Blue'));
      await tester.pumpAndSettle();

      expect(primary(tester), primaryFrom(blue));
      expect(find.text('Blue'), findsOneWidget, reason: 'the subtitle');
      expect((await deps.settings.load()).themeSeed, blue);
    });

    testWidgets('with wallpaper colors they are the default, and can be '
        'chosen again after another color', (tester) async {
      final deps = await onboarded(wallpaperSeed: wallpaper);
      await openSettings(tester, deps);
      expect(primary(tester), primaryFrom(wallpaper));
      expect(find.text('Wallpaper colors'), findsOneWidget);

      await tester.tap(find.text('Theme color'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Blue'));
      await tester.pumpAndSettle();
      expect(primary(tester), primaryFrom(blue));

      await tester.tap(find.text('Theme color'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Wallpaper colors'));
      await tester.pumpAndSettle();
      expect(primary(tester), primaryFrom(wallpaper));
      expect((await deps.settings.load()).themeSeed, isNull);
    });
  });

  group('customize tiles', () {
    Finder disc(String emoji) => find.ancestor(
      of: find.text(emoji),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );

    testWidgets('shows both shapes as options and a live preview', (
      tester,
    ) async {
      usePhoneSize(tester);
      final deps = await onboarded();
      await openSettings(tester, deps);
      await tester.tap(find.text('Customize tiles'));
      await tester.pumpAndSettle();

      // All three options of both shapes are shown at once; the defaults
      // are rounded tiles and circle buttons.
      bool isPicked(String label, {required int row}) =>
          isSemantics(isSelected: true)
              .matches(tester.getSemantics(find.text(label).at(row)), {});
      for (final label in ['Square', 'Rounded square', 'Circle']) {
        expect(find.text(label), findsNWidgets(2), reason: label);
      }
      expect(isPicked('Rounded square', row: 0), isTrue);
      expect(isPicked('Circle', row: 0), isFalse);
      expect(isPicked('Circle', row: 1), isTrue);
      // The preview has the user's own categories and events.
      expect(find.text('Bills'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(disc('🧾'), findsNothing, reason: 'rounded tiles');

      await tester.tap(find.text('Circle').first);
      await tester.pumpAndSettle();
      expect(disc('🧾'), findsOneWidget, reason: 'the preview follows');
      expect((await deps.settings.load()).tileShape, ItemShape.circle);

      await tester.tap(find.text('Square').last);
      await tester.pumpAndSettle();
      expect((await deps.settings.load()).buttonShape, ItemShape.square);
    });

    testWidgets('the preview is only a picture: taps and drags do nothing', (
      tester,
    ) async {
      usePhoneSize(tester);
      final deps = await onboarded();
      await openSettings(tester, deps);
      await tester.tap(find.text('Customize tiles'));
      await tester.pumpAndSettle();

      // The pickers' rows scroll sideways, but not in the preview (owner,
      // 2026-10-04).
      final bills = tester.getTopLeft(find.text('Bills'));
      await tester.drag(
        find.text('Bills'),
        const Offset(-300, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Bills')), bills);

      // warnIfMissed: false, as the preview ignores taps on purpose.
      await tester.tap(find.text('Bills'), warnIfMissed: false);
      await tester.tap(find.byIcon(Icons.search).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing, reason: 'no search bar');
      expect(
        isSemantics(isSelected: true)
            .matches(tester.getSemantics(find.text('Bills')), {}),
        isFalse,
      );
    });
  });

  group('restore default look', () {
    testWidgets('asks first, then resets the theme color and shapes', (
      tester,
    ) async {
      final deps = await onboarded(wallpaperSeed: wallpaper);
      await deps.settings.setThemeSeed(blue);
      await deps.settings.setTileShape(ItemShape.circle);
      await deps.settings.setButtonShape(ItemShape.square);
      await openSettings(tester, deps);
      expect(primary(tester), primaryFrom(blue));

      await tester.tap(find.text('Restore default look'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(primary(tester), primaryFrom(blue), reason: 'cancelled');

      await tester.tap(find.text('Restore default look'));
      await tester.pumpAndSettle();
      expect(find.text('Restore the default look?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();

      expect(primary(tester), primaryFrom(wallpaper));
      final settings = await deps.settings.load();
      expect(settings.themeSeed, isNull);
      expect(settings.tileShape, ItemShape.rounded);
      expect(settings.buttonShape, ItemShape.circle);
    });
  });
}
