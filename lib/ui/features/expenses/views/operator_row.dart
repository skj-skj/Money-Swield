import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/amount_field_input.dart';
import '../../../../l10n/app_localizations.dart';

/// The amount field's keyboard filter: maps `-` `*` `/` to `− × ÷`, drops
/// spaces, refuses anything else. The rules are in [filterKeyboardEdit].
class AmountKeyboardFormatter extends TextInputFormatter {
  const AmountKeyboardFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final edit = filterKeyboardEdit(
      _editOf(newValue),
      previousLength: oldValue.text.length,
    );
    if (edit == null) return oldValue;
    if (edit.text == newValue.text) return newValue;
    return TextEditingValue(
      text: edit.text,
      selection: newValue.selection.copyWith(
        baseOffset: edit.base,
        extentOffset: edit.extent,
      ),
    );
  }
}

/// Applies the operator row's [key] to [controller] at its cursor
/// ([applyRowKey]). Returns the new text, or null when the key did
/// nothing there.
String? applyRowKeyTo(
  TextEditingController controller,
  RowKey key,
  String decimalSeparator,
) {
  final edit = applyRowKey(_editOf(controller.value), key, decimalSeparator);
  if (edit == null) return null;
  controller.value = TextEditingValue(
    text: edit.text,
    selection: TextSelection.collapsed(offset: edit.base),
  );
  return edit.text;
}

FieldEdit _editOf(TextEditingValue value) => (
  text: value.text,
  base: value.selection.baseOffset,
  extent: value.selection.extentOffset,
);

/// The five keys above the keyboard while the amount has focus: `+ − × ÷` and
/// the locale's decimal separator.
///
/// Wrapped in a [TextFieldTapRegion] and an [ExcludeFocus], so tapping a
/// key never closes the keyboard or moves the focus.
class OperatorRow extends StatelessWidget {
  const OperatorRow({
    super.key,
    required this.decimalSeparator,
    required this.onKey,
  });

  final String decimalSeparator;
  final ValueChanged<RowKey> onKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final keys = [
      (RowKey.plus, '+', l10n.keyPlus),
      (RowKey.minus, '−', l10n.keyMinus),
      (RowKey.times, '×', l10n.keyTimes),
      (RowKey.divide, '÷', l10n.keyDivide),
      (RowKey.decimal, decimalSeparator, l10n.keyDecimal),
    ];
    return TextFieldTapRegion(
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        // The keys never take the focus away from the amount field.
        child: ExcludeFocus(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                for (final (key, symbol, label) in keys)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: TextButton(
                        key: ValueKey('rowKey-${key.name}'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          textStyle: theme.textTheme.titleLarge,
                        ),
                        onPressed: () => onKey(key),
                        // TalkBack reads "plus", not the symbol.
                        child: Text(symbol, semanticsLabel: label),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
