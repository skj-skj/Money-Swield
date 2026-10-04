import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/money_formatter.dart';

/// Home's usual amounts (phase-4.md §8.1): up to 6 chips in one row that
/// scrolls sideways. A tap opens Add with that amount. Nothing when empty.
class AmountChipsRow extends StatelessWidget {
  const AmountChipsRow({super.key, required this.chips, required this.onTap});

  final List<Money> chips;
  final ValueChanged<Money> onTap;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final money = MoneyFormatter.of(context);
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).amountChipsLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            for (final chip in chips)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ActionChip(
                  key: ValueKey('amountChip-${chip.amountMinor}'),
                  label: Text(money.formatShort(chip)),
                  onPressed: () => onTap(chip),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
