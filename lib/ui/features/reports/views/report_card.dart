import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/currency.dart';
import '../../../../domain/models/dashboard_options.dart';
import '../../../../domain/report.dart';
import '../../../../domain/report_chart.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/charts/donut_chart.dart';
import '../../../core/charts/group_palette.dart';
import '../../../core/widgets/reel_card.dart';
import '../view_models/report_cubit.dart';
import 'report_texts.dart';

/// The report card (owner 2026-10-10): the categories in one currency as bars
/// or a donut (no trend: a report is an overview), on Home's reel ([ReelCard]):
/// up / down through the enabled faces, left / right through the currencies.
/// Every face is as tall as the others, so the reel doesn't jump. A tap on
/// Other opens what it holds ([onOther]).
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.state,
    required this.texts,
    required this.size,
    required this.haptics,
    required this.onTurn,
    required this.onCurrency,
    required this.onSelect,
    required this.onOther,
  });

  final ReportState state;
  final ReportTexts texts;
  final TrendCardSize size;
  final CardHaptics haptics;
  final ValueChanged<int> onTurn;
  final ValueChanged<int> onCurrency;
  final ValueChanged<int> onSelect;

  /// Other was tapped: the groups it holds, in its currency.
  final void Function(ChartSlice other, String currency) onOther;

  /// Legend lines and bars per face: 5 groups and Other.
  static const rows = maxSlices;

  ReportChart _faceAt(int steps) {
    final faces = state.faces;
    return faces[(faces.indexOf(state.face) + steps) % faces.length];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = texts.l10n;
    final report = state.report!;
    final pages = state.currencies;
    final total = report.totals[state.currency]?.amount;
    final rangeName = texts.range(state.range);
    final amount = total == null
        ? _emptyText(l10n)
        : l10n.chartCurrencyAnnounce(
            findCurrency(state.currency)?.englishName ?? state.currency,
            texts.amount(state.currency, total),
          );
    return ReelCard(
      semanticsKey: const ValueKey('reportCard'),
      semanticsLabel: state.filter.isEmpty
          ? l10n.reportCardSemantics(rangeName, texts.face(state.face), amount)
          : l10n.reportCardSemanticsFiltered(
              rangeName,
              texts.face(state.face),
              amount,
            ),
      faceCount: state.faces.length,
      pageCount: pages.length,
      haptics: haptics,
      nextFaceLabel: l10n.nextChart,
      previousFaceLabel: l10n.previousChart,
      onTurn: onTurn,
      onPage: onCurrency,
      title: (context, steps) => _title(context, _faceAt(steps)),
      body: (context, steps, page) {
        final index = pages.indexOf(state.currency);
        final currency = pages[(index + page) % pages.length];
        return _Face(
          card: this,
          face: _faceAt(steps),
          currency: currency,
          isCurrent: steps == 0 && page == 0,
        );
      },
    );
  }

  Widget _title(BuildContext context, ReportChart face) {
    final theme = Theme.of(context);
    final l10n = texts.l10n;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  // What the chart shows, not the range: the period row
                  // right above already names it (found on the Oppo,
                  // 2026-10-10: "October 2026" twice). TalkBack still
                  // reads the range in the card's label.
                  l10n.reportDocGrouping(
                    texts.dimension(GroupDimension.category),
                  ),
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!state.filter.isEmpty) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.filter_alt,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    l10n.trendFiltered,
                    key: const ValueKey('reportFiltered'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (state.faces.length > 1)
          ReelDots(
            count: state.faces.length,
            current: state.faces.indexOf(face),
          ),
      ],
    );
  }

  String _emptyText(AppLocalizations l10n) {
    if (state.range.isAllTime && state.filter.isEmpty) {
      return l10n.reportNoExpensesYet;
    }
    final name = texts.range(state.range);
    return state.filter.isEmpty
        ? l10n.reportEmpty(name)
        : l10n.reportEmptyFiltered(name);
  }
}

/// One face of the card in one currency: the headline, a line under it,
/// then the face's chart in an area as tall on every face.
class _Face extends StatelessWidget {
  const _Face({
    required this.card,
    required this.face,
    required this.currency,
    required this.isCurrent,
  });

  final ReportCard card;
  final ReportChart face;
  final String currency;

  /// The face and currency the user is on: taps and the selection apply.
  final bool isCurrent;

  ReportState get state => card.state;
  ReportTexts get texts => card.texts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = texts.l10n;
    final report = state.report!;
    final metrics = CardMetrics.of(card.size, theme);
    final total = report.totals[currency]?.amount;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final area = _areaHeight(context, metrics);
    final selected = isCurrent ? state.selected : null;
    final slices = chartSlices(report, currency);
    final String? detail = switch (selected) {
      null => null,
      final i when i < slices.length => l10n.reportSliceDetail(
        _sliceName(slices[i]),
        texts.amount(currency, slices[i].amount),
        texts.sliceShare(slices[i]),
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          total == null ? card._emptyText(l10n) : texts.amount(currency, total),
          key: isCurrent ? const ValueKey('reportHeadline') : null,
          style: total == null
              ? theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : metrics.headline,
        ),
        // One line under the headline: the tapped item, else the
        // currencies (the current one bold). Always there, so the faces
        // keep one height.
        if (detail != null)
          Text(
            detail,
            key: const ValueKey('reportDetail'),
            style: muted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        else
          _currencies(muted),
        SizedBox(height: metrics.gap),
        SizedBox(
          height: area,
          child: total == null
              ? const SizedBox.shrink()
              : switch (face) {
                  ReportChart.bars => _bars(context, slices, selected, area),
                  ReportChart.donut => _donut(
                    context,
                    slices,
                    selected,
                    area,
                    report.totals[currency]!.count,
                  ),
                },
        ),
      ],
    );
  }

  /// "INR · usd", the current one bold; empty with one currency (but the
  /// line is kept, for the faces' one height).
  Widget _currencies(TextStyle? style) {
    final pages = state.currencies;
    return Text.rich(
      TextSpan(
        children: [
          if (pages.length > 1)
            for (final (i, code) in pages.indexed) ...[
              if (i > 0) const TextSpan(text: ' · '),
              TextSpan(
                text: code == currency ? code : code.toLowerCase(),
                style: code == currency
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              ),
            ]
          else
            const TextSpan(text: ' '),
        ],
      ),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// The chart area: tall enough for 6 legend lines or bars at the
  /// current font size, and for the size's chart and its labels.
  double _areaHeight(BuildContext context, CardMetrics metrics) =>
      math.max(metrics.chartHeight + 20, ReportCard.rows * _rowHeight(context));

  /// One legend line or bar: the label's line plus a little room, by the
  /// card's size.
  double _rowHeight(BuildContext context) {
    final style = _rowStyle(context);
    final line = MediaQuery.textScalerOf(context)
        .scale((style?.fontSize ?? 12) * (style?.height ?? 1.34));
    final spacing = switch (card.size) {
      TrendCardSize.small => 1.0,
      TrendCardSize.medium => 3.0,
      TrendCardSize.large => 5.0,
    };
    return line + spacing;
  }

  TextStyle? _rowStyle(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return card.size == TrendCardSize.small
        ? text.labelSmall
        : text.labelMedium;
  }

  String _sliceName(ChartSlice slice) {
    final group = slice.group;
    if (group == null) return texts.l10n.reportOtherGroups(slice.others.length);
    return texts.group(group, state.data!);
  }

  List<Color> _colors(BuildContext context, List<ChartSlice> slices) {
    final palette = GroupPalette.of(Theme.of(context).colorScheme);
    return [
      for (final (i, s) in slices.indexed) palette.slice(i, isOther: s.isOther),
    ];
  }

  String _sliceSemantics(ChartSlice slice) => texts.l10n.reportSliceSemantics(
    _sliceName(slice),
    texts.amount(currency, slice.amount),
    texts.sliceShare(slice),
  );

  /// A slice or bar: Other opens what it holds; any other selects it
  /// (again: clears).
  void _tap(int index, List<ChartSlice> slices) {
    if (!isCurrent) return;
    if (index < slices.length && slices[index].isOther) {
      return card.onOther(slices[index], currency);
    }
    card.onSelect(index);
  }

  // --- Bars ---------------------------------------------------------------

  /// The slices as horizontal bars (names are long): name, bar, amount;
  /// the longest bar is the largest slice.
  Widget _bars(
    BuildContext context,
    List<ChartSlice> slices,
    int? selected,
    double area,
  ) {
    final theme = Theme.of(context);
    final colors = _colors(context, slices);
    final style = _rowStyle(context);
    final largest = slices.map((s) => s.amount).fold(BigInt.zero, _max);
    final rowHeight = area / ReportCard.rows;
    return Column(
      key: const ValueKey('reportBars'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, slice) in slices.indexed)
          SizedBox(
            height: rowHeight,
            child: Semantics(
              button: true,
              selected: i == selected,
              label: _sliceSemantics(slice),
              excludeSemantics: true,
              child: InkWell(
                onTap: () => _tap(i, slices),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        _sliceName(slice),
                        style: style?.copyWith(
                          fontWeight: i == selected ? FontWeight.bold : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 4,
                      child: LayoutBuilder(
                        builder: (context, constraints) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            width: math.max(
                              2,
                              constraints.maxWidth *
                                  geometryRatio(slice.amount, largest),
                            ),
                            height: math.min(10, rowHeight * 0.55),
                            decoration: BoxDecoration(
                              color: colors[i],
                              borderRadius: BorderRadius.circular(2),
                              border: i == selected
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Never cut: scaled down to fit.
                    Flexible(
                      flex: 4,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            texts.amount(currency, slice.amount),
                            style: style,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- Donut --------------------------------------------------------------

  Widget _donut(
    BuildContext context,
    List<ChartSlice> slices,
    int? selected,
    double area,
    int count,
  ) => LayoutBuilder(
    builder: (context, constraints) =>
        _donutIn(context, slices, selected, area, count, constraints.maxWidth),
  );

  Widget _donutIn(
    BuildContext context,
    List<ChartSlice> slices,
    int? selected,
    double area,
    int count,
    double width,
  ) {
    final theme = Theme.of(context);
    final colors = _colors(context, slices);
    final style = _rowStyle(context);
    final rowHeight = area / ReportCard.rows;
    // At most 38 % of the width: at the largest font the legend's names
    // were cut to "🏠 …" next to a full-size ring (found on the Oppo,
    // 2026-10-10, Hindi at ×1.6).
    final diameter = math.min(math.min(area, 160.0), width * 0.38);
    return Row(
      key: const ValueKey('reportDonut'),
      children: [
        DonutChart(
          sweeps: ringSweeps([
            for (final s in slices) s.ringFraction,
          ], gapDegrees: DonutPainter.gapDegrees),
          colors: colors,
          size: diameter,
          selected: selected,
          sliceLabel: (i) => _sliceSemantics(slices[i]),
          onTap: (i) => _tap(i, slices),
          center: Text(texts.count(count), style: theme.textTheme.titleMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ExcludeSemantics(
            // The ring's nodes read each slice; the legend repeats them.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (i, slice) in slices.indexed)
                  SizedBox(
                    height: rowHeight,
                    child: InkWell(
                      onTap: () => _tap(i, slices),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors[i],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _sliceName(slice),
                              style: style?.copyWith(
                                fontWeight: i == selected
                                    ? FontWeight.bold
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(texts.sliceShare(slice), style: style),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static BigInt _max(BigInt a, BigInt b) => a > b ? a : b;
}
