import 'package:material_ui/material_ui.dart';

import '../../../domain/models/item_shape.dart';
import '../../../domain/models/owner_usage.dart';
import '../../../l10n/app_localizations.dart';
import '../builtin_names.dart';
import '../picker_order.dart';
import 'back_guard.dart';
import 'confirm_dialog.dart';
import 'save_error.dart';
import 'tile_picker.dart';

/// Delete for a category or payment method: a plain confirm when nothing uses
/// it; otherwise ask where to move its expenses, binned ones included, and its
/// recurring items, archived ones included, then move and delete in one
/// transaction. Returns whether it was deleted.
///
/// One copy for both forms, so the two delete flows can't drift apart.
/// [targets] are the other items; they are shown in name order, like the
/// Manage list the form was opened from. A failed read of [usage] says
/// "Couldn't save", like a failed delete.
Future<bool> deleteOrMoveThenDelete(
  BuildContext context, {
  required String name,
  required Future<OwnerUsage> Function() usage,
  required List<PickerItem> targets,
  required String searchHint,
  required String allTitle,
  required ItemShape tileShape,
  required ItemShape buttonShape,
  required Future<void> Function() delete,
  required Future<void> Function(int toId) moveAndDelete,
}) async {
  final l10n = AppLocalizations.of(context);
  OwnerUsage? used;
  final read = await saveOrShowError(context, () async => used = await usage());
  if (!read || !context.mounted) return false;
  if (isUnused(used!)) {
    if (!await confirmDelete(context, name) || !context.mounted) return false;
    return saveOrShowError(context, delete);
  }

  final message = ownerUsageMessage(l10n, name, used!);
  if (targets.isEmpty) {
    await showAddAnotherFirst(context, message);
    return false;
  }
  final toId = await showMoveDialog(
    context,
    tileShape: tileShape,
    buttonShape: buttonShape,
    message: message,
    items: [...targets]..sort((a, b) => compareNames(a.name, b.name)),
    searchHint: searchHint,
    allTitle: allTitle,
  );
  if (toId == null || !context.mounted) return false;
  return saveOrShowError(context, () => moveAndDelete(toId));
}

/// What uses a category or payment method about to be deleted: "… is used
/// by 4 expenses (1 in the bin). It is also used by 1 recurring item: its
/// later payments use the one you pick." Sentences rather than one
/// message per combination, so each language translates three plurals,
/// not six.
String ownerUsageMessage(AppLocalizations l10n, String name, OwnerUsage usage) {
  final (:active, :binned, :templates) = usage;
  final expenses = active + binned;
  if (expenses == 0) {
    return '${l10n.usedByTemplatesOnly(name, templates)} '
        '${l10n.templatesMoveToo(templates)}';
  }
  final first = binned == 0
      ? l10n.usedByExpenses(name, expenses)
      : l10n.usedByExpensesWithBin(name, expenses, binned);
  return templates == 0
      ? first
      : '$first ${l10n.alsoUsedByTemplates(templates)}';
}

/// Asks where to move the expenses of a category or payment method that is
/// about to be deleted. [message] says how many use it; [items] are the
/// possible targets. Returns the picked target's id, or null if cancelled.
/// Nothing is picked at first, so "Move and delete" starts disabled.
Future<int?> showMoveDialog(
  BuildContext context, {
  required String message,
  required List<PickerItem> items,
  required String searchHint,
  required String allTitle,
  ItemShape tileShape = ItemShape.rounded,
  ItemShape buttonShape = ItemShape.rounded,
}) => showDialog<int>(
  context: context,
  builder: (context) => _MoveDialog(
    message: message,
    items: items,
    searchHint: searchHint,
    allTitle: allTitle,
    tileShape: tileShape,
    buttonShape: buttonShape,
  ),
);

/// Tells the user to add another category or payment method first: there
/// is nowhere to move the expenses to.
Future<void> showAddAnotherFirst(BuildContext context, String message) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text('$message\n\n${l10n.addAnotherFirst}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}

class _MoveDialog extends StatefulWidget {
  const _MoveDialog({
    required this.message,
    required this.items,
    required this.searchHint,
    required this.allTitle,
    required this.tileShape,
    required this.buttonShape,
  });

  final String message;
  final List<PickerItem> items;
  final String searchHint;
  final String allTitle;
  final ItemShape tileShape;
  final ItemShape buttonShape;

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  int? _selected;
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _selected;
    return BackGuard(
      // Back closes the search first, as on the expense form.
      intercept: _searching,
      onBack: () => setState(() => _searching = false),
      child: AlertDialog(
        // Narrower margins than a plain dialog: at the default width the
        // four tiles per row cut most names to a few letters.
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.message),
                const SizedBox(height: 16),
                Text(
                  l10n.moveExpensesTo,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TilePicker(
                  tileShape: widget.tileShape,
                  buttonShape: widget.buttonShape,
                  items: widget.items,
                  selectedIds: {?selected},
                  multiSelect: false,
                  searching: _searching,
                  onSearchingChanged: (on) => setState(() => _searching = on),
                  onTap: (id) => setState(() => _selected = id),
                  searchHint: widget.searchHint,
                  allTitle: widget.allTitle,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: selected == null
                ? null
                : () => Navigator.pop(context, selected),
            child: Text(l10n.moveAndDelete),
          ),
        ],
      ),
    );
  }
}
