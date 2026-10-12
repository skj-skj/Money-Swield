import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';

/// What the Skip dialog chose.
enum SkipChoice {
  /// Skip only this payment (the default).
  once,

  /// Stop the item: no more payments (archived, with Undo).
  stop,
}

/// "Skip Gym on 9 Nov?" with **Skip only this payment** (picked) or **Stop
/// Gym: no more payments**; the button reads Skip or Stop. Null when
/// cancelled or dismissed: nothing happens.
Future<SkipChoice?> showSkipDialog(
  BuildContext context, {
  required String title,
  required String date,
}) => showDialog<SkipChoice>(
  context: context,
  builder: (_) => _SkipDialog(title: title, date: date),
);

class _SkipDialog extends StatefulWidget {
  const _SkipDialog({required this.title, required this.date});

  final String title;
  final String date;

  @override
  State<_SkipDialog> createState() => _SkipDialogState();
}

class _SkipDialogState extends State<_SkipDialog> {
  var _choice = SkipChoice.once;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.skipDialogTitle(widget.title, widget.date)),
      // Scrolls at the largest font instead of overflowing.
      scrollable: true,
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: RadioGroup<SkipChoice>(
        groupValue: _choice,
        onChanged: (choice) {
          if (choice != null) setState(() => _choice = choice);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<SkipChoice>(
              key: const ValueKey('skipOnce'),
              value: SkipChoice.once,
              title: Text(l10n.skipOnlyThis),
            ),
            RadioListTile<SkipChoice>(
              key: const ValueKey('skipStop'),
              value: SkipChoice.stop,
              title: Text(l10n.stopItem(widget.title)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const ValueKey('skipConfirm'),
          onPressed: () => Navigator.pop(context, _choice),
          child: Text(switch (_choice) {
            SkipChoice.once => l10n.skip,
            SkipChoice.stop => l10n.stop,
          }),
        ),
      ],
    );
  }
}
