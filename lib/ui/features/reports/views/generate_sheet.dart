import 'package:material_ui/material_ui.dart';

import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/report.dart';
import '../../../../domain/report_document.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/widgets/filter/filter_sheet.dart';
import '../../../core/widgets/section_heading.dart';
import 'report_texts.dart';

/// What the Generate sheet closed with: its filter (applied to the screen
/// however the sheet closes, like the filter sheet), its options (remembered)
/// and the button tapped, or null when closed without one.
typedef GenerateChoice = ({
  ExpenseFilter filter,
  Set<int> paymentMethodIds,
  ReportExportOptions options,
  ExportAction? action,
});

/// The Generate sheet (owner, 2026-10-10): the options first (Group by,
/// Chart, Group small items as Others, Format), then the screen's filter
/// in the shared filter fields, then Share, Save as… and Save.
Future<GenerateChoice> showGenerateSheet(
  BuildContext context, {
  required ExpenseFilter filter,
  required Set<int> paymentMethodIds,
  required ReportExportOptions options,
  required Map<int, Category> categories,
  required Map<int, Event> events,
  required Map<int, PaymentMethod> paymentMethods,
  required ReportTexts texts,
}) async {
  // Not disposed: the sheet may still build it while it slides away; it
  // has no other listener and goes with it.
  final chosen = ValueNotifier(options);
  ExportAction? action;
  final value = await showFilterSheet(
    context,
    filter: filter,
    categories: categories,
    events: events,
    paymentMethods: paymentMethods,
    paymentMethodIds: paymentMethodIds,
    leading: (context) => _Options(options: chosen, texts: texts),
    actions: (context, value, clear) {
      final l10n = AppLocalizations.of(context);
      void tap(ExportAction a) {
        action = a;
        Navigator.pop(context);
      }

      // Save is the main button, last; they wrap at 360 dp × 2.0.
      return [
        TextButton.icon(
          key: const ValueKey('generateShare'),
          onPressed: () => tap(ExportAction.share),
          icon: const Icon(Icons.share_outlined),
          label: Text(l10n.reportShare),
        ),
        TextButton(
          key: const ValueKey('generateSaveAs'),
          onPressed: () => tap(ExportAction.saveAs),
          child: Text(l10n.reportSaveAs),
        ),
        FilledButton.icon(
          key: const ValueKey('generateSave'),
          onPressed: () => tap(ExportAction.save),
          icon: const Icon(Icons.download_outlined),
          label: Text(l10n.reportSave),
        ),
      ];
    },
  );
  return (
    filter: value.filter,
    paymentMethodIds: value.paymentMethodIds,
    options: chosen.value,
    action: action,
  );
}

/// Group by, Chart, Group small items as Others, Format.
class _Options extends StatelessWidget {
  const _Options({required this.options, required this.texts});

  final ValueNotifier<ReportExportOptions> options;
  final ReportTexts texts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: options,
      builder: (context, o, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.reportGenerateTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SectionHeading(l10n.reportGroupBy),
          _segments<GroupDimension>(
            key: const ValueKey('generateGroupBy'),
            values: ReportExportOptions.sectionDimensions,
            selected: o.groupBy,
            label: texts.dimension,
            onChanged: (v) => options.value = o.copyWith(groupBy: v),
          ),
          const SizedBox(height: 12),
          SectionHeading(l10n.reportChart),
          _segments<ExportChart>(
            key: const ValueKey('generateChart'),
            values: ExportChart.values,
            selected: o.chart,
            label: (c) => exportChartName(l10n, c),
            icon: (c) => switch (c) {
              ExportChart.bars => Icons.bar_chart,
              ExportChart.pie => Icons.pie_chart,
              ExportChart.donut => Icons.donut_large,
            },
            onChanged: (v) => options.value = o.copyWith(chart: v),
          ),
          SwitchListTile(
            key: const ValueKey('generateOthers'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.reportGroupOthers),
            subtitle: Text(l10n.reportGroupOthersHint),
            value: o.groupOthers,
            onChanged: (on) => options.value = o.copyWith(groupOthers: on),
          ),
          SectionHeading(l10n.reportFormat),
          _segments<ReportExport>(
            key: const ValueKey('generateFormat'),
            values: ReportExport.values,
            selected: o.format,
            label: (f) => f == ReportExport.pdf
                ? l10n.reportFormatPdf
                : l10n.reportFormatExcel,
            onChanged: (v) => options.value = o.copyWith(format: v),
          ),
          const SizedBox(height: 16),
          const Divider(),
          SectionHeading(l10n.filters),
        ],
      ),
    );
  }

  Widget _segments<T>({
    required Key key,
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
    IconData Function(T)? icon,
  }) => SegmentedButton<T>(
    key: key,
    showSelectedIcon: false,
    segments: [
      for (final v in values)
        ButtonSegment(
          value: v,
          icon: icon == null ? null : Icon(icon(v)),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text(label(v))),
        ),
    ],
    selected: {selected},
    onSelectionChanged: (s) => onChanged(s.single),
  );
}

/// Bars, Pie, Donut.
String exportChartName(AppLocalizations l10n, ExportChart chart) =>
    switch (chart) {
      ExportChart.bars => l10n.reportFaceBars,
      ExportChart.pie => l10n.reportChartPie,
      ExportChart.donut => l10n.reportFaceDonut,
    };
