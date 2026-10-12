import 'package:material_ui/material_ui.dart';

import '../../../domain/repeat_input.dart';
import '../../../l10n/app_localizations.dart';
import '../recurrence_text.dart';
import 'repeat_number_field.dart';

/// "Every [ 1 ] [ month ▾ ]": the Add form's Repeats section and the recurring
/// item's Edit screen. A Wrap, so at a large font the dropdown goes under the
/// field instead of being cut. The screen owns the field's controller, so
/// typing never moves the cursor.
class RepeatEveryRow extends StatelessWidget {
  const RepeatEveryRow({
    super.key,
    required this.frequency,
    required this.interval,
    required this.controller,
    required this.onInterval,
    required this.onFrequency,
    this.showError = false,
    this.enabled = true,
    this.focusNode,
    this.fieldKey = const ValueKey('repeatInterval'),
    this.dropdownKey = const ValueKey('repeatFrequency'),
  });

  final Frequency frequency;

  /// The interval typed, when valid: the unit's plural follows it.
  final int? interval;
  final TextEditingController controller;
  final ValueChanged<String> onInterval;
  final ValueChanged<Frequency> onFrequency;

  /// "1 to 99" under the field.
  final bool showError;

  /// Off: shown, not changeable (payments waiting on the Edit screen).
  final bool enabled;
  final FocusNode? focusNode;
  final Key fieldKey;
  final Key dropdownKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = interval ?? 1;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        // The field carries the label for TalkBack ("Every, 1").
        ExcludeSemantics(child: Text(l10n.repeatEvery)),
        RepeatNumberField(
          fieldKey: fieldKey,
          label: l10n.repeatEvery,
          hint: '1',
          controller: controller,
          focusNode: focusNode,
          onChanged: onInterval,
          maxDigits: 2,
          width: 72,
          enabled: enabled,
          errorText: showError
              ? l10n.repeatIntervalError(maxRepeatInterval)
              : null,
        ),
        DropdownButton<Frequency>(
          key: dropdownKey,
          value: frequency,
          onChanged: enabled
              ? (f) {
                  if (f != null) onFrequency(f);
                }
              : null,
          items: [
            for (final f in Frequency.values)
              DropdownMenuItem(value: f, child: Text(unitText(l10n, f, count))),
          ],
        ),
      ],
    );
  }
}
