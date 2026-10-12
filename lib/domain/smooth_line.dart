/// The trend card's smooth line.
///
/// A plain smoothing curve (Catmull-Rom, a cubic spline) overshoots:
/// between a day of ₹500 and a day of ₹0 it dips below zero, which would
/// show negative spending. A **monotone** cubic (Fritsch–Carlson) never
/// goes above the higher or below the lower end of a segment.
library;

import 'dart:math' as math;

/// Tangents for a monotone cubic Hermite curve through [ys], one per
/// point, for points one unit apart (Fritsch–Carlson).
List<double> monotoneTangents(List<double> ys) {
  final n = ys.length;
  if (n < 2) return List.filled(n, 0);
  final slopes = [for (var i = 0; i < n - 1; i++) ys[i + 1] - ys[i]];
  final m = List<double>.filled(n, 0);
  m[0] = slopes.first;
  m[n - 1] = slopes.last;
  for (var i = 1; i < n - 1; i++) {
    // A peak, a valley or a flat neighbour: a flat tangent, so the curve
    // can't overshoot past the point.
    m[i] = slopes[i - 1] * slopes[i] <= 0 ? 0 : (slopes[i - 1] + slopes[i]) / 2;
  }
  for (var i = 0; i < n - 1; i++) {
    final slope = slopes[i];
    if (slope == 0) {
      m[i] = 0;
      m[i + 1] = 0;
      continue;
    }
    final a = m[i] / slope;
    final b = m[i + 1] / slope;
    final s = a * a + b * b;
    if (s > 9) {
      final t = 3 / math.sqrt(s);
      m[i] = t * a * slope;
      m[i + 1] = t * b * slope;
    }
  }
  return m;
}

/// The cubic Hermite segment from ([y0], tangent [m0]) to ([y1], [m1]) at
/// [t] in 0..1, for points one unit apart.
double hermite(double y0, double y1, double m0, double m1, double t) {
  final t2 = t * t;
  final t3 = t2 * t;
  return (2 * t3 - 3 * t2 + 1) * y0 +
      (t3 - 2 * t2 + t) * m0 +
      (-2 * t3 + 3 * t2) * y1 +
      (t3 - t2) * m1;
}
