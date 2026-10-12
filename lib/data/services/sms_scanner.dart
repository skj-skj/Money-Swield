import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' show max, min;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, debugPrint, kReleaseMode;

import '../../domain/models/sms_suggestion.dart';
import '../../domain/sms/sms_ai_prompt.dart';
import '../../domain/sms/sms_ai_result.dart';
import '../../domain/sms/sms_parser.dart';
import '../../domain/sms/sms_window.dart';
import '../repositories/settings_repository.dart';
import '../repositories/sms_suggestion_repository.dart';
import 'on_device_ai_service.dart';
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

  /// The on-device model's pass stopped early: the app left the front, AICore
  /// was busy, or [SmsScanner.pause]. What was read is stored (the result's
  /// `added`); the cursor stays at the first SMS not read, so the next scan
  /// asks again from there.
  stopped,
}

typedef ScanResult = ({ScanOutcome outcome, int added});

/// The candidate check for each `(sender, body)`, in one go so it can run in an
/// isolate.
typedef SmsCandidatesAll = Future<List<bool>> Function(
  List<(String, String)> messages,
);

/// One inbox row and its text's SHA-256.
typedef _Hashed = ({InboxSms sms, String sha});

/// Parses each `(sender, body)`: the candidate check, then the parser. One list
/// in, one list out, so it can run in an isolate.
typedef SmsParseAll = Future<List<SmsParse?>> Function(
  List<(String, String)> messages,
);

/// Reads the bank SMS that came since the last scan, parses each one once and
/// stores what it found. **The SMS text never leaves this class's memory**: not
/// into the database, a file or the log.
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
    this._ai = const NoOnDeviceAi(),
    this._parser = const IndiaSmsParser(),
    SmsCandidatesAll? candidatesAll,
    this.aiTimeout = const Duration(seconds: 10),
    this.aiBatchSize = 10,
  }) : _now = now ?? DateTime.now,
       _offsetMinutesAt = offsetMinutesAt ?? _deviceOffsetMinutes,
       _parseAll = parseAll ?? parseInIsolate,
       _candidatesAll = candidatesAll ?? candidatesInIsolate;

  /// The app's scanner: the look-back is 30 days unless a debug build was given
  /// `--dart-define=SMS_LOOKBACK_DAYS=<n>`. [releaseMode] is injectable so a
  /// test can pin that a release build ignores it.
  factory SmsScanner.forApp({
    required SmsService service,
    required SmsSuggestionRepository repository,
    required SettingsRepository settings,
    OnDeviceAiService ai = const NoOnDeviceAi(),
    DateTime Function()? now,
    bool releaseMode = kReleaseMode,
    String lookbackDefine = const String.fromEnvironment('SMS_LOOKBACK_DAYS'),
  }) => SmsScanner(
    service: service,
    repository: repository,
    settings: settings,
    ai: ai,
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
  final OnDeviceAiService _ai;
  final SmsParser _parser;
  final SmsCandidatesAll _candidatesAll;

  /// How long the model may take for one SMS; then the regex reads it. The
  /// model answered in about 0.7 s on the Pixel 11 Pro.
  final Duration aiTimeout;

  /// The model's rows are written every this many SMS, with the cursor, so a
  /// kill loses at most this many parses.
  final int aiBatchSize;

  /// A pass that stopped on `busy` before the model answered anything, this
  /// many scans in a row, makes the next scan read with the regex: a model that
  /// stays busy must not keep the SMS from ever being read. Counted in memory;
  /// a restart tries the model again.
  static const busyStopsBeforeRegex = 3;

  /// How far back a scan may read, and the purge's age: always 30 in a release
  /// build.
  final int lookbackDays;

  /// The most inbox rows one scan handles: the rest next time.
  final int readLimit;

  /// The cursor stays this far behind the scan's start: an SMS the provider
  /// stores a little after its `date` is still read next time.
  static const cursorLag = Duration(minutes: 10);

  Future<ScanResult>? _running;
  bool _closed = false;

  /// The rows the last scan handled from its new cursor on: the next scan reads
  /// them again (the lag), and only stored ones are known to the database.
  /// Without this, a non-candidate or a row dropped for its reference would be
  /// parsed again at every open within the lag. Keys only (a hash, never the
  /// text), in memory: after a restart such a row is parsed once more.
  Set<SmsKey> _handled = {};

  /// [pause] was called during this scan.
  bool _pauseRequested = false;

  /// Passes in a row that stopped on `busy` with no answer
  /// ([busyStopsBeforeRegex]).
  int _busyStops = 0;

  final _progress = ValueNotifier<ScanProgress?>(null);

  /// The model's pass, while one runs; null otherwise (a regex scan takes
  /// about a second and shows no count).
  ValueListenable<ScanProgress?> get progress => _progress;

  /// Completes when no scan runs: the backup waits on it.
  Future<void> get idle => _running ?? Future<void>.value();

  /// Whether a scan runs now.
  bool get isScanning => _running != null;

  /// Stops scanning: a running scan writes nothing more, and later calls return
  /// [ScanOutcome.closed] (a restore is about to swap the database).
  void close() => _closed = true;

  /// Stops the model's pass after the SMS it is reading (the app left the
  /// front): the scan ends [ScanOutcome.stopped]. Nothing happens when no scan
  /// runs.
  void pause() {
    if (_running != null) _pauseRequested = true;
  }

  /// One scan at a time: a call while one runs gets that one's result.
  ///
  /// [useAi]: the on-device model reads the candidates: the user's switch is on
  /// and the model is in. `SmsCubit` decides, from the status it has just read
  /// for Settings, so AICore is asked once per scan. [categories] are the ones
  /// the model may pick from: the user's, with the names they see; read only
  /// when the model has SMS to read.
  Future<ScanResult> scan({
    bool useAi = false,
    Future<List<CategoryName>> Function() categories = _noCategories,
  }) {
    if (_closed) return Future.value((outcome: ScanOutcome.closed, added: 0));
    return _running ??= _scan(useAi: useAi, categories: categories)
        .whenComplete(() {
          _running = null;
          _progress.value = null;
        });
  }

  static Future<List<CategoryName>> _noCategories() async => const [];

  Future<ScanResult> _scan({
    required bool useAi,
    required Future<List<CategoryName>> Function() categories,
  }) async {
    _pauseRequested = false;
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
      if (useAi) {
        final stored = await _storeWithAi(
          inbox,
          since: since,
          startMs: start,
          categories: categories,
        );
        return switch (stored) {
          null => _result(ScanOutcome.closed),
          (:final added, stopped: true) => (
            outcome: ScanOutcome.stopped,
            added: added,
          ),
          (:final added, stopped: false) => (
            outcome: ScanOutcome.done,
            added: added,
          ),
        };
      }
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

  /// The parse and store steps for [inbox] (oldest first). Null when closed
  /// before the write.
  Future<int?> _store(
    List<InboxSms> inbox, {
    required int since,
    required int startMs,
  }) async {
    final hashed = _hashedOf(inbox);
    final fresh = await _freshOf(hashed);
    final parses = fresh.isEmpty
        ? const <SmsParse?>[]
        : await _parseAll([for (final r in fresh) (r.sms.sender, r.sms.body)]);
    final rows = [
      for (final (i, row) in fresh.indexed)
        if (parses[i] case final parse?) _rowOf(row, parse),
    ];
    if (_closed) return null;
    final cursor = _cursorAfter(inbox, since: since, startMs: startMs);
    final added = await _repository.insertScanned(rows, cursorMs: cursor);
    _rememberHandled(hashed, cursor: cursor);
    return added;
  }

  /// The parse and store steps with the on-device model: the candidates one at a time,
  /// oldest first; the model's answer if [acceptAiResult] takes it, else the
  /// regex. Written every [aiBatchSize] SMS with the cursor up to the last one
  /// read. Null when closed before a write. `stopped` when the pass ended
  /// early: the cursor then stays at the SMS not read, which the next scan
  /// reads first.
  Future<({int added, bool stopped})?> _storeWithAi(
    List<InboxSms> inbox, {
    required int since,
    required int startMs,
    required Future<List<CategoryName>> Function() categories,
  }) async {
    final hashed = _hashedOf(inbox);
    final fresh = await _freshOf(hashed);
    final candidate = fresh.isEmpty
        ? const <bool>[]
        : await _candidatesAll([
            for (final r in fresh) (r.sms.sender, r.sms.body),
          ]);
    final todo = [
      for (final (i, row) in fresh.indexed)
        if (candidate[i]) row,
    ];
    // After [busyStopsBeforeRegex] busy stops in a row, this scan reads
    // with the regex; the next one asks the model again.
    var askModel = _busyStops < busyStopsBeforeRegex;
    final names = askModel && todo.isNotEmpty
        ? await categories()
        : const <CategoryName>[];
    var busyStop = false;
    var rows = <NewSmsSuggestion>[];
    var added = 0;
    var answered = 0;
    var modelMs = 0;
    _Hashed? stoppedAt;
    _progress.value = (done: 0, total: todo.length);
    for (final (done, row) in todo.indexed) {
      if (_closed) return null;
      if (askModel && _pauseRequested) {
        stoppedAt = row;
        break;
      }
      NewSmsSuggestion? stored;
      if (askModel) {
        if (buildAiPrompt(row.sms.body, names) case final prompt?) {
          final watch = Stopwatch()..start();
          final reply = await _ai.prompt(prompt, timeout: aiTimeout);
          modelMs += watch.elapsedMilliseconds;
          switch (reply) {
            case AiAnswer(:final text):
              answered++;
              if (acceptAiResult(text, row.sms.body, names) case final ai?) {
                stored = _aiRowOf(row, ai);
              }
            case AiRefused(:final error) when error.stopsPass:
              busyStop = error == AiError.busy && answered == 0;
              stoppedAt = row;
            case AiRefused(error: AiError.quota):
              askModel = false;
            case AiRefused():
              break;
          }
          if (stoppedAt != null) break;
        }
      }
      if (stored == null) {
        if (_parser.parse(row.sms.body) case final parse?) {
          stored = _rowOf(row, parse);
        }
      }
      if (stored != null) rows.add(stored);
      _progress.value = (done: done + 1, total: todo.length);
      if ((done + 1) % aiBatchSize == 0 && done + 1 < todo.length) {
        if (_closed) return null;
        added += await _repository.insertScanned(
          rows,
          cursorMs: _cursorAt(row.sms, since: since, startMs: startMs),
        );
        rows = [];
      }
    }
    if (_closed) return null;
    final cursor = stoppedAt == null
        ? _cursorAfter(inbox, since: since, startMs: startMs)
        : _cursorAt(stoppedAt.sms, since: since, startMs: startMs);
    added += await _repository.insertScanned(rows, cursorMs: cursor);
    _rememberHandled(
      stoppedAt == null ? hashed : hashed.takeWhile((r) => r != stoppedAt),
      cursor: cursor,
    );
    // Any other end (an answer, another stop, the regex) breaks the row.
    _busyStops = busyStop ? _busyStops + 1 : 0;
    // Counts and times only, never a text.
    debugPrint(
      'SMS scan: ${todo.length} candidates, $answered answered by the '
      'on-device model in ${answered == 0 ? 0 : modelMs ~/ answered} ms '
      'each${stoppedAt == null ? '' : ', stopped'}',
    );
    return (added: added, stopped: stoppedAt != null);
  }

  List<_Hashed> _hashedOf(List<InboxSms> inbox) => [
    for (final sms in inbox) (sms: sms, sha: _sha256(sms.body)),
  ];

  /// The rows of [hashed] neither stored nor handled by the last scan: an SMS
  /// is parsed once.
  Future<List<_Hashed>> _freshOf(List<_Hashed> hashed) async {
    final known = hashed.isEmpty
        ? const <SmsKey>{}
        : await _repository.existingKeys(
            fromMs: hashed.first.sms.receivedAtMs,
            toMs: hashed.last.sms.receivedAtMs,
          );
    return [
      for (final row in hashed)
        if (!known.contains(_keyOf(row)) && !_handled.contains(_keyOf(row)))
          row,
    ];
  }

  /// The next scan reads again from [cursor]; what it would find there was
  /// handled now ([handled]: the rows read, up to where a pass stopped).
  void _rememberHandled(Iterable<_Hashed> handled, {required int cursor}) {
    _handled = {
      for (final row in handled)
        if (row.sms.receivedAtMs >= cursor) _keyOf(row),
    };
  }

  static SmsKey _keyOf(_Hashed row) => (
    sender: row.sms.sender,
    receivedAtMs: row.sms.receivedAtMs,
    bodySha256: row.sha,
  );

  NewSmsSuggestion _rowOf(_Hashed row, SmsParse parse) => NewSmsSuggestion(
    sender: row.sms.sender,
    receivedAtMs: row.sms.receivedAtMs,
    utcOffsetMinutes: _offsetMinutesAt(row.sms.receivedAtMs),
    bodySha256: row.sha,
    amountMinor: parse.amountMinor,
    paymentMethodKey: parse.paymentMethodKey,
    payee: parse.payee,
    reference: parse.reference,
  );

  /// The model's amount, payment method (when one of the three), title and
  /// category; the regex's reference (the duplicate check) and payee (one payee
  /// key per payee for the learning; the model's only when the regex has none).
  NewSmsSuggestion _aiRowOf(_Hashed row, AiParse ai) {
    final details = _parser.details(row.sms.body);
    return NewSmsSuggestion(
      sender: row.sms.sender,
      receivedAtMs: row.sms.receivedAtMs,
      utcOffsetMinutes: _offsetMinutesAt(row.sms.receivedAtMs),
      bodySha256: row.sha,
      amountMinor: ai.amountMinor,
      paymentMethodKey: ai.paymentMethodKey ?? details.paymentMethodKey,
      payee: details.payee ?? ai.payee,
      reference: details.reference,
      parsedBy: SmsParsedBy.ai,
      aiTitle: ai.title,
      aiCategoryId: ai.categoryId,
    );
  }

  /// Where the next scan starts:
  ///
  /// - a full read ([readLimit] rows): the newest row handled, so the rest
  ///   comes next time (rows at that same ms are read again and skipped);
  /// - otherwise everything up to now was handled: the scan's start minus
  ///   [cursorLag], never before [since].
  ///
  /// The doc says "the older of the newest handled and start − 10 min" in both
  /// cases; that re-reads days of non-candidates at every open when the newest
  /// SMS is old.
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

  /// Where the next scan starts when this one wrote or stopped at [sms]: that
  /// SMS, so it is read again, but never past [cursorLag] behind the start (an
  /// SMS stored late, dated before it, is still read), never before [since].
  int _cursorAt(InboxSms sms, {required int since, required int startMs}) =>
      max(since, min(sms.receivedAtMs, startMs - cursorLag.inMilliseconds));

  static ScanResult _result(ScanOutcome outcome) =>
      (outcome: outcome, added: 0);

  static String _sha256(String body) =>
      sha256.convert(utf8.encode(body)).toString();

  static int _deviceOffsetMinutes(int epochMs) =>
      DateTime.fromMillisecondsSinceEpoch(epochMs).timeZoneOffset.inMinutes;
}

/// The look-back a build uses: [define] (`SMS_LOOKBACK_DAYS`) in a debug or
/// profile build when it is a whole number from 1 to 3650; otherwise, and
/// always in a release build, [smsLookbackDays].
int lookbackDaysFor({required bool releaseMode, required String define}) {
  if (releaseMode) return smsLookbackDays;
  final days = int.tryParse(define.trim());
  return days != null && days >= 1 && days <= 3650 ? days : smsLookbackDays;
}

/// [SmsParseAll] in a background isolate: the parser is pure, and a few
/// thousand regex runs shouldn't cost frames.
Future<List<SmsParse?>> parseInIsolate(List<(String, String)> messages) =>
    Isolate.run(() => parseAllNow(messages));

/// [SmsCandidatesAll] in a background isolate: the check runs a few regexes
/// on each of up to 2,000 rows.
Future<List<bool>> candidatesInIsolate(List<(String, String)> messages) =>
    Isolate.run(() => candidatesNow(messages));

/// [SmsCandidatesAll]'s work, on this isolate, with [parser].
List<bool> candidatesNow(
  List<(String, String)> messages, {
  SmsParser parser = const IndiaSmsParser(),
}) => [
  for (final (sender, body) in messages) parser.isDebitCandidate(sender, body),
];

/// [SmsParseAll]'s work, on this isolate, with [parser] (India's banks:
/// the only ones read for now).
List<SmsParse?> parseAllNow(
  List<(String, String)> messages, {
  SmsParser parser = const IndiaSmsParser(),
}) => [
  for (final (sender, body) in messages)
    parser.isDebitCandidate(sender, body) ? parser.parse(body) : null,
];
