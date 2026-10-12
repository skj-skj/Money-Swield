import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A small digits-only box inside a sentence: "Every [ 1 ] month", "After [ 12
/// ] payments". The words around it say what it is; [label] is for TalkBack
/// only.
///
/// Not an `InputDecoration.labelText`: an empty field shows its label in place
/// of the hint, so an emptied box read "Numb…" on the Oppo. The [hint] shows
/// instead.
class RepeatNumberField extends StatelessWidget {
  const RepeatNumberField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    required this.maxDigits,
    required this.width,
    this.focusNode,
    this.errorText,
    this.enabled = true,
    this.fieldKey,
  });

  /// On the `TextField` itself, for tests.
  final Key? fieldKey;

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxDigits;
  final double width;
  final FocusNode? focusNode;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    // One node: "Number of payments, 12, edit box", not the label and the
    // field read apart.
    child: MergeSemantics(
      child: Semantics(
        label: label,
        child: TextField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxDigits),
          ],
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            errorMaxLines: 2,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ),
    ),
  );
}
