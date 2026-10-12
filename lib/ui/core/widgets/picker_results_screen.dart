import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../picker_order.dart';
import 'item_card.dart';
import 'two_column_masonry.dart';

/// The ⋯ screen of a `TilePicker` in search mode: the matches after the first
/// 4, as cards like the Manage lists.
///
/// Pops with true when the picker should leave search mode: after picking
/// in a single-select picker, or after creating a new item. Back pops with
/// nothing, so a multi-select picker stays in search mode with its query.
class PickerResultsScreen extends StatefulWidget {
  const PickerResultsScreen({
    super.key,
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.multiSelect,
    required this.onTap,
    this.newLabel,
    this.onNew,
  });

  /// The query, or e.g. "All events" for an empty one.
  final String title;

  final List<PickerItem> items;
  final Set<int> selectedIds;
  final bool multiSelect;
  final ValueChanged<int> onTap;

  /// The button's label, e.g. "New event". Shown with [onNew].
  final String? newLabel;

  /// Creates an item named after the query; returns whether one was made.
  final Future<bool> Function()? onNew;

  @override
  State<PickerResultsScreen> createState() => _PickerResultsScreenState();
}

class _PickerResultsScreenState extends State<PickerResultsScreen> {
  /// A copy that follows the taps here, so toggled cards show their check
  /// mark at once.
  late final Set<int> _selected = {...widget.selectedIds};

  void _tap(int id) {
    widget.onTap(id);
    if (!widget.multiSelect) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Future<void> _new() async {
    final created = await widget.onNew?.call() ?? false;
    if (created && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final newLabel = widget.newLabel;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: widget.onNew == null || newLabel == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _new,
              icon: const Icon(Icons.add),
              label: Text(newLabel),
            ),
      body: widget.items.isEmpty
          ? Center(child: Text(l10n.noMoreMatches))
          : SingleChildScrollView(
              // Room for the floating button under the last card.
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              child: TwoColumnMasonry(
                children: [
                  for (final item in widget.items)
                    ItemCard(
                      emoji: item.emoji,
                      title: item.name,
                      selected:
                          widget.multiSelect && _selected.contains(item.id),
                      onTap: () => _tap(item.id),
                    ),
                ],
              ),
            ),
    );
  }
}
