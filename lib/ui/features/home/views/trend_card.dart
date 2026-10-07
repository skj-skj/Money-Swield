import 'dart:math' as math;

import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;
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

class _TrendCardState extends State<TrendCard> with TickerProviderStateMixin {
  /// The reel, in faces: 0 shows the current period, 1 the next one (come
  /// up from below by a swipe up), -1 the previous one, 2 the one after
  /// the next, and so on without end: a held drag turns several faces
  /// (owner, 2026-10-07). The card's period changes once, when the reel
  /// stops on a face. Ticks as it reaches each face ([_tickAtFaces]).
  late final _reel = AnimationController.unbounded(vsync: this)
    ..addListener(_tickAtFaces);

  /// The carousel: towards 1 the next currency comes in from the right
  /// (swipe left), towards -1 the previous from the left.
  late final _slide = AnimationController.unbounded(vsync: this);

  /// A fling at least this fast commits a turn or a page (dp/s).
  static const _flingVelocity = 300.0;

  /// How strongly the reel sticks at each face, 0 (not at all) to below 1:
  /// at a face it moves at 1 − this of the finger's speed, half-way
  /// between two at 1 + this, so it clicks from face to face like a
  /// mechanical dial ([_detented]).
  static const _detent = 0.55;

  /// How far a single currency follows the finger before springing back.
  static const _springPull = 0.25;

  @override
  void dispose() {
    _reel.dispose();
    _slide.dispose();
    super.dispose();
  }

  bool get _noAnimations => MediaQuery.disableAnimationsOf(context);

  /// The card's size when the current drag started: read in the gesture
  /// callbacks (a render object's size can't be read during build) and
  /// used by build while the reel or the carousel moves.
  Size _size = const Size(300, 200);

  void _measure() => _size = context.size ?? _size;

  double get _height => _size.height;
  double get _width => _size.width;

  int get _pageCount => widget.state.currenciesOf(widget.state.period).length;

  /// A page that a released drag committed to, while its animation runs.
  /// A new drag in that time finishes it at once (§8.2): the animation can
  /// then be below half-way (a fast, short fling), so the carousel's
  /// position can't tell.
  int? _pendingPage;

  // --- Reel ---------------------------------------------------------------

  /// Where the finger has taken the reel, in faces, before the detents
  /// ([_detented] of it is what shows).
  double _drag = 0;

  /// The reel's last value, to tick when it reaches a face.
  double _lastReel = 0;

  /// Set while the reel is put back to 0 after a turn: no tick for that.
  bool _rebasing = false;

  /// [raw] with a detent at each face: a monotone curve that is slow
  /// around whole numbers and fast between them, and meets [raw] at every
  /// whole and half number, so the finger and the reel never drift apart.
  static double _detented(double raw) {
    final face = raw.floorToDouble();
    final p = raw - face;
    return face + p - _detent / (2 * math.pi) * math.sin(2 * math.pi * p);
  }

  /// The finger position that shows [value] ([_detented] backwards), for
  /// a drag that catches the reel between faces.
  static double _undetented(double value) {
    var low = value.floorToDouble();
    var high = low + 1;
    for (var i = 0; i < 30; i++) {
      final mid = (low + high) / 2;
      if (_detented(mid) < value) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  /// A tick each time the reel reaches a face, dragged or animated: when it
  /// arrives on a whole number, or passes one.
  void _tickAtFaces() {
    final value = _reel.value;
    final last = _lastReel;
    _lastReel = value;
    if (_rebasing || value == last) return;
    final reached = value > last
        ? value.floor() != last.floor()
        : value.ceil() != last.ceil();
    if (reached) cardHaptic(widget.haptics);
  }

  void _onVerticalStart(DragStartDetails details) {
    _measure();
    // A finger on a moving reel catches it where it is; the drag goes on
    // from there, and its release decides the face.
    if (_reel.isAnimating) _reel.stop();
    _drag = _undetented(_reel.value);
  }

  void _onVerticalUpdate(DragUpdateDetails details) {
    // No limit: every card height of drag turns one more face.
    _drag -= details.primaryDelta! / _height;
    _reel.value = _detented(_drag);
  }

  Future<void> _onVerticalEnd(DragEndDetails details) async {
    // Up is positive here, like the reel.
    final velocity = -(details.primaryVelocity ?? 0);
    final value = _reel.value;
    final target = _reelTarget(value, velocity);
    if (!_noAnimations && value != target) {
      final distance = (target - value).abs();
      await _reel.animateTo(
        target.toDouble(),
        duration: Duration(
          milliseconds: (180 + 220 * distance).clamp(180, 400).round(),
        ),
        // No overshoot: past a face it would turn beyond edge-on and show
        // mirrored (owner, 2026-10-06: was easeOutBack's "clunk").
        curve: Curves.easeOutCubic,
      );
      // Stopped early: a new drag caught the reel, and its release decides.
      if (!mounted || _reel.value != target) return;
    }
    _rebasing = true;
    _reel.value = 0;
    _rebasing = false;
    if (target != 0) widget.onTurn(target);
  }

  /// The face the reel stops on when released at [value] with [velocity]
  /// (dp/s, up positive): with a flick, the next face that way, exactly
  /// one, however fast (owner, 2026-10-07: a flick that spun several faces
  /// was too much; a held drag turns more); else the nearest face.
  int _reelTarget(double value, double velocity) {
    if (velocity.abs() < _flingVelocity) return value.round();
    return velocity > 0 ? value.floor() + 1 : value.ceil() - 1;
  }

  // --- Carousel -----------------------------------------------------------

  void _onHorizontalStart(DragStartDetails details) {
    _measure();
    // A swipe while the carousel still slides on finishes that page at
    // once; a spring back is caught where it is.
    final pending = _pendingPage;
    if (pending == null || !_slide.isAnimating) return;
    _slide.stop();
    _pendingPage = null;
    widget.onCurrency(pending);
    _slide.value = 0;
  }

  void _onHorizontalUpdate(DragUpdateDetails details) {
    final pulled = _slide.value - details.primaryDelta! / _width;
    _slide.value = _pageCount < 2
        ? pulled.clamp(-_springPull, _springPull)
        : pulled.clamp(-1.0, 1.0);
  }

  Future<void> _onHorizontalEnd(DragEndDetails details) async {
    // A swipe to the left is positive: the next currency.
    final velocity = -(details.primaryVelocity ?? 0);
    final value = _slide.value;
    final direction = value != 0 ? value.sign.toInt() : velocity.sign.toInt();
    final commit =
        _pageCount >= 2 &&
        direction != 0 &&
        (value.abs() > 0.35 ||
            (velocity.abs() >= _flingVelocity && velocity.sign == direction));
    if (!commit) {
      await _slide.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
      );
      return;
    }
    _pendingPage = direction;
    if (!_noAnimations) {
      await _slide.animateTo(
        direction.toDouble(),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      // A new drag finished it already.
      if (!mounted || _pendingPage == null) return;
    }
    _pendingPage = null;
    widget.onCurrency(direction);
    _slide.value = 0;
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final face = state.face;
    final formatter = MoneyFormatter.of(context);
    final total = face.totals[state.currency];
    final pages = _pageCount;
    return Semantics(
      key: const ValueKey('trendCard'),
      container: true,
      label: _cardSemantics(l10n, formatter, state, total),
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.nextPeriod): () => widget.onTurn(1),
        CustomSemanticsAction(label: l10n.previousPeriod): () =>
            widget.onTurn(-1),
        if (pages >= 2) ...{
          CustomSemanticsAction(label: l10n.nextCurrency): () =>
              widget.onCurrency(1),
          CustomSemanticsAction(label: l10n.previousCurrency): () =>
              widget.onCurrency(-1),
        },
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          // The whole card, not only where a child paints: a swipe that
          // started in its padding or between the chart's labels turned
          // nothing (found on the Oppo, 2026-10-07).
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onVerticalStart,
          onVerticalDragUpdate: _onVerticalUpdate,
          onVerticalDragEnd: _onVerticalEnd,
          // E.g. a system gesture took the pointer: settle on a face.
          onVerticalDragCancel: () => _onVerticalEnd(DragEndDetails()),
          onHorizontalDragStart: _onHorizontalStart,
          onHorizontalDragUpdate: _onHorizontalUpdate,
          onHorizontalDragEnd: _onHorizontalEnd,
          child: AnimatedBuilder(
            animation: _reel,
            builder: (context, _) => _buildReel(),
          ),
        ),
      ),
    );
  }

  /// The face the reel is on alone, or the two faces it is between.
  Widget _buildReel() {
    final value = _reel.value;
    final state = widget.state;
    // The two faces around [value]: the one it left and the next one in
    // the direction it turns, and how far it is from the first (0..1).
    final up = value >= 0;
    final from = up ? value.floor() : value.ceil();
    final t = (value - from).abs();
    final current = _face(cardPeriodAfter(state.period, from));
    if (t == 0) return current;
    final other = cardPeriodAfter(state.period, up ? from + 1 : from - 1);
    final height = _height;
    final outgoing = _turned(
      current,
      dy: up ? -t * height : t * height,
      angle: up ? -t * math.pi / 2 : t * math.pi / 2,
      hinge: up ? Alignment.bottomCenter : Alignment.topCenter,
      shade: t,
    );
    final incoming = Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: height,
      child: _turned(
        OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: _face(other),
        ),
        dy: up ? (1 - t) * height : -(1 - t) * height,
        angle: up ? (1 - t) * math.pi / 2 : -(1 - t) * math.pi / 2,
        hinge: up ? Alignment.topCenter : Alignment.bottomCenter,
        shade: 1 - t,
      ),
    );
    // The face that faces the viewer more is drawn last, on top.
    return ClipRect(
      child: Stack(
        children: t < 0.5 ? [incoming, outgoing] : [outgoing, incoming],
      ),
    );
  }

  /// One face of the reel, moved and tilted with perspective, darkened as
  /// it turns away. Each in a `RepaintBoundary`, so a frame of the turn
  /// only re-composites two layers (light 3D: no blur, no shader).
  Widget _turned(
    Widget face, {
    required double dy,
    required double angle,
    required Alignment hinge,
    required double shade,
  }) => Transform(
    alignment: hinge,
    transform: Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..translateByDouble(0, dy, 0, 1)
      ..rotateX(angle),
    child: Stack(
      children: [
        // Opaque, in the card's colour: the other face mustn't show through.
        RepaintBoundary(
          child: ColoredBox(color: _faceColor(context), child: face),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(
                alpha: 0.25 * shade.clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  static Color _faceColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
  }

  /// The title row (the same for every currency), then the body, which
  /// slides sideways with the carousel.
  Widget _face(Period period) {
    final state = widget.state;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final face = state.faces[period]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
              _PeriodDots(period: period),
            ],
          ),
          const SizedBox(height: 4),
          period == state.period
              ? AnimatedBuilder(
                  animation: _slide,
                  builder: (context, _) => _slidingBody(period),
                )
              : _body(
                  period,
                  state.currencyFor(period, widget.defaultCurrency),
                ),
        ],
      ),
    );
  }

  Widget _slidingBody(Period period) {
    final value = _slide.value;
    final state = widget.state;
    final pages = state.currenciesOf(period);
    final current = _body(period, state.currency);
    if (value == 0) return current;
    final width = _width;
    if (pages.length < 2) {
      return Transform.translate(
        offset: Offset(-value * width, 0),
        child: current,
      );
    }
    final index = pages.indexOf(state.currency);
    final direction = value > 0 ? 1 : -1;
    final neighbour = pages[(index + direction) % pages.length];
    return ClipRect(
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(-value * width, 0),
            child: current,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Transform.translate(
              offset: Offset((direction - value) * width, 0),
              child: _body(period, neighbour),
            ),
          ),
        ],
      ),
    );
  }

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
    final metrics = _CardMetrics.of(widget.size, theme);
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

/// Three small dots, the current period filled, so the swipe can be
/// discovered: week, month, year.
class _PeriodDots extends StatelessWidget {
  const _PeriodDots({required this.period});

  final Period period;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in const [Period.week, Period.month, Period.year])
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(vertical: 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p == period ? colors.primary : null,
                border: Border.all(color: colors.outline),
              ),
            ),
        ],
      ),
    );
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

/// The card's headline and chart for each [TrendCardSize] (owner,
/// 2026-10-06). Large is the original card; the others give the list
/// more room.
class _CardMetrics {
  const _CardMetrics(this.headline, this.chartHeight, this.gap);

  factory _CardMetrics.of(TrendCardSize size, ThemeData theme) =>
      switch (size) {
        TrendCardSize.large => _CardMetrics(
          theme.textTheme.headlineSmall,
          120,
          8,
        ),
        TrendCardSize.medium => _CardMetrics(theme.textTheme.titleLarge, 80, 6),
        TrendCardSize.small => _CardMetrics(theme.textTheme.titleMedium, 44, 4),
      };

  final TextStyle? headline;
  final double chartHeight;
  final double gap;
}

/// The reel's tick at a face, as set in Settings → Home (owner,
/// 2026-10-07). Also played there when a strength is picked, to feel it.
void cardHaptic(CardHaptics haptics) {
  switch (haptics) {
    case CardHaptics.off:
      return;
    case CardHaptics.light:
      HapticFeedback.selectionClick();
    case CardHaptics.medium:
      HapticFeedback.mediumImpact();
    case CardHaptics.strong:
      HapticFeedback.heavyImpact();
  }
}
