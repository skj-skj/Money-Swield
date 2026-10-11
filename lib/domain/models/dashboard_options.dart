/// How Home's trend card is drawn (phase-5.md P5-28; owner, 2026-10-06
/// added [dots] and [runningTotal]). Colours come only from the theme.
enum TrendChartStyle {
  /// A smooth line, the area under it filled (the default).
  lineFilled,

  /// A smooth line.
  line,

  /// One bar per day (per month in Year).
  bar,

  /// A dot on a thin stem per day.
  dots,

  /// The running total: a filled line that climbs through the period to
  /// its total, the headline.
  runningTotal,
}

/// Whether the trend card stays at the top of Home or scrolls away with
/// the list (phase-5.md P5-11).
enum TrendCardPosition { locked, scrolls }

/// How tall the trend card is (owner, 2026-10-06): a smaller card leaves
/// more of the list on screen.
enum TrendCardSize { small, medium, large }

/// The tick felt as the trend card's reel clicks into a face, like a
/// mechanical dial's detent (owner, 2026-10-07): none, or a light, medium
/// or strong one. Android's own touch-feedback switch still applies.
enum CardHaptics { off, light, medium, strong }

/// The report card's faces, in reel order (phase-8.md §8.5, P8-2): bars
/// (the default) and a donut. No trend line (owner, 2026-10-10: a report
/// is an overview).
enum ReportChart { bars, donut }
