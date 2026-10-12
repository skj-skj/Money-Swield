/// A minimal `.xlsx` writer: own code on `archive`, no package. Six kinds of
/// part: `[Content_Types].xml`, `_rels/.rels`, `xl/workbook.xml`,
/// `xl/_rels/workbook.xml.rels`, `xl/styles.xml` (with `<cellStyles>`: without
/// it openpyxl warns), one `xl/worksheets/sheetN.xml` per sheet. Strings are
/// inline (`t="inlineStr"`), no shared-strings part. No formulas: every number
/// is computed in Dart, so the file shows the screen's numbers.
///
/// Pure Dart: tested by unzipping and parsing the XML, without a phone.
library;

// The XML below is split across adjacent strings where a space would
// break it (inside namespace URIs and attribute values).
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One cell. `null` in a row is an empty cell.
sealed class XlsxCell {
  const XlsxCell();
}

final class TextCell extends XlsxCell {
  const TextCell(this.text, {this.bold = false});

  final String text;
  final bool bold;
}

/// Money: exact minor units and the currency's digits (0, 2 or 3).
final class AmountCell extends XlsxCell {
  const AmountCell(this.minor, this.digits, {this.bold = false});

  final BigInt minor;
  final int digits;
  final bool bold;
}

final class CountCell extends XlsxCell {
  const CountCell(this.value);

  final int value;
}

/// A date, `YYYY-MM-DD`.
final class DateCell extends XlsxCell {
  const DateCell(this.day);

  final String day;
}

/// A share in tenths of a percent.
final class ShareCell extends XlsxCell {
  const ShareCell(this.permille);

  final int permille;
}

final class XlsxSheet {
  const XlsxSheet(this.name, this.rows, {this.widths = const []});

  /// At most 31 characters, none of `\ / ? * [ ] :`: the app's sheet names are
  /// fixed ARB strings, checked by a test.
  final String name;
  final List<List<XlsxCell?>> rows;

  /// Column widths in characters, from column A; the rest default.
  final List<double> widths;
}

final class XlsxWorkbook {
  const XlsxWorkbook(this.sheets);

  final List<XlsxSheet> sheets;
}

/// A sheet has more rows than Excel allows (1,048,576).
class TooManyRows implements Exception {
  const TooManyRows(this.sheet, this.rows);

  final String sheet;
  final int rows;

  @override
  String toString() => 'TooManyRows: $sheet has $rows rows';
}

/// The most rows a sheet can hold.
const maxSheetRows = 1048576;

/// The most UTF-16 units a cell holds.
const maxCellLength = 32767;

/// The most significant digits Excel keeps in a number; an amount with more is
/// written as text, every digit kept.
const maxExactDigits = 15;

/// The workbook as `.xlsx` bytes. Throws [TooManyRows] when a sheet is
/// too long for Excel.
Uint8List writeXlsx(XlsxWorkbook book) {
  for (final sheet in book.sheets) {
    if (sheet.rows.length > maxSheetRows) {
      throw TooManyRows(sheet.name, sheet.rows.length);
    }
  }
  final archive = Archive();
  void add(String name, String xml) {
    final bytes = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  final count = book.sheets.length;
  add('[Content_Types].xml', _contentTypes(count));
  add('_rels/.rels', _rootRels);
  add('xl/workbook.xml', _workbook(book));
  add('xl/_rels/workbook.xml.rels', _workbookRels(count));
  add('xl/styles.xml', _styles);
  for (final (i, sheet) in book.sheets.indexed) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheet(sheet));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

// --- Cells ------------------------------------------------------------------

/// Style ids in `styles.xml`'s `cellXfs`, in order.
abstract final class _Style {
  static const normal = 0;
  static const bold = 1;
  static const amount0 = 2; // #,##0
  static const amount2 = 3; // #,##0.00
  static const amount3 = 4; // #,##0.000
  static const date = 5; // the reader's short date (numFmtId 14)
  static const share = 6; // 0.0%
  static const boldAmount0 = 7;
  static const boldAmount2 = 8;
  static const boldAmount3 = 9;

  static int amount(int digits, bool bold) => switch (digits) {
    0 => bold ? boldAmount0 : amount0,
    3 => bold ? boldAmount3 : amount3,
    _ => bold ? boldAmount2 : amount2,
  };
}

/// [minor] as a decimal written from the integer itself (`11050`, 2 →
/// `110.50`), never through a `double`: exact, with `.` in every app language
/// (the file's syntax, not its display).
String decimalOf(BigInt minor, int digits) {
  final negative = minor.isNegative;
  final text = minor.abs().toString().padLeft(digits + 1, '0');
  final whole = text.substring(0, text.length - digits);
  final body = digits == 0
      ? whole
      : '$whole.${text.substring(text.length - digits)}';
  return negative ? '-$body' : body;
}

/// Whether [minor] has more significant digits than Excel keeps.
bool tooPreciseForExcel(BigInt minor) {
  final digits = minor.abs().toString().replaceFirst(RegExp(r'0+$'), '');
  return digits.length > maxExactDigits;
}

/// Excel's serial for [day] (days since 1899-12-30), or null before 1900-03-01:
/// Excel counts a 29 Feb 1900 that never was, LibreOffice and Google Sheets
/// don't, so earlier serials disagree. Integer date arithmetic on UTC
/// midnights.
int? excelSerial(String day) {
  if (day.compareTo('1900-03-01') < 0) return null;
  final date = DateTime.utc(
    int.parse(day.substring(0, 4)),
    int.parse(day.substring(5, 7)),
    int.parse(day.substring(8, 10)),
  );
  return date.difference(DateTime.utc(1899, 12, 30)).inDays;
}

/// [text] fit for a cell: characters XML 1.0 forbids dropped (controls but
/// tab, line feed and carriage return; U+FFFE, U+FFFF; lone surrogates),
/// then cut to [maxCellLength] UTF-16 units, never inside a surrogate
/// pair.
String cellText(String text) {
  final out = StringBuffer();
  var length = 0;
  for (final rune in text.runes) {
    final allowed =
        rune == 0x9 ||
        rune == 0xA ||
        rune == 0xD ||
        (rune >= 0x20 && rune <= 0xD7FF) ||
        (rune >= 0xE000 && rune <= 0xFFFD) ||
        rune >= 0x10000;
    if (!allowed) continue;
    final units = rune >= 0x10000 ? 2 : 1;
    if (length + units > maxCellLength) break;
    out.writeCharCode(rune);
    length += units;
  }
  return out.toString();
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// `A`, `B`, … `Z`, `AA`, … for a 0-based [column].
String columnName(int column) {
  var n = column + 1;
  final letters = <int>[];
  while (n > 0) {
    final rem = (n - 1) % 26;
    letters.insert(0, 0x41 + rem);
    n = (n - 1) ~/ 26;
  }
  return String.fromCharCodes(letters);
}

void _cell(StringBuffer xml, String ref, XlsxCell cell) {
  switch (cell) {
    case TextCell(:final text, :final bold):
      _text(xml, ref, text, bold ? _Style.bold : _Style.normal);
    case AmountCell(:final minor, :final digits, :final bold):
      if (tooPreciseForExcel(minor)) {
        // Every digit, as text: a number would lose the last ones.
        _text(xml, ref, decimalOf(minor, digits), bold ? _Style.bold : 0);
      } else {
        xml.write(
          '<c r="$ref" s="${_Style.amount(digits, bold)}">'
          '<v>${decimalOf(minor, digits)}</v></c>',
        );
      }
    case CountCell(:final value):
      xml.write('<c r="$ref"><v>$value</v></c>');
    case DateCell(:final day):
      final serial = excelSerial(day);
      if (serial == null) {
        _text(xml, ref, day, _Style.normal);
      } else {
        xml.write('<c r="$ref" s="${_Style.date}"><v>$serial</v></c>');
      }
    case ShareCell(:final permille):
      xml.write(
        '<c r="$ref" s="${_Style.share}">'
        '<v>${decimalOf(BigInt.from(permille), 3)}</v></c>',
      );
  }
}

void _text(StringBuffer xml, String ref, String text, int style) {
  final clean = cellText(text);
  final preserve = clean != clean.trim() || clean.contains('\n');
  xml
    ..write('<c r="$ref" t="inlineStr"')
    ..write(style == 0 ? '' : ' s="$style"')
    ..write('><is><t')
    ..write(preserve ? ' xml:space="preserve"' : '')
    ..write('>${_escape(clean)}</t></is></c>');
}

// --- Parts ------------------------------------------------------------------

String _sheet(XlsxSheet sheet) {
  final xml = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
    '2006/main" xmlns:r="http://schemas.openxmlformats.org/'
    'officeDocument/2006/relationships">',
  );
  if (sheet.widths.isNotEmpty) {
    xml.write('<cols>');
    for (final (i, width) in sheet.widths.indexed) {
      xml.write(
        '<col min="${i + 1}" max="${i + 1}" width="$width" customWidth="1"/>',
      );
    }
    xml.write('</cols>');
  }
  xml.write('<sheetData>');
  for (final (r, row) in sheet.rows.indexed) {
    xml.write('<row r="${r + 1}">');
    for (final (c, cell) in row.indexed) {
      if (cell != null) _cell(xml, '${columnName(c)}${r + 1}', cell);
    }
    xml.write('</row>');
  }
  xml.write('</sheetData></worksheet>');
  return xml.toString();
}

String _contentTypes(int sheets) {
  final xml = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
    'content-types">'
    '<Default Extension="rels" ContentType="application/'
    'vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/'
    'vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/'
    'vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
  );
  for (var i = 1; i <= sheets; i++) {
    xml.write(
      '<Override PartName="/xl/worksheets/sheet$i.xml" '
      'ContentType="application/'
      'vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    );
  }
  xml.write('</Types>');
  return xml.toString();
}

const _rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
    'relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
    'officeDocument/2006/relationships/officeDocument" '
    'Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbook(XlsxWorkbook book) {
  final xml = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
    '2006/main" xmlns:r="http://schemas.openxmlformats.org/'
    'officeDocument/2006/relationships"><sheets>',
  );
  for (final (i, sheet) in book.sheets.indexed) {
    xml.write(
      '<sheet name="${_escape(sheet.name)}" sheetId="${i + 1}" '
      'r:id="rId${i + 1}"/>',
    );
  }
  xml.write('</sheets></workbook>');
  return xml.toString();
}

String _workbookRels(int sheets) {
  final xml = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
    'relationships">',
  );
  for (var i = 1; i <= sheets; i++) {
    xml.write(
      '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet$i.xml"/>',
    );
  }
  xml.write(
    '<Relationship Id="rId${sheets + 1}" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/'
    'relationships/styles" Target="styles.xml"/>',
  );
  xml.write('</Relationships>');
  return xml.toString();
}

/// Fonts: 0 normal, 1 bold. Number formats: 3 `#,##0`, 4 `#,##0.00`, 14
/// short date (built in); 164 `#,##0.000`, 165 `0.0%`. `cellXfs` in
/// [_Style]'s order.
const _styles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
    '2006/main">'
    '<numFmts count="2">'
    '<numFmt numFmtId="164" formatCode="#,##0.000"/>'
    '<numFmt numFmtId="165" formatCode="0.0%"/>'
    '</numFmts>'
    '<fonts count="2">'
    '<font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font>'
    '</fonts>'
    '<fills count="2"><fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill></fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/>'
    '</border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" '
    'borderId="0"/></cellStyleXfs>'
    '<cellXfs count="10">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" '
    'applyFont="1"/>'
    '<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '<xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1"/>'
    '<xf numFmtId="3" fontId="1" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1" applyFont="1"/>'
    '<xf numFmtId="4" fontId="1" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1" applyFont="1"/>'
    '<xf numFmtId="164" fontId="1" fillId="0" borderId="0" xfId="0" '
    'applyNumberFormat="1" applyFont="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" '
    'builtinId="0"/></cellStyles>'
    '</styleSheet>';
