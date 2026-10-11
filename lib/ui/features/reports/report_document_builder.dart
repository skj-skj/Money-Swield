import '../../../data/repositories/report_repository.dart';
import '../../../data/services/report_pdf.dart';
import '../../../data/services/xlsx/xlsx_writer.dart';
import '../../../domain/models/currency.dart';
import '../../../domain/report.dart';
import '../../../domain/report_chart.dart';
import '../../../domain/report_document.dart';
import '../../core/builtin_names.dart';
import '../../core/charts/group_palette.dart';
import '../../core/date_texts.dart';
import '../../core/item_labels.dart';
import 'views/report_texts.dart';

/// The export's document was cancelled while it was being built.
class ExportCancelled implements Exception {
  const ExportCancelled();
}

/// Builds the PDF's blocks and the Excel workbook (phase-8.md §5.5,
/// overhauled by the owner on 2026-10-10) from a [report] grouped by
/// [options] (`options.grouping`: sections by event, category or payment
/// method, each split by category, or by event for category sections).
///
/// - The top: the header, then **Overall**: per currency its total and a
///   chart of the sections.
/// - Then one **section** per event, category or payment method: per
///   currency its subtotal, its chart and its expenses (date, title with
///   🔁 for a recurring payment, its category and / or events, amount).
/// - Excel: an Overall sheet and one sheet per section.
///
/// Built from the report on screen (no second read, §9), every currency,
/// in the app's language. In the UI layer: it needs `AppLocalizations`
/// and `MoneyFormatter` (through [texts]). Long reports are built in
/// chunks of [chunk] rows with a pause between, so the busy dialog stays
/// live and Cancel ([isCancelled]) is heard.
class ReportDocumentBuilder {
  ReportDocumentBuilder({
    required this.report,
    required this.data,
    required this.texts,
    required this.options,
    required this.madeAt,
    this.isCancelled,
  });

  final Report report;
  final ReportData data;
  final ReportTexts texts;
  final ReportExportOptions options;

  /// When the file is made: its header's "Made on".
  final DateTime madeAt;
  final bool Function()? isCancelled;

  /// Rows built between two pauses.
  static const chunk = 500;

  int _sinceYield = 0;

  /// Lets the busy dialog draw and Cancel come in, every [chunk] rows.
  Future<void> _tick() async {
    if (++_sinceYield < chunk) return;
    _sinceYield = 0;
    await Future<void>.delayed(Duration.zero);
    if (isCancelled?.call() ?? false) throw const ExportCancelled();
  }

  // --- Shared texts ---------------------------------------------------------

  /// The range, "Made on …", the filter, "Grouped by Event".
  List<String> headerLines() => [
    texts.rangeWithSpan(report.range, report.span),
    texts.l10n.reportDocMadeOn(dateTimeText(texts.dateLocale, madeAt)),
    filterText(),
    texts.l10n.reportDocGrouping(texts.dimension(options.groupBy)),
  ];

  /// "Filter: Search: dinner · Categories: Food, Drinks · Events: Wedding
  /// · Paid with: Cash · Only recurring", or "No filter".
  String filterText() {
    final l10n = texts.l10n;
    final filter = report.filter;
    final base = filter.base;
    final words = base.text.trim();
    final parts = [
      if (words.isNotEmpty) l10n.reportDocSearch(words),
      if (base.categoryIds.isNotEmpty)
        l10n.reportDocCategories(
          namesInOrder(
            base.categoryIds,
            data.categories,
            name: (c) => categoryName(l10n, c),
            missing: ReportTexts.unknown,
          ).join(', '),
        ),
      if (base.eventIds.isNotEmpty)
        l10n.reportDocEvents(
          namesInOrder(
            base.eventIds,
            data.events,
            name: (e) => eventName(l10n, e),
            missing: ReportTexts.unknown,
          ).join(', '),
        ),
      if (filter.paymentMethodIds.isNotEmpty)
        l10n.reportDocPaidWith(
          namesInOrder(
            filter.paymentMethodIds,
            data.paymentMethods,
            name: (m) => paymentMethodName(l10n, m),
            missing: ReportTexts.unknown,
          ).join(', '),
        ),
      if (base.onlyRecurring) l10n.onlyRecurring,
    ];
    return parts.isEmpty
        ? l10n.reportDocNoFilter
        : l10n.reportDocFilter(parts.join(' · '));
  }

  /// Every digit, never "Too large" (R7).
  String _money(String currency, BigInt minor) =>
      texts.formatter.exactTotal(currency, minor);

  /// "INR · Indian Rupee".
  String _currencyName(String code) {
    final name = findCurrency(code)?.englishName;
    return name == null ? code : '$code · $name';
  }

  /// Each currency's first-level groups in order ([Report.groupsIn] sorts
  /// on every call), by key: read once per section and currency below.
  late final Map<String, Map<GroupKey, ReportGroup>> _sections = {
    for (final code in report.currencies)
      code: {for (final g in report.groupsIn(code)) g.key: g},
  };

  /// The sections in order: the default currency's order first, then any
  /// only other currencies have.
  List<GroupKey> sectionKeys() =>
      {for (final groups in _sections.values) ...groups.keys}.toList();

  ReportGroup? _section(GroupKey key, String currency) =>
      _sections[currency]?[key];

  String _sectionName(GroupKey key) => texts.key(key, data);

  /// The other event sections that hold [row] too ("also in Party").
  String? _alsoIn(ReportRow row, GroupKey key) {
    if (key is! EventKey) return null;
    final others = [
      for (final k in keysOf(
        row,
        GroupDimension.event,
        report.filter.base.eventIds,
      ))
        if (k != key) texts.key(k, data),
    ];
    return others.isEmpty
        ? null
        : texts.l10n.reportDocAlsoIn(others.join(', '));
  }

  String _methodName(ReportRow row) =>
      switch (data.paymentMethods[row.paymentMethodId]) {
        final m? => paymentMethodLabel(texts.l10n, m),
        null => ReportTexts.unknown,
      };

  String _categoryName(ReportRow row) =>
      switch (data.categories[row.categoryId]) {
        final c? => categoryLabel(texts.l10n, c),
        null => ReportTexts.unknown,
      };

  String _eventsOf(ReportRow row) => namesInOrder(
    row.eventIds,
    data.events,
    name: (e) => eventName(texts.l10n, e),
    show: (e) => eventLabel(texts.l10n, e),
    missing: ReportTexts.unknown,
  ).join(', ');

  /// What a row says besides its own section (owner, 2026-10-10): its
  /// category for event sections, its events for category sections, both
  /// for payment-method sections.
  String _context(ReportRow row) => switch (options.groupBy) {
    GroupDimension.event => _categoryName(row),
    GroupDimension.category => _eventsOf(row),
    _ => [
      _categoryName(row),
      _eventsOf(row),
    ].where((s) => s.isNotEmpty).join(' · '),
  };

  /// The title, marked 🔁 when it's a recurring payment, and "(also in
  /// Party)" for a row in two event sections.
  String _title(ReportRow row, GroupKey section) {
    final also = _alsoIn(row, section);
    final title = row.recurring ? '${row.title.trim()} 🔁' : row.title.trim();
    return also == null ? title : '$title ($also)';
  }

  // --- PDF -----------------------------------------------------------------

  Future<PdfDoc> pdf() async {
    final l10n = texts.l10n;
    final palette = GroupPalette.onWhite();
    PdfChart chart(List<ChartSlice> slices, String currency, String center) =>
        PdfChart(
          kind: options.chart,
          center: center,
          slices: [
            for (final (i, s) in slices.indexed)
              (
                f: s.ringFraction,
                color: _hex(palette.slice(i, isOther: s.isOther).toARGB32()),
                label: s.group == null
                    ? l10n.reportOtherGroups(s.others.length)
                    : texts.group(s.group!, data),
                value:
                    '${_money(currency, s.amount)} · '
                    '${texts.sliceShare(s)}',
              ),
          ],
        );

    final blocks = <PdfBlock>[
      PdfTitle(l10n.reportDocTitle),
      for (final (i, line) in headerLines().indexed)
        PdfText(line, muted: i > 0),
      PdfHeading(l10n.reportOverall),
    ];
    for (final code in report.currencies) {
      final total = report.totals[code]!;
      blocks
        ..add(
          PdfText(
            '${_currencyName(code)}: ${_money(code, total.amount)} · '
            '${l10n.reportExpenseCount(total.count)}',
          ),
        )
        ..add(
          chart(
            slicesOf(
              [..._sections[code]!.values],
              code,
              total.amount,
              groupOthers: options.groupOthers,
            ),
            code,
            _money(code, total.amount),
          ),
        );
      if (report.overlapIn(code) > 0) {
        blocks.add(PdfText(l10n.reportSectionsOverlap, muted: true));
      }
    }
    for (final key in sectionKeys()) {
      blocks.add(PdfHeading(_sectionName(key)));
      for (final code in report.currencies) {
        final section = _section(key, code);
        if (section == null) continue;
        final subtotal = section.byCurrency[code]!;
        blocks
          ..add(
            PdfText(
              '${_currencyName(code)}: ${_money(code, subtotal.amount)} · '
              '${l10n.reportExpenseCount(subtotal.count)}',
            ),
          )
          ..add(
            chart(
              slicesOf(
                section.childrenIn(code),
                code,
                subtotal.amount,
                groupOthers: options.groupOthers,
              ),
              code,
              _money(code, subtotal.amount),
            ),
          )
          ..add(await _rowsTable(section, code));
      }
    }
    return PdfDoc(
      blocks: blocks,
      footer: l10n.reportDocPageOf('{page}', '{pages}'),
    );
  }

  /// A section's expenses in one currency, then its subtotal.
  Future<PdfTable> _rowsTable(ReportGroup section, String code) async {
    final l10n = texts.l10n;
    final rows = <PdfRow>[];
    for (final row in section.rowsIn(code)) {
      await _tick();
      rows.add((
        cells: [
          texts.day(row.day),
          _title(row, section.key),
          _context(row),
          _money(code, BigInt.from(row.amountMinor)),
        ],
        style: PdfRowStyle.row,
        indent: 0,
      ));
    }
    rows.add((
      cells: [
        l10n.reportColSubtotal,
        '',
        l10n.reportExpenseCount(section.byCurrency[code]!.count),
        _money(code, section.byCurrency[code]!.amount),
      ],
      style: PdfRowStyle.subtotal,
      indent: 0,
    ));
    return PdfTable(
      columns: const [
        (w: 0.17, end: false),
        (w: 0.37, end: false),
        (w: 0.24, end: false),
        (w: 0.22, end: true),
      ],
      header: [
        l10n.reportColDate,
        l10n.reportColTitle,
        switch (options.groupBy) {
          GroupDimension.event => l10n.reportColCategory,
          GroupDimension.category => l10n.reportColEvents,
          _ => l10n.reportColNote,
        },
        l10n.reportColAmount,
      ],
      rows: rows,
    );
  }

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  // --- Excel ---------------------------------------------------------------

  Future<XlsxWorkbook> xlsx() async {
    final keys = sectionKeys();
    // The overall sheet's name first, so a section can't take it.
    final names = sheetNames([
      texts.l10n.reportOverall,
      for (final key in keys) _sectionName(key),
    ]);
    return XlsxWorkbook([
      _overallSheet(names.first),
      for (final (i, key) in keys.indexed)
        await _sectionSheet(key, names[i + 1]),
    ]);
  }

  int _digits(String code) => findCurrency(code)?.minorDigits ?? 2;

  XlsxSheet _overallSheet(String name) {
    final l10n = texts.l10n;
    final rows = <List<XlsxCell?>>[
      [TextCell(l10n.reportDocTitle, bold: true)],
      for (final line in headerLines()) [TextCell(line)],
      [],
      [
        TextCell(texts.dimension(options.groupBy), bold: true),
        TextCell(l10n.reportColCurrency, bold: true),
        TextCell(l10n.reportColCount, bold: true),
        TextCell(l10n.reportColAmount, bold: true),
        TextCell(l10n.reportColShare, bold: true),
      ],
    ];
    for (final code in report.currencies) {
      final total = report.totals[code]!;
      for (final g in _sections[code]!.values) {
        final t = g.byCurrency[code]!;
        rows.add([
          TextCell(texts.group(g, data)),
          TextCell(code),
          CountCell(t.count),
          AmountCell(t.amount, _digits(code)),
          if (sharePermille(t.amount, total.amount) case final p?)
            ShareCell(p)
          else
            null,
        ]);
      }
      rows.add([
        TextCell(l10n.reportDocTotal, bold: true),
        TextCell(code, bold: true),
        CountCell(total.count),
        AmountCell(total.amount, _digits(code), bold: true),
      ]);
      if (report.overlapIn(code) > 0) {
        rows.add([TextCell(l10n.reportSectionsOverlap)]);
      }
      rows.add([]);
    }
    return XlsxSheet(name, rows, widths: const [32, 10, 10, 18, 10]);
  }

  /// A section: per currency its expenses (every row once in the sheet;
  /// the subtotal in its own column, so a SUM over Amount never adds it),
  /// then its split by the chart's dimension.
  Future<XlsxSheet> _sectionSheet(GroupKey key, String name) async {
    final l10n = texts.l10n;
    final header = <XlsxCell?>[
      TextCell(l10n.reportColDate, bold: true),
      TextCell(l10n.reportColTime, bold: true),
      TextCell(l10n.reportColTitle, bold: true),
      TextCell(l10n.reportColCategory, bold: true),
      TextCell(l10n.reportColEvents, bold: true),
      TextCell(l10n.reportColPaymentMethod, bold: true),
      TextCell(l10n.reportColRecurring, bold: true),
      TextCell(l10n.reportColCurrency, bold: true),
      TextCell(l10n.reportColAmount, bold: true),
      TextCell(l10n.reportColSubtotal, bold: true),
      TextCell(l10n.reportColNote, bold: true),
    ];
    final rows = <List<XlsxCell?>>[
      [TextCell(_sectionName(key), bold: true)],
      [],
    ];
    for (final code in report.currencies) {
      final section = _section(key, code);
      if (section == null) continue;
      // The column names before each currency's rows: a second currency
      // comes after the first one's split table (found on the Oppo).
      rows.add(header);
      for (final row in section.rowsIn(code)) {
        await _tick();
        rows.add([
          DateCell(row.day),
          TextCell(clockTimeOf(row.occurredAtMs, row.utcOffsetMinutes)),
          TextCell(row.title),
          TextCell(_categoryName(row)),
          TextCell(_eventsOf(row)),
          TextCell(_methodName(row)),
          row.recurring ? const TextCell('✓') : null,
          TextCell(code),
          AmountCell(BigInt.from(row.amountMinor), _digits(code)),
          null,
          if (_alsoIn(row, key) case final also?) TextCell(also) else null,
        ]);
      }
      final subtotal = section.byCurrency[code]!;
      rows
        ..add([
          TextCell(l10n.reportColSubtotal, bold: true),
          null,
          null,
          null,
          null,
          null,
          null,
          TextCell(code, bold: true),
          null,
          AmountCell(subtotal.amount, _digits(code), bold: true),
        ])
        ..add([])
        ..add([
          TextCell(texts.dimension(options.grouping.then!), bold: true),
          TextCell(l10n.reportColCurrency, bold: true),
          TextCell(l10n.reportColCount, bold: true),
          TextCell(l10n.reportColAmount, bold: true),
          TextCell(l10n.reportColShare, bold: true),
        ]);
      for (final c in section.childrenIn(code)) {
        final t = c.byCurrency[code]!;
        rows.add([
          TextCell(texts.group(c, data)),
          TextCell(code),
          CountCell(t.count),
          AmountCell(t.amount, _digits(code)),
          if (sharePermille(t.amount, subtotal.amount) case final p?)
            ShareCell(p)
          else
            null,
        ]);
      }
      rows.add([]);
    }
    return XlsxSheet(
      name,
      rows,
      widths: const [14, 8, 30, 18, 18, 18, 10, 9, 16, 16, 24],
    );
  }
}
