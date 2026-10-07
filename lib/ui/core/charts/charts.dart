/// The app's charts: one series of values drawn as bars, a smooth line,
/// a filled smooth line or dots, with labels under it, tap to select and a
/// TalkBack node per point. Home's trend card uses them (phase-5.md §8.2);
/// they know nothing of money or periods, so Reports (Phase 8) can reuse
/// them for any series.
///
/// Drawn with `CustomPaint`, no package (P5-6). Colours come only from the
/// theme (`ChartColors`): nothing reads as good or bad (P5-28). No y-axis
/// (P5-7): a tap shows the exact value.
///
/// - `SeriesChart`: the chart, from fractions in 0..1 (each value ÷ the
///   largest) and a `ChartKind`.
/// - `SeriesChartPreview`: a tiny drawing of a kind, for choices.
/// - One painter per kind (`BarPainter`, `LinePainter`, `DotPainter`) on a
///   shared `SeriesPainter` (guide line, baseline, semantics).
library;

export 'chart_colors.dart';
export 'chart_kind.dart';
export 'series_chart.dart';
export 'series_painter.dart';
