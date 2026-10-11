import '../report_document.dart';
import '../report_filter.dart';
import '../report_range.dart';
import 'dashboard_options.dart';

/// What the Reports screen opens on, remembered across starts
/// (phase-8.md §4, owner revs 4 and 5, 2026-10-10): the card's face, the
/// period, the custom range, the filter and the Generate sheet's options.
/// Not part of `AppSettings`: they belong to the Reports screen alone,
/// which writes them as the user goes, and nothing else rebuilds for them.
final class ReportPrefs {
  const ReportPrefs({
    this.chart = ReportChart.bars,
    this.period = ReportPeriod.month,
    this.range,
    this.filter = ReportFilter.none,
    this.export = const ReportExportOptions(),
  });

  final ReportChart chart;
  final ReportPeriod period;

  /// The Range the screen opens on with [ReportPeriod.range], and the
  /// Range dialog's start; null until a range was first shown.
  final ReportRange? range;

  final ReportFilter filter;
  final ReportExportOptions export;
}
