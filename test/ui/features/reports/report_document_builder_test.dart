import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_expense_tracker_app/data/repositories/report_repository.dart';
import 'package:my_expense_tracker_app/data/services/report_pdf.dart';
import 'package:my_expense_tracker_app/data/services/xlsx/xlsx_writer.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/models/category.dart';
import 'package:my_expense_tracker_app/domain/models/event.dart';
import 'package:my_expense_tracker_app/domain/models/payment_method.dart';
import 'package:my_expense_tracker_app/domain/periods.dart';
import 'package:my_expense_tracker_app/domain/report.dart';
import 'package:my_expense_tracker_app/domain/report_chart.dart';
import 'package:my_expense_tracker_app/domain/report_document.dart';
import 'package:my_expense_tracker_app/domain/report_filter.dart';
import 'package:my_expense_tracker_app/domain/report_range.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/money_formatter.dart';
import 'package:my_expense_tracker_app/ui/core/period_names.dart';
import 'package:my_expense_tracker_app/ui/features/reports/report_document_builder.dart';
import 'package:my_expense_tracker_app/ui/features/reports/views/report_texts.dart';

/// The document builder (owner's overhaul, 2026-10-10): the
/// PDF's blocks and the Excel sheets from a report, without widgets.
void main() {
  setUpAll(initializeDateFormatting);

  final at = DateTime.utc(2026, 1, 1);
  final data = ReportData(
    rows: const [],
    categories: {
      1: Category(
        builtinKey: null,
        description: null,
        id: 1,
        name: 'Food',
        emoji: '🍔',
        createdAt: at,
        updatedAt: at,
      ),
      2: Category(
        builtinKey: null,
        description: null,
        id: 2,
        name: 'Gifts',
        emoji: '🎁',
        createdAt: at,
        updatedAt: at,
      ),
    },
    events: {
      7: Event(
        builtinKey: null,
        description: null,
        archivedAt: null,
        id: 7,
        name: 'Wedding',
        emoji: '💍',
        createdAt: at,
        updatedAt: at,
      ),
      8: Event(
        builtinKey: null,
        description: null,
        archivedAt: null,
        id: 8,
        name: 'Party/Fun',
        emoji: '🎉',
        createdAt: at,
        updatedAt: at,
      ),
    },
    paymentMethods: {
      1: PaymentMethod(
        builtinKey: null,
        id: 1,
        name: 'Cash',
        emoji: '💵',
        createdAt: at,
        updatedAt: at,
      ),
    },
  );
  var nextId = 1;
  ReportRow row(
    int amount, {
    String code = 'INR',
    int category = 1,
    Set<int> events = const {},
    bool recurring = false,
    String title = 'Lunch',
  }) => ReportRow(
    id: nextId++,
    title: title,
    amountMinor: amount,
    currencyCode: code,
    occurredAtMs: DateTime.utc(2026, 10, 5, 8, 30).millisecondsSinceEpoch,
    utcOffsetMinutes: 330,
    day: '2026-10-05',
    categoryId: category,
    paymentMethodId: 1,
    eventIds: events,
    recurring: recurring,
  );

  const oct = ReportRange(ReportPeriod.month, '2026-10-01', '2026-10-31');

  ReportDocumentBuilder builderFor(
    List<ReportRow> rows, {
    ReportExportOptions options = const ReportExportOptions(),
    ReportFilter filter = ReportFilter.none,
    String language = 'en',
    String locale = 'en_IN',
    bool Function()? cancelled,
  }) {
    final l10n = lookupAppLocalizations(Locale(language));
    final report = buildReport(
      rows,
      range: oct,
      filter: filter,
      grouping: options.grouping,
      defaultCurrency: 'INR',
    );
    return ReportDocumentBuilder(
      report: report,
      data: data,
      texts: ReportTexts(
        l10n: l10n,
        dateLocale: locale,
        formatter: MoneyFormatter.forLocale(locale),
        names: PeriodNames(
          l10n: l10n,
          locale: locale,
          today: '2026-10-10',
          weekLabel: WeekLabel.month,
        ),
      ),
      options: options,
      madeAt: DateTime.utc(2026, 10, 10, 6),
      isCancelled: cancelled,
    );
  }

  List<String> texts(PdfDoc doc) => [
    for (final b in doc.blocks)
      switch (b) {
        PdfTitle(:final text) || PdfHeading(:final text) => text,
        PdfText(:final text) => text,
        _ => '',
      },
  ];

  test('PDF by event: Overall, then a section each; a row in two events '
      'in both, "also in"; the overlap said; recurring marked', () async {
    final doc = await builderFor([
      row(7000, events: {7}),
      row(3000, events: {7, 8}, title: 'Cake', recurring: true),
      row(500, category: 2),
    ], options: const ReportExportOptions(groupBy: GroupDimension.event)).pdf();
    final all = texts(doc);
    expect(all, contains('Overall'));
    expect(all, containsAll(['💍 Wedding', '🎉 Party/Fun', 'No event']));
    expect(
      all.any(
        (t) => t.contains('in two events') || t.contains('both sections'),
      ),
      isTrue,
    );
    final tables = doc.blocks.whereType<PdfTable>().toList();
    final wedding = tables.first;
    expect(
      wedding.rows.map((r) => r.cells[1]),
      contains('Cake 🔁 (also in 🎉 Party/Fun)'),
    );
    // The category beside each row of an event section.
    expect(wedding.rows.first.cells[2], '🍔 Food');
    // Subtotal last.
    expect(wedding.rows.last.style, PdfRowStyle.subtotal);
    expect(wedding.rows.last.cells.last, '₹100.00');
    // The overall total counts the shared row once.
    expect(all, contains(startsWith('INR · Indian Rupee: ₹105.00')));
  });

  test('chart kind and Others: 5 + Other, or all', () async {
    final rows = [for (var c = 1; c <= 8; c++) row(c * 100, category: c)];
    var charts = (await builderFor(rows).pdf()).blocks.whereType<PdfChart>();
    expect(charts.first.kind, ExportChart.bars);
    expect(charts.first.slices, hasLength(6));
    charts = (await builderFor(
      rows,
      options: const ReportExportOptions(
        chart: ExportChart.donut,
        groupOthers: false,
      ),
    ).pdf()).blocks.whereType<PdfChart>();
    expect(charts.first.kind, ExportChart.donut);
    expect(charts.first.slices, hasLength(8));
    expect(charts.first.slices.first.color, matches(r'^#[0-9a-f]{6}$'));
  });

  test('a tiny Other still gets a visible sweep in the PDF (it vanished: '
      'Kotlin skipped slices under the 2° gap)', () async {
    final doc = await builderFor([
      row(1000000, category: 1),
      row(1, category: 2),
    ], options: const ReportExportOptions(chart: ExportChart.donut)).pdf();
    final json = doc.blocks.whereType<PdfChart>().first.toJson();
    final slices = (json['slices']! as List).cast<Map<String, Object?>>();
    expect(json['gap'], 2.0);
    expect(slices.last['sweep'], minSweepDegrees);
    final total = slices.fold(0.0, (t, s) => t + (s['sweep']! as double));
    expect(total + 2 * slices.length, closeTo(360, 1e-9));
  });

  test('a total past what the screen prints keeps every digit', () async {
    const max = 9223372036854775807;
    // 101 rows: the major part passes 2⁶³ − 1, where the screen says
    // "Too large".
    final doc = await builderFor([for (var i = 0; i < 101; i++) row(max)])
        .pdf();
    expect(
      texts(doc),
      contains(startsWith('INR · Indian Rupee: INR 9315605757223323565.07')),
    );
  });

  test('es: shares with a decimal comma; hi: Hindi headings', () async {
    final es = await builderFor(
      [row(100), row(200, category: 2)],
      language: 'es',
      locale: 'es',
    ).pdf();
    final slice = es.blocks.whereType<PdfChart>().first.slices.first;
    expect(slice.value, endsWith('66,7 %'));
    final hi = await builderFor([row(100)], language: 'hi', locale: 'hi').pdf();
    expect(texts(hi).first, 'खर्च रिपोर्ट');
    expect(hi.footer, 'पेज {page} / {pages}');
  });

  test('0- and 3-digit currencies in Excel', () async {
    final book = await builderFor([
      row(500, code: 'JPY'),
      row(1234, code: 'KWD'),
    ]).xlsx();
    final amounts = [
      for (final r in book.sheets.first.rows)
        for (final c in r)
          if (c is AmountCell) (c.minor.toInt(), c.digits),
    ];
    expect(amounts, containsAll([(500, 0), (1234, 3)]));
  });

  test('Excel by category: Overall + a sheet each, safe names; every row '
      'once in its sheet; the subtotal in its own column', () async {
    final book = await builderFor([
      row(100),
      row(200),
      row(50, category: 2, events: {8}),
    ]).xlsx();
    expect(
      [for (final s in book.sheets) s.name],
      ['Overall', '🍔 Food', '🎁 Gifts'],
    );
    final food = book.sheets[1];
    final amountColumn = 8;
    final subtotalColumn = 9;
    final amounts = [
      for (final r in food.rows)
        if (r.length > amountColumn && r[amountColumn] is AmountCell)
          (r[amountColumn]! as AmountCell).minor.toInt(),
    ];
    expect(amounts, [100, 200]);
    final subtotals = [
      for (final r in food.rows)
        if (r.length > subtotalColumn && r[subtotalColumn] is AmountCell)
          (r[subtotalColumn]! as AmountCell).minor.toInt(),
    ];
    expect(subtotals, [300]);
    // A category section shows each row's events.
    final gifts = book.sheets[2];
    expect(
      gifts.rows.any(
        (r) =>
            r.length > 4 &&
            r[4] is TextCell &&
            (r[4]! as TextCell).text == '🎉 Party/Fun',
      ),
      isTrue,
    );
    // A section named after a user's item gets a safe sheet name ("/" is
    // forbidden), and the writer takes the whole workbook.
    final byEvent = await builderFor(
      [
        row(100, events: {8}),
      ],
      options: const ReportExportOptions(groupBy: GroupDimension.event),
    ).xlsx();
    expect(byEvent.sheets[1].name, '🎉 Party-Fun');
    expect(writeXlsx(byEvent), isNotEmpty);
  });

  test('the filter in words; none', () {
    expect(builderFor([row(1)]).filterText(), 'No filter');
    final b = builderFor(
      [
        row(1, events: {7}),
      ],
      filter: const ReportFilter(
        base: ExpenseFilter(
          text: 'cake',
          categoryIds: {1, 2},
          eventIds: {7},
          onlyRecurring: true,
        ),
        paymentMethodIds: {1},
      ),
    );
    expect(
      b.filterText(),
      'Filter: Search: cake · Categories: Food, Gifts · Events: Wedding · '
      'Paid with: Cash · Only recurring',
    );
  });

  test('a long report is built in chunks and can be cancelled', () async {
    var cancelled = false;
    final rows = [for (var i = 0; i < 1200; i++) row(100)];
    final builder = builderFor(rows, cancelled: () => cancelled);
    cancelled = true;
    expect(builder.pdf(), throwsA(isA<ExportCancelled>()));
  });

  test('a section in two currencies: the column names before each', () async {
    final book = await builderFor([row(100), row(5, code: 'USD')]).xlsx();
    final food = book.sheets[1];
    final headers = [
      for (final (i, r) in food.rows.indexed)
        if (r.isNotEmpty &&
            r.first is TextCell &&
            (r.first! as TextCell).text == 'Date')
          i,
    ];
    expect(headers, hasLength(2));
    // The USD rows come right after the second header.
    final usd = food.rows[headers[1] + 1];
    expect((usd[7]! as TextCell).text, 'USD');
  });
}
