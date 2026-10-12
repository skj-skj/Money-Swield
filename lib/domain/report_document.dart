/// What an export holds and what it's called. The strings themselves are made
/// in the UI layer, which has the app's language
/// (`report_document_builder.dart`).
library;

import 'periods.dart';
import 'report.dart';
import 'report_range.dart';

/// The file an export makes.
enum ReportExport { pdf, xlsx }

/// How the export's charts are drawn (owner, 2026-10-10): bars by
/// default, a full pie, or a donut.
enum ExportChart { bars, pie, donut }

/// What the Generate sheet chose (owner, 2026-10-10), remembered across
/// starts.
final class ReportExportOptions {
  const ReportExportOptions({
    this.groupBy = GroupDimension.category,
    this.chart = ExportChart.bars,
    this.groupOthers = true,
    this.format = ReportExport.pdf,
  });

  /// The sections: one per event, category or payment method.
  final GroupDimension groupBy;
  final ExportChart chart;

  /// The charts show the 5 largest and Other (on), or every item (off).
  final bool groupOthers;
  final ReportExport format;

  /// The dimensions sections can be.
  static const sectionDimensions = [
    GroupDimension.event,
    GroupDimension.category,
    GroupDimension.paymentMethod,
  ];

  /// Sections by [groupBy], each split for its chart by category, or by
  /// event for category sections (owner, 2026-10-10).
  ReportGrouping get grouping => ReportGrouping(
    groupBy,
    then: groupBy == GroupDimension.category
        ? GroupDimension.event
        : GroupDimension.category,
  );

  ReportExportOptions copyWith({
    GroupDimension? groupBy,
    ExportChart? chart,
    bool? groupOthers,
    ReportExport? format,
  }) => ReportExportOptions(
    groupBy: groupBy ?? this.groupBy,
    chart: chart ?? this.chart,
    groupOthers: groupOthers ?? this.groupOthers,
    format: format ?? this.format,
  );

  @override
  bool operator ==(Object other) =>
      other is ReportExportOptions &&
      other.groupBy == groupBy &&
      other.chart == chart &&
      other.groupOthers == groupOthers &&
      other.format == format;

  @override
  int get hashCode => Object.hash(groupBy, chart, groupOthers, format);
}

/// Excel's rules for sheet names: at most 31 characters, none of
/// `\ / ? * [ ] :`, not starting or ending with `'`, not "History", and no two
/// alike (ignoring case). Sections are named after the user's categories, events and
/// payment methods, so their names are made safe here: forbidden characters
/// become `-`, a long name is cut (never inside a surrogate pair), an empty one
/// is "Sheet N", and a repeat gets " (2)". [names] in, the same count out, in
/// order.
List<String> sheetNames(List<String> names) {
  const max = 31;
  final taken = <String>{'history'};
  String cut(String text, int units) {
    final out = StringBuffer();
    var length = 0;
    for (final rune in text.runes) {
      final size = rune >= 0x10000 ? 2 : 1;
      if (length + size > units) break;
      out.writeCharCode(rune);
      length += size;
    }
    return out.toString();
  }

  return [
    for (final (i, name) in names.indexed)
      () {
        var base = name
            .replaceAll(RegExp(r'[\\/?*\[\]:]'), '-')
            .replaceAll(RegExp(r"^'+|'+$"), '')
            .trim();
        base = cut(base, max).trim();
        if (base.isEmpty) base = 'Sheet ${i + 1}';
        var candidate = base;
        for (var n = 2; taken.contains(candidate.toLowerCase()); n++) {
          final suffix = ' ($n)';
          candidate = '${cut(base, max - suffix.length).trim()}$suffix';
        }
        taken.add(candidate.toLowerCase());
        return candidate;
      }(),
  ];
}

/// Where the file goes after it's made.
enum ExportAction { save, saveAs, share }

const pdfMimeType = 'application/pdf';
const xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

String mimeTypeOf(ReportExport format) =>
    format == ReportExport.pdf ? pdfMimeType : xlsxMimeType;

/// `expense-report-2026-10.pdf`: ASCII only, named after the period. A week by
/// `weekIdOf`'s year and number (29 Dec 2025 – 4 Jan 2026 is `2026-W01`; ISO
/// 8601 only with a Monday start), a custom range by its dates, All time by
/// [today].
String reportFileName(
  ReportRange range,
  ReportExport format,
  WeekStart weekStart,
  String today,
) {
  final ext = format == ReportExport.pdf ? 'pdf' : 'xlsx';
  String compact(String day) => day.replaceAll('-', '');
  final name = switch (range.period) {
    _ when range.isAllTime => 'all-${compact(today)}',
    ReportPeriod.month => range.from!.substring(0, 7),
    ReportPeriod.year => range.from!.substring(0, 4),
    ReportPeriod.week => _weekName(range),
    ReportPeriod.range => '${compact(range.from!)}-${compact(range.to!)}',
  };
  return 'expense-report-$name.$ext';
}

String _weekName(ReportRange range) {
  final id = weekIdOf((period: Period.week, from: range.from!, to: range.to!));
  return '${id.year}-W${id.number.toString().padLeft(2, '0')}';
}

/// The clock time a row was recorded at, `14:05`: its moment on the clock
/// [utcOffsetMinutes] from UTC (not the phone's zone now). Integer arithmetic,
/// never a `double` fraction of a day.
String clockTimeOf(int occurredAtMs, int utcOffsetMinutes) {
  final local = DateTime.fromMillisecondsSinceEpoch(
    occurredAtMs,
    isUtc: true,
  ).add(Duration(minutes: utcOffsetMinutes));
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
