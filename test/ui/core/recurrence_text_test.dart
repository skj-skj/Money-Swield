import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_expense_tracker_app/domain/recurrence.dart';
import 'package:my_expense_tracker_app/ui/core/recurrence_text.dart';

import '../../helpers/test_database.dart';

Schedule rule(Frequency f, String start, {int every = 1}) =>
    Schedule(frequency: f, interval: every, startOn: start);

void main() {
  setUpAll(initializeDateFormatting);
  final en = l10nFor('en');
  final es = l10nFor('es');
  final hi = l10nFor('hi');

  group('scheduleText in en', () {
    String text(Schedule s) => scheduleText(en, 'en_IN', s);

    test('daily and weekly', () {
      expect(text(rule(Frequency.daily, '2026-10-09')), 'Every day');
      expect(
        text(rule(Frequency.daily, '2026-10-09', every: 3)),
        'Every 3 days',
      );
      // 2026-10-05 is a Monday.
      expect(
        text(rule(Frequency.weekly, '2026-10-05')),
        'Every week on Monday',
      );
      expect(
        text(rule(Frequency.weekly, '2026-10-05', every: 2)),
        'Every 2 weeks on Monday',
      );
    });

    test('monthly, with the last-day note from the 29th on', () {
      expect(
        text(rule(Frequency.monthly, '2026-10-09')),
        'Every month on day 9',
      );
      expect(
        text(rule(Frequency.monthly, '2026-10-28')),
        'Every month on day 28',
      );
      expect(
        text(rule(Frequency.monthly, '2026-10-30', every: 3)),
        "Every 3 months on day 30 (or the month's last day)",
      );
      expect(
        text(rule(Frequency.monthly, '2026-01-29')),
        "Every month on day 29 (or the month's last day)",
      );
    });

    test('yearly, and 29 Feb', () {
      expect(text(rule(Frequency.yearly, '2026-10-09')), 'Every year on 9 Oct');
      expect(
        text(rule(Frequency.yearly, '2024-02-29')),
        'Every year on 29 Feb (28 Feb in other years)',
      );
      expect(
        text(rule(Frequency.yearly, '2024-02-29', every: 4)),
        'Every 4 years on 29 Feb (28 Feb in other years)',
      );
    });
  });

  test('F14: en writes "Sep 30", en_IN "30 Sept"; the locale is the '
      'formatting one, so tests pin it', () {
    expect(dayText('en', '2026-09-30', today: '2026-10-09'), 'Sep 30');
    expect(dayText('en_IN', '2026-09-30', today: '2026-10-09'), '30 Sept');
  });

  test('Spanish and Hindi weekdays, months and numbers', () {
    expect(
      scheduleText(es, 'es', rule(Frequency.weekly, '2026-10-05')),
      'Cada semana, el lunes',
    );
    expect(
      scheduleText(es, 'es', rule(Frequency.yearly, '2026-10-09', every: 2)),
      'Cada 2 años, el 9 oct',
    );
    final hiWeekly = scheduleText(
      hi,
      'hi',
      rule(Frequency.weekly, '2026-10-05'),
    );
    expect(hiWeekly, contains('सोमवार'));
    expect(
      scheduleText(hi, 'hi', rule(Frequency.monthly, '2026-10-09')),
      'हर महीने की 9 तारीख़ को',
    );
  });

  test('ends, next and the short forms', () {
    expect(endsText(en, 'en_IN', null), 'Never ends');
    expect(endsText(en, 'en_IN', '2026-09-15'), 'Ends 15 Sept 2026');
    expect(
      nextText(en, 'en_IN', '2026-10-31', today: '2026-10-09'),
      'Next: 31 Oct',
    );
    expect(
      nextText(en, 'en_IN', '2027-10-31', today: '2026-10-09'),
      'Next: 31 Oct 2027',
    );
    expect(
      nextText(en, 'en_IN', null, today: '2026-10-09'),
      'No more payments',
    );
    expect(shortScheduleText(en, Frequency.monthly, 1), 'Monthly');
    expect(shortScheduleText(en, Frequency.monthly, 3), 'Every 3 months');
    expect(unitText(en, Frequency.weekly, 1), 'week');
    expect(unitText(en, Frequency.weekly, 2), 'weeks');
    expect(unitText(es, Frequency.monthly, 2), 'meses');
  });

  test('the days list: three, then "and N more"', () {
    final days = [
      '2026-08-31',
      '2026-09-30',
      '2026-10-31',
      '2026-11-30',
      '2026-12-31',
    ];
    expect(
      daysListText(en, 'en_IN', days.take(2).toList(), today: '2026-12-31'),
      '31 Aug, 30 Sept',
    );
    expect(
      daysListText(en, 'en_IN', days, today: '2026-12-31'),
      '31 Aug, 30 Sept, 31 Oct and 2 more',
    );
    expect(
      daysListText(en, 'en_IN', days.take(4).toList(), today: '2026-12-31'),
      '31 Aug, 30 Sept, 31 Oct and 1 more',
    );
  });

  test('numbers are grouped: hi the Indian way', () {
    expect(en.repeatAndMore(1234), 'and 1,234 more');
    expect(hi.repeatTooManyPast(123456, 1000), contains('1,23,456'));
    expect(en.scheduleDaily(1000), 'Every 1,000 days');
  });
}
