import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/data/services/on_device_ai_service.dart';
import 'package:money_swield/domain/models/sms_suggestion.dart';
import 'package:money_swield/ui/features/backup/views/backup_screen.dart';

import '../../helpers/fake_on_device_ai.dart';
import '../../helpers/fake_sms_service.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// Settings → SMS's "Use on-device AI" and the backup's count.
void main() {
  late AppDependencies deps;
  late FakeOnDeviceAi ai;

  const aiSwitch = ValueKey('smsAiSwitch');

  Future<void> setUpApp(
    WidgetTester tester, {
    AiStatus status = AiStatus.available,
    String language = 'en',
    double width = 360,
    double textScale = 1,
  }) async {
    await tester.runAsync(() async {
      ai = FakeOnDeviceAi(current: status);
      deps = await openTestDependencies(
        clock: TestClock(DateTime.utc(2026, 10, 11, 9)),
        sms: FakeSmsService(),
        ai: ai,
      );
      await deps.settings.setOnboardingCompleted();
      await deps.settings.setSmsEnabled(true);
      if (language != 'en') await deps.settings.setLocale(Locale(language));
    });
    tester.view.physicalSize = Size(width * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  /// Settings → SMS.
  Future<void> openSmsSettings(
    WidgetTester t, {
    String settings = 'Settings',
  }) async {
    await pumpApp(t, dependencies: deps);
    await t.pumpAndSettle();
    await t.tap(find.text(settings));
    await t.pumpAndSettle();
    // Below the fold at the largest font.
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('settingsSms')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('settingsSms')));
    await t.pumpAndSettle();
  }

  SwitchListTile switchOf(WidgetTester t) =>
      t.widget<SwitchListTile>(find.byKey(aiSwitch));

  // Which statuses show the switch, and SMS off: `sms_cubit_ai_test`
  // ("the switch"); here only that the screen follows `showsAi`. Shown:
  // the available and downloadable tests below.
  testWidgets('unavailable (a phone without the model, foss) → no switch', (
    t,
  ) async {
    await setUpApp(t, status: AiStatus.unavailable);
    await openSmsSettings(t);
    expect(find.byKey(aiSwitch), findsNothing);
  });

  testWidgets('available: on, with its help; off → saved', (t) async {
    await setUpApp(t);
    await openSmsSettings(t);
    expect(switchOf(t).value, isTrue);
    expect(find.text('Use on-device AI'), findsOneWidget);
    expect(find.textContaining('Nothing leaves the phone'), findsOneWidget);
    await t.tap(find.byKey(aiSwitch));
    await pumpUntil(t, () => !switchOf(t).value);
    await t.runAsync(() async {
      expect(await deps.settings.smsAiParsing(), isFalse);
    });
  });

  testWidgets('downloadable: off; a tap starts the download and shows '
      '"Downloading the model…" with the help still there', (t) async {
    await setUpApp(t, status: AiStatus.downloadable);
    ai.downloadAnswer = Completer<bool>();
    await openSmsSettings(t);
    expect(switchOf(t).value, isFalse);
    expect(find.text('Downloading the model…'), findsNothing);
    await t.tap(find.byKey(aiSwitch));
    await pumpUntil(t, () => switchOf(t).value);
    expect(ai.downloads, 1);
    expect(find.text('Downloading the model…'), findsOneWidget);
    expect(find.textContaining('Nothing leaves the phone'), findsOneWidget);
    // Done: the line goes.
    ai.current = AiStatus.available;
    ai.downloadAnswer!.complete(true);
    await pumpUntil(
      t,
      () => find.text('Downloading the model…').evaluate().isEmpty,
    );
    expect(switchOf(t).value, isTrue);
  });

  for (final (language, title, settings) in [
    ('es', 'Usar IA en el dispositivo', 'Ajustes'),
    ('hi', 'डिवाइस पर AI का उपयोग करें', 'सेटिंग'),
  ]) {
    testWidgets('$language at the largest font on a 360 dp phone: the '
        'switch reads in full, nothing overflows', (t) async {
      await setUpApp(t, language: language, textScale: 2);
      await openSmsSettings(t, settings: settings);
      expect(find.text(title), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  group('the backup waits with a count', () {
    testWidgets('"(12 of 40)" while the model reads; the plain message '
        'without a count', (t) async {
      await setUpApp(t);
      final scan = Completer<void>();
      final progress = ValueNotifier<ScanProgress?>((done: 12, total: 40));
      await pumpApp(t, dependencies: deps);
      await t.pumpAndSettle();
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => BackupScreen(
              dependencies: deps,
              runningSmsScan: () => scan.isCompleted ? null : scan.future,
              smsProgress: progress,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Back up now'));
      await t.pump();
      expect(
        find.text('Waiting for SMS reading to finish… (12 of 40)'),
        findsOneWidget,
      );
      progress.value = (done: 13, total: 40);
      await t.pump();
      expect(
        find.text('Waiting for SMS reading to finish… (13 of 40)'),
        findsOneWidget,
      );
      progress.value = null;
      await t.pump();
      expect(find.text('Waiting for SMS reading to finish…'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cancelSmsWait')));
      await t.pumpAndSettle();
      scan.complete();
    });
  });
}
