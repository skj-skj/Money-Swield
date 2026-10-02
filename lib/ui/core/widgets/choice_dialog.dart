import 'package:material_ui/material_ui.dart';

/// A dialog listing [options] with a radio mark on [selectedIndex]. Returns
/// the index of the tapped option, or null if dismissed.
///
/// Returns an index rather than a value because some choices are null on
/// purpose (e.g. "System default" language), which would look like a
/// dismissal.
Future<int?> showChoiceDialog(
  BuildContext context, {
  required String title,
  required List<Widget> options,
  required int? selectedIndex,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final (index, option) in options.indexed)
          ListTile(
            leading: Icon(
              index == selectedIndex
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: option,
            selected: index == selectedIndex,
            onTap: () => Navigator.pop(context, index),
          ),
      ],
    ),
  );
}
