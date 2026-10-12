import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/saved_picture.dart';

void main() {
  String name(String title, {String day = '2026-10-01', String ext = 'jpg'}) =>
      savedPictureName(
        title: title,
        day: day,
        extension: ext,
        fallbackTitle: 'Expense',
      );

  group('every name case', () {
    test('Lunch', () {
      expect(name('Lunch', day: '2026-10-05'), 'Lunch 2026-10-05.jpg');
    });
    test('forbidden characters go', () {
      expect(name('Rent: Oct/Nov'), 'Rent OctNov 2026-10-01.jpg');
    });
    test('only spaces → Expense', () {
      expect(name('  '), 'Expense 2026-10-01.jpg');
    });
    test('a leading dot (a hidden file) goes', () {
      expect(name('.hidden'), 'hidden 2026-10-01.jpg');
      expect(name('...  x'), 'x 2026-10-01.jpg');
    });
    test('80 × a → 60 × a', () {
      expect(name('a' * 80), '${'a' * 60} 2026-10-01.jpg');
    });
    test('Hindi', () {
      expect(
        name('सब्ज़ी मंडी', day: '2026-10-05'),
        'सब्ज़ी मंडी 2026-10-05.jpg',
      );
    });
    test('emoji', () {
      expect(name('🍕 Pizza', day: '2026-10-05'), '🍕 Pizza 2026-10-05.jpg');
    });
  });

  test('every forbidden character, and control characters', () {
    expect(name(r'a/b\c:d*e?f"g<h>i|j'), 'abcdefghij 2026-10-01.jpg');
    expect(
      name('a\u0000b\u001Fc\u007Fd\te'),
      'abcde 2026-10-01.jpg',
      reason: 'a tab is a control character, not a space',
    );
    expect(name(r'/\:*?"<>|'), 'Expense 2026-10-01.jpg');
  });

  test('spaces collapse, newlines too', () {
    expect(name('  Taxi \n  home  '), 'Taxi home 2026-10-01.jpg');
  });

  test('a grapheme cluster at character 60 is kept whole', () {
    // 59 letters, then a family emoji of several code points.
    final title = '${'a' * 59}👨‍👩‍👧‍👦tail';
    final cut = name(title).replaceAll(' 2026-10-01.jpg', '');
    expect(cut.characters.length, 60);
    expect(cut.characters.last, '👨‍👩‍👧‍👦');
  });

  test('a cut that ends in a space drops it', () {
    expect(name('${'a' * 59} bcd'), '${'a' * 59} 2026-10-01.jpg');
  });

  test('the extension and a future-dated expense\'s day are kept', () {
    expect(name('X', day: '2030-01-31', ext: 'png'), 'X 2030-01-31.png');
  });

  test('EXIF date and offset', () {
    expect(
      exifDateTime(DateTime.utc(2026, 10, 5, 9, 3, 7)),
      '2026:10:05 09:03:07',
    );
    expect(exifOffset(330), '+05:30');
    expect(exifOffset(-210), '-03:30');
    expect(exifOffset(0), '+00:00');
    expect(exifOffset(840), '+14:00');
  });
}
