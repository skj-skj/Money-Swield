import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/services/on_device_ai_service.dart';
import 'package:my_expense_tracker_app/data/services/sms_scanner.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_ai_prompt.dart';
import 'package:my_expense_tracker_app/ui/features/sms/view_models/sms_cubit.dart';

import '../../../../domain/sms/fixtures/india_sms.dart';
import '../../../../helpers/fake_on_device_ai.dart';
import '../../../../helpers/fake_sms_service.dart';
import '../../../../helpers/test_database.dart';

/// `SmsCubit` with the on-device model.
void main() {
  late AppDependencies deps;
  late TestClock clock;
  late FakeSmsService sms;
  late FakeOnDeviceAi ai;
  late SmsScanner scanner;
  late List<List<CategoryName>> categoriesAsked;

  const day = Duration.millisecondsPerDay;
  const bank = 'VM-ABCBNK-S';

  setUp(() async {
    clock = TestClock(DateTime.utc(2026, 10, 11, 9));
    deps = await openTestDependencies(clock: clock);
    sms = FakeSmsService();
    ai = FakeOnDeviceAi();
    categoriesAsked = [];
    scanner = SmsScanner(
      service: sms,
      repository: deps.smsSuggestions,
      settings: deps.settings,
      now: clock.call,
      offsetMinutesAt: (_) => 330,
      ai: ai,
      candidatesAll: (messages) async => candidatesNow(messages),
    );
    await deps.settings.setSmsEnabled(true);
  });

  int nowMs() => clock.now.millisecondsSinceEpoch;

  SmsCubit smsCubit() {
    final cubit = SmsCubit(
      service: sms,
      scanner: scanner,
      repository: deps.smsSuggestions,
      settings: deps.settings,
      ai: ai,
      categoryNames: () async {
        final names = [(id: 1, name: 'Groceries')];
        categoriesAsked.add(names);
        return names;
      },
      now: clock.call,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('the scan gets the categories; its rows come from the model', () async {
    sms.add(bank, nowMs() - day, bankSent1);
    final cubit = smsCubit();
    await cubit.start();
    expect(categoriesAsked, hasLength(1));
    expect(ai.asked, [bankSent1]);
    expect(ai.prompts.single, contains('- Groceries\n'));
    expect(cubit.value.aiStatus, AiStatus.available);
    expect(cubit.value.pendingCount, 1);
    // Read once, for Settings and the scan alike.
    expect(ai.statusCalls, 1);
  });

  for (final status in [
    AiStatus.downloadable,
    AiStatus.downloading,
    AiStatus.unavailable,
  ]) {
    test(
      '$status → the scan reads with the regex, no categories read',
      () async {
        ai.current = status;
        sms.add(bank, nowMs() - day, bankSent1);
        final cubit = smsCubit();
        await cubit.start();
        expect(cubit.value.pendingCount, 1);
        expect(ai.asked, isEmpty);
        expect(categoriesAsked, isEmpty);
      },
    );
  }

  test('a status that fails → no model; SMS suggestions go on', () async {
    sms.add(bank, nowMs() - day, bankSent1);
    ai = _FailingStatusAi();
    final cubit = smsCubit();
    await cubit.start();
    expect(cubit.value.availability, SmsAvailability.on);
    expect(cubit.value.aiStatus, AiStatus.unavailable);
    expect(cubit.value.pendingCount, 1);
  });

  test(
    'categories that can\'t be read → the scan still runs, with none',
    () async {
      sms.add(bank, nowMs() - day, bankSent1);
      final cubit = SmsCubit(
        service: sms,
        scanner: scanner,
        repository: deps.smsSuggestions,
        settings: deps.settings,
        ai: ai,
        categoryNames: () async => throw StateError('gone'),
        now: clock.call,
      );
      addTearDown(cubit.close);
      await cubit.start();
      expect(cubit.value.pendingCount, 1);
      expect(ai.prompts.single, isNot(contains('- ')));
    },
  );

  group('the switch', () {
    test('foss / unavailable → hidden; available / downloadable / '
        'downloading → shown while SMS is on', () async {
      for (final (status, shown) in [
        (AiStatus.unavailable, false),
        (AiStatus.available, true),
        (AiStatus.downloadable, true),
        (AiStatus.downloading, true),
      ]) {
        ai.current = status;
        final cubit = smsCubit();
        await cubit.start();
        expect(cubit.value.showsAi, shown, reason: '$status');
      }
      // SMS off: no AI switch either.
      await deps.settings.setSmsEnabled(false);
      ai.current = AiStatus.available;
      final off = smsCubit();
      await off.start();
      expect(off.value.showsAi, isFalse);
    });

    test('available: on by default; off → the next scan reads with the '
        'regex; on again → the model', () async {
      final cubit = smsCubit();
      await cubit.start();
      expect(cubit.value.aiSwitchOn, isTrue);
      await cubit.setAiParsing(false);
      expect(cubit.value.aiSwitchOn, isFalse);
      expect(await deps.settings.smsAiParsing(), isFalse);
      sms.add(bank, nowMs() - 60000, bankSent1);
      clock.advance(const Duration(minutes: 2));
      await cubit.resumed();
      expect(ai.asked, isEmpty);
      await cubit.setAiParsing(true);
      sms.add(bank, nowMs() - 30000, bankSent2);
      clock.advance(const Duration(minutes: 2));
      await cubit.resumed();
      expect(ai.asked, [bankSent2]);
    });

    test('downloadable: shown off though the setting is on; the app never '
        'downloads on its own', () async {
      ai.current = AiStatus.downloadable;
      final cubit = smsCubit();
      await cubit.start();
      expect(await deps.settings.smsAiParsing(), isTrue);
      expect(cubit.value.aiSwitchOn, isFalse);
      expect(ai.downloads, 0);
    });

    test('downloadable, turned on → the download starts, "Downloading…" '
        'until the status says available', () async {
      ai
        ..current = AiStatus.downloadable
        ..downloadAnswer = Completer<bool>();
      final cubit = smsCubit();
      await cubit.start();
      await cubit.setAiParsing(true);
      expect(ai.downloads, 1);
      expect(cubit.value.aiDownloading, isTrue);
      expect(cubit.value.aiSwitchOn, isTrue);
      // Off and on again while it runs (a double tap): no second one.
      await cubit.setAiParsing(false);
      await cubit.setAiParsing(true);
      expect(ai.downloads, 1);
      ai.current = AiStatus.available;
      ai.downloadAnswer!.complete(true);
      await pumpEventQueue();
      expect(cubit.value.aiStatus, AiStatus.available);
      expect(cubit.value.aiDownloading, isFalse);
      expect(cubit.value.aiSwitchOn, isTrue);
    });

    test(
      'a failed download → no longer "Downloading…", the switch off',
      () async {
        ai
          ..current = AiStatus.downloadable
          ..downloadAnswer = Completer<bool>();
        final cubit = smsCubit();
        await cubit.start();
        await cubit.setAiParsing(true);
        ai.downloadAnswer!.complete(false);
        await pumpEventQueue();
        expect(cubit.value.aiDownloading, isFalse);
        expect(cubit.value.aiSwitchOn, isFalse);
      },
    );

    test(
      'a download that never answers: the scans go on with the regex',
      () async {
        ai
          ..current = AiStatus.downloadable
          ..downloadAnswer = Completer<bool>();
        final cubit = smsCubit();
        await cubit.start();
        await cubit.setAiParsing(true);
        sms.add(bank, nowMs() - 60000, bankSent1);
        clock.advance(const Duration(minutes: 2));
        await cubit.resumed();
        expect(cubit.value.pendingCount, 1);
        expect(ai.asked, isEmpty);
      },
    );

    test('turned on while available → no download', () async {
      final cubit = smsCubit();
      await cubit.start();
      await cubit.setAiParsing(false);
      await cubit.setAiParsing(true);
      expect(ai.downloads, 0);
    });
  });

  group('leaving the front', () {
    test('paused() stops the pass after the current SMS; resumed() goes on '
        'at once, not after a minute', () async {
      for (var i = 0; i < 4; i++) {
        sms.add(
          bank,
          nowMs() - day + i * 1000,
          bankSent1
              .replaceAll('100000000001', '10000000000$i')
              .replaceAll('150.00', '15$i.00'),
        );
      }
      final hold = Completer<AiReply>();
      ai.reply = (text) =>
          ai.asked.length == 2 ? hold.future : FakeOnDeviceAi.plainAnswer(text);
      final cubit = smsCubit();
      final started = cubit.start();
      await pumpEventQueue(times: 50);
      cubit.paused();
      hold.complete(FakeOnDeviceAi.plainAnswer(ai.asked.last));
      await started;
      expect(cubit.value.pendingCount, 2);
      expect(ai.asked, hasLength(2));
      // Back after 5 seconds: inside the minute, but the pass had stopped.
      clock.advance(const Duration(seconds: 5));
      await cubit.resumed();
      expect(cubit.value.pendingCount, 4);
      expect(ai.asked, hasLength(4));
      // A finished scan keeps the minute.
      clock.advance(const Duration(seconds: 5));
      await cubit.resumed();
      expect(sms.reads, hasLength(2));
    });

    test(
      'background refused (error 30) → stopped; back → asked again',
      () async {
        sms.add(bank, nowMs() - day, bankSent1);
        ai.reply = (_) => const AiRefused(AiError.background);
        final cubit = smsCubit();
        await cubit.start();
        expect(cubit.value.pendingCount, 0);
        ai.reply = null;
        clock.advance(const Duration(seconds: 3));
        await cubit.resumed();
        expect(cubit.value.pendingCount, 1);
        expect(ai.asked, [bankSent1, bankSent1]);
      },
    );
  });
}

/// AICore broken in a way the channel service doesn't catch.
class _FailingStatusAi extends FakeOnDeviceAi {
  @override
  Future<AiStatus> status() async => throw StateError('AICore');
}
