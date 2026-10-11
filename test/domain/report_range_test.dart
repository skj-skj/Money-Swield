import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/domain/report_range.dart';

/// phase-8.md §5.1 and §12 "Domain: report_range".
void main() {
  const mon = WeekStart.monday;
  const sun = WeekStart.sunday;
  const today = '2026-10-10';

  (String?, String?) dates(ReportRange r) => (r.from, r.to);

  group('currentRange', () {
    test('month holds future days', () {
      expect(dates(currentRange(ReportPeriod.month, today, mon)), (
        '2026-10-01',
        '2026-10-31',
      ));
    });

    test('week with a Monday and a Sunday start', () {
      expect(dates(currentRange(ReportPeriod.week, today, mon)), (
        '2026-10-05',
        '2026-10-11',
      ));
      expect(dates(currentRange(ReportPeriod.week, today, sun)), (
        '2026-10-04',
        '2026-10-10',
      ));
    });

    test('year', () {
      expect(dates(currentRange(ReportPeriod.year, today, mon)), (
        '2026-01-01',
        '2026-12-31',
      ));
    });

    test('range has no current one', () {
      expect(
        () => currentRange(ReportPeriod.range, today, mon),
        throwsArgumentError,
      );
    });
  });

  group('stepRange', () {
    test('month back into February, leap and not', () {
      final march = currentRange(ReportPeriod.month, '2026-03-15', mon);
      expect(dates(stepRange(march, -1, mon)), ('2026-02-01', '2026-02-28'));
      final leap = currentRange(ReportPeriod.month, '2024-03-31', mon);
      expect(dates(stepRange(leap, -1, mon)), ('2024-02-01', '2024-02-29'));
    });

    test('month across a year, both ways, several steps', () {
      final jan = currentRange(ReportPeriod.month, '2026-01-31', mon);
      expect(dates(stepRange(jan, -1, mon)), ('2025-12-01', '2025-12-31'));
      expect(dates(stepRange(jan, 13, mon)), ('2027-02-01', '2027-02-28'));
    });

    test('year forward', () {
      final year = currentRange(ReportPeriod.year, today, mon);
      expect(dates(stepRange(year, 1, mon)), ('2027-01-01', '2027-12-31'));
    });

    test('week across a year', () {
      final week = currentRange(ReportPeriod.week, '2026-01-05', mon);
      expect(dates(stepRange(week, -1, mon)), ('2025-12-29', '2026-01-04'));
      final sunday = currentRange(ReportPeriod.week, '2026-01-04', sun);
      expect(dates(stepRange(sunday, -1, sun)), ('2025-12-28', '2026-01-03'));
    });

    test('a custom range does not step', () {
      const r = ReportRange(ReportPeriod.range, '2026-01-01', '2026-02-01');
      expect(stepRange(r, 1, mon), r);
      expect(canStep(r, 1, mon), isFalse);
      expect(canStep(const ReportRange.allTime(), -1, mon), isFalse);
    });
  });

  group('canStep at the bounds', () {
    test('January 1900 back, December 2199 forward into the 2200 month', () {
      final first = currentRange(ReportPeriod.month, '1900-01-15', mon);
      expect(canStep(first, -1, mon), isFalse);
      expect(canStep(first, 1, mon), isTrue);
      final dec = currentRange(ReportPeriod.month, '2199-12-15', mon);
      // January 2200 holds 2200-01-01, the last day an expense can have.
      expect(canStep(dec, 1, mon), isTrue);
      final jan2200 = stepRange(dec, 1, mon);
      expect(canStep(jan2200, 1, mon), isFalse);
    });

    test('the week holding 2200-01-01 forward; 1900 years', () {
      final week = currentRange(ReportPeriod.week, lastExpenseDay, mon);
      expect(dates(week), ('2199-12-30', '2200-01-05'));
      expect(canStep(week, 1, mon), isFalse);
      expect(canStep(week, -1, mon), isTrue);
      final y1900 = currentRange(ReportPeriod.year, '1900-06-01', mon);
      expect(canStep(y1900, -1, mon), isFalse);
      // 1900-01-01 was a Monday: the week before it is all 1899.
      final firstWeek = currentRange(ReportPeriod.week, firstExpenseDay, mon);
      expect(firstWeek.from, '1900-01-01');
      expect(canStep(firstWeek, -1, mon), isFalse);
      // With a Sunday start the first week starts in 1899 and still holds
      // 1900-01-01: no step back from it, but it exists.
      final sundayWeek = currentRange(ReportPeriod.week, firstExpenseDay, sun);
      expect(sundayWeek.from, '1899-12-31');
      expect(canStep(sundayWeek, -1, sun), isFalse);
    });

    test('zero steps never', () {
      expect(
        canStep(currentRange(ReportPeriod.month, today, mon), 0, mon),
        isFalse,
      );
    });
  });

  group('defaultCustomRange', () {
    test('12 whole months, this one included', () {
      expect(dates(defaultCustomRange(today)), ('2025-11-01', '2026-10-31'));
      expect(dates(defaultCustomRange('2024-02-29')), (
        '2023-03-01',
        '2024-02-29',
      ));
      expect(dates(defaultCustomRange('2026-01-31')), (
        '2025-02-01',
        '2026-01-31',
      ));
      expect(dates(defaultCustomRange('2026-12-31')), (
        '2026-01-01',
        '2026-12-31',
      ));
      expect(defaultCustomRange(today).period, ReportPeriod.range);
    });
  });

  group('checkCustomRange', () {
    test('valid, one day, reversed, bounds, malformed', () {
      expect(checkCustomRange('2026-10-01', '2026-10-31'), isNull);
      expect(checkCustomRange('2026-10-01', '2026-10-01'), isNull);
      expect(
        checkCustomRange('2026-10-31', '2026-10-01'),
        CustomRangeProblem.fromAfterTo,
      );
      expect(
        checkCustomRange('1899-12-31', '2026-10-01'),
        CustomRangeProblem.outOfBounds,
      );
      expect(
        checkCustomRange('2026-10-01', '2200-01-02'),
        CustomRangeProblem.outOfBounds,
      );
      expect(checkCustomRange(firstExpenseDay, lastExpenseDay), isNull);
      for (final bad in ['2026-02-30', '2026-13-01', '26-10-01', '', 'x']) {
        expect(
          checkCustomRange(bad, '2026-10-01'),
          CustomRangeProblem.malformed,
          reason: bad,
        );
      }
    });
  });

  test('holdsToday', () {
    expect(
      holdsToday(currentRange(ReportPeriod.month, today, mon), today),
      isTrue,
    );
    final sept = stepRange(
      currentRange(ReportPeriod.month, today, mon),
      -1,
      mon,
    );
    expect(holdsToday(sept, today), isFalse);
    expect(holdsToday(const ReportRange.allTime(), today), isFalse);
    expect(holdsToday(defaultCustomRange(today), today), isTrue);
  });

  group('stored report_range', () {
    test('round trip', () {
      for (final r in [
        const ReportRange.allTime(),
        defaultCustomRange(today),
        const ReportRange(ReportPeriod.range, '2026-10-10', '2026-10-10'),
      ]) {
        expect(decodeCustomRange(encodeCustomRange(r)), r);
      }
      expect(encodeCustomRange(const ReportRange.allTime()), 'all');
    });

    test('anything else → null (the caller uses the default)', () {
      for (final bad in [
        null,
        '',
        'ALL',
        '2026-10-31..2026-10-01',
        '1899-01-01..2026-10-01',
        '2026-10-01..2200-01-02',
        '2026-10-01',
        '2026-10-01..2026-10-02..2026-10-03',
        '2026-02-30..2026-03-01',
        '2026-10-01...2026-10-02',
      ]) {
        expect(decodeCustomRange(bad), isNull, reason: '$bad');
      }
    });
  });

  test('contains: All time holds every day', () {
    expect(const ReportRange.allTime().contains('1900-01-01'), isTrue);
    final oct = currentRange(ReportPeriod.month, today, mon);
    expect(oct.contains('2026-10-31'), isTrue);
    expect(oct.contains('2026-11-01'), isFalse);
    expect(oct.contains('2026-09-30'), isFalse);
  });
}
