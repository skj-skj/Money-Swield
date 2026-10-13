import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../../domain/models/app_flavor.dart';

/// Whether the phone's on-device model can be used.
enum AiStatus {
  available,

  /// The phone can have it once the user turns the AI on.
  downloadable,
  downloading,

  /// No model on this phone, AICore missing, or the foss build.
  unavailable;

  /// The channel's word; anything unknown is [unavailable].
  static AiStatus fromName(String? name) => switch (name) {
    'available' => available,
    'downloadable' => downloadable,
    'downloading' => downloading,
    _ => unavailable,
  };

  /// Whether Settings → SMS shows the switch: a model in, or one that can come.
  bool get canBeUsed => this != unavailable;
}

/// Why a prompt got no answer, which says what the scan does.
enum AiError {
  /// The app isn't the top foreground app (ML Kit error 30): stop the AI pass,
  /// ask again at the next open.
  background,

  /// AICore is busy or the short quota is used up (9): as [background].
  busy,

  /// The daily per-app quota (27): the regex reads the rest of this scan.
  quota,

  /// No answer within the time given: the regex reads that SMS.
  timeout,

  /// Anything else: the regex reads that SMS.
  failed;

  static AiError fromName(String name) => switch (name) {
    'background' => background,
    'busy' => busy,
    'quota' => quota,
    'timeout' => timeout,
    _ => failed,
  };

  /// Whether the AI pass stops here, with the cursor before this SMS.
  bool get stopsPass => this == background || this == busy;
}

/// A prompt's outcome: the model's text, or why there is none.
sealed class AiReply {
  const AiReply();
}

final class AiAnswer extends AiReply {
  const AiAnswer(this.text);
  final String text;
}

final class AiRefused extends AiReply {
  const AiRefused(this.error);
  final AiError error;
}

/// The phone's on-device model (Gemini Nano through AICore, play only), behind
/// an interface so tests use a fake.
abstract interface class OnDeviceAiService {
  Future<AiStatus> status();

  /// Starts the model's download (only when the user turns the AI on).
  /// Completes when it is in (true) or failed (false); it may take long or, on
  /// some phones, never complete, so callers don't wait on it for anything the
  /// user sees.
  Future<bool> download();

  /// One prompt. Never throws: a failure is an [AiRefused].
  Future<AiReply> prompt(String text, {required Duration timeout});
}

/// [OnDeviceAiService] over `money_swield/on_device_ai` (`OnDeviceAi.kt`).
/// On foss it never calls the channel: the status is [AiStatus.unavailable].
class ChannelOnDeviceAiService implements OnDeviceAiService {
  const ChannelOnDeviceAiService({
    required this.flavor,
    this.statusTimeout = const Duration(seconds: 5),
    this.promptBackstop = const Duration(seconds: 5),
  });

  final AppFlavor flavor;

  /// A status that doesn't come by then reads `unavailable`: the scan and
  /// Settings must never wait on AICore (a release build's channel once left a
  /// call unanswered). It answered in well under a second on the Pixel.
  final Duration statusTimeout;

  /// Kotlin times the prompt out itself; this, on top of the prompt's own
  /// timeout, is a backstop for a channel that never answers, so a scan
  /// can't hang on it.
  final Duration promptBackstop;

  static const _channel = MethodChannel('money_swield/on_device_ai');

  @override
  Future<AiStatus> status() async {
    if (flavor != AppFlavor.play) return AiStatus.unavailable;
    try {
      return AiStatus.fromName(
        await _channel.invokeMethod<String>('status').timeout(statusTimeout),
      );
    } on Exception catch (error) {
      // No channel (a test) or AICore broken: as if there were no model.
      debugPrint('On-device AI status failed: $error');
      return AiStatus.unavailable;
    }
  }

  @override
  Future<bool> download() async {
    if (flavor != AppFlavor.play) return false;
    try {
      return await _channel.invokeMethod<bool>('download') ?? false;
    } on Exception catch (error) {
      debugPrint('On-device AI download failed: $error');
      return false;
    }
  }

  @override
  Future<AiReply> prompt(String text, {required Duration timeout}) async {
    if (flavor != AppFlavor.play) return const AiRefused(AiError.failed);
    try {
      final answer = await _channel
          .invokeMethod<String>('prompt', {
            'text': text,
            'timeoutMs': timeout.inMilliseconds,
          })
          .timeout(timeout + promptBackstop);
      return AiAnswer(answer ?? '');
    } on TimeoutException {
      return const AiRefused(AiError.timeout);
    } on PlatformException catch (error) {
      // The code and ML Kit's number only; never the text.
      debugPrint('On-device AI: ${error.code} ${error.message}');
      return AiRefused(AiError.fromName(error.code));
    } on Exception catch (error) {
      debugPrint('On-device AI prompt failed: ${error.runtimeType}');
      return const AiRefused(AiError.failed);
    }
  }
}

/// No on-device AI (widget tests, foss without the channel).
class NoOnDeviceAi implements OnDeviceAiService {
  const NoOnDeviceAi();

  @override
  Future<AiStatus> status() async => AiStatus.unavailable;

  @override
  Future<bool> download() async => false;

  @override
  Future<AiReply> prompt(String text, {required Duration timeout}) async =>
      const AiRefused(AiError.failed);
}
