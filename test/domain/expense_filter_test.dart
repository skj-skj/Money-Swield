import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';

void main() {
  SearchEntry entry(String title, [String? description]) => (
    id: 1,
    day: '2026-10-05',
    occurredAtMs: 0,
    amountMinor: 100,
    currencyCode: 'INR',
    folded: foldForSearch(title, description),
  );

  bool matches(String text, String title, [String? description]) =>
      matchesText(entry(title, description), searchWords(text));

  test('every case of the text match', () {
    expect(matches('lunch', 'Lunch with Ana'), isTrue);
    expect(matches('LUNCH ana', 'Lunch with Ana'), isTrue);
    expect(matches('café', 'CAFÉ COFFEE DAY'), isTrue);
    expect(matches('potato', 'Groceries', '50 (potato) + 60 (onion)'), isTrue);
    expect(matches('uber air', 'Uber', 'to airport'), isTrue);
    expect(matches('lunchana', 'Lunch with Ana'), isFalse);
    expect(matches('50%', '50% off shoes'), isTrue);
    expect(matches('a_b', 'ab'), isFalse);
    expect(matches('सब्ज़ी', 'सब्ज़ी मंडी'), isTrue);
  });

  test('no wildcards: % and _ and * are plain characters', () {
    expect(matches('5%', '50 off'), isFalse);
    expect(matches('a*', 'abc'), isFalse);
    expect(matches('a*', 'a* rating'), isTrue);
  });

  test('a word never matches across title and description', () {
    expect(matches('uberto', 'Uber', 'to airport'), isFalse);
  });

  test('a newline inside a description is just whitespace for the text', () {
    expect(matches('onion', 'Groceries', 'potato\nonion'), isTrue);
  });

  test('no accent folding', () {
    expect(matches('cafe', 'Café'), isFalse);
  });

  group('searchWords', () {
    test('splits on any whitespace, the no-break space too', () {
      expect(searchWords('a b\tc  d\n'), ['a', 'b', 'c', 'd']);
    });

    test('only whitespace is no text filter', () {
      expect(searchWords('     '), isEmpty);
      expect(const ExpenseFilter(text: '  ').hasText, isFalse);
      expect(const ExpenseFilter(text: '  ').isEmpty, isTrue);
    });

    test('101 characters → the first 100', () {
      final text = 'a' * 100 + 'b';
      expect(searchWords(text), ['a' * 100]);
    });

    test('an emoji at position 100 is kept whole', () {
      // 👨‍👩‍👧 is one character of 5 code points.
      final text = '${'a' * 99}👨‍👩‍👧xyz';
      expect(searchWords(text), ['${'a' * 99}👨‍👩‍👧']);
    });
  });

  test('onlyRecurring: in ==, hashCode, isEmpty, '
      'withoutText, copyWith', () {
    const on = ExpenseFilter(onlyRecurring: true);
    expect(on.isEmpty, isFalse);
    expect(on == ExpenseFilter.none, isFalse);
    expect(on.hashCode == ExpenseFilter.none.hashCode, isFalse);
    expect(on, const ExpenseFilter(onlyRecurring: true));
    expect(
      const ExpenseFilter(text: 'x', onlyRecurring: true).withoutText,
      on,
      reason: 'an SQL part: kept without the text',
    );
    expect(on.copyWith(text: 'y').onlyRecurring, isTrue);
    expect(on.copyWith(onlyRecurring: false), ExpenseFilter.none);
    expect('$on', contains('only recurring'));
  });

  test('ExpenseFilter equality ignores set order', () {
    expect(
      const ExpenseFilter(categoryIds: {1, 2}),
      const ExpenseFilter(categoryIds: {2, 1}),
    );
    expect(
      const ExpenseFilter(categoryIds: {1}),
      isNot(const ExpenseFilter(eventIds: {1})),
    );
  });
}
