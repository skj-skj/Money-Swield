/// The PDF a report export hands to Android (plan A): a layout-free document,
/// every string already formatted in the app's language (money by
/// `MoneyFormatter`, dates by intl), plus fractions and colours for the donuts.
/// Kotlin (`ReportPdfChannel.kt`) lays it out on A4 pages and draws it with
/// Android's own text stack, so Hindi conjuncts and colour emoji come out right
/// (probed on the Oppo).
library;

import '../../domain/report_chart.dart' show ringGap, ringSweeps;
import '../../domain/report_document.dart' show ExportChart;

/// One block of the document, drawn top to bottom.
sealed class PdfBlock {
  const PdfBlock();

  Map<String, Object?> toJson();
}

final class PdfTitle extends PdfBlock {
  const PdfTitle(this.text);
  final String text;

  @override
  Map<String, Object?> toJson() => {'t': 'title', 'text': text};
}

/// A heading: a currency, a section.
final class PdfHeading extends PdfBlock {
  const PdfHeading(this.text);
  final String text;

  @override
  Map<String, Object?> toJson() => {'t': 'heading', 'text': text};
}

final class PdfText extends PdfBlock {
  const PdfText(this.text, {this.muted = false});
  final String text;
  final bool muted;

  @override
  Map<String, Object?> toJson() => {'t': 'text', 'text': text, 'muted': muted};
}

/// One slice of a chart: its fraction of the slices' sum (geometry only),
/// its colour as `#rrggbb` (a Kotlin `Int` can't hold `0xff2a78d6`), the
/// legend's name and value.
typedef PdfSlice = ({double f, String color, String label, String value});

/// A chart of slices with its legend (owner, 2026-10-10): bars, a pie or
/// a donut.
final class PdfChart extends PdfBlock {
  const PdfChart({
    required this.kind,
    required this.center,
    required this.slices,
  });

  final ExportChart kind;

  /// The gap after each slice of a pie or donut (2 pt on its ring).
  static const gapDegrees = 2.0;

  /// In the donut's hole: the total.
  final String center;
  final List<PdfSlice> slices;

  @override
  Map<String, Object?> toJson() {
    // The round charts' sweeps as the card's (ringSweeps): no slice under
    // the minimum, so a small Other still shows. Bars use `f`.
    final sweeps = ringSweeps([
      for (final s in slices) s.f,
    ], gapDegrees: gapDegrees);
    return {
      't': 'chart',
      'kind': kind.name,
      'center': center,
      'gap': ringGap(slices.length, gapDegrees),
      'slices': [
        for (final (i, s) in slices.indexed)
          {
            'f': s.f,
            'sweep': sweeps[i],
            'color': s.color,
            'label': s.label,
            'value': s.value,
          },
      ],
    };
  }
}

/// A column: its share of the width; numbers are end-aligned and never
/// cut (Kotlin measures them first).
typedef PdfColumn = ({double w, bool end});

enum PdfRowStyle { group, row, subtotal }

typedef PdfRow = ({List<String> cells, PdfRowStyle style, int indent});

/// A table whose header repeats on each page; a group line is never the
/// last line of a page.
final class PdfTable extends PdfBlock {
  const PdfTable({
    required this.columns,
    required this.header,
    required this.rows,
  });

  final List<PdfColumn> columns;
  final List<String> header;
  final List<PdfRow> rows;

  @override
  Map<String, Object?> toJson() => {
    't': 'table',
    'columns': [
      for (final c in columns) {'w': c.w, 'end': c.end},
    ],
    'header': header,
    'rows': [
      for (final r in rows)
        {'cells': r.cells, 'style': r.style.name, 'indent': r.indent},
    ],
  };
}

final class PdfDoc {
  const PdfDoc({required this.blocks, required this.footer});

  final List<PdfBlock> blocks;

  /// "Page {page} of {pages}": Kotlin fills both numbers.
  final String footer;

  Map<String, Object?> toJson() => {
    'pageSize': 'a4',
    'footer': footer,
    'blocks': [for (final b in blocks) b.toJson()],
  };
}
