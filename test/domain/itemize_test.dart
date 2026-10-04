import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/amount_expression.dart';
import 'package:my_expense_tracker_app/domain/itemize.dart';

List<String> termsOf(String canonical) =>
    (evaluateExpression(canonical, minorDigits: 2) as ExpressionValue).terms;

void main() {
  group('buildItemizeLine: the §5.2 table', () {
    test('every term labelled', () {
      expect(
        buildItemizeLine(termsOf('50+60*2'), ['potato', 'onion'], '.'),
        '50 (potato) + 60 × 2 (onion)',
      );
    });

    test('an empty label leaves the term bare', () {
      expect(
        buildItemizeLine(termsOf('50+60*2'), ['', 'onion'], '.'),
        '50 + 60 × 2 (onion)',
      );
      expect(
        buildItemizeLine(termsOf('50+60*2'), ['  ', 'onion'], '.'),
        '50 + 60 × 2 (onion)',
        reason: 'blank counts as empty',
      );
    });

    test('a minus term', () {
      expect(
        buildItemizeLine(termsOf('50+60-20'), [
          'potato',
          'onion',
          'discount',
        ], '.'),
        '50 (potato) + 60 (onion) − 20 (discount)',
      );
    });

    test('labels are trimmed; the locale separator is used', () {
      expect(
        buildItemizeLine(termsOf('1.5*2+0.5'), [' a ', 'b'], ','),
        '1,5 × 2 (a) + 0,5 (b)',
      );
    });
  });

  group('parseItemizeLine', () {
    test('recognises a built line and recovers the labels', () {
      final terms = termsOf('50+60*2-20');
      final line = buildItemizeLine(terms, ['potato', '', 'discount'], '.');
      expect(parseItemizeLine(line, terms), ['potato', '', 'discount']);
    });

    test('accepts either decimal separator (a language change)', () {
      final terms = termsOf('1.5*2+0.5');
      expect(parseItemizeLine('1,5 × 2 (a) + 0,5 (b)', terms), ['a', 'b']);
      expect(parseItemizeLine('1.5 × 2 (a) + 0.5 (b)', terms), ['a', 'b']);
    });

    test('a label with brackets inside survives', () {
      final terms = termsOf('50+60');
      final line = buildItemizeLine(terms, ['milk (2L)', 'eggs'], '.');
      expect(line, '50 (milk (2L)) + 60 (eggs)');
      expect(parseItemizeLine(line, terms), ['milk (2L)', 'eggs']);
    });

    test('rejects an edited line', () {
      final terms = termsOf('50+60*2');
      for (final edited in [
        '50 (potato) + 60 × 2 (onion) and more',
        '50 (potato) + 60 × 3 (onion)',
        '50 (potato) +60 × 2 (onion)',
        'x 50 (potato) + 60 × 2 (onion)',
        '50 (potato) + 60 × 2 ()',
        '',
      ]) {
        expect(parseItemizeLine(edited, terms), isNull, reason: edited);
      }
    });

    test('rejects the line of other terms', () {
      final line = buildItemizeLine(termsOf('50+60'), ['a', 'b'], '.');
      expect(parseItemizeLine(line, termsOf('50+70')), isNull);
      expect(parseItemizeLine(line, termsOf('50+60+1')), isNull);
    });

    test('a decimal point is not a wildcard', () {
      expect(parseItemizeLine('1x5 + 2', termsOf('1.5+2')), isNull);
    });
  });

  group('putItemizeLine', () {
    test('into an empty description', () {
      expect(putItemizeLine('', 'L', null), 'L');
    });

    test('replaces an unchanged first line', () {
      expect(putItemizeLine('old\nnotes', 'new', 'old'), 'new\nnotes');
      expect(putItemizeLine('old', 'new', 'old'), 'new');
    });

    test('adds above an edited first line', () {
      expect(putItemizeLine('old!\nnotes', 'new', 'old'), 'new\nold!\nnotes');
      expect(putItemizeLine('notes', 'new', null), 'new\nnotes');
    });

    test('firstLineOf', () {
      expect(firstLineOf('a\nb'), 'a');
      expect(firstLineOf('a'), 'a');
      expect(firstLineOf(''), '');
    });
  });

  test('itemizeTermLabel: the sheet row labels', () {
    final terms = termsOf('50+60*2-10');
    expect(
      [for (final t in terms) itemizeTermLabel(t, '.')],
      ['50', '60 × 2', '−10'],
    );
    expect(itemizeTermLabel('-1.5*2', ','), '−1,5 × 2');
  });
}
