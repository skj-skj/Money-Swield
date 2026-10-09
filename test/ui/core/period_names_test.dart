import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/ui/core/money_formatter.dart';
import 'package:my_expense_tracker_app/ui/core/period_names.dart';

import '../../helpers/test_database.dart';

/// phase-5.md §8.3 names, with a fixed today of Mon 5 Oct 2026.
void main() {
  setUpAll(initializeDateFormatting);

  PeriodNames names({
    String language = 'en',
    String locale = 'en_IN',
    WeekLabel label = WeekLabel.month,
  }) => PeriodNames(
    l10n: l10nFor(language),
    locale: locale,
    today: '2026-10-05',
    weekLabel: label,
  );

  PeriodRange week(String day) => periodOf(day, Period.week, WeekStart.monday);

  test('days: no Today, the year only in another year', () {
    expect(names().day('2026-10-04'), 'Sun, 4 Oct');
    expect(names().day('2026-10-05'), 'Mon, 5 Oct');
    expect(names(locale: 'en_US').day('2026-10-04'), 'Sun, Oct 4');
    expect(names().day('2025-12-31'), 'Wed, 31 Dec, 2025');
  });

  test('weeks named by month (the default)', () {
    expect(names().week(week('2026-10-05')), 'Oct Week 2');
    expect(names().week(week('2026-10-01')), 'Oct Week 1');
    expect(names().week(week('2025-12-24')), 'Dec 2025 Week 4');
    expect(
      names().week(week('2025-12-31')),
      'Jan Week 1',
      reason: '29 Dec 2025 – 4 Jan 2026 belongs to its 4th day, 1 Jan',
    );
  });

  test('weeks named by number', () {
    final byNumber = names(label: WeekLabel.number);
    expect(byNumber.week(week('2026-10-05')), 'Week 41');
    expect(byNumber.week(week('2025-12-24')), 'Week 52, 2025');
  });

  test('months and years', () {
    expect(names().month('2026-10-05'), 'Oct');
    expect(names().month('2026-09-05'), 'Sept', reason: "en_IN's own data");
    expect(names(locale: 'en_US').month('2025-09-05'), 'Sep 2025');
    expect(
      names().of(periodOf('2026-10-05', Period.year, WeekStart.monday)),
      '2026',
    );
    expect(
      names().of(periodOf('2025-10-05', Period.year, WeekStart.monday)),
      '2025',
    );
  });

  test('Spanish starts with a capital letter (R13)', () {
    final es = names(language: 'es', locale: 'es');
    expect(es.day('2026-10-05'), 'Lun, 5 oct');
    expect(es.month('2026-10-05'), 'Oct');
    expect(es.week(week('2026-10-05')), 'Semana 2 de oct');
  });

  test('Hindi in Devanagari', () {
    final hi = names(language: 'hi', locale: 'hi');
    expect(hi.day('2026-10-05'), 'सोम, 5 अक्टू॰');
    expect(hi.week(week('2026-10-05')), 'अक्टू॰ सप्ताह 2');
  });

  test('totalsText: default first, then by code; spoken with "and"', () {
    final l10n = l10nFor('en');
    final formatter = MoneyFormatter.forLocale('en_IN');
    final totals = {
      'USD': BigInt.from(8500),
      'INR': BigInt.from(456000),
      'EUR': BigInt.one,
    };
    expect(
      totalsText(l10n, formatter, totals, 'INR'),
      '₹4,560.00 + €0.01 + \$85.00',
    );
    expect(
      totalsText(l10n, formatter, {'INR': BigInt.one}, 'INR', spoken: true),
      '₹0.01',
    );
    expect(
      totalsText(l10n, formatter, totals, 'INR', spoken: true),
      '₹4,560.00 and €0.01 and \$85.00',
    );
    final tooLarge = BigInt.parse('9223372036854775808') * BigInt.from(100);
    expect(totalsText(l10n, formatter, {'INR': tooLarge}, 'INR'), 'Too large');
  });

  test('monthWithYear always has the year (phase-6.md §8.9)', () {
    expect(names().monthWithYear('2026-10-05'), 'Oct 2026');
    expect(names().monthWithYear('2025-09-01'), 'Sept 2025');
    expect(names(locale: 'en_US').monthWithYear('2025-09-01'), 'Sep 2025');
    expect(
      names(language: 'es', locale: 'es_ES').monthWithYear('2026-10-05'),
      startsWith('Oct'),
      reason: 'sentence-cased: intl writes "oct 2026"',
    );
    expect(
      names(language: 'hi', locale: 'hi').monthWithYear('2026-10-05'),
      contains('2026'),
    );
  });
}
