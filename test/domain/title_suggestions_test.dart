import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/title_suggestions.dart';

TitleHistoryRow row(
  String title, {
  int recent = 0,
  int day = 1,
  int amount = 100,
  int category = 1,
}) => TitleHistoryRow(
  title: title,
  amountMinor: amount,
  currencyCode: 'INR',
  categoryId: category,
  lastAt: DateTime.utc(2026, 9, day),
  recent: recent,
);

List<String> titles(List<TitleSuggestion> s) => [for (final x in s) x.title];

void main() {
  group('groupTitleHistory', () {
    test('spellings that fold together are one title, shown in the newest', () {
      final grouped = groupTitleHistory([
        row('lunch', recent: 2, day: 1, amount: 100),
        row('Lunch', recent: 3, day: 5, amount: 200),
        row('LUNCH', recent: 1, day: 3, amount: 300),
      ]);
      expect(grouped, hasLength(1));
      final lunch = grouped.single;
      expect(lunch.title, 'Lunch');
      expect(lunch.recent, 6);
      expect(lunch.amountMinor, 200, reason: 'the newest spelling\'s amount');
      expect(lunch.spellings, unorderedEquals(['lunch', 'Lunch', 'LUNCH']));
      expect(lunch.lastAt, DateTime.utc(2026, 9, 5));
    });

    test('a tie on the newest picks the same spelling whatever the order', () {
      final a = groupTitleHistory([row('Tea', day: 2), row('TEA', day: 2)]);
      final b = groupTitleHistory([row('TEA', day: 2), row('Tea', day: 2)]);
      expect(a.single.title, b.single.title);
    });

    test('Unicode folding: CAFÉ and café are one title', () {
      final grouped = groupTitleHistory([row('CAFÉ'), row('café', day: 2)]);
      expect(grouped.single.title, 'café');
    });

    test('Devanagari is left unchanged', () {
      final grouped = groupTitleHistory([row('चाय'), row('खाना')]);
      expect(titles(grouped), unorderedEquals(['चाय', 'खाना']));
      expect(foldTitle('चाय'), 'चाय');
    });
  });

  group('matchTitles', () {
    final history = groupTitleHistory([
      row('Lunch', recent: 1, day: 1),
      row('Late lunch', recent: 9, day: 9),
      row('Lunch box', recent: 5, day: 2),
      row('Lunar gift', recent: 5, day: 3),
      row('Tea', recent: 20, day: 20),
    ]);

    test('prefix matches come before contains, whatever their counts', () {
      expect(titles(matchTitles(history, 'lun')), [
        'Lunar gift', // 5 uses, newer
        'Lunch box', // 5 uses
        'Lunch', // 1 use
        'Late lunch', // contains, 9 uses
      ]);
    });

    test('an exact match is still listed', () {
      expect(titles(matchTitles(history, 'Tea')), ['Tea']);
    });

    test('blank or whitespace text suggests nothing', () {
      expect(matchTitles(history, ''), isEmpty);
      expect(matchTitles(history, '   '), isEmpty);
    });

    test('typed text is trimmed and folded', () {
      expect(titles(matchTitles(history, '  TEA ')), ['Tea']);
    });

    test('at most 5', () {
      final many = groupTitleHistory([
        for (var i = 0; i < 9; i++) row('Item $i', recent: i, day: i + 1),
      ]);
      expect(titles(matchTitles(many, 'item')), [
        'Item 8',
        'Item 7',
        'Item 6',
        'Item 5',
        'Item 4',
      ]);
    });

    test('ties go by most recent, then by folded title', () {
      final tied = groupTitleHistory([
        row('b', recent: 1, day: 1),
        row('a', recent: 1, day: 1),
        row('c', recent: 1, day: 2),
      ]);
      expect(titles(matchTitles(tied, ' ')), isEmpty);
      final abc = groupTitleHistory([
        row('xb', recent: 1, day: 1),
        row('xa', recent: 1, day: 1),
        row('xc', recent: 1, day: 2),
      ]);
      expect(titles(matchTitles(abc, 'x')), ['xc', 'xa', 'xb']);
    });

    test('CAFÉ is found by typing café and the other way round', () {
      final cafe = groupTitleHistory([row('CAFÉ')]);
      expect(titles(matchTitles(cafe, 'café')), ['CAFÉ']);
      expect(titles(matchTitles(groupTitleHistory([row('café')]), 'CAFÉ')), [
        'café',
      ]);
    });

    test('Devanagari matches by contains', () {
      final hindi = groupTitleHistory([row('सुबह की चाय')]);
      expect(titles(matchTitles(hindi, 'चाय')), ['सुबह की चाय']);
    });

    test('regex characters typed are plain text', () {
      final odd = groupTitleHistory([row('50% off (sale)'), row('a.b')]);
      expect(titles(matchTitles(odd, '(sale')), ['50% off (sale)']);
      expect(titles(matchTitles(odd, '.')), ['a.b']);
      expect(matchTitles(odd, '_'), isEmpty);
    });
  });
}
