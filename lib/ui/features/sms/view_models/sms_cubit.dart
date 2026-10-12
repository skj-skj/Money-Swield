import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show ValueListenable, debugPrint;

import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/repositories/sms_suggestion_repository.dart';
import '../../../../data/services/on_device_ai_service.dart';
import '../../../../data/services/sms_scanner.dart';
import '../../../../data/services/sms_service.dart';
import '../../../../domain/models/sms_suggestion.dart' show ScanProgress;
import '../../../../domain/sms/sms_ai_prompt.dart';
import '../../../core/emit_if_open.dart';

/// Where SMS suggestions stand (phase-9a.md §7.1).
enum SmsAvailability {
  /// Not known yet (before the first status read): nothing shows.
  unknown,

  /// The build has no READ_SMS (play with `-PnoSms`, D11): no icon, no
  /// tile, no onboarding step.
  notBuilt,

  /// Built, not turned on.
  off,

  /// Turned on, but the permission is off now (taken away in Android's
  /// settings): the icon says so, the screen offers Allow / Open settings.
  needsPermission,

  on,
}

class SmsState {
  const SmsState({
    this.availability = SmsAvailability.unknown,
    this.pendingCount = 0,
    this.scanning = false,
    this.lastScanAt,
    this.scanVersion = 0,
    this.canAsk = true,
    this.aiStatus = AiStatus.unavailable,
    this.aiOn = true,
    this.aiDownloadStarted = false,
  });

  final SmsAvailability availability;

  /// Suggestions waiting: Home's badge.
  final int pendingCount;

  final bool scanning;

  /// When the last scan finished reading, for "Checked 14:05"; null
  /// before the first one in this run.
  final DateTime? lastScanAt;

  /// Bumped when a scan stored new suggestions: an open SMS screen
  /// reloads (P9a-42).
  final int scanVersion;

  /// Whether Android will still show its permission dialog; when not, only
  /// the app's settings page can grant it (P9a-30).
  final bool canAsk;

  /// The on-device model (phase-9b.md §7): always `unavailable` on foss,
  /// read without a channel call.
  final AiStatus aiStatus;

  /// The `sms_ai_parsing` setting (on by default).
  final bool aiOn;

  /// The user turned the AI on and its download was asked for in this run:
  /// "Downloading the model…" shows until the status says `available`.
  final bool aiDownloadStarted;

  /// Settings → SMS shows the AI switch (§8): a model in or one that can
  /// come, with SMS suggestions on. Never on foss.
  bool get showsAi =>
      aiStatus.canBeUsed &&
      (availability == SmsAvailability.on ||
          availability == SmsAvailability.needsPermission);

  /// The model is being fetched: Android's own download, or the one this
  /// run asked for.
  bool get aiDownloading =>
      aiStatus == AiStatus.downloading ||
      (aiDownloadStarted && aiStatus != AiStatus.available);

  /// The switch's position: on when the setting is on and the model is in
  /// or coming. A `downloadable` model shows off though the setting is on
  /// (the default): the app never downloads it on its own (P9b-34), and a
  /// tap starts the download.
  bool get aiSwitchOn =>
      aiOn && (aiStatus == AiStatus.available || aiDownloading);

  /// A scan asks the model (phase-9b.md §6.2): the switch is on and the
  /// model is in; `downloadable` and `downloading` read with the regex
  /// (P9b-34), as does foss (`unavailable`).
  bool get aiReads => aiOn && aiStatus == AiStatus.available;

  /// The feature can be seen at all (Settings tile, onboarding step).
  bool get isBuilt =>
      availability != SmsAvailability.unknown &&
      availability != SmsAvailability.notBuilt;

  SmsState copyWith({
    SmsAvailability? availability,
    int? pendingCount,
    bool? scanning,
    DateTime? lastScanAt,
    int? scanVersion,
    bool? canAsk,
    AiStatus? aiStatus,
    bool? aiOn,
    bool? aiDownloadStarted,
  }) => SmsState(
    availability: availability ?? this.availability,
    pendingCount: pendingCount ?? this.pendingCount,
    scanning: scanning ?? this.scanning,
    lastScanAt: lastScanAt ?? this.lastScanAt,
    scanVersion: scanVersion ?? this.scanVersion,
    canAsk: canAsk ?? this.canAsk,
    aiStatus: aiStatus ?? this.aiStatus,
    aiOn: aiOn ?? this.aiOn,
    aiDownloadStarted: aiDownloadStarted ?? this.aiDownloadStarted,
  );

  @override
  bool operator ==(Object other) =>
      other is SmsState &&
      other.availability == availability &&
      other.pendingCount == pendingCount &&
      other.scanning == scanning &&
      other.lastScanAt == lastScanAt &&
      other.scanVersion == scanVersion &&
      other.canAsk == canAsk &&
      other.aiStatus == aiStatus &&
      other.aiOn == aiOn &&
      other.aiDownloadStarted == aiDownloadStarted;

  @override
  int get hashCode => Object.hash(
    availability,
    pendingCount,
    scanning,
    lastScanAt,
    scanVersion,
    canAsk,
    aiStatus,
    aiOn,
    aiDownloadStarted,
  );
}

/// What [SmsCubit.enable] did, for the screen's message.
enum SmsEnableResult {
  /// On, and a scan started.
  enabled,

  /// The user refused: stays off, with the message of §8.7.
  refused,

  /// Android won't ask any more: the app's settings page was opened.
  openedSettings,

  /// The build has no SMS.
  notBuilt,
}

/// App-level SMS state (phase-9a.md §7.1): created by the shell, given to
/// Home, Settings and the backup screen. Scans when the app opens and when
/// it comes back to the front, at most once a minute (P9a-13).
class SmsCubit extends CubitSignal<SmsState> with EmitIfOpen<SmsState> {
  SmsCubit({
    required this._service,
    required this._scanner,
    required this._repository,
    required this._settings,
    this._ai = const NoOnDeviceAi(),
    Future<List<CategoryName>> Function()? categoryNames,
    DateTime Function()? now,
    this.minScanInterval = const Duration(seconds: 60),
  }) : _categoryNames = categoryNames ?? _noCategories,
       _now = now ?? DateTime.now,
       super(initialState: const SmsState());

  final SmsService _service;
  final SmsScanner _scanner;
  final SmsSuggestionRepository _repository;
  final SettingsRepository _settings;
  final OnDeviceAiService _ai;

  /// The user's categories with the names they see (R16): the UI builds
  /// them (built-ins are localized), the scan passes them to the model.
  final Future<List<CategoryName>> Function() _categoryNames;
  final DateTime Function() _now;
  final Duration minScanInterval;

  static Future<List<CategoryName>> _noCategories() async => const [];

  /// The last scan's model pass stopped early (the app left the front,
  /// AICore busy): the next [resumed] scans at once, not after a minute,
  /// so the rest is read as soon as the app is back (P9b-40).
  bool _stoppedEarly = false;

  /// When the last scan started; null before the first.
  DateTime? _lastScanStart;

  /// [enable] sent the user to Android's settings to allow SMS.
  bool _enableWhenGranted = false;

  /// After the first frame (application-design §3 step 6).
  Future<void> start() => _scanIfDue(force: true);

  /// The app came back to the front: the permission may have changed in
  /// Android's settings, and new SMS may have come.
  Future<void> resumed() => _scanIfDue(force: _stoppedEarly);

  /// The app left the front (phase-9b.md §6.2 step 4): the model refuses
  /// background calls, so its pass stops after the SMS it is reading, and
  /// [resumed] goes on from there.
  void paused() => _scanner.pause();

  /// The model's progress while a scan with it runs (the backup's "SMS 12
  /// of 40", §6.2).
  ValueListenable<ScanProgress?> get scanProgress => _scanner.progress;

  /// The AI switch (§8). On: the setting is written, and a model that is
  /// `downloadable` starts downloading (P9b-34: only now, never on its own).
  /// Off: the regex reads everything from the next scan on; a download
  /// already running isn't stopped (AICore's, not the app's).
  Future<void> setAiParsing(bool on) async {
    await _settings.setSmsAiParsing(on);
    emitIfOpen(value.copyWith(aiOn: on));
    // A second tap while the first download runs (off, on again) starts
    // none: one download at a time.
    if (on &&
        value.aiStatus == AiStatus.downloadable &&
        !value.aiDownloadStarted) {
      _download();
    }
  }

  /// Starts the download and, when it ends, reads the status again; a model
  /// that is in by then is used from the next scan on. Not awaited: on some
  /// phones it never answers (phase-9b.md §12a), and the screen shows
  /// "Downloading the model…" meanwhile.
  void _download() {
    emitIfOpen(value.copyWith(aiDownloadStarted: true));
    unawaited(
      _ai.download().then((_) async {
        if (isClosed) return;
        // Done or failed: the status says which.
        final status = await _ai.status();
        emitIfOpen(value.copyWith(aiStatus: status, aiDownloadStarted: false));
      }),
    );
  }

  /// The SMS screen closed, or Home shows again.
  Future<void> refreshCount() async {
    try {
      final count = await _repository.pendingCount();
      emitIfOpen(value.copyWith(pendingCount: count));
    } catch (error) {
      debugPrint('Counting SMS suggestions failed: $error');
    }
  }

  /// Turns SMS suggestions on (onboarding, Settings, the screen's Allow):
  /// asks for the permission when it isn't granted; granted → on and a
  /// scan. Refused → stays off. When Android won't ask any more, the app's
  /// settings page opens instead (P9a-30); [resumed] picks up the answer.
  Future<SmsEnableResult> enable() async {
    final permission = await _service.status();
    if (!permission.built) return SmsEnableResult.notBuilt;
    var granted = permission.granted;
    if (!granted) {
      if (!permission.canAsk) {
        // `sms_enabled` is written only once the permission is granted
        // (database.md §3.1): [resumed] turns it on if the user allows it
        // on the settings page, so they needn't tap the switch again.
        _enableWhenGranted = true;
        await _service.openSettings();
        await _readAvailability();
        return SmsEnableResult.openedSettings;
      }
      granted = await _service.request();
    }
    if (!granted) {
      await _readAvailability();
      return SmsEnableResult.refused;
    }
    await _settings.setSmsEnabled(true);
    await _scanIfDue(force: true);
    return SmsEnableResult.enabled;
  }

  /// Turns them off: no more scans; the stored suggestions stay until the
  /// 30-day purge (P9a-29), and come back when turned on again.
  Future<void> disable() async {
    await _settings.setSmsEnabled(false);
    await _readAvailability();
  }

  /// The app's page in Android's settings (permission refused for good).
  Future<void> openSettings() => _service.openSettings();

  /// The scan running now, or null: the backup waits on it and shows that
  /// it does only then (§6.7).
  Future<void>? runningScan() => _scanner.isScanning ? _scanner.idle : null;

  Future<void> _scanIfDue({required bool force}) async {
    var now = force;
    if (_enableWhenGranted) {
      _enableWhenGranted = false;
      if ((await _service.status()).granted) {
        await _settings.setSmsEnabled(true);
        now = true;
      }
    }
    final available = await _readAvailability();
    if (available != SmsAvailability.on) {
      await refreshCount();
      return;
    }
    final last = _lastScanStart;
    final at = _now();
    if (!now && last != null && at.difference(last) < minScanInterval) {
      return;
    }
    _lastScanStart = at;
    emitIfOpen(value.copyWith(scanning: true));
    final result = await _scanner.scan(
      useAi: value.aiReads,
      categories: _categoriesOrNone,
    );
    _stoppedEarly = result.outcome == ScanOutcome.stopped;
    final count = await _countOr(value.pendingCount);
    emitIfOpen(
      value.copyWith(
        scanning: false,
        pendingCount: count,
        lastScanAt:
            result.outcome == ScanOutcome.done ||
                result.outcome == ScanOutcome.stopped
            ? _now()
            : null,
        scanVersion: result.added > 0 ? value.scanVersion + 1 : null,
      ),
    );
  }

  /// Reads the build, the setting and the permission into the state.
  Future<SmsAvailability> _readAvailability() async {
    try {
      final permission = await _service.status();
      final enabled = permission.built && await _settings.smsEnabled();
      final availability = !permission.built
          ? SmsAvailability.notBuilt
          : !enabled
          ? SmsAvailability.off
          : permission.granted
          ? SmsAvailability.on
          : SmsAvailability.needsPermission;
      emitIfOpen(
        value.copyWith(availability: availability, canAsk: permission.canAsk),
      );
      await _readAi();
      return availability;
    } catch (error) {
      // No channel (a test, a phone without the SMS provider): as if the
      // build had no SMS. Nothing is lost.
      debugPrint('Reading the SMS status failed: $error');
      emitIfOpen(value.copyWith(availability: SmsAvailability.notBuilt));
      return SmsAvailability.notBuilt;
    }
  }

  /// The model's status and the switch's setting into the state: the
  /// switch shows from it, and the next scan reads with the model from it.
  /// The status is a quick call to AICore on play, none on foss. A failure
  /// here reads as no model; SMS suggestions themselves go on.
  Future<void> _readAi() async {
    try {
      final status = await _ai.status();
      final on = await _settings.smsAiParsing();
      emitIfOpen(value.copyWith(aiStatus: status, aiOn: on));
    } catch (error) {
      debugPrint('Reading the on-device AI status failed: $error');
      emitIfOpen(value.copyWith(aiStatus: AiStatus.unavailable));
    }
  }

  /// The categories for the model; none when they can't be read (the scan
  /// then still runs: the model just picks no category).
  Future<List<CategoryName>> _categoriesOrNone() async {
    try {
      return await _categoryNames();
    } catch (error) {
      debugPrint('Reading categories for the SMS scan failed: $error');
      return const [];
    }
  }

  Future<int> _countOr(int fallback) async {
    try {
      return await _repository.pendingCount();
    } catch (error) {
      debugPrint('Counting SMS suggestions failed: $error');
      return fallback;
    }
  }
}
