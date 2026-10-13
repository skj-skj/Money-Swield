import 'package:flutter/services.dart';

/// Whether SMS can be read: `built` (the merged manifest asks for READ_SMS;
/// false in play built with `-PnoSms`), `granted`, and `canAsk` (false after
/// "Don't allow" twice: only the app's system settings can grant it then).
typedef SmsPermission = ({bool built, bool granted, bool canAsk});

/// One inbox row. Its `body` lives only in the scan's memory.
typedef InboxSms = ({String sender, int receivedAtMs, String body});

/// The phone's SMS inbox and the READ_SMS permission, behind an interface so
/// tests use a fake. Own Kotlin, no plugin.
abstract interface class SmsService {
  Future<SmsPermission> status();

  /// Shows Android's permission dialog; whether it was granted. Never
  /// throws for a refusal.
  Future<bool> request();

  /// Opens the app's page in the system settings.
  Future<void> openSettings();

  /// Inbox rows with `date >= sinceMs`, oldest first, at most [limit];
  /// rows without a body or sender are left out.
  Future<List<InboxSms>> read({required int sinceMs, required int limit});
}

/// [SmsService] over the `money_swield/sms` channel (`SmsChannel.kt`).
class ChannelSmsService implements SmsService {
  const ChannelSmsService();

  static const _channel = MethodChannel('money_swield/sms');

  @override
  Future<SmsPermission> status() async {
    final map = (await _channel.invokeMapMethod<String, Object?>('status'))!;
    return (
      built: map['built'] == true,
      granted: map['granted'] == true,
      canAsk: map['canAsk'] == true,
    );
  }

  @override
  Future<bool> request() async =>
      await _channel.invokeMethod<bool>('request') ?? false;

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  @override
  Future<List<InboxSms>> read({
    required int sinceMs,
    required int limit,
  }) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'read',
      {'sinceMs': sinceMs, 'limit': limit},
    );
    return [
      for (final row in rows ?? const <Map<Object?, Object?>>[])
        if (row case {
          'address': final String sender,
          'date': final int receivedAtMs,
          'body': final String body,
        })
          (sender: sender, receivedAtMs: receivedAtMs, body: body),
    ];
  }
}

/// A build without the channel (widget tests, a phone without the SMS
/// provider): SMS is "not built", nothing is read.
class NoSmsService implements SmsService {
  const NoSmsService();

  @override
  Future<SmsPermission> status() async =>
      (built: false, granted: false, canAsk: false);

  @override
  Future<bool> request() async => false;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<InboxSms>> read({
    required int sinceMs,
    required int limit,
  }) async => const [];
}
