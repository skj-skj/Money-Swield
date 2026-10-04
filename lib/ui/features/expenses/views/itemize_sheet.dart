import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/itemize.dart';
import '../../../../l10n/app_localizations.dart';

/// Asks a label for each additive term of the amount (phase-4.md §5.2).
/// Returns the labels, one per term (`''` = none), or null if closed
/// without Done. Done needs at least one label.
Future<List<String>?> showItemizeSheet(
  BuildContext context, {
  required List<String> terms,
  required List<String> labels,
  required String decimalSeparator,
}) => showModalBottomSheet<List<String>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _ItemizeSheet(
    terms: terms,
    labels: labels,
    decimalSeparator: decimalSeparator,
  ),
);

class _ItemizeSheet extends StatefulWidget {
  const _ItemizeSheet({
    required this.terms,
    required this.labels,
    required this.decimalSeparator,
  });

  final List<String> terms;
  final List<String> labels;
  final String decimalSeparator;

  @override
  State<_ItemizeSheet> createState() => _ItemizeSheetState();
}

class _ItemizeSheetState extends State<_ItemizeSheet> {
  late final _controllers = [
    for (var i = 0; i < widget.terms.length; i++)
      TextEditingController(
        text: i < widget.labels.length ? widget.labels[i] : '',
      ),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _anyLabel => _controllers.any((c) => c.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      // Above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.itemizeTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            for (var i = 0; i < widget.terms.length; i++) ...[
              TextField(
                key: ValueKey('itemLabel-$i'),
                controller: _controllers[i],
                autofocus: i == 0,
                maxLength: maxItemLabelLength,
                // One line: a newline would break the description's
                // first line.
                inputFormatters: [FilteringTextInputFormatter.deny('\n')],
                textCapitalization: TextCapitalization.sentences,
                textInputAction: i == widget.terms.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                onChanged: (_) => setState(() {}),
                // The item is the label, so every row says which one it
                // is (a prefix shows only while the field has focus or
                // text: found on the Oppo). No hint: the same one on every
                // row read oddly (owner).
                decoration: InputDecoration(
                  labelText: itemizeTermLabel(
                    widget.terms[i],
                    widget.decimalSeparator,
                  ),
                  border: const OutlineInputBorder(),
                ),
                // The limit still holds; three "0/40" counters were noise.
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
              ),
              const SizedBox(height: 16),
            ],
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: _anyLabel
                    ? () => Navigator.pop(context, [
                        for (final c in _controllers) c.text.trim(),
                      ])
                    : null,
                child: Text(l10n.done),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
