import 'dart:async';

import 'package:my_expense_tracker_app/data/services/sms_service.dart';

/// Stands in for the SMS channel (phase-9a.md §12 "Scanner"): an inbox in
/// memory, a permission the test sets, and a record of every read.
class FakeSmsService implements SmsService {
  FakeSmsService({this.built = true, this.granted = true, this.canAsk = true});

  bool built;
  bool granted;
  bool canAsk;

  /// What the next `request` answers; it also sets [granted].
  bool grantOnRequest = true;

  /// Asking flips [canAsk] off after this many refusals ("Don't allow"
  /// twice, P9a-30).
  int refusalsUntilBlocked = 2;
  int requests = 0;
  int settingsOpened = 0;

  /// The inbox, any order; `read` sorts and filters it like the provider.
  final inbox = <InboxSms>[];

  /// Every read's `(sinceMs, limit)`.
  final reads = <({int sinceMs, int limit})>[];

  /// Set to make the next reads throw.
  Exception? readError;

  /// While set, `read` waits for it: a test can hold a scan mid-way.
  Completer<void>? gate;

  void add(String sender, int atMs, String body) =>
      inbox.add((sender: sender, receivedAtMs: atMs, body: body));

  @override
  Future<SmsPermission> status() async =>
      (built: built, granted: granted, canAsk: canAsk);

  @override
  Future<bool> request() async {
    requests++;
    granted = grantOnRequest;
    if (!granted && requests >= refusalsUntilBlocked) canAsk = false;
    return granted;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<List<InboxSms>> read({
    required int sinceMs,
    required int limit,
  }) async {
    reads.add((sinceMs: sinceMs, limit: limit));
    await gate?.future;
    if (readError case final error?) throw error;
    final rows = [
      for (final sms in inbox)
        if (sms.receivedAtMs >= sinceMs) sms,
    ]..sort((a, b) => a.receivedAtMs.compareTo(b.receivedAtMs));
    return rows.take(limit).toList();
  }
}
