/// How a series is drawn.
enum ChartKind {
  /// One bar per slot, 60 % of its width (at least 2 dp).
  bars,

  /// A smooth line through the slot centres: a monotone cubic, so it never
  /// overshoots a point (never below zero between a busy and an empty
  /// slot; `domain/smooth_line.dart`).
  line,

  /// The same line, the area under it filled with a fade.
  area,

  /// A dot on a thin stem per slot (a lollipop chart); empty slots draw
  /// nothing over the baseline.
  dots,
}
