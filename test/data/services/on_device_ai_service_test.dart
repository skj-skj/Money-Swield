import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/on_device_ai_service.dart';
import 'package:my_expense_tracker_app/domain/models/app_flavor.dart';

/// `ChannelOnDeviceAiService` over a mocked `expense_tracker/on_device_ai`
/// (phase-9b.md §6.1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('expense_tracker/on_device_ai');
  final calls = <MethodCall>[];

  void answer(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return handler(call);
        });
  }

  setUp(calls.clear);
  tearDown(() => answer((_) => null));

  const play = ChannelOnDeviceAiService(
    flavor: AppFlavor.play,
    statusTimeout: Duration(milliseconds: 50),
    promptBackstop: Duration(milliseconds: 50),
  );

  test('status words; anything unknown is unavailable', () async {
    for (final (word, status) in [
      ('available', AiStatus.available),
      ('downloadable', AiStatus.downloadable),
      ('downloading', AiStatus.downloading),
      ('unavailable', AiStatus.unavailable),
      ('later', AiStatus.unavailable),
    ]) {
      answer((_) async => word);
      expect(await play.status(), status);
    }
  });

  test('a status that never comes → unavailable after the timeout, no '
      'hang (the release build\'s crash)', () async {
    answer((_) => Completer<Object?>().future);
    expect(await play.status(), AiStatus.unavailable);
  });

  test('a channel error or no channel → unavailable', () async {
    answer((_) async => throw PlatformException(code: 'x'));
    expect(await play.status(), AiStatus.unavailable);
    answer((_) async => throw MissingPluginException());
    expect(await play.status(), AiStatus.unavailable);
  });

  test('prompt: text and timeout sent; error codes mapped', () async {
    answer((call) async => 'json');
    final reply = await play.prompt('p', timeout: const Duration(seconds: 10));
    expect((reply as AiAnswer).text, 'json');
    expect(calls.single.arguments, {'text': 'p', 'timeoutMs': 10000});
    for (final (code, error) in [
      ('background', AiError.background),
      ('busy', AiError.busy),
      ('quota', AiError.quota),
      ('timeout', AiError.timeout),
      ('failed', AiError.failed),
      ('whatever', AiError.failed),
    ]) {
      answer((_) async => throw PlatformException(code: code));
      expect(
        ((await play.prompt(
          'p',
          timeout: const Duration(seconds: 1),
        )) as AiRefused).error,
        error,
      );
    }
  });

  test('a prompt the channel never answers → timeout, not a hang', () async {
    answer((_) => Completer<Object?>().future);
    final reply = await play.prompt(
      'p',
      timeout: const Duration(milliseconds: 1),
    );
    expect((reply as AiRefused).error, AiError.timeout);
  });

  test('foss never calls the channel', () async {
    answer((_) async => 'available');
    const foss = ChannelOnDeviceAiService(flavor: AppFlavor.foss);
    expect(await foss.status(), AiStatus.unavailable);
    expect(await foss.download(), isFalse);
    expect(
      await foss.prompt('p', timeout: const Duration(seconds: 1)),
      isA<AiRefused>(),
    );
    expect(calls, isEmpty);
  });
}
