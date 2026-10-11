import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/data_version.dart';
import '../../../../data/repositories/report_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/dashboard_options.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/report.dart';
import '../../../../domain/report_document.dart';
import '../../../../domain/report_filter.dart';
import '../../../../domain/report_range.dart';
import '../../../../domain/trend.dart' show initialChartCurrency;
import '../../../core/emit_if_open.dart';

enum ReportPhase { loading, loaded, failed }

/// Categories, events and payment methods deleted since they were chosen
/// in the filter, dropped from it at a load (R11, P8-26). The items are
/// those the screen last knew (named in the UI, in its language); [count]
/// says how many were dropped, also when none was known (right after a
/// start). A new object each time, so the screen says it once.
final class FilterChangedNotice {
  FilterChangedNotice({
    required this.count,
    this.categories = const [],
    this.events = const [],
    this.methods = const [],
  });

  final int count;
  final List<Category> categories;
  final List<Event> events;
  final List<PaymentMethod> methods;

  /// How many of the [count] are known by name.
  int get known => categories.length + events.length + methods.length;
}

/// The Reports screen's state (phase-8.md §7.1, owner 2026-10-10). The
/// period, filter and card show in every phase; [report] only when
/// loaded.
final class ReportState {
  const ReportState({
    required this.phase,
    required this.range,
    required this.filter,
    required this.face,
    required this.faces,
    required this.currency,
    required this.today,
    this.report,
    this.data,
    this.selected,
    this.notice,
  });

  final ReportPhase phase;
  final ReportRange range;
  final ReportFilter filter;

  /// The card's face, one of [faces].
  final ReportChart face;

  /// The faces, in reel order: bars and the donut (owner, 2026-10-11:
  /// no setting).
  final List<ReportChart> faces;

  /// The carousel's currency.
  final String currency;

  /// The device's local date when loaded.
  final String today;

  /// Null until loaded.
  final Report? report;

  /// The rows and the name maps the [report] was built from.
  final ReportData? data;

  /// A tapped slice or bar (its index on the face), or null.
  final int? selected;

  /// Set by a load that dropped deleted ids from the filter.
  final FilterChangedNotice? notice;

  /// The carousel's pages: the report's currencies, or the current one
  /// when it has none.
  List<String> get currencies {
    final codes = report?.currencies ?? const <String>[];
    return codes.isEmpty ? [currency] : codes;
  }

  ReportState copyWith({
    ReportPhase? phase,
    ReportRange? range,
    ReportFilter? filter,
    ReportChart? face,
    List<ReportChart>? faces,
    String? currency,
    String? today,
    Report? report,
    ReportData? data,
    int? Function()? selected,
    FilterChangedNotice? Function()? notice,
  }) => ReportState(
    phase: phase ?? this.phase,
    range: range ?? this.range,
    filter: filter ?? this.filter,
    face: face ?? this.face,
    faces: faces ?? this.faces,
    currency: currency ?? this.currency,
    today: today ?? this.today,
    report: report ?? this.report,
    data: data ?? this.data,
    selected: selected == null ? this.selected : selected(),
    notice: notice == null ? this.notice : notice(),
  );
}

/// The Reports tab (phase-8.md §7.1, owner 2026-10-10): the range, the
/// filter and the card, an overview by category; the Generate sheet's
/// options ([exportOptions]). Reads through [ReportRepository];
/// writes nothing but its own remembered settings (§4), each method
/// returning that write for the screen to report a failure
/// (`saveOrShowError`), as Home's period.
class ReportCubit extends CubitSignal<ReportState>
    with EmitIfOpen<ReportState> {
  ReportCubit({
    required this._reports,
    required this._settings,
    required this._dataVersion,
    required this._now,
    required this._defaultCurrency,
    required this._weekStart,
  }) : super(
         initialState: ReportState(
           phase: ReportPhase.loading,
           range: currentRange(ReportPeriod.month, todayOn(_now()), _weekStart),
           filter: ReportFilter.none,
           face: ReportChart.bars,
           faces: ReportChart.values,
           currency: _defaultCurrency,
           today: todayOn(_now()),
         ),
       );

  final ReportRepository _reports;
  final SettingsRepository _settings;
  final DataVersion _dataVersion;
  final DateTime Function() _now;
  String _defaultCurrency;
  WeekStart _weekStart;

  /// The custom range the Range dialog starts from: the saved one, or
  /// null for [defaultCustomRange].
  ReportRange? _customRange;

  /// [DataVersion] when the last load read.
  int? _loadedVersion;

  /// Bumped by every load, so a late result can't replace a newer one.
  int _generation = 0;

  /// The Generate sheet's options, remembered (owner, 2026-10-10).
  ReportExportOptions get exportOptions => _exportOptions;
  ReportExportOptions _exportOptions = const ReportExportOptions();

  /// Remembers the Generate sheet's options.
  Future<void> setExportOptions(ReportExportOptions options) async {
    if (options == _exportOptions) return;
    _exportOptions = options;
    await _settings.setReportExportOptions(options);
  }

  /// The custom range the Range dialog opens on (P8-4).
  ReportRange get customRange =>
      _customRange ?? defaultCustomRange(todayOn(_now()));

  /// Reads the remembered period, range, filter, face and options, then
  /// loads. Week / Month / Year open on the current one; Range on its
  /// saved dates (or the last 12 months).
  Future<void> start() async {
    try {
      final (:prefs, :filterUnreadable) = await _settings.loadReport();
      if (filterUnreadable) {
        debugPrint('The remembered report filter was unreadable: none used');
      }
      _customRange = prefs.range;
      _exportOptions = prefs.export;
      final today = todayOn(_now());
      final range = prefs.period == ReportPeriod.range
          ? customRange
          : currentRange(prefs.period, today, _weekStart);
      final state = value;
      emitIfOpen(
        state.copyWith(
          range: range,
          filter: prefs.filter,
          face: state.faces.contains(prefs.chart)
              ? prefs.chart
              : state.faces.first,
          today: today,
        ),
      );
    } catch (error) {
      // The defaults are fine to show: nothing is lost by not reading them.
      debugPrint('Reading the report settings failed: $error');
    }
    await load();
  }

  /// Reads the range's rows for the filter and builds the report. Ids of
  /// deleted categories, events or payment methods are dropped from the
  /// filter first, said once ([ReportState.notice]) and the filter saved
  /// without them (R11).
  Future<void> load() => _latest = _load();

  /// The newest [load]; [settled] waits for it.
  Future<void>? _latest;

  /// Done once no load is running: the latest one, and any it started
  /// (a pruned filter reads again) or that began meanwhile (a resume).
  Future<void> settled() async {
    Future<void>? waited;
    while (!identical(_latest, waited)) {
      waited = _latest;
      await waited;
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final version = _dataVersion.value;
    final start = value;
    emitIfOpen(start.copyWith(phase: ReportPhase.loading));
    try {
      final watch = Stopwatch()..start();
      final data = await _reports.read(
        start.range,
        start.filter.withoutText,
        withDescriptions: start.filter.base.hasText,
      );
      // Timed on the Oppo (phase-8.md §12a); also a hint in a bug report.
      debugPrint(
        'Report read: ${data.rows.length} rows in ${watch.elapsedMilliseconds} ms',
      );
      if (generation != _generation || isClosed) return;
      final state = value;
      final pruned = state.filter.withoutMissing(
        categories: data.categories.keys.toSet(),
        events: data.events.keys.toSet(),
        methods: data.paymentMethods.keys.toSet(),
      );
      final dropped =
          pruned.categories.length +
          pruned.events.length +
          pruned.methods.length;
      if (dropped > 0) {
        _saveQuietly(() => _settings.setReportFilter(pruned.filter));
        emitIfOpen(
          state.copyWith(
            filter: pruned.filter,
            notice: () => _notice(state.data, pruned, dropped),
          ),
        );
        // The rows were read for the old filter: with every chosen event
        // (or category, method) gone, the pruned one lets more through.
        await load();
        return;
      }
      _loadedVersion = version;
      emitIfOpen(
        _built(
          state.copyWith(
            phase: ReportPhase.loaded,
            data: data,
            today: todayOn(_now()),
            selected: () => null,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Loading the report failed: $error');
      if (generation != _generation) return;
      emitIfOpen(value.copyWith(phase: ReportPhase.failed));
    }
  }

  /// Week / Month / Year: the current one. Range goes through the dialog
  /// and [setCustomRange].
  Future<void> setPeriod(ReportPeriod period) async {
    assert(period != ReportPeriod.range, 'Range comes from the dialog');
    final range = currentRange(period, todayOn(_now()), _weekStart);
    _setRange(range);
    await _settings.setReportPeriod(period);
  }

  /// ‹ (negative) or › (positive), within the bounds.
  void step(int steps) {
    final range = value.range;
    if (!canStep(range, steps, _weekStart)) return;
    _setRange(stepRange(range, steps, _weekStart));
  }

  /// A tap on the period's name: back to the current week, month or year.
  void backToCurrent() {
    final range = value.range;
    if (range.period == ReportPeriod.range) return;
    final current = currentRange(range.period, todayOn(_now()), _weekStart);
    if (current != range) _setRange(current);
  }

  /// The Range dialog's Show: From … To, or All time. Remembered with the
  /// period in one write (the screen opens on it next time).
  Future<void> setCustomRange(ReportRange range) async {
    assert(range.period == ReportPeriod.range, 'a custom range');
    if (!range.isAllTime) {
      final problem = checkCustomRange(range.from!, range.to!);
      if (problem != null) {
        throw ArgumentError.value(range, 'range', '$problem');
      }
    }
    _customRange = range;
    _setRange(range);
    await _settings.setReportCustomRange(range);
  }

  void _setRange(ReportRange range) {
    if (range == value.range && value.phase != ReportPhase.failed) return;
    emitIfOpen(value.copyWith(range: range, selected: () => null));
    load();
  }

  /// A new filter (the sheet closed, a chip's ✕, Clear filters). Text is
  /// trimmed (only whitespace is none). Saved; the same filter does
  /// nothing.
  Future<void> setFilter(ReportFilter filter) async {
    final words = searchWords(filter.base.text);
    final cleaned = filter.copyWith(
      base: filter.base.copyWith(
        text: words.isEmpty ? '' : filter.base.text.trim(),
      ),
    );
    if (cleaned == value.filter) return;
    emitIfOpen(value.copyWith(filter: cleaned, selected: () => null));
    final loading = load();
    await _settings.setReportFilter(cleaned);
    await loading;
  }

  /// Swiped [steps] faces through the enabled ones, wrapping. Returns the
  /// new face, for the screen to save.
  ReportChart turnFace(int steps) {
    final state = value;
    final faces = state.faces;
    final index = faces.indexOf(state.face);
    final face = faces[(index + steps) % faces.length];
    if (face != state.face) {
      emitIfOpen(state.copyWith(face: face, selected: () => null));
    }
    return face;
  }

  /// Saves the face [turnFace] returned.
  Future<void> saveFace(ReportChart face) => _settings.setReportChart(face);

  /// The carousel: the next (1) or previous (-1) currency, wrapping.
  void moveCurrency(int direction) {
    final state = value;
    final pages = state.currencies;
    final index = pages.indexOf(state.currency);
    final next = pages[(index + direction) % pages.length];
    if (next == state.currency) return;
    emitIfOpen(state.copyWith(currency: next, selected: () => null));
  }

  /// A tapped slice, bar or point; again clears it.
  void select(int index) {
    final state = value;
    emitIfOpen(
      state.copyWith(selected: () => state.selected == index ? null : index),
    );
  }

  /// Midnight, or the app resumed: a week, month or year that held the
  /// day before follows today (on 1 Nov "October" becomes "November",
  /// P8-25); a stepped or custom range stays. Then reads if anything was
  /// written meanwhile.
  Future<void> newDay() async {
    final state = value;
    final today = todayOn(_now());
    final range = state.range;
    if (range.period != ReportPeriod.range &&
        holdsToday(range, state.today) &&
        !holdsToday(range, today)) {
      emitIfOpen(
        state.copyWith(
          range: currentRange(range.period, today, _weekStart),
          today: today,
          selected: () => null,
        ),
      );
      return load();
    }
    if (today != state.today) emitIfOpen(state.copyWith(today: today));
    await reloadIfChanged();
  }

  /// Reads again only if something was written since the last read (R5).
  Future<bool> reloadIfChanged() async {
    if (_dataVersion.value == _loadedVersion &&
        value.phase != ReportPhase.failed) {
      return false;
    }
    await load();
    return true;
  }

  /// Reorders the currencies; reads nothing.
  void setDefaultCurrency(String code) {
    if (code == _defaultCurrency) return;
    _defaultCurrency = code;
    if (value.data != null) emitIfOpen(_built(value));
  }

  /// A week now starts on another day: the current week moves.
  Future<void> setWeekStart(WeekStart weekStart) async {
    if (weekStart == _weekStart) return;
    _weekStart = weekStart;
    final range = value.range;
    if (range.period == ReportPeriod.week) {
      _setRange(currentRange(ReportPeriod.week, range.from!, weekStart));
    } else if (value.data != null) {
      emitIfOpen(_built(value));
    }
  }

  WeekStart get weekStart => _weekStart;

  /// [state] with its report rebuilt from its rows in memory, and the
  /// currency kept while the report has it, else the default, else the
  /// first (as Home's card).
  ReportState _built(ReportState state) {
    final data = state.data;
    if (data == null) return state;
    final report = buildReport(
      data.rows,
      range: state.range,
      filter: state.filter,
      // The card is an overview by category (owner, 2026-10-10); the
      // export groups its own way (ReportExportOptions).
      grouping: ReportGrouping.byCategory,
      defaultCurrency: _defaultCurrency,
    );
    final currency = report.currencies.contains(state.currency)
        ? state.currency
        : initialChartCurrency(report.currencies, _defaultCurrency);
    return state.copyWith(report: report, currency: currency);
  }

  /// What [previous] knew of the ids [pruned] dropped.
  static FilterChangedNotice _notice(
    ReportData? previous,
    ({
      ReportFilter filter,
      Set<int> categories,
      Set<int> events,
      Set<int> methods,
    })
    pruned,
    int count,
  ) => FilterChangedNotice(
    count: count,
    categories: [for (final id in pruned.categories) ?previous?.categories[id]],
    events: [for (final id in pruned.events) ?previous?.events[id]],
    methods: [for (final id in pruned.methods) ?previous?.paymentMethods[id]],
  );

  void _saveQuietly(Future<void> Function() write) {
    write().catchError((Object error) {
      debugPrint('Saving the report filter failed: $error');
    });
  }
}
