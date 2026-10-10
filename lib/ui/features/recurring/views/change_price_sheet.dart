import 'package:material_ui/material_ui.dart';

import '../../../../domain/amount_expression.dart';
import '../../../../domain/models/money.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/recurring_price.dart';
import '../../../../domain/repeat_input.dart' show lastEndOn;
import '../../../../l10n/app_localizations.dart';
import '../../../core/amount_texts.dart';
import '../../../core/currency_labels.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/money_formatter.dart';
import '../../../core/pickers.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/save_error.dart';
import '../../expenses/views/operator_row.dart';
import '../view_models/recurring_detail_cubit.dart';

/// Change price (phase-7a.md §8.5): the new amount, typed like the form's
/// (operators, the currency's digits, a live result), and the date it
/// applies from (default: the next payment). Save stays off until both are
/// valid; the sheet says why. Returns true when a price was saved.
Future<bool> showChangePriceSheet(
  BuildContext context, {
  required RecurringDetailCubit cubit,
  required String currencyCode,
  required String startOn,
}) async =>
    await showAppSheet<bool>(
      context,
      builder: (_) => _ChangePriceSheet(
        cubit: cubit,
        currencyCode: currencyCode,
        startOn: startOn,
      ),
    ) ??
    false;

class _ChangePriceSheet extends StatefulWidget {
  const _ChangePriceSheet({
    required this.cubit,
    required this.currencyCode,
    required this.startOn,
  });

  final RecurringDetailCubit cubit;
  final String currencyCode;
  final String startOn;

  @override
  State<_ChangePriceSheet> createState() => _ChangePriceSheetState();
}

class _ChangePriceSheetState extends State<_ChangePriceSheet> {
  final _amount = TextEditingController();
  final _focus = FocusNode();
  late String _from = widget.cubit.defaultPriceFrom;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _focus.dispose();
    super.dispose();
  }

  PriceCheck? get _check => widget.cubit.checkNewPrice(_amount.text, _from);

  Future<void> _pickFrom() async {
    final picked = await pickDay(
      context,
      initial: _from,
      first: widget.startOn,
      last: lastEndOn,
      helpText: AppLocalizations.of(context).priceFrom,
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _save() async {
    if (_saving || _check is! PriceOk) return;
    setState(() => _saving = true);
    var saved = false;
    await saveOrShowError(context, () async {
      saved = await widget.cubit.changePrice(_amount.text, _from);
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = dateLocaleOf(context);
    final separator = decimalSeparatorOf(context);
    final check = _amount.text.trim().isEmpty ? null : _check;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Padding(
      // Above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.changePrice, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('newPrice'),
                    controller: _amount,
                    focusNode: _focus,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: const [AmountKeyboardFormatter()],
                    style: theme.textTheme.headlineSmall,
                    decoration: InputDecoration(
                      labelText: l10n.newPrice,
                      // The symbol only: the item's currency is fixed, so
                      // the code would only crowd the amount (owner,
                      // 2026-10-09).
                      prefixText: '${currencySymbol(widget.currencyCode)} ',
                      errorText: _amountError(l10n, check),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (check is PriceOk && needsResultLine(_amount.text))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 12,
                        top: 4,
                      ),
                      child: Text(
                        l10n.amountPreview(
                          MoneyFormatter.of(context).format(
                            Money(check.amountMinor, widget.currencyCode),
                          ),
                        ),
                        key: const ValueKey('newPriceResult'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Semantics(
                    container: true,
                    button: true,
                    label:
                        '${l10n.priceFrom}: '
                        '${longDateText(locale, parseDay(_from))}',
                    excludeSemantics: true,
                    child: InkWell(
                      key: const ValueKey('priceFrom'),
                      onTap: _pickFrom,
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.priceFrom,
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.event),
                          errorText: _dateError(l10n, locale, check),
                          errorMaxLines: 3,
                        ),
                        child: Text(shortDateText(locale, parseDay(_from))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    switch (check) {
                      PriceOk(:final replaces?) => l10n.priceReplaces(
                        MoneyFormatter.of(context)
                            .format(Money(replaces, widget.currencyCode)),
                        shortDateText(locale, parseDay(_from)),
                      ),
                      _ => l10n.priceKeepsPast,
                    },
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stacks the buttons when they don't fit side by side (a
                  // Row overflowed at font 2.0 on 360 dp; §12a).
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        key: const ValueKey('savePrice'),
                        onPressed: check is PriceOk && !_saving ? _save : null,
                        child: Text(l10n.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_focus.hasFocus && keyboardUp)
            OperatorRow(
              decimalSeparator: separator,
              onKey: (key) {
                final text = applyRowKeyTo(_amount, key, separator);
                if (text != null) setState(() {});
              },
            ),
        ],
      ),
    );
  }

  String? _amountError(AppLocalizations l10n, PriceCheck? check) =>
      switch (check) {
        PriceAmountInvalid(:final error) => amountErrorText(
          l10n,
          error,
          widget.currencyCode,
        ),
        _ => null,
      };

  String? _dateError(AppLocalizations l10n, String locale, PriceCheck? check) =>
      switch (check) {
        PriceDateRefused(change: PriceChange.beforeStart) =>
          l10n.priceBeforeStart(
            shortDateText(locale, parseDay(widget.startOn)),
          ),
        PriceDateRefused(change: PriceChange.inForce) => l10n.priceInForce,
        _ => null,
      };
}
