import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';

void main() {
  String range(String day, Period period, [WeekStart s = WeekStart.monday]) {
    final r = periodOf(day, period, s);
    return '${r.from} … ${r.to}';
  }

  group('periodOf', () {
    test('every period kind', () {
      expect(range('2026-10-05', Period.day), '2026-10-05 … 2026-10-05');
      expect(range('2026-10-04', Period.week), '2026-09-28 … 2026-10-04');
      expect(
        range('2026-10-04', Period.week, WeekStart.sunday),
        '2026-10-04 … 2026-10-10',
      );
      expect(range('2026-10-05', Period.week), '2026-10-05 … 2026-10-11');
      expect(range('2025-12-31', Period.week), '2025-12-29 … 2026-01-04');
      expect(range('2026-03-29', Period.week), '2026-03-23 … 2026-03-29');
      expect(range('2028-02-10', Period.month), '2028-02-01 … 2028-02-29');
      expect(range('2026-02-10', Period.month), '2026-02-01 … 2026-02-28');
      expect(range('2026-10-05', Period.year), '2026-01-01 … 2026-12-31');
    });

    test('a Sunday start, for every weekday of one week', () {
      for (var day = 4; day <= 10; day++) {
        expect(
          range(
            '2026-10-${'$day'.padLeft(2, '0')}',
            Period.week,
            WeekStart.sunday,
          ),
          '2026-10-04 … 2026-10-10',
          reason: 'Oct $day',
        );
      }
    });

    test("the weeks of Spain's DST days have 7 days", () {
      for (final day in ['2026-03-29', '2026-10-25']) {
        for (final start in WeekStart.values) {
          expect(daysIn(periodOf(day, Period.week, start)), hasLength(7));
        }
      }
    });

    test('the week of 1 January', () {
      expect(range('2027-01-01', Period.week), '2026-12-28 … 2027-01-03');
      expect(
        range('2027-01-01', Period.week, WeekStart.sunday),
        '2026-12-27 … 2027-01-02',
      );
    });
  });

  test('previousPeriod across a year and a February', () {
    String previous(String day, Period period) {
      final r = previousPeriod(
        periodOf(day, period, WeekStart.monday),
        WeekStart.monday,
      );
      return '${r.from} … ${r.to}';
    }

    expect(previous('2026-01-02', Period.week), '2025-12-22 … 2025-12-28');
    expect(previous('2026-03-15', Period.month), '2026-02-01 … 2026-02-28');
    expect(previous('2026-01-15', Period.month), '2025-12-01 … 2025-12-31');
    expect(previous('2026-06-01', Period.year), '2025-01-01 … 2025-12-31');
  });

  test('daysIn lengths', () {
    int days(String day, Period p) =>
        daysIn(periodOf(day, p, WeekStart.monday)).length;
    expect(days('2026-10-05', Period.week), 7);
    expect(days('2026-02-01', Period.month), 28);
    expect(days('2028-02-01', Period.month), 29);
    expect(days('2026-04-01', Period.month), 30);
    expect(days('2026-10-01', Period.month), 31);
    expect(days('2026-10-01', Period.year), 365);
    expect(days('2028-10-01', Period.year), 366);
    expect(
      daysIn(periodOf('2026-10-05', Period.week, WeekStart.monday)).first,
      '2026-10-05',
    );
  });

  test('the card turns wrap both ways and never give day', () {
    expect(nextCardPeriod(Period.week), Period.month);
    expect(nextCardPeriod(Period.month), Period.year);
    expect(nextCardPeriod(Period.year), Period.week);
    expect(previousCardPeriod(Period.week), Period.year);
    expect(previousCardPeriod(Period.year), Period.month);
    expect(previousCardPeriod(Period.month), Period.week);
    for (final p in Period.values) {
      expect(nextCardPeriod(p), isNot(Period.day));
      expect(previousCardPeriod(p), isNot(Period.day));
    }
  });

  test('cardPeriodAfter turns any number of faces, wrapping', () {
    expect(cardPeriodAfter(Period.month, 0), Period.month);
    expect(cardPeriodAfter(Period.month, 1), Period.year);
    expect(cardPeriodAfter(Period.month, 2), Period.week);
    expect(cardPeriodAfter(Period.month, 3), Period.month);
    expect(cardPeriodAfter(Period.month, 7), Period.year);
    expect(cardPeriodAfter(Period.month, -1), Period.week);
    expect(cardPeriodAfter(Period.month, -2), Period.year);
    expect(cardPeriodAfter(Period.month, -3), Period.month);
    expect(cardPeriodAfter(Period.week, -4), Period.year);
  });

  test('todayOn is the local date, built in any zone', () {
    expect(todayOn(DateTime(2026, 10, 5, 23, 59)), '2026-10-05');
    expect(todayOn(DateTime(2026, 10, 6)), '2026-10-06');
  });

  group('weekIdOf', () {
    ({int year, int month, int number, int numberInMonth}) id(
      String day, [
      WeekStart start = WeekStart.monday,
    ]) => weekIdOf(periodOf(day, Period.week, start));

    test('every week-number case', () {
      expect(id('2026-10-05'), (
        year: 2026,
        month: 10,
        number: 41,
        numberInMonth: 2,
      ));
      expect(id('2026-10-01'), (
        year: 2026,
        month: 10,
        number: 40,
        numberInMonth: 1,
      ));
      expect(id('2026-10-01', WeekStart.sunday), (
        year: 2026,
        month: 9,
        number: 39,
        numberInMonth: 5,
      ));
      expect(id('2026-08-12'), (
        year: 2026,
        month: 8,
        number: 33,
        numberInMonth: 2,
      ));
      expect(id('2025-12-31'), (
        year: 2026,
        month: 1,
        number: 1,
        numberInMonth: 1,
      ));
      expect(id('2025-12-31', WeekStart.sunday), (
        year: 2025,
        month: 12,
        number: 53,
        numberInMonth: 5,
      ));
      expect(id('2027-01-01'), (
        year: 2026,
        month: 12,
        number: 53,
        numberInMonth: 5,
      ));
    });

    test('with a Monday start, ISO 8601 for every week 2020–2030', () {
      // ISO weeks of the Thursdays of 2020–2030 come from the rule that
      // week 1 holds the year's first Thursday, independent of the code:
      // count Thursdays from the first one of each ISO year.
      var monday = DateTime.utc(2019, 12, 30); // ISO 2020-W01 starts here.
      var isoYear = 2020;
      var isoWeek = 1;
      while (monday.isBefore(DateTime.utc(2031))) {
        final thursday = monday.add(const Duration(days: 3));
        if (thursday.year != isoYear) {
          isoYear = thursday.year;
          isoWeek = 1;
        }
        final got = id(isoDay(monday));
        expect(
          (got.year, got.number),
          (isoYear, isoWeek),
          reason: isoDay(monday),
        );
        monday = monday.add(const Duration(days: 7));
        isoWeek++;
      }
    });

    test('53-week years, and a month with 5 weeks', () {
      expect(id('2020-12-31').number, 53);
      expect(id('2026-12-31').number, 53);
      expect(id('2021-12-31').number, 52);
      // October 2026 holds five Thursdays: weeks 1–5 of October.
      expect(id('2026-10-29').numberInMonth, 5);
      expect(id('2026-10-29').month, 10);
    });
  });
}
