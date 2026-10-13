import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/amount_expression.dart';
import 'package:money_swield/domain/amount_field_input.dart';

/// `|` marks the cursor, `[…]` a selection, in these tests' strings.
FieldEdit parse(String marked) {
  final open = marked.indexOf('[');
  if (open >= 0) {
    final close = marked.indexOf(']');
    final text = marked.replaceAll('[', '').replaceAll(']', '');
    return (text: text, base: open, extent: close - 1);
  }
  final cursor = marked.indexOf('|');
  return (text: marked.replaceAll('|', ''), base: cursor, extent: cursor);
}

String show(FieldEdit? edit) {
  if (edit == null) return 'ignored';
  if (edit.base == edit.extent) {
    return '${edit.text.substring(0, edit.base)}|'
        '${edit.text.substring(edit.base)}';
  }
  final start = edit.base < edit.extent ? edit.base : edit.extent;
  final end = edit.base < edit.extent ? edit.extent : edit.base;
  return '${edit.text.substring(0, start)}['
      '${edit.text.substring(start, end)}]${edit.text.substring(end)}';
}

String key(String marked, RowKey key, [String separator = '.']) =>
    show(applyRowKey(parse(marked), key, separator));

String typed(String marked) => show(filterKeyboardEdit(parse(marked)));

void main() {
  group('keyboard edits', () {
    test('ASCII operators map to the field symbols', () {
      expect(typed('50-|'), '50−|');
      expect(typed('50*|'), '50×|');
      expect(typed('50x|'), '50×|');
      expect(typed('50X|'), '50×|');
      expect(typed('50/|'), '50÷|');
      expect(typed('50+|'), '50+|');
    });

    test('digits, separators and the symbols are kept', () {
      expect(typed('1.5,2+3−4×5÷6|'), '1.5,2+3−4×5÷6|');
    });

    test('a letter or a Devanagari digit refuses the whole edit', () {
      expect(typed('50a|'), 'ignored');
      expect(typed('5०|'), 'ignored');
      expect(typed('5#|'), 'ignored');
      expect(typed('50+😀|'), 'ignored');
      expect(typed('50\n|'), 'ignored');
    });

    test('spaces are dropped; a paste of `50 + 60` becomes `50+60`', () {
      expect(typed('50 + 60|'), '50+60|');
      expect(typed(' 5|'), '5|');
    });

    test(
      'an edit in the middle keeps the cursor where the keyboard put it',
      () {
        expect(typed('5*|0+60'), '5×|0+60');
        expect(typed('5 |0+60'), '5|0+60', reason: 'a dropped space');
        expect(typed('5 0+|60'), '50+|60', reason: 'moved past the space');
        expect(typed('50+[6 0]'), '50+[60]');
      },
    );

    test('101 characters are refused, 100 accepted', () {
      final hundred = List.filled(100, '1').join();
      expect(
        filterKeyboardEdit((text: hundred, base: 100, extent: 100))?.text,
        hundred,
      );
      expect(
        filterKeyboardEdit((text: '${hundred}1', base: 101, extent: 101)),
        isNull,
      );
      expect(
        filterKeyboardEdit((text: '$hundred ', base: 101, extent: 101))?.text,
        hundred,
        reason: 'the space is dropped first',
      );
    });

    test('a text already over the limit (a damaged draft) can be deleted '
        'down, never grown', () {
      final long = List.filled(103, '1').join();
      expect(
        filterKeyboardEdit((
          text: long.substring(1),
          base: 0,
          extent: 0,
        ), previousLength: 103)?.text,
        long.substring(1),
      );
      expect(
        filterKeyboardEdit((
          text: '${long}1',
          base: 104,
          extent: 104,
        ), previousLength: 103),
        isNull,
      );
      expect(
        filterKeyboardEdit((
          text: long,
          base: 0,
          extent: 0,
        ), previousLength: 103),
        isNull,
        reason: 'same length, still over: nothing to allow',
      );
    });

    test('no selection (-1) is kept as is', () {
      expect(filterKeyboardEdit((text: '5-', base: -1, extent: -1)), (
        text: '5−',
        base: -1,
        extent: -1,
      ));
    });

    test('the result reads back as the same canonical text', () {
      final edit = filterKeyboardEdit(parse('50+60*2-10/5|'))!;
      expect(fieldToCanonical(edit.text), '50+60*2-10/5');
    });
  });

  group('operator row', () {
    test('inserts at the cursor in the middle', () {
      expect(key('50|60', RowKey.plus), '50+|60');
      expect(key('5|0+60', RowKey.times), '5×|0+60');
    });

    test('replaces a selection', () {
      expect(key('5[00]', RowKey.plus), '5+|');
      expect(key('[500]', RowKey.plus), 'ignored', reason: 'at the start');
      expect(key('5[0]0', RowKey.decimal), '5.|0');
    });

    test('an operator at the start is ignored', () {
      for (final k in [
        RowKey.plus,
        RowKey.minus,
        RowKey.times,
        RowKey.divide,
      ]) {
        expect(key('|', k), 'ignored');
        expect(key('|50', k), 'ignored');
      }
    });

    test('an operator right after an operator replaces it', () {
      expect(key('50+|', RowKey.times), '50×|');
      expect(key('50+|60', RowKey.minus), '50−|60');
      expect(key('50÷|', RowKey.divide), '50÷|');
    });

    test('an operator right after the cursor is replaced too', () {
      expect(key('50|+60', RowKey.times), '50×|60');
      expect(key('50+|+60', RowKey.minus), '50−|60');
      expect(key('5|+', RowKey.divide), '5÷|');
      expect(key('|+60', RowKey.times), 'ignored', reason: 'at the start');
    });

    test('no cursor yet types at the end', () {
      expect(
        show(applyRowKey((text: '50', base: -1, extent: -1), RowKey.plus, '.')),
        '50+|',
      );
    });

    test('a second decimal in the same number is ignored', () {
      expect(key('5.5|', RowKey.decimal), 'ignored');
      expect(key('5|.5', RowKey.decimal), 'ignored');
      expect(
        key('5,5|', RowKey.decimal),
        'ignored',
        reason: 'either separator',
      );
      expect(
        key('5.5+6|', RowKey.decimal),
        '5.5+6.|',
        reason: 'another number',
      );
      expect(key('5|+6.5', RowKey.decimal), '5.|+6.5');
    });

    test('decimal at the start or after an operator inserts 0 first', () {
      expect(key('|', RowKey.decimal), '0.|');
      expect(key('50+|', RowKey.decimal), '50+0.|');
      expect(key('50+|', RowKey.decimal, ','), '50+0,|');
    });

    test('es inserts `,`', () {
      expect(key('5|', RowKey.decimal, ','), '5,|');
    });

    test('ignored at 100 characters', () {
      final hundred = List.filled(100, '1').join();
      for (final k in RowKey.values) {
        expect(
          applyRowKey((text: hundred, base: 100, extent: 100), k, '.'),
          isNull,
          reason: '$k',
        );
      }
      final ninetyNine = hundred.substring(1);
      expect(
        applyRowKey(
          (text: '$ninetyNine+', base: 100, extent: 100),
          RowKey.times,
          '.',
        )?.text,
        '$ninetyNine×',
        reason: 'replacing keeps the length',
      );
      expect(
        applyRowKey(
          (text: '$ninetyNine+', base: 100, extent: 100),
          RowKey.decimal,
          '.',
        ),
        isNull,
        reason: '`0.` would make 102',
      );
    });

    test('the result evaluates as typed', () {
      var edit = parse('50|');
      edit = applyRowKey(edit, RowKey.plus, '.')!;
      edit = (text: '${edit.text}60', base: 5, extent: 5);
      edit = applyRowKey(edit, RowKey.times, '.')!;
      edit = (text: '${edit.text}2', base: 7, extent: 7);
      expect(edit.text, '50+60×2');
      expect(
        (evaluateExpression(
          fieldToCanonical(edit.text),
          minorDigits: 2,
        ) as ExpressionValue).amountMinor,
        17000,
      );
    });
  });
}
