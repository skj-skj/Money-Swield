import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/money_formatter.dart';
import '../../../core/widgets/app_sheet.dart';

/// **Add selected**: every held date with its
/// price, all ticked at first; Select all / None; the button says what it does
/// ("Add 9", or "Skip all 10" with nothing ticked). Returns the ticked dates,
/// or null on Cancel, Back, a swipe down or a tap outside: nothing is written
/// then.
Future<Set<String>?> showAddSelectedSheet(
  BuildContext context, {
  required List<String> days,
  required Money? Function(String day) priceOn,
  required String Function(String day) dayName,
}) => showAppSheet<Set<String>>(
  context,
  builder: (_) =>
      _AddSelectedSheet(days: days, priceOn: priceOn, dayName: dayName),
);

class _AddSelectedSheet extends StatefulWidget {
  const _AddSelectedSheet({
    required this.days,
    required this.priceOn,
    required this.dayName,
  });

  /// Oldest first, at most 1,000.
  final List<String> days;
  final Money? Function(String day) priceOn;

  /// "Mon, Aug 3", as Home names its days (`PeriodNames.day`).
  final String Function(String day) dayName;

  @override
  State<_AddSelectedSheet> createState() => _AddSelectedSheetState();
}

class _AddSelectedSheetState extends State<_AddSelectedSheet> {
  // What is ticked is this sheet's own view state: nothing is saved until
  // the button, which hands it to the page's cubit.
  late final Set<String> _ticked = {...widget.days};

  void _setAll(bool on) => setState(() {
    _ticked.clear();
    if (on) _ticked.addAll(widget.days);
  });

  void _toggle(String day) => setState(() {
    if (!_ticked.remove(day)) _ticked.add(day);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = MoneyFormatter.of(context);
    final total = widget.days.length;
    final all = _ticked.length == total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            header: true,
            child: Text(
              l10n.whichPaymentsToAdd,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // A Wrap: at a large font the two go one under the other.
          child: Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: const ValueKey('selectAllHeld'),
                onPressed: all ? null : () => _setAll(true),
                child: Text(l10n.selectAll),
              ),
              TextButton(
                key: const ValueKey('selectNoneHeld'),
                onPressed: _ticked.isEmpty ? null : () => _setAll(false),
                child: Text(l10n.selectNone),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: total,
            itemBuilder: (context, i) {
              final day = widget.days[i];
              final price = widget.priceOn(day);
              return CheckboxListTile(
                key: ValueKey('held $day'),
                value: _ticked.contains(day),
                onChanged: (_) => _toggle(day),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(widget.dayName(day), maxLines: 2),
                secondary: price == null
                    ? null
                    : Text(
                        money.format(price),
                        style: theme.textTheme.bodyLarge,
                      ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          // An OverflowBar: at 360 dp × 2.0 the two buttons stack instead of
          // overflowing.
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const ValueKey('addSelectedConfirm'),
                onPressed: () => Navigator.pop(context, {..._ticked}),
                child: Text(
                  _ticked.isEmpty
                      ? l10n.skipAllN(total)
                      : l10n.addN(_ticked.length),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
