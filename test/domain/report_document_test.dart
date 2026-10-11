import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/domain/report.dart';
import 'package:my_expense_tracker_app/domain/report_document.dart';
import 'package:my_expense_tracker_app/domain/report_range.dart';

/// phase-8.md §6.6 file names (P8-20).
void main() {
  const mon = WeekStart.monday;
  const today = '2026-10-10';

  String name(ReportRange r, [ReportExport f = ReportExport.pdf]) =>
      reportFileName(r, f, mon, today);

  test('month, year, range, All time', () {
    expect(
      name(currentRange(ReportPeriod.month, today, mon)),
      'expense-report-2026-10.pdf',
    );
    expect(
      name(currentRange(ReportPeriod.year, today, mon), ReportExport.xlsx),
      'expense-report-2026.xlsx',
    );
    expect(
      name(defaultCustomRange(today)),
      'expense-report-20251101-20261031.pdf',
    );
    expect(
      name(const ReportRange.allTime()),
      'expense-report-all-20261010.pdf',
    );
  });

  test('weeks by weekIdOf: 29 Dec 2025 – 4 Jan 2026 is 2026-W01', () {
    expect(
      name(currentRange(ReportPeriod.week, '2026-01-01', mon)),
      'expense-report-2026-W01.pdf',
    );
    expect(
      name(currentRange(ReportPeriod.week, today, mon)),
      'expense-report-2026-W41.pdf',
    );
  });

  test('ASCII only', () {
    for (final r in [
      currentRange(ReportPeriod.week, '1900-01-01', mon),
      const ReportRange.allTime(),
    ]) {
      expect(RegExp(r'^[\x21-\x7e]+$').hasMatch(name(r)), isTrue);
    }
  });

  group('sheetNames (F9; sections are user-named)', () {
    test('forbidden characters, quotes, 31 characters, empty, History', () {
      expect(sheetNames([r'a/b\c?d*e[f]g:h']), ['a-b-c-d-e-f-g-h']);
      expect(sheetNames(["'Quoted'"]), ['Quoted']);
      expect(sheetNames(['x' * 40]).single.length, 31);
      expect(sheetNames(['  ']), ['Sheet 1']);
      expect(sheetNames(['History']), ['History (2)']);
    });

    test('repeats get (2), (3), ignoring case, still ≤ 31', () {
      expect(sheetNames(['Food', 'food', 'FOOD']), [
        'Food',
        'food (2)',
        'FOOD (3)',
      ]);
      final long = sheetNames(['y' * 40, 'y' * 40]);
      expect(long[1].length, lessThanOrEqualTo(31));
      expect(long[1], endsWith(' (2)'));
    });

    test('an emoji at the cut is not split', () {
      final name = sheetNames(['${'a' * 30}🍔']).single;
      expect(name, 'a' * 30);
      expect(sheetNames(['💍 Wedding']), ['💍 Wedding']);
    });

    test('the overall sheet, first, keeps its name', () {
      expect(sheetNames(['Overall', 'Overall']), ['Overall', 'Overall (2)']);
    });
  });

  test('export options: sections and their chart dimension', () {
    expect(
      const ReportExportOptions(groupBy: GroupDimension.event).grouping,
      const ReportGrouping(GroupDimension.event, then: GroupDimension.category),
    );
    expect(
      const ReportExportOptions().grouping,
      const ReportGrouping(GroupDimension.category, then: GroupDimension.event),
    );
    expect(
      const ReportExportOptions(groupBy: GroupDimension.paymentMethod)
          .grouping
          .then,
      GroupDimension.category,
    );
  });
}
