import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/currency.dart';
import '../../../../domain/models/dashboard_options.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/trend.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/charts/charts.dart';
import '../../../core/date_texts.dart';
import '../../../core/money_formatter.dart';
import '../../../core/period_names.dart';
import '../../../core/widgets/reel_card.dart';
import '../view_models/trend_cubit.dart';

/// Home's trend card (phase-5.md §8.2): the current week, month or year
/// as a chart, headed by the whole period's total in one currency.
///
/// **Swipe up / down** turns it Week → Month → Year like a slot-machine
/// reel: while the finger drags, the current face tilts away and the next
/// one comes into view. Like a mechanical dial it has **detents**: it
/// sticks a little at each face and runs freely between them, with a
/// haptic tick as it clicks into one ([CardHaptics]). A quick flick turns
/// exactly one face; a held drag turns as many as it goes, one per card
/// height; on release it settles on the nearest face (owner, 2026-10-07).
/// Each face is opaque and never turns past edge-on, so the other face never shows
/// through or mirrored (owner, 2026-10-06). **Swipe left / right** goes round the currencies, an
/// endless loop with two or more, a spring with one. Both are drags on the
/// card itself, split by direction, so neither needs a scroll view of its
/// own (and the card's height can follow its text at any font size).
class TrendCard extends StatefulWidget {
  const TrendCard({
    super.key,
    required this.state,
    required this.names,
    required this.style,
    required this.size,
    required this.haptics,
    required this.defaultCurrency,
    required this.onTurn,
    required this.onCurrency,
    required this.onSelect,
  });

  final TrendLoaded state;
  final PeriodNames names;
  final TrendChartStyle style;
  final TrendCardSize size;

  /// The tick at each face of the reel.
  final CardHaptics haptics;
  final String defaultCurrency;

  /// Turned this many periods: positive to the next ones, negative to the
  /// previous ones. Called once per swipe, when the reel stops.
  final ValueChanged<int> onTurn;

  /// The next (1) or previous (-1) currency.
  final ValueChanged<int> onCurrency;

  final ValueChanged<int> onSelect;

  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final formatter = MoneyFormatter.of(context);
    return ReelCard(
      semanticsKey: const ValueKey('trendCard'),
      semanticsLabel: _cardSemantics(
        l10n,
        formatter,
        state,
        state.face.totals[state.currency],
      ),
      faceCount: 3,
      pageCount: state.currenciesOf(state.period).length,
      haptics: widget.haptics,
      nextFaceLabel: l10n.nextPeriod,
      previousFaceLabel: l10n.previousPeriod,
      onTurn: widget.onTurn,
      onPage: widget.onCurrency,
      title: (context, steps) => _title(cardPeriodAfter(state.period, steps)),
      body: (context, steps, page) {
        final period = cardPeriodAfter(state.period, steps);
        if (steps != 0) {
          return _body(
            period,
            state.currencyFor(period, widget.defaultCurrency),
          );
        }
        final pages = state.currenciesOf(period);
        final index = pages.indexOf(state.currency);
        return _body(period, pages[(index + page) % pages.length]);
      },
    );
  }

  /// The period's name, the "Filtered" mark, the dots.
  Widget _title(Period period) {
    final state = widget.state;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final face = state.faces[period]!;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Semantics(
                  liveRegion: period == state.period,
                  child: Text(
                    widget.names.of(face.range),
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (state.filtered) ...[
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
                    key: const ValueKey('trendFiltered'),
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
        ReelDots(count: 3, current: _cardPeriods.indexOf(period)),
      ],
    );
  }

  static const _cardPeriods = [Period.week, Period.month, Period.year];

  /// The headline total, the currencies (or the tapped point), the chart
  /// and its labels, for one currency.
  Widget _body(Period period, String currency) {
    final state = widget.state;
    final face = state.faces[period]!;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final formatter = MoneyFormatter.of(context);
    final daily = face.pointsFor(currency);
    final running = widget.style == TrendChartStyle.runningTotal;
    final points = running ? runningTotals(daily) : daily;
    final metrics = CardMetrics.of(widget.size, theme);
    String pointText(int i) => running
        ? l10n.trendRunningTotalPoint(
            _pointName(points[i], period),
            totalText(l10n, formatter, currency, points[i].amountMinor),
          )
        : l10n.trendPointLabel(
            _pointName(points[i], period),
            totalText(l10n, formatter, currency, points[i].amountMinor),
          );
    final isCurrent = period == state.period && currency == state.currency;
    final selected = isCurrent ? state.selected : null;
    final total = face.totals[currency];
    final pages = state.currenciesOf(period);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          total == null
              ? _emptyText(l10n, period)
              : totalText(l10n, formatter, currency, total),
          key: isCurrent ? const ValueKey('trendHeadline') : null,
          style: total == null
              ? theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : metrics.headline,
        ),
        // One line under the headline: the tapped point while one is
        // tapped, else the currencies there are (the current one bold).
        if (selected != null)
          Text(
            pointText(selected),
            key: const ValueKey('trendPointDetail'),
            style: muted,
          )
        else if (pages.length > 1)
          Text.rich(
            TextSpan(
              children: [
                for (final (i, code) in pages.indexed) ...[
                  if (i > 0) const TextSpan(text: ' · '),
                  TextSpan(
                    text: code == currency ? code : code.toLowerCase(),
                    style: code == currency
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                ],
              ],
            ),
            style: muted,
          ),
        SizedBox(height: metrics.gap),
        SeriesChart(
          key: const ValueKey('trendChart'),
          fractions: pointFractions(points),
          kind: chartKindOf(widget.style),
          height: metrics.chartHeight,
          labels: _labels(period, face.range),
          highlighted: pointIndexOf(points, state.today),
          selected: selected,
          // For TalkBack: a comma, not the screen's "·".
          pointLabel: (i) => running
              ? pointText(i)
              : l10n.daySubtotalSemantics(
                  _pointName(points[i], period),
                  totalText(l10n, formatter, currency, points[i].amountMinor),
                ),
          onTap: isCurrent ? widget.onSelect : (_) {},
        ),
      ],
    );
  }

  String _emptyText(AppLocalizations l10n, Period period) {
    final filtered = widget.state.filtered;
    return switch (period) {
      Period.week => filtered ? l10n.trendNoMatchWeek : l10n.trendEmptyWeek,
      Period.year => filtered ? l10n.trendNoMatchYear : l10n.trendEmptyYear,
      _ => filtered ? l10n.trendNoMatchMonth : l10n.trendEmptyMonth,
    };
  }

  /// "Mon, 5 Oct" for a day, "Sep" for a month of the Year face.
  String _pointName(TrendPoint point, Period period) => period == Period.year
      ? widget.names.month(point.from)
      : widget.names.day(point.from);

  /// Week: narrow weekdays from the week start; Month: 1, 8, 15, 22, 29;
  /// Year: narrow months (P5-23).
  Map<int, String> _labels(Period period, PeriodRange range) {
    final locale = widget.names.locale;
    return switch (period) {
      Period.year => {
        for (var m = 0; m < 12; m++)
          m: cachedDateFormat(
            'LLLLL',
            locale,
          ).format(DateTime.utc(2026, m + 1)),
      },
      Period.week => {
        for (final (i, day) in daysIn(range).indexed)
          i: cachedDateFormat('EEEEE', locale).format(parseDay(day)),
      },
      _ => {
        for (final day in const [1, 8, 15, 22, 29])
          if (day <= daysIn(range).length) day - 1: '$day',
      },
    };
  }

  String _cardSemantics(
    AppLocalizations l10n,
    MoneyFormatter formatter,
    TrendLoaded state,
    BigInt? total,
  ) {
    final name = widget.names.of(state.face.range);
    final amount = total == null
        ? _emptyText(l10n, state.period)
        : l10n.chartCurrencyAnnounce(
            findCurrency(state.currency)?.englishName ?? state.currency,
            totalText(l10n, formatter, state.currency, total),
          );
    return state.filtered
        ? l10n.trendCardSemanticsFiltered(name, amount)
        : l10n.trendCardSemantics(name, amount);
  }
}

/// How [TrendChartStyle] is drawn by the shared chart (`ui/core/charts`).
/// The running total is a filled line of the cumulative points.
ChartKind chartKindOf(TrendChartStyle style) => switch (style) {
  TrendChartStyle.lineFilled || TrendChartStyle.runningTotal => ChartKind.area,
  TrendChartStyle.line => ChartKind.line,
  TrendChartStyle.bar => ChartKind.bars,
  TrendChartStyle.dots => ChartKind.dots,
};
