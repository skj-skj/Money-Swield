import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/services/xlsx/xlsx_writer.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';

/// phase-8.md §6.5 and §12 "Xlsx writer": decode the zip, read the XML.
void main() {
  Map<String, String> parts(XlsxWorkbook book) {
    final archive = ZipDecoder().decodeBytes(writeXlsx(book));
    return {
      for (final file in archive.files)
        file.name: utf8.decode(file.content as List<int>),
    };
  }

  String sheetOf(List<List<XlsxCell?>> rows) =>
      parts(XlsxWorkbook([XlsxSheet('S', rows)]))['xl/worksheets/sheet1.xml']!;

  /// The `<c …>…</c>` of cell A1.
  String a1(XlsxCell cell) {
    final xml = sheetOf([
      [cell],
    ]);
    return RegExp(r'<c r="A1"[^>]*>[\s\S]*?</c>').firstMatch(xml)!.group(0)!;
  }

  String? valueOf(String cell) =>
      RegExp(r'<v>([^<]*)</v>').firstMatch(cell)?.group(1);
  String? textOf(String cell) =>
      RegExp(r'<t[^>]*>([^<]*)</t>').firstMatch(cell)?.group(1);
  bool isText(String cell) => cell.contains('t="inlineStr"');

  test('the parts, content types, cellStyles', () {
    final p = parts(
      const XlsxWorkbook([
        XlsxSheet('Summary', [
          [TextCell('x')],
        ]),
        XlsxSheet('Expenses', [
          [TextCell('y')],
        ]),
      ]),
    );
    expect(p.keys.toSet(), {
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/_rels/workbook.xml.rels',
      'xl/styles.xml',
      'xl/worksheets/sheet1.xml',
      'xl/worksheets/sheet2.xml',
    });
    expect(p['[Content_Types].xml'], contains('/xl/worksheets/sheet2.xml'));
    expect(p['xl/styles.xml'], contains('<cellStyles'));
    expect(p['xl/workbook.xml'], contains('name="Summary"'));
    expect(p['xl/workbook.xml'], contains('name="Expenses"'));
    expect(p['xl/_rels/workbook.xml.rels'], contains('styles.xml'));
    for (final xml in p.values) {
      expect(xml, startsWith('<?xml'));
    }
  });

  group('AmountCell', () {
    String amount(int minor, int digits) =>
        valueOf(a1(AmountCell(BigInt.from(minor), digits)))!;

    test('spliced from the integer', () {
      expect(amount(11050, 2), '110.50');
      expect(amount(500, 0), '500');
      expect(amount(1234, 3), '1.234');
      expect(amount(1, 2), '0.01');
      expect(amount(0, 2), '0.00');
      expect(amount(0, 0), '0');
      expect(amount(5, 3), '0.005');
    });

    test('15 significant digits a number, 16 text with every digit', () {
      final fifteen = a1(AmountCell(BigInt.parse('123456789012345'), 2));
      expect(isText(fifteen), isFalse);
      expect(valueOf(fifteen), '1234567890123.45');
      final sixteen = a1(AmountCell(BigInt.parse('1234567890123456'), 2));
      expect(isText(sixteen), isTrue);
      expect(textOf(sixteen), '12345678901234.56');
      // Trailing zeros aren't significant: still a number.
      final round = a1(AmountCell(BigInt.parse('1000000000000000000'), 2));
      expect(isText(round), isFalse);
    });

    test('2⁶³ − 1 (2 digits) → text; beyond → text, every digit', () {
      final max = a1(AmountCell(BigInt.parse('9223372036854775807'), 2));
      expect(textOf(max), '92233720368547758.07');
      final beyond = a1(
        AmountCell(BigInt.parse('9223372036854775807') * BigInt.from(3), 2),
      );
      expect(textOf(beyond), '276701161105643274.21');
    });

    test('the style follows the digits', () {
      expect(a1(AmountCell(BigInt.one, 0)), contains('s="2"'));
      expect(a1(AmountCell(BigInt.one, 2)), contains('s="3"'));
      expect(a1(AmountCell(BigInt.one, 3)), contains('s="4"'));
      expect(a1(AmountCell(BigInt.one, 2, bold: true)), contains('s="8"'));
    });

    test('the decimal is "." whatever the app language', () {
      // Nothing in the writer reads a locale; the es test is the same.
      expect(decimalOf(BigInt.from(11050), 2), '110.50');
      expect(decimalOf(BigInt.from(-11050), 2), '-110.50');
    });
  });

  group('DateCell', () {
    test('serials; before 1900-03-01 text', () {
      expect(isText(a1(const DateCell('1900-01-01'))), isTrue);
      expect(textOf(a1(const DateCell('1900-02-28'))), '1900-02-28');
      expect(valueOf(a1(const DateCell('1900-03-01'))), '61');
      expect(valueOf(a1(const DateCell('2026-10-01'))), '46296');
      expect(valueOf(a1(const DateCell('2200-01-01'))), '109575');
      expect(a1(const DateCell('2026-10-01')), contains('s="5"'));
    });
  });

  test('ShareCell and CountCell', () {
    expect(valueOf(a1(const ShareCell(333))), '0.333');
    expect(valueOf(a1(const ShareCell(1000))), '1.000');
    expect(valueOf(a1(const ShareCell(1))), '0.001');
    expect(a1(const ShareCell(1)), contains('s="6"'));
    expect(valueOf(a1(const CountCell(42))), '42');
  });

  group('text', () {
    test('escaping', () {
      expect(
        textOf(a1(const TextCell('a & b <c> "d"'))),
        'a &amp; b &lt;c&gt; &quot;d&quot;',
      );
    });

    test('forbidden characters dropped; tab and new line kept', () {
      final cell = a1(TextCell('a\u0000b\u0008c\u000Bd\u001Fe￾f￿\tg\nh'));
      expect(textOf(cell), 'abcdef\tg\nh');
    });

    test('a lone surrogate dropped; emoji kept', () {
      final lone = String.fromCharCodes([0x61, 0xD83C, 0x62]);
      expect(textOf(a1(TextCell(lone))), 'ab');
      expect(textOf(a1(const TextCell('🍔 खाना'))), '🍔 खाना');
    });

    test('40,000 characters → 32,767; an emoji at the cut not split', () {
      final long = 'a' * 40000;
      expect(cellText(long).length, maxCellLength);
      final atCut = '${'a' * (maxCellLength - 1)}🍔tail';
      final cut = cellText(atCut);
      expect(cut.length, maxCellLength - 1);
      expect(cut.runes.last, 0x61);
    });

    test('xml:space="preserve" for a leading or trailing space', () {
      expect(a1(const TextCell(' x')), contains('xml:space="preserve"'));
      expect(a1(const TextCell('x ')), contains('xml:space="preserve"'));
      expect(a1(const TextCell('x')), isNot(contains('xml:space')));
      expect(textOf(a1(const TextCell('  x'))), '  x');
    });

    test('bold', () {
      expect(a1(const TextCell('x', bold: true)), contains('s="1"'));
    });
  });

  test('cells skip nulls; columns past Z', () {
    final xml = sheetOf([
      [const TextCell('a'), null, const TextCell('c')],
      [for (var i = 0; i < 28; i++) CountCell(i)],
    ]);
    expect(xml, contains('r="A1"'));
    expect(xml, isNot(contains('r="B1"')));
    expect(xml, contains('r="C1"'));
    expect(xml, contains('r="AB2"'));
    expect(columnName(0), 'A');
    expect(columnName(25), 'Z');
    expect(columnName(26), 'AA');
    expect(columnName(701), 'ZZ');
    expect(columnName(702), 'AAA');
  });

  test('more rows than a sheet holds → TooManyRows', () {
    final rows = List.generate(maxSheetRows + 1, (_) => <XlsxCell?>[]);
    expect(
      () => writeXlsx(XlsxWorkbook([XlsxSheet('S', rows)])),
      throwsA(isA<TooManyRows>()),
    );
  });

  test('sheet names in en, es, hi: ≤ 31 chars, none of \\ / ? * [ ] :', () {
    for (final code in ['en', 'es', 'hi']) {
      final l10n = lookupAppLocalizations(Locale(code));
      for (final name in [l10n.reportOverall]) {
        expect(name.length, lessThanOrEqualTo(31), reason: '$code $name');
        expect(name, isNot(matches(r'[\\/?*\[\]:]')), reason: name);
        expect(name.startsWith("'") || name.endsWith("'"), isFalse);
        expect(name.toLowerCase(), isNot('history'));
        expect(name.trim(), isNotEmpty);
      }
    }
  });
}
