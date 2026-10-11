import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/dashboard_options.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/report.dart';
import '../../../../domain/report_chart.dart';
import '../../../../domain/report_filter.dart';
import '../../../../domain/report_highlights.dart';
import '../../../../domain/report_range.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/money_formatter.dart';
import '../../../core/period_names.dart';
import '../../../core/widgets/filter/filter_sheet.dart';
import '../../../core/widgets/filter_chips.dart';
import '../../../core/widgets/retry_row.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/show_message.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/report_cubit.dart';
import '../view_models/report_export_cubit.dart';
import 'export_busy_dialog.dart';
import 'generate_sheet.dart';
import 'highlights_view.dart';
import 'range_dialog.dart';
import 'report_card.dart';
import 'report_texts.dart';

/// The Reports tab (phase-8.md §8.2, overhauled by the owner on
/// 2026-10-10): an overview, not a second Home. The period row, the
/// report's own filter (Home's sheet and chips), the card (categories as
/// bars or a donut), and **Generate report**: a sheet with the filter and
/// the export's options, which makes the PDF or Excel file. Reloads when
/// it shows again after a write elsewhere, on resume and at midnight.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.dependencies,
    required this.isVisible,
  });

  final AppDependencies dependencies;

  /// Whether this tab is the one shown (the shell keeps it alive).
  final bool isVisible;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final AppSettings _startSettings = context.read<SettingsCubit>().value;

  late final ReportCubit _cubit = ReportCubit(
    reports: widget.dependencies.reports,
    settings: widget.dependencies.settings,
    dataVersion: widget.dependencies.dataVersion,
    now: widget.dependencies.now,
    defaultCurrency: _startSettings.defaultCurrency,
    weekStart: _startSettings.weekStart,
  )..start();

  late final _export = ReportExportCubit(
    service: widget.dependencies.reportExports,
    now: widget.dependencies.now,
  );

  /// The screen's own messenger, so its snackbars stay on this tab.
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  BuildContext get _messengerContext => _scaffoldKey.currentContext ?? context;

  Timer? _midnight;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _newDay);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = widget.dependencies.now().toLocal();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), _newDay);
  }

  void _newDay() {
    if (!mounted) return;
    _cubit.newDay();
    _scheduleMidnight();
  }

  @override
  void didUpdateWidget(ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) _cubit.reloadIfChanged();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    _export
      ..cancel()
      ..close();
    _cubit.close();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  void _showMessage(String message, {SnackBarAction? action}) =>
      showMessage(_messenger.currentState, message, action: action);

  ReportTexts _texts(AppSettings settings) => ReportTexts(
    l10n: _l10n,
    dateLocale: dateLocaleOf(context),
    formatter: MoneyFormatter.of(context),
    names: PeriodNames.of(
      context,
      today: todayOn(widget.dependencies.now()),
      weekLabel: settings.weekLabel,
    ),
  );

  // --- Actions --------------------------------------------------------------

  Future<void> _pickPeriod(ReportPeriod period) async {
    if (period == ReportPeriod.range) return _openRange();
    await saveOrShowError(_messengerContext, () => _cubit.setPeriod(period));
  }

  /// The Range dialog: Show applies (and remembers); Cancel changes
  /// nothing, the segment stays where it was (§8.3).
  Future<void> _openRange() async {
    final settings = context.read<SettingsCubit>().value;
    final state = _cubit.value;
    final initial = state.range.period == ReportPeriod.range
        ? state.range
        : _cubit.customRange;
    final range = await showRangeDialog(
      context,
      initial: initial,
      // All time keeps no dates: the dialog's greyed ones are these.
      fallback: initial.isAllTime
          ? defaultCustomRange(todayOn(widget.dependencies.now()))
          : initial,
      texts: _texts(settings),
    );
    if (range == null || !mounted) return;
    await saveOrShowError(
      _messengerContext,
      () => _cubit.setCustomRange(range),
    );
  }

  Future<void> _openFilters(ReportState state) async {
    final data = state.data;
    if (data == null) return;
    final result = await showFilterSheet(
      context,
      filter: state.filter.base,
      categories: data.categories,
      events: data.events,
      paymentMethods: data.paymentMethods,
      paymentMethodIds: state.filter.paymentMethodIds,
    );
    if (!mounted) return;
    await _setFilter(
      ReportFilter(
        base: result.filter,
        paymentMethodIds: result.paymentMethodIds,
      ),
    );
  }

  Future<void> _setFilter(ReportFilter filter) =>
      saveOrShowError(_messengerContext, () => _cubit.setFilter(filter));

  void _turnCard(int steps) {
    final face = _cubit.turnFace(steps);
    saveOrShowError(_messengerContext, () => _cubit.saveFace(face));
  }

  /// What Other holds, largest first, with each one's amount and share
  /// (owner, 2026-10-10).
  Future<void> _openOther(ChartSlice other, String currency) {
    final state = _cubit.value;
    final report = state.report;
    final data = state.data;
    if (report == null || data == null) return Future.value();
    final texts = _texts(context.read<SettingsCubit>().value);
    final total = report.totals[currency]!.amount;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.reportOtherTitle),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            key: const ValueKey('reportOtherList'),
            shrinkWrap: true,
            children: [
              for (final g in other.others)
                ListTile(
                  title: Text(
                    texts.group(g, data),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _l10n.reportExpenseCount(g.byCurrency[currency]!.count),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        texts.amount(currency, g.byCurrency[currency]!.amount),
                      ),
                      Text(
                        texts.share(
                          sharePermille(g.byCurrency[currency]!.amount, total),
                          g.byCurrency[currency]!.amount,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  /// Generate report (owner, 2026-10-10): the sheet with the filter and
  /// the options. Its filter becomes the screen's however it closes (so
  /// the card shows what the file holds) and its options are remembered;
  /// with a button tapped, the file is made from the report as it then
  /// is, no other read: the busy dialog, then what happened (§8.8, §8.9).
  Future<void> _openGenerate() async {
    final state = _cubit.value;
    final data = state.data;
    if (data == null || _export.isWorking) return;
    final settings = context.read<SettingsCubit>().value;
    final choice = await showGenerateSheet(
      context,
      filter: state.filter.base,
      paymentMethodIds: state.filter.paymentMethodIds,
      options: _cubit.exportOptions,
      categories: data.categories,
      events: data.events,
      paymentMethods: data.paymentMethods,
      texts: _texts(settings),
    );
    if (!mounted) return;
    await saveOrShowError(
      _messengerContext,
      () => _cubit.setExportOptions(choice.options),
    );
    await _setFilter(
      ReportFilter(
        base: choice.filter,
        paymentMethodIds: choice.paymentMethodIds,
      ),
    );
    final action = choice.action;
    if (action == null || !mounted) return;
    // A read started meanwhile (a resume, a write elsewhere) finishes
    // first, so the file holds what the card then shows.
    await _cubit.settled();
    if (!mounted) return;
    final loaded = _cubit.value;
    final rows = loaded.data;
    if (loaded.phase != ReportPhase.loaded || rows == null) {
      return _showMessage(_l10n.reportLoadFailed);
    }
    final report = buildReport(
      rows.rows,
      range: loaded.range,
      filter: loaded.filter,
      grouping: choice.options.grouping,
      defaultCurrency: context.read<SettingsCubit>().value.defaultCurrency,
    );
    if (report.isEmpty) return _showMessage(_l10n.reportNothingToExport);
    // The route itself, not a context its builder hands out: a quick
    // export can finish before the dialog is first built, and then that
    // context would never be set and the dialog never closed.
    final navigator = Navigator.of(context);
    final busy = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExportBusyDialog(cubit: _export),
    );
    unawaited(navigator.push(busy));
    final outcome = await _export.export(
      options: choice.options,
      action: action,
      report: report,
      data: rows,
      texts: _texts(settings),
      weekStart: _cubit.weekStart,
    );
    if (busy.isActive) navigator.removeRoute(busy);
    if (outcome == null || !mounted) return;
    _showExportOutcome(outcome);
  }

  void _showExportOutcome(ExportOutcome outcome) {
    final l10n = _l10n;
    switch (outcome) {
      case ExportSaved():
        // Opened at once, no "Open" snackbar (owner, 2026-10-11); only
        // when nothing can open it does the screen say where it went.
        unawaited(_openSaved(outcome));
      case ExportSavedAs():
        _showMessage(l10n.reportSaved);
      case ExportShared() || ExportCancelledOutcome():
        break;
      case ExportFailed(:final reason):
        _showMessage(switch (reason) {
          ExportFailure.pdf => l10n.reportPdfFailed,
          ExportFailure.excel => l10n.reportExcelFailed,
          ExportFailure.tooManyRows => l10n.reportTooManyRows,
          ExportFailure.save => l10n.reportSaveFailed,
          ExportFailure.noShareTarget => l10n.reportNoShareTarget,
        });
    }
  }

  Future<void> _openSaved(ExportSaved saved) async {
    try {
      await _export.open(saved);
    } catch (error) {
      // NoAppForReport, or the viewer failed to start.
      debugPrint('Opening the report failed: $error');
      if (mounted) _showMessage(_l10n.reportSavedNoViewer);
    }
  }

  void _onNotice(BuildContext context, ReportState state) {
    final notice = state.notice;
    if (notice == null) return;
    final l10n = _l10n;
    final names = [
      for (final c in notice.categories) categoryName(l10n, c),
      for (final e in notice.events) eventName(l10n, e),
      for (final m in notice.methods) paymentMethodName(l10n, m),
    ];
    _showMessage(
      notice.count == 1 && names.length == 1
          ? l10n.reportFilterChanged(names.single)
          : l10n.reportFilterChangedMany(notice.count),
    );
  }

  /// The card follows the settings wherever they change.
  void _onSettings(BuildContext context, AppSettings settings) {
    _cubit
      ..setDefaultCurrency(settings.defaultCurrency)
      ..setWeekStart(settings.weekStart);
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) =>
      ScaffoldMessenger(key: _messenger, child: _scaffold(context));

  Widget _scaffold(BuildContext context) {
    final l10n = _l10n;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(l10n.navReports),
        actions: [
          BlocSignalBuilder<ReportCubit, ReportState>(
            bloc: _cubit,
            builder: (context, state) => IconButton(
              key: const ValueKey('reportFilterButton'),
              tooltip: l10n.filters,
              onPressed: state.data == null ? null : () => _openFilters(state),
              icon: Badge(
                isLabelVisible: !state.filter.isEmpty,
                smallSize: 8,
                child: const Icon(Icons.tune),
              ),
            ),
          ),
        ],
      ),
      body: BlocSignalListener<SettingsCubit, AppSettings>(
        listenWhen: (previous, current) =>
            previous.defaultCurrency != current.defaultCurrency ||
            previous.weekStart != current.weekStart,
        listener: _onSettings,
        child: BlocSignalListener<ReportCubit, ReportState>(
          bloc: _cubit,
          listenWhen: (previous, current) =>
              current.notice != null && current.notice != previous.notice,
          listener: _onNotice,
          child: BlocSignalBuilder<SettingsCubit, AppSettings>(
            buildWhen: (previous, current) =>
                previous.weekLabel != current.weekLabel ||
                previous.trendCardHaptics != current.trendCardHaptics,
            builder: (context, settings) =>
                BlocSignalBuilder<ReportCubit, ReportState>(
                  bloc: _cubit,
                  builder: (context, state) => _body(state, settings),
                ),
          ),
        ),
      ),
    );
  }

  /// The last Highlights and what they were made from: [highlightsOf]
  /// walks every row (50,000 at All time), and a tap on a bar or a swipe
  /// rebuilds the screen without changing them.
  ({Report report, String currency, String today, ReportHighlights? value})?
  _highlights;

  ReportHighlights? _highlightsFor(
    Report report,
    String currency,
    String today,
  ) {
    if (_highlights case final h?
        when identical(h.report, report) &&
            h.currency == currency &&
            h.today == today) {
      return h.value;
    }
    final value = highlightsOf(report, currency, today);
    _highlights = (
      report: report,
      currency: currency,
      today: today,
      value: value,
    );
    return value;
  }

  /// The period, the chips, the card and the Highlights scroll; Generate
  /// report is pinned at the bottom (owner, 2026-10-11).
  Widget _body(ReportState state, AppSettings settings) {
    final texts = _texts(settings);
    final ready =
        state.phase == ReportPhase.loaded && !(state.report?.isEmpty ?? true);
    final report = state.report;
    final data = state.data;
    final highlights = ready
        ? _highlightsFor(report!, state.currency, state.today)
        : null;
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            key: const ValueKey('reportScroll'),
            slivers: [
              SliverToBoxAdapter(child: _periodRow(state, texts)),
              if (!state.filter.isEmpty)
                SliverToBoxAdapter(child: _chips(state)),
              SliverToBoxAdapter(child: _card(state, texts)),
              if (highlights != null && data != null)
                SliverToBoxAdapter(
                  child: HighlightsView(
                    highlights: highlights,
                    currency: state.currency,
                    data: data,
                    texts: texts,
                  ),
                ),
              if (state.phase == ReportPhase.loaded &&
                  (report?.isEmpty ?? false) &&
                  !state.filter.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: TextButton(
                      key: const ValueKey('reportClearFilters'),
                      onPressed: () => _setFilter(ReportFilter.none),
                      child: Text(_l10n.clearFilters),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('reportGenerate'),
              // Disabled while empty, loading or failed (P8-24).
              onPressed: ready ? _openGenerate : null,
              icon: const Icon(Icons.description_outlined),
              label: Text(
                ready ? _l10n.reportGenerate : _l10n.reportNothingToExport,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(ReportState state, ReportTexts texts) => switch (state.phase) {
    ReportPhase.failed => Card(
      key: const ValueKey('reportCardFailed'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Center(
        child: RetryRow(message: _l10n.reportLoadFailed, onRetry: _cubit.load),
      ),
    ),
    _ when state.report == null || state.phase == ReportPhase.loading =>
      const Card(
        key: ValueKey('reportCardLoading'),
        margin: EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: SizedBox(
          height: 160,
          child: Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        ),
      ),
    _ => ReportCard(
      state: state,
      texts: texts,
      // The large card always (owner, 2026-10-11: no size setting;
      // the page has room).
      size: TrendCardSize.large,
      haptics: context.read<SettingsCubit>().value.trendCardHaptics,
      onTurn: _turnCard,
      onCurrency: _cubit.moveCurrency,
      onSelect: _cubit.select,
      onOther: _openOther,
    ),
  };

  /// Week / Month / Year / Range, then ‹ name › or the range with ✎.
  Widget _periodRow(ReportState state, ReportTexts texts) {
    final l10n = _l10n;
    final range = state.range;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ReportPeriod>(
            key: const ValueKey('reportPeriod'),
            showSelectedIcon: false,
            segments: [
              for (final p in ReportPeriod.values)
                ButtonSegment(
                  value: p,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_periodLabel(l10n, p)),
                  ),
                ),
            ],
            selected: {range.period},
            onSelectionChanged: (selection) => _pickPeriod(selection.single),
          ),
          if (range.period == ReportPeriod.range)
            // A tap on Range itself opens the dialog again (§8.3); the
            // segment doesn't fire for the selected one, so the row does.
            InkWell(
              key: const ValueKey('reportRangeRow'),
              onTap: _openRange,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        texts.rangeWithSpan(range, state.report?.span),
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      semanticLabel: l10n.reportChangeRange,
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                IconButton(
                  key: const ValueKey('reportPrevious'),
                  tooltip: l10n.previousPeriod,
                  onPressed: canStep(range, -1, _cubit.weekStart)
                      ? () => _cubit.step(-1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    onTapHint: l10n.reportBackToCurrent,
                    child: InkWell(
                      key: const ValueKey('reportRangeName'),
                      onTap: _cubit.backToCurrent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          texts.range(range),
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('reportNext'),
                  tooltip: l10n.nextPeriod,
                  onPressed: canStep(range, 1, _cubit.weekStart)
                      ? () => _cubit.step(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _periodLabel(AppLocalizations l10n, ReportPeriod period) =>
      switch (period) {
        ReportPeriod.week => periodName(l10n, Period.week),
        ReportPeriod.month => periodName(l10n, Period.month),
        ReportPeriod.year => periodName(l10n, Period.year),
        ReportPeriod.range => l10n.reportPeriodRange,
      };

  Widget _chips(ReportState state) {
    final data = state.data;
    final filter = state.filter;
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: filterChips(
            context,
            filter: filter.base,
            categories: data?.categories ?? const {},
            events: data?.events ?? const {},
            paymentMethodIds: filter.paymentMethodIds,
            paymentMethods: data?.paymentMethods ?? const {},
            onOpen: () => _openFilters(state),
            onChange: (base) => _setFilter(filter.copyWith(base: base)),
            onClearPaymentMethods: () =>
                _setFilter(filter.copyWith(paymentMethodIds: const {})),
          ),
        ),
      ),
    );
  }
}
