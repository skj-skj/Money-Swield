import 'package:material_ui/material_ui.dart';

import '../../../../domain/periods.dart';
import '../../../../domain/report_range.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/pickers.dart';
import 'report_texts.dart';

/// The Range dialog (phase-8.md §8.3, P8-4, P8-5): From, To, All time.
/// Returns the range on Show; null on Cancel, back or a tap outside
/// (nothing changes then). [initial] is the saved range, or the last 12
/// months the first time; with All time its dates are [fallback]'s.
Future<ReportRange?> showRangeDialog(
  BuildContext context, {
  required ReportRange initial,
  required ReportRange fallback,
  required ReportTexts texts,
}) => showDialog<ReportRange>(
  context: context,
  builder: (_) =>
      _RangeDialog(initial: initial, fallback: fallback, texts: texts),
);

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({
    required this.initial,
    required this.fallback,
    required this.texts,
  });

  final ReportRange initial;
  final ReportRange fallback;
  final ReportTexts texts;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late bool _allTime = widget.initial.isAllTime;

  /// Kept while All time is on (greyed), back when it's turned off.
  late String _from = widget.initial.from ?? widget.fallback.from!;
  late String _to = widget.initial.to ?? widget.fallback.to!;

  /// From can't pass To, nor To come before From (§8.3), so the pair is
  /// always valid.
  Future<void> _pickFrom() async {
    final picked = await pickDay(
      context,
      initial: _from,
      first: firstExpenseDay,
      last: _to,
      helpText: AppLocalizations.of(context).reportFrom,
    );
    if (picked != null && mounted) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await pickDay(
      context,
      initial: _to,
      first: _from,
      last: lastExpenseDay,
      helpText: AppLocalizations.of(context).reportTo,
    );
    if (picked != null && mounted) setState(() => _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.reportRangeTitle),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DateRow(
              key: const ValueKey('rangeFrom'),
              label: l10n.reportFrom,
              value: widget.texts.day(_from),
              onTap: _allTime ? null : _pickFrom,
            ),
            _DateRow(
              key: const ValueKey('rangeTo'),
              label: l10n.reportTo,
              value: widget.texts.day(_to),
              onTap: _allTime ? null : _pickTo,
            ),
            SwitchListTile(
              key: const ValueKey('rangeAllTime'),
              title: Text(l10n.reportAllTime),
              value: _allTime,
              onChanged: (on) => setState(() => _allTime = on),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('rangeShow'),
          onPressed: () => Navigator.pop(
            context,
            _allTime
                ? const ReportRange.allTime()
                : ReportRange(ReportPeriod.range, _from, _to),
          ),
          child: Text(l10n.reportShow),
        ),
      ],
    );
  }
}

/// "From  [ 1 Nov 2025 ▾ ]": greyed and not tappable without [onTap].
class _DateRow extends StatelessWidget {
  const _DateRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: onTap != null,
    onTap: onTap,
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: onTap == null ? Theme.of(context).disabledColor : null,
          ),
        ),
        const Icon(Icons.arrow_drop_down),
      ],
    ),
  );
}
