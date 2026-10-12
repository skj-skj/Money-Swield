import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../data/repositories/expense_repository.dart';
import '../../../../domain/expense_filter.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/totals.dart';
import '../../../../domain/trend.dart';
import '../../../core/emit_if_open.dart';

/// One face of the trend card: the current week, month or year.
final class TrendFace {
  TrendFace(this.range, List<AmountRow> rows, String defaultCurrency)
    : totals = periodTotals(range, rows),
      _rows = rows {
    currencies = chartCurrencies(totals, defaultCurrency);
  }

  final PeriodRange range;

  /// The whole period's total per currency (the headline).
  final CurrencyTotals totals;

  /// The carousel's pages: currencies with rows, default first, then by
  /// code. Empty when the period has no rows.
  late final List<String> currencies;

  final List<AmountRow> _rows;
  final _points = <String, List<TrendPoint>>{};

  bool get isEmpty => currencies.isEmpty;

  /// The chart's points in [currency], built once.
  List<TrendPoint> pointsFor(String currency) =>
      _points.putIfAbsent(currency, () => trendPoints(range, _rows, currency));
}

sealed class TrendState {
  const TrendState();
}

/// The card's frame with a thin progress bar.
final class TrendLoading extends TrendState {
  const TrendLoading();
}

final class TrendLoaded extends TrendState {
  const TrendLoaded({
    required this.faces,
    required this.period,
    required this.currency,
    required this.filtered,
    required this.today,
    this.selected,
  });

  /// Week, month and year, all built from one read, so a turn or a currency
  /// swipe reads nothing and the next face is ready mid-drag.
  final Map<Period, TrendFace> faces;

  final Period period;

  /// The carousel's current currency.
  final String currency;

  /// The rows are filtered: the card says so.
  final bool filtered;

  /// The device's local date when loaded, for the highlighted point.
  final String today;

  /// The tapped point, or null.
  final int? selected;

  TrendFace get face => faces[period]!;

  /// The carousel's pages for [period]'s face: its currencies, or just the
  /// current one when the period has no rows.
  List<String> currenciesOf(Period period) {
    final face = faces[period]!;
    return face.isEmpty ? [currency] : face.currencies;
  }

  /// The currency [period]'s face shows: the current one while that period has
  /// rows in it, else its first.
  String currencyFor(Period period, String defaultCurrency) {
    final face = faces[period]!;
    return face.currencies.contains(currency)
        ? currency
        : initialChartCurrency(face.currencies, defaultCurrency);
  }

  TrendLoaded copyWith({
    Period? period,
    String? currency,
    int? Function()? selected,
  }) => TrendLoaded(
    faces: faces,
    period: period ?? this.period,
    currency: currency ?? this.currency,
    filtered: filtered,
    today: today,
    selected: selected == null ? this.selected : selected(),
  );
}

final class TrendFailed extends TrendState {
  const TrendFailed();
}

/// Home's trend card: the current week, month or year, one currency at a time,
/// for what the filters show.
class TrendCubit extends CubitSignal<TrendState> with EmitIfOpen<TrendState> {
  TrendCubit({
    required this._expenses,
    required this._now,
    required this._defaultCurrency,
    required this._period,
    required this._weekStart,
  }) : super(initialState: const TrendLoading());

  final ExpenseRepository _expenses;
  final DateTime Function() _now;
  String _defaultCurrency;
  Period _period;
  WeekStart _weekStart;
  ExpenseFilter _filter = ExpenseFilter.none;

  /// The rows of the last read, so a default-currency change reorders
  /// without reading again.
  List<AmountRow>? _rows;
  String? _rowsToday;

  /// Bumped by every load, so a late result can't replace a newer one.
  int _generation = 0;

  /// Reads the current periods' rows and builds the three faces. Keeps the
  /// chosen currency while the period has rows in it; clears the
  /// selection.
  Future<void> load() async {
    final generation = ++_generation;
    final today = todayOn(_now());
    final filter = _filter;
    final ranges = _rangesFor(today);
    // One read from the earliest start to the latest end: this year,
    // widened when this week crosses into another year.
    final from = ranges.map((r) => r.from).reduce(_min);
    final to = ranges.map((r) => r.to).reduce(_max);
    try {
      final List<AmountRow> rows;
      if (filter.hasText) {
        final words = searchWords(filter.text);
        rows = [
          for (final entry in await _expenses.searchEntries(
            filter: filter.withoutText,
          ))
            if (entry.day.compareTo(from) >= 0 &&
                entry.day.compareTo(to) <= 0 &&
                matchesText(entry, words))
              (entry.day, entry.currencyCode, entry.amountMinor),
        ];
      } else {
        rows = await _expenses.amountsIn(from: from, to: to, filter: filter);
      }
      if (generation != _generation) return;
      _rows = rows;
      _rowsToday = today;
      _build(clearSelection: true);
    } catch (error) {
      debugPrint('Loading the trend failed: $error');
      if (generation != _generation) return;
      emitIfOpen(const TrendFailed());
    }
  }

  /// The card follows the filters. The same filter reads nothing: Home's list
  /// hands its filter over after its first load, while the card's own first
  /// load (same filter) is already running.
  Future<void> setFilter(ExpenseFilter filter) async {
    if (filter == _filter) return;
    _filter = filter;
    await load();
  }

  Future<void> setWeekStart(WeekStart weekStart) async {
    if (weekStart == _weekStart) return;
    _weekStart = weekStart;
    await load();
  }

  /// Reorders the currencies (default first); reads nothing.
  void setDefaultCurrency(String code) {
    if (code == _defaultCurrency) return;
    _defaultCurrency = code;
    if (_rows != null) _build(clearSelection: false);
  }

  /// Turns the card [steps] periods: positive to the next ones, negative to the
  /// previous ones, wrapping; a spin of the reel can turn several at once.
  /// Reads nothing: every face is loaded. Returns the new period, for the
  /// screen to save.
  Period turn(int steps) {
    _period = cardPeriodAfter(_period, steps);
    final state = value;
    if (state is TrendLoaded) {
      emitIfOpen(
        state.copyWith(
          period: _period,
          currency: state.currencyFor(_period, _defaultCurrency),
          selected: () => null,
        ),
      );
    }
    return _period;
  }

  /// The carousel: the next (1) or previous (-1) currency, wrapping.
  void moveCurrency(int direction) {
    final state = value;
    if (state is! TrendLoaded) return;
    final pages = state.currenciesOf(state.period);
    final index = pages.indexOf(state.currency);
    final next = pages[(index + direction) % pages.length];
    if (next == state.currency) return;
    emitIfOpen(state.copyWith(currency: next, selected: () => null));
  }

  /// Taps a point; tapping it again clears it.
  void select(int index) {
    final state = value;
    if (state is! TrendLoaded) return;
    emitIfOpen(
      state.copyWith(selected: () => state.selected == index ? null : index),
    );
  }

  void _build({required bool clearSelection}) {
    final rows = _rows!;
    final today = _rowsToday!;
    final faces = {
      for (final range in _rangesFor(today))
        range.period: TrendFace(range, rows, _defaultCurrency),
    };
    final previous = value;
    final kept = previous is TrendLoaded ? previous.currency : null;
    final face = faces[_period]!;
    emitIfOpen(
      TrendLoaded(
        faces: faces,
        period: _period,
        currency: kept != null && face.currencies.contains(kept)
            ? kept
            : initialChartCurrency(face.currencies, _defaultCurrency),
        filtered: !_filter.isEmpty,
        today: today,
        selected: clearSelection || previous is! TrendLoaded
            ? null
            : previous.selected,
      ),
    );
  }

  List<PeriodRange> _rangesFor(String today) => [
    for (final period in const [Period.week, Period.month, Period.year])
      periodOf(today, period, _weekStart),
  ];

  static String _min(String a, String b) => a.compareTo(b) <= 0 ? a : b;
  static String _max(String a, String b) => a.compareTo(b) >= 0 ? a : b;
}
