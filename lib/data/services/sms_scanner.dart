import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;

import '../../domain/models/sms_suggestion.dart';
import '../../domain/sms/sms_parser.dart';
import '../../domain/sms/sms_window.dart';
import '../repositories/settings_repository.dart';
import '../repositories/sms_suggestion_repository.dart';
import 'sms_service.dart';

/// What a [SmsScanner.scan] did.
enum ScanOutcome {
  /// The build has no READ_SMS (play with `-PnoSms`).
  notBuilt,

  /// The user hasn't turned SMS suggestions on.
  off,

  /// Turned on, but the permission was taken away.
  noPermission,

  /// Read and stored (the result's `added` new suggestions).
  done,

  /// Reading or storing failed; logged, the cursor didn't move, the next
  /// open tries again.
  failed,

  /// [SmsScanner.close] came first: nothing was written.
  closed,
}

typedef ScanResult = ({ScanOutcome outcome, int added});

/// Parses each `(sender, body)`: the candidate check, then the parser
/// (§5.1, §5.2). One list in, one list out, so it can run in an isolate.
typedef SmsParseAll = Future<List<SmsParse?>> Function(
  List<(String, String)> messages,
);

/// Reads the bank SMS that came since the last scan, parses each one once
/// and stores what it found (phase-9a.md §6.3). **The SMS text never leaves
/// this class's memory** (P9a-19): not into the database, a file or the
/// log.
class SmsScanner {
  SmsScanner({
    required this._service,
    required this._repository,
    required this._settings,
    this.lookbackDays = smsLookbackDays,
    DateTime Function()? now,
    int Function(int epochMs)? offsetMinutesAt,
    SmsParseAll? parseAll,
    this.readLimit = 2000,
  }) : _now = now ?? DateTime.now,
       _offsetMinutesAt = offsetMinutesAt ?? _deviceOffsetMinutes,
       _parseAll = parseAll ?? parseInIsolate;

  /// The app's scanner: the look-back is 30 days unless a debug build was
  /// given `--dart-define=SMS_LOOKBACK_DAYS=<n>` (§6.8, P9a-49).
  /// [releaseMode] is injectable so a test can pin that a release build
  /// ignores it.
  factory SmsScanner.forApp({
    required SmsService service,
    required SmsSuggestionRepository repository,
    required SettingsRepository settings,
    DateTime Function()? now,
    bool releaseMode = kReleaseMode,
    String lookbackDefine = const String.fromEnvironment('SMS_LOOKBACK_DAYS'),
  }) => SmsScanner(
    service: service,
    repository: repository,
    settings: settings,
    now: now,
    lookbackDays: lookbackDaysFor(
      releaseMode: releaseMode,
      define: lookbackDefine,
    ),
  );

  final SmsService _service;
  final SmsSuggestionRepository _repository;
  final SettingsRepository _settings;
  final DateTime Function() _now;
  final int Function(int epochMs) _offsetMinutesAt;
  final SmsParseAll _parseAll;

  /// How far back a scan may read, and the purge's age (§5.8): always 30
  /// in a release build.
  final int lookbackDays;

  /// The most inbox rows one scan handles (P9a-39): the rest next time.
  final int readLimit;

  /// The cursor stays this far behind the scan's start (P9a-41): an SMS the
  /// provider stores a little after its `date` is still read next time.
  static const cursorLag = Duration(minutes: 10);

  Future<ScanResult>? _running;
  bool _closed = false;

  /// The rows the last scan handled from its new cursor on: the next scan
  /// reads them again (the lag, P9a-41), and only stored ones are known to
  /// the database. Without this, a non-candidate or a row dropped for its
  /// reference would be parsed again at every open within the lag. Keys
  /// only (a hash, never the text), in memory: after a restart such a row
  /// is parsed once more.
  Set<SmsKey> _handled = {};

  /// Completes when no scan runs: the backup waits on it (§6.7).
  Future<void> get idle => _running ?? Future<void>.value();

  /// Whether a scan runs now.
  bool get isScanning => _running != null;

  /// Stops scanning: a running scan writes nothing more, and later calls
  /// return [ScanOutcome.closed] (a restore is about to swap the database,
  /// R14).
  void close() => _closed = true;

  /// One scan at a time: a call while one runs gets that one's result.
  Future<ScanResult> scan() {
    if (_closed) return Future.value((outcome: ScanOutcome.closed, added: 0));
    return _running ??= _scan().whenComplete(() => _running = null);
  }

  Future<ScanResult> _scan() async {
    try {
      final permission = await _service.status();
      if (!permission.built) return _result(ScanOutcome.notBuilt);
      if (!await _settings.smsEnabled()) return _result(ScanOutcome.off);
      if (!permission.granted) return _result(ScanOutcome.noPermission);
      final start = _now().millisecondsSinceEpoch;
      final since = scanSince(
        nowMs: start,
        cursorMs: await _repository.cursor(),
        lookbackDays: lookbackDays,
      );
      final inbox = await _service.read(sinceMs: since, limit: readLimit);
      final added = await _store(inbox, since: since, startMs: start);
      return added == null
          ? _result(ScanOutcome.closed)
          : (outcome: ScanOutcome.done, added: added);
    } catch (error, stackTrace) {
      // Never the text: the error comes from the channel or the database,
      // which never had it.
      debugPrint('SMS scan failed: $error\n$stackTrace');
      return _result(ScanOutcome.failed);
    }
  }

  /// Steps 3 – 7 of §6.3 for [inbox] (oldest first). Null when closed
  /// before the write.
  Future<int?> _store(
    List<InboxSms> inbox, {
    required int since,
    required int startMs,
  }) async {
    final hashed = [
      for (final sms in inbox) (sms: sms, sha: _sha256(sms.body)),
    ];
    final known = inbox.isEmpty
        ? const <SmsKey>{}
        : await _repository.existingKeys(
            fromMs: inbox.first.receivedAtMs,
            toMs: inbox.last.receivedAtMs,
          );
    SmsKey keyOf(({InboxSms sms, String sha}) row) => (
      sender: row.sms.sender,
      receivedAtMs: row.sms.receivedAtMs,
      bodySha256: row.sha,
    );
    final fresh = [
      for (final row in hashed)
        if (!known.contains(keyOf(row)) && !_handled.contains(keyOf(row))) row,
    ];
    final parses = fresh.isEmpty
        ? const <SmsParse?>[]
        : await _parseAll([for (final r in fresh) (r.sms.sender, r.sms.body)]);
    final rows = [
      for (final (i, row) in fresh.indexed)
        if (parses[i] case final parse?)
          NewSmsSuggestion(
            sender: row.sms.sender,
            receivedAtMs: row.sms.receivedAtMs,
            utcOffsetMinutes: _offsetMinutesAt(row.sms.receivedAtMs),
            bodySha256: row.sha,
            amountMinor: parse.amountMinor,
            paymentMethodKey: parse.paymentMethodKey,
            payee: parse.payee,
            reference: parse.reference,
          ),
    ];
    if (_closed) return null;
    final cursor = _cursorAfter(inbox, since: since, startMs: startMs);
    final added = await _repository.insertScanned(rows, cursorMs: cursor);
    // The next scan reads again from the cursor; what it would find there
    // was handled now.
    _handled = {
      for (final row in hashed)
        if (row.sms.receivedAtMs >= cursor) keyOf(row),
    };
    return added;
  }

  /// Where the next scan starts (§6.3 step 7, P9a-39, P9a-41):
  ///
  /// - a full read ([readLimit] rows): the newest row handled, so the rest
  ///   comes next time (rows at that same ms are read again and skipped);
  /// - otherwise everything up to now was handled: the scan's start minus
  ///   [cursorLag], never before [since].
  ///
  /// The doc says "the older of the newest handled and start − 10 min" in
  /// both cases; that re-reads days of non-candidates at every open when
  /// the newest SMS is old (phase-9a.md §12a).
  int _cursorAfter(
    List<InboxSms> inbox, {
    required int since,
    required int startMs,
  }) {
    final lagged = startMs - cursorLag.inMilliseconds;
    final newest = inbox.isEmpty ? lagged : inbox.last.receivedAtMs;
    final cursor = inbox.length >= readLimit && newest < lagged
        ? newest
        : lagged;
    // Never backwards: the cursor only moves past what was handled.
    return cursor < since ? since : cursor;
  }

  static ScanResult _result(ScanOutcome outcome) =>
      (outcome: outcome, added: 0);

  static String _sha256(String body) =>
      sha256.convert(utf8.encode(body)).toString();

  static int _deviceOffsetMinutes(int epochMs) =>
      DateTime.fromMillisecondsSinceEpoch(epochMs).timeZoneOffset.inMinutes;
}

/// The look-back a build uses (§6.8): [define] (`SMS_LOOKBACK_DAYS`) in a
/// debug or profile build when it is a whole number from 1 to 3650;
/// otherwise, and always in a release build, [smsLookbackDays].
int lookbackDaysFor({required bool releaseMode, required String define}) {
  if (releaseMode) return smsLookbackDays;
  final days = int.tryParse(define.trim());
  return days != null && days >= 1 && days <= 3650 ? days : smsLookbackDays;
}

/// [SmsParseAll] in a background isolate (§6.3 step 4): the parser is
/// pure, and a few thousand regex runs shouldn't cost frames.
Future<List<SmsParse?>> parseInIsolate(List<(String, String)> messages) =>
    Isolate.run(() => parseAllNow(messages));

/// [SmsParseAll]'s work, on this isolate, with [parser] (India's banks:
/// the only ones read for now).
List<SmsParse?> parseAllNow(
  List<(String, String)> messages, {
  SmsParser parser = const IndiaSmsParser(),
}) => [
  for (final (sender, body) in messages)
    parser.isDebitCandidate(sender, body) ? parser.parse(body) : null,
];
