import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:money_swield/ui/core/date_texts.dart';

void main() {
  setUpAll(initializeDateFormatting);

  // An expense's wall clock: 12:30 pm on Monday 5 Oct 2026 where it was
  // recorded. Stored as a UTC DateTime whose fields are the clock's.
  final wallClock = DateTime.utc(2026, 10, 5, 12, 30);

  test('the formats on an Indian phone in English', () {
    // intl puts a narrow no-break space before am / pm.
    expect(timeText('en_IN', wallClock), '12:30 pm');
    expect(longDateText('en_IN', wallClock), 'Monday, 5 October 2026');
    expect(shortDateText('en_IN', wallClock), '5 Oct 2026');
  });

  test('Spanish and Hindi', () {
    expect(longDateText('es', wallClock), 'lunes, 5 de octubre de 2026');
    expect(shortDateText('hi', wallClock), contains('2026'));
    expect(timeText('hi', wallClock), contains('12:30'));
  });

  test('a wall clock is shown as given, whatever the time zone', () {
    // Formatting reads the fields; a local DateTime with the same fields
    // reads the same, so no conversion can sneak in.
    final local = DateTime(2026, 10, 5, 12, 30);
    expect(timeText('en_IN', wallClock), timeText('en_IN', local));
    expect(longDateText('en_IN', wallClock), longDateText('en_IN', local));
  });

  test('a moment is shown in the device time zone', () {
    final at = DateTime.utc(2026, 10, 3, 8, 35);
    expect(
      dateTimeText('en_IN', at),
      DateFormat.yMMMd('en_IN').add_jm().format(at.toLocal()),
    );
    // The same instant given as local time reads the same.
    expect(dateTimeText('en_IN', at.toLocal()), dateTimeText('en_IN', at));
  });

  test('cachedDateFormat: one instance per skeleton and locale', () {
    final first = cachedDateFormat('MMMEd', 'en_IN');
    expect(identical(first, cachedDateFormat('MMMEd', 'en_IN')), isTrue);
    expect(identical(first, cachedDateFormat('MMMEd', 'es')), isFalse);
    expect(identical(first, cachedDateFormat('yMMMEd', 'en_IN')), isFalse);
    // The same text as building the named format each time.
    for (final locale in ['en_IN', 'en_US', 'es', 'es_MX', 'hi']) {
      expect(
        cachedDateFormat('MMMEd', locale).format(wallClock),
        DateFormat.MMMEd(locale).format(wallClock),
      );
      expect(
        cachedDateFormat('EEEEE', locale).format(wallClock),
        DateFormat.EEEEE(locale).format(wallClock),
      );
      expect(
        cachedDateFormat('LLLLL', locale).format(wallClock),
        DateFormat('LLLLL', locale).format(wallClock),
      );
    }
  });
}
