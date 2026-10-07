import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/domain/smooth_line.dart';
import 'package:my_expense_tracker_app/domain/totals.dart';
import 'package:my_expense_tracker_app/domain/trend.dart';

/// phase-5.md §5.2–§5.4 and §12 "Domain".
void main() {
  final maxInt = BigInt.from(9223372036854775807);

  group('sumByCurrency', () {
    test('per currency; none → empty', () {
      expect(sumByCurrency([('INR', 100), ('USD', 5), ('INR', 50)]), {
        'INR': BigInt.from(150),
        'USD': BigInt.from(5),
      });
      expect(sumByCurrency([]), isEmpty);
    });

    test('three rows of max int64 → exactly 3 × (2⁶³ − 1)', () {
      final rows = [for (var i = 0; i < 3; i++) ('INR', 9223372036854775807)];
      expect(sumByCurrency(rows)['INR'], maxInt * BigInt.from(3));
    });
  });

  test('orderedTotals: default first, the rest by code', () {
    final totals = {
      'USD': BigInt.one,
      'EUR': BigInt.two,
      'INR': BigInt.from(3),
    };
    expect(
      [for (final (c, _) in orderedTotals(totals, 'INR')) c],
      ['INR', 'EUR', 'USD'],
    );
    expect(
      [for (final (c, _) in orderedTotals(totals, 'JPY')) c],
      ['EUR', 'INR', 'USD'],
      reason: 'default absent',
    );
  });

  group('trendPoints', () {
    List<int> amounts(List<TrendPoint> points) => [
      for (final p in points) p.amountMinor.toInt(),
    ];

    test('a Monday and a Sunday week, in week order', () {
      final rows = [
        ('2026-10-04', 'INR', 1), // Sunday
        ('2026-10-05', 'INR', 2), // Monday
        ('2026-10-05', 'USD', 99),
      ];
      expect(
        amounts(
          trendPoints(
            periodOf('2026-10-05', Period.week, WeekStart.monday),
            rows,
            'INR',
          ),
        ),
        [2, 0, 0, 0, 0, 0, 0],
      );
      final sunday = trendPoints(
        periodOf('2026-10-05', Period.week, WeekStart.sunday),
        rows,
        'INR',
      );
      expect(amounts(sunday), [1, 2, 0, 0, 0, 0, 0]);
      expect(sunday.first.from, '2026-10-04');
    });

    test('a week crossing a year end still has its 7 days', () {
      final week = periodOf('2027-01-01', Period.week, WeekStart.monday);
      final points = trendPoints(week, [
        ('2026-12-28', 'INR', 5),
        ('2027-01-03', 'INR', 7),
      ], 'INR');
      expect(amounts(points), [5, 0, 0, 0, 0, 0, 7]);
    });

    test('Feb 2028 has 29 points, October 31; future days count', () {
      expect(
        trendPoints(
          periodOf('2028-02-10', Period.month, WeekStart.monday),
          [],
          'INR',
        ),
        hasLength(29),
      );
      final october = trendPoints(
        periodOf('2026-10-05', Period.month, WeekStart.monday),
        [('2026-10-31', 'INR', 4), ('2026-11-01', 'INR', 1000)],
        'INR',
      );
      expect(october, hasLength(31));
      expect(october.last.amountMinor, BigInt.from(4));
    });

    test('a year has 12 points, each month summed', () {
      final points = trendPoints(
        periodOf('2026-10-05', Period.year, WeekStart.monday),
        [
          ('2026-01-01', 'INR', 1),
          ('2026-01-31', 'INR', 2),
          ('2026-12-31', 'INR', 3),
          ('2025-12-31', 'INR', 100),
        ],
        'INR',
      );
      expect(amounts(points), [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3]);
      expect(points[1].from, '2026-02-01');
      expect(points[1].to, '2026-02-28');
    });

    test('periodTotals equals the sum of the points, every currency', () {
      final range = periodOf('2026-10-05', Period.month, WeekStart.monday);
      final random = math.Random(5);
      final rows = [
        for (var i = 0; i < 200; i++)
          (
            '2026-${(9 + random.nextInt(3)).toString().padLeft(2, '0')}-'
                '${(1 + random.nextInt(28)).toString().padLeft(2, '0')}',
            ['INR', 'USD', 'JPY'][random.nextInt(3)],
            random.nextInt(100000),
          ),
      ];
      final totals = periodTotals(range, rows);
      for (final code in ['INR', 'USD', 'JPY']) {
        final points = trendPoints(range, rows, code);
        expect(
          points.fold(BigInt.zero, (sum, p) => sum + p.amountMinor),
          totals[code] ?? BigInt.zero,
          reason: code,
        );
      }
    });
  });

  test('runningTotals: each point adds the ones before; the last is the '
      'total', () {
    TrendPoint p(int v) =>
        (from: 'f$v', to: 't$v', amountMinor: BigInt.from(v));
    final running = runningTotals([p(5), p(0), p(7), p(1)]);
    expect([for (final r in running) r.amountMinor.toInt()], [5, 5, 12, 13]);
    expect(running[2].from, 'f7', reason: 'dates kept');
    expect(runningTotals([]), isEmpty);
  });

  test('chartCurrencies / initialChartCurrency', () {
    final totals = {'USD': BigInt.one, 'INR': BigInt.one, 'EUR': BigInt.one};
    expect(chartCurrencies(totals, 'INR'), ['INR', 'EUR', 'USD']);
    expect(initialChartCurrency(['INR', 'EUR'], 'INR'), 'INR');
    expect(initialChartCurrency(['EUR', 'USD'], 'INR'), 'EUR');
    expect(initialChartCurrency([], 'INR'), 'INR');
  });

  test('pointFractions: largest 0 → all 0', () {
    TrendPoint p(int v) => (from: '', to: '', amountMinor: BigInt.from(v));
    expect(pointFractions([p(0), p(0)]), [0, 0]);
    expect(pointFractions([p(1), p(4), p(0)]), [0.25, 1, 0]);
  });

  group('monotoneTangents', () {
    /// Samples each segment at 20 steps and checks it stays within its two
    /// ends (§5.4): never below the lower, never above the higher.
    void expectNoOvershoot(List<double> ys) {
      final m = monotoneTangents(ys);
      for (var i = 0; i < ys.length - 1; i++) {
        final low = math.min(ys[i], ys[i + 1]);
        final high = math.max(ys[i], ys[i + 1]);
        for (var step = 0; step <= 20; step++) {
          final y = hermite(ys[i], ys[i + 1], m[i], m[i + 1], step / 20);
          expect(
            y,
            inInclusiveRange(low - 1e-9, high + 1e-9),
            reason: '$ys segment $i step $step',
          );
        }
      }
    }

    test('edge inputs', () {
      expectNoOvershoot([5, 5, 5, 5]);
      expectNoOvershoot([0, 0, 0, 0, 0]);
      expectNoOvershoot([0, 0, 500, 0, 0]);
      expectNoOvershoot([0, 1, 0, 1, 0, 1, 0]);
      expectNoOvershoot([1, 0, 1, 0, 1, 0, 1]);
      expectNoOvershoot([0, 1, 2, 100, 101, 102]);
      expectNoOvershoot([100, 0]);
    });

    test('random inputs', () {
      final random = math.Random(42);
      for (var run = 0; run < 300; run++) {
        expectNoOvershoot([
          for (var i = 0; i < 2 + random.nextInt(30); i++)
            random.nextBool() ? 0 : random.nextDouble() * 1000,
        ]);
      }
    });

    test('a run of zeros stays exactly 0; one point is a dot', () {
      final ys = <double>[3, 0, 0, 0, 7];
      final m = monotoneTangents(ys);
      for (var step = 0; step <= 20; step++) {
        expect(hermite(ys[1], ys[2], m[1], m[2], step / 20), 0);
        expect(hermite(ys[2], ys[3], m[2], m[3], step / 20), 0);
      }
      expect(monotoneTangents([4]), [0]);
      expect(monotoneTangents([]), isEmpty);
    });
  });
}
