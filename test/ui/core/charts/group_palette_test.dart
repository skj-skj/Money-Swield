import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/ui/core/charts/group_palette.dart';

/// Over 144 themes, light and dark, every slice
/// colour keeps 3:1 on the card and adjacent slices stay apart for normal,
/// protan and deutan vision. Contrast and colour distance are computed here
/// from sRGB, independently of the palette's own HCT maths.
void main() {
  final schemes = [
    for (final brightness in Brightness.values)
      for (final chroma in const [8.0, 48.0])
        for (var hue = 0; hue < 360; hue += 5)
          ColorScheme.fromSeed(
            seedColor: Color(Hct.from(hue.toDouble(), chroma, 50).toInt()),
            brightness: brightness,
          ),
  ];

  test('144 themes × light and dark', () {
    expect(schemes.length, 288);
  });

  test('every colour ≥ 3:1 on surfaceContainerLow', () {
    var worst = double.infinity;
    for (final scheme in schemes) {
      final palette = GroupPalette.of(scheme);
      for (final color in palette.colors) {
        final ratio = _contrast(color, scheme.surfaceContainerLow);
        worst = math.min(worst, ratio);
        expect(ratio, greaterThanOrEqualTo(3.0), reason: '$scheme $color');
      }
    }
    // The worst value, for tuning the palette.
    // ignore: avoid_print
    print('worst contrast: ${worst.toStringAsFixed(2)}');
  });

  for (final (name, matrix, minimum) in [
    ('normal vision', _identity, 15.0),
    ('protan', _protan, 8.0),
    ('deutan', _deutan, 8.0),
  ]) {
    test('adjacent slices (5 → 1 wraps) ΔE ≥ $minimum, $name', () {
      var worst = double.infinity;
      for (final scheme in schemes) {
        final colors = GroupPalette.of(scheme).colors;
        for (var i = 0; i < colors.length; i++) {
          final a = colors[i];
          final b = colors[(i + 1) % colors.length];
          final distance = _deltaE(_simulate(a, matrix), _simulate(b, matrix));
          worst = math.min(worst, distance);
          expect(distance, greaterThanOrEqualTo(minimum), reason: '$a $b');
        }
      }
      // The worst value, for tuning the palette.
      // ignore: avoid_print
      print('$name worst ΔE: ${worst.toStringAsFixed(1)}');
    });
  }

  test('a colour already far enough is kept as it is', () {
    const blue = Color(0xFF2A78D6);
    expect(GroupPalette.fitToBackground(blue, Colors.white), blue);
  });

  test('Other is the outline; slices by rank wrap', () {
    final scheme = schemes.first;
    final palette = GroupPalette.of(scheme);
    expect(palette.slice(0, isOther: true), scheme.outline);
    expect(palette.slice(5), palette.colors[0]);
  });
}

// --- sRGB, WCAG, OKLab, Machado 2009 (severity 1) -------------------------

double _linear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

List<double> _rgbLinear(Color c) => [_linear(c.r), _linear(c.g), _linear(c.b)];

double _luminance(Color c) {
  final [r, g, b] = _rgbLinear(c);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const _identity = [
  [1.0, 0.0, 0.0],
  [0.0, 1.0, 0.0],
  [0.0, 0.0, 1.0],
];

const _protan = [
  [0.152286, 1.052583, -0.204868],
  [0.114503, 0.786281, 0.099216],
  [-0.003882, -0.048116, 1.051998],
];

const _deutan = [
  [0.367322, 0.860646, -0.227968],
  [0.280085, 0.672501, 0.047413],
  [-0.011820, 0.042940, 0.968881],
];

List<double> _simulate(Color c, List<List<double>> m) {
  final rgb = _rgbLinear(c);
  return [
    for (final row in m)
      (row[0] * rgb[0] + row[1] * rgb[1] + row[2] * rgb[2]).clamp(0.0, 1.0),
  ];
}

List<double> _oklab(List<double> rgb) {
  final [r, g, b] = rgb;
  double cbrt(double x) => math.pow(x, 1 / 3).toDouble();
  final l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}

/// OKLab distance × 100 (the dataviz targets' scale).
double _deltaE(List<double> a, List<double> b) {
  final x = _oklab(a);
  final y = _oklab(b);
  var sum = 0.0;
  for (var i = 0; i < 3; i++) {
    sum += (x[i] - y[i]) * (x[i] - y[i]);
  }
  return math.sqrt(sum) * 100;
}
