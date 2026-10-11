import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/report_repository.dart';
import '../../../../domain/report_highlights.dart';
import 'report_texts.dart';

/// The Highlights strip under the report card (owner, 2026-10-11): the
/// expenses' count, the average per day, the largest expense, the payment
/// method most paid with and the top event, in the card's currency (it
/// follows the carousel). Two tiles a row; each value fits its tile,
/// scaled down rather than cut.
class HighlightsView extends StatelessWidget {
  const HighlightsView({
    super.key,
    required this.highlights,
    required this.currency,
    required this.data,
    required this.texts,
  });

  final ReportHighlights highlights;
  final String currency;
  final ReportData data;
  final ReportTexts texts;

  @override
  Widget build(BuildContext context) {
    final l10n = texts.l10n;
    final h = highlights;
    final largest = h.largest;
    final tiles = [
      _Tile(
        key: const ValueKey('hiExpenses'),
        icon: Icons.receipt_long_outlined,
        label: l10n.reportHiExpenses,
        value: texts.count(h.count),
      ),
      _Tile(
        key: const ValueKey('hiPerDay'),
        icon: Icons.today_outlined,
        label: l10n.reportHiPerDay,
        value: texts.amount(currency, h.perDay),
        caption: l10n.reportHiOverDays(h.days),
      ),
      if (largest != null)
        _Tile(
          key: const ValueKey('hiLargest'),
          icon: Icons.trending_up,
          label: l10n.reportHiLargest,
          value: texts.amount(currency, BigInt.from(largest.amountMinor)),
          caption: '${largest.title.trim()} · ${texts.day(largest.day)}',
        ),
      if (h.topMethod case final top?)
        _Tile(
          key: const ValueKey('hiTopMethod'),
          icon: Icons.payments_outlined,
          label: l10n.reportHiTopMethod,
          value: texts.key(top.key, data),
          caption: texts.amount(currency, top.amount),
        ),
      if (h.topEvent case final top?)
        _Tile(
          key: const ValueKey('hiTopEvent'),
          icon: Icons.celebration_outlined,
          label: l10n.reportHiTopEvent,
          value: texts.key(top.key, data),
          caption: texts.amount(currency, top.amount),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reportHighlights,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tile in tiles) SizedBox(width: width, child: tile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Semantics(
        container: true,
        label: [label, value, ?caption].join(', '),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // A long amount scales down, never cut.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(value, style: theme.textTheme.titleMedium),
              ),
              if (caption case final text?)
                Text(
                  text,
                  style: muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
