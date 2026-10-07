import 'package:material_ui/material_ui.dart';

import 'choice_dialog.dart';
import 'save_error.dart';

/// A settings row (icon, title, the current value under it) that opens a
/// choice dialog of [values] and saves the pick with the "Couldn't save"
/// handling. For settings whose values are a fixed list (theme, chart
/// style, week start …).
class ChoiceSettingTile<T> extends StatelessWidget {
  const ChoiceSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.values,
    required this.current,
    required this.label,
    required this.onSave,
    this.option,
  });

  final IconData icon;
  final String title;

  /// In the order the dialog lists them.
  final List<T> values;
  final T current;

  /// The text of a value: the row's subtitle and, without [option], the
  /// dialog's option.
  final String Function(T value) label;

  /// The dialog's option for a value when it needs more than text (a
  /// chart preview).
  final Widget Function(T value)? option;

  /// Writes the picked value; a throw shows "Couldn't save".
  final Future<void> Function(T value) onSave;

  Future<void> _choose(BuildContext context) async {
    final option = this.option;
    final index = await showChoiceDialog(
      context,
      title: title,
      options: [
        for (final value in values)
          option == null ? Text(label(value)) : option(value),
      ],
      selectedIndex: values.indexOf(current),
    );
    if (index == null || !context.mounted) return;
    await saveOrShowError(context, () => onSave(values[index]));
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(label(current)),
    onTap: () => _choose(context),
  );
}
