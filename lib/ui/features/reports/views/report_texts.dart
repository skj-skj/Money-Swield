import 'package:intl/intl.dart';

import '../../../../data/repositories/report_repository.dart';
import '../../../../domain/models/dashboard_options.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/report.dart';
import '../../../../domain/report_chart.dart';
import '../../../../domain/report_range.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/item_labels.dart';
import '../../../core/money_formatter.dart';
import '../../../core/period_names.dart';

/// The report's words, shared by the screen and the exports
/// (phase-8.md §8, §5.5): range, group and dimension names, shares. A
/// group whose category, event or payment method is missing from the
/// maps (a newer app's data, or deleted between two reads) is "?",
/// never left out (§6.1).
class ReportTexts {
  ReportTexts({
    required this.l10n,
    required this.dateLocale,
    required this.formatter,
    required this.names,
  });

  final AppLocalizations l10n;

  /// For intl's dates (`dateLocaleOf`).
  final String dateLocale;

  /// Money in the formatting locale.
  final MoneyFormatter formatter;

  /// Home's period names (a week as "Oct Week 2").
  final PeriodNames names;

  /// The name of [range]: "Oct Week 2", "October 2026", "2026",
  /// "1 Nov 2025 – 31 Oct 2026", "All time".
  String range(ReportRange range) {
    if (range.isAllTime) return l10n.reportAllTime;
    return switch (range.period) {
      ReportPeriod.week => names.week((
        period: Period.week,
        from: range.from!,
        to: range.to!,
      )),
      ReportPeriod.month => toBeginningOfSentenceCase(
        cachedDateFormat('yMMMM', dateLocale).format(parseDay(range.from!)),
        dateLocale,
      ),
      ReportPeriod.year => range.from!.substring(0, 4),
      ReportPeriod.range => l10n.reportRangeDates(
        day(range.from!),
        day(range.to!),
      ),
    };
  }

  /// [range] with All time's span: "All time · 12 Mar 2019 – 4 Nov 2026".
  String rangeWithSpan(
    ReportRange range,
    ({String first, String last})? span,
  ) => range.isAllTime && span != null
      ? l10n.reportAllTimeSpan(day(span.first), day(span.last))
      : this.range(range);

  /// "5 Oct 2026".
  String day(String day) => shortDateText(dateLocale, parseDay(day));

  String dimension(GroupDimension dimension) => switch (dimension) {
    GroupDimension.category => l10n.reportGroupCategory,
    GroupDimension.event => l10n.reportGroupEvent,
    GroupDimension.paymentMethod => l10n.reportGroupPaymentMethod,
  };

  String face(ReportChart chart) => reportFaceName(l10n, chart);

  /// A group's name as the screen shows it: "🍔 Food", "No event", or "?"
  /// for an item not in [data].
  String group(ReportGroup group, ReportData data) => key(group.key, data);

  /// [group] by its key alone.
  String key(GroupKey key, ReportData data) => switch (key) {
    CategoryKey(:final id) => switch (data.categories[id]) {
      final c? => categoryLabel(l10n, c),
      null => unknown,
    },
    EventKey(:final id) => switch (data.events[id]) {
      final e? => eventLabel(l10n, e),
      null => unknown,
    },
    PaymentMethodKey(:final id) => switch (data.paymentMethods[id]) {
      final m? => paymentMethodLabel(l10n, m),
      null => unknown,
    },
    NoEventKey() => l10n.reportNoEvent,
  };

  /// A missing item's name (§6.1).
  static const unknown = '?';

  /// [permille] of [part]'s whole: "33.3 %"; "< 0.1 %" when [part] isn't
  /// zero but rounds to 0 (a ₹0 group reads "0.0 %"); "—" without a whole.
  /// Integer maths: tenths spliced with the locale's separator.
  String share(int? permille, BigInt part) {
    if (permille == null) return '—';
    final separator = decimalSeparatorFor(formatter.localeName);
    if (permille == 0 && part != BigInt.zero) {
      return l10n.reportShareTiny('0${separator}1');
    }
    return l10n.reportSharePercent(
      '${permille ~/ 10}$separator${permille % 10}',
    );
  }

  /// A chart slice's share of the whole the chart shows.
  String sliceShare(ChartSlice slice) =>
      share(slice.sharePermille, slice.amount);

  /// A total, or "Too large" past what the screen can print (R7).
  String amount(String currency, BigInt minor) =>
      totalText(l10n, formatter, currency, minor);

  /// "32" in the locale's digits and grouping.
  String count(int count) =>
      NumberFormat.decimalPattern(formatter.localeName).format(count);
}

/// A report card face's name: Bars, Donut.
String reportFaceName(AppLocalizations l10n, ReportChart face) =>
    switch (face) {
      ReportChart.bars => l10n.reportFaceBars,
      ReportChart.donut => l10n.reportFaceDonut,
    };
