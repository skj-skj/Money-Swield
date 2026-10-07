import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/item_card.dart';
import '../../../core/widgets/two_column_masonry.dart';

/// The list screen the Manage lists share (categories, events, payment
/// methods): a title, an Add button once the list is loaded, and the body
/// for each [LoadPhase], with an empty state of [emptyIcon] and the
/// "Nothing here yet" text. Each list keeps its own cubit and its own form
/// to open; this only lays them out.
class ManageListScaffold extends StatelessWidget {
  const ManageListScaffold({
    super.key,
    required this.title,
    required this.addLabel,
    required this.phase,
    required this.onRetry,
    required this.onAdd,
    required this.emptyIcon,
    required this.emptyText,
    required this.builder,
  });

  final String title;
  final String addLabel;
  final LoadPhase phase;
  final VoidCallback onRetry;

  /// Opens the add form; the button shows once the list is read (the form
  /// needs every item, to refuse a duplicate name).
  final VoidCallback onAdd;

  final IconData emptyIcon;
  final String emptyText;

  /// The loaded list, e.g. an [ItemCardGrid].
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final loaded = phase == LoadPhase.loaded || phase == LoadPhase.empty;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: loaded
          ? FloatingActionButton.extended(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            )
          : null,
      body: AsyncBody(
        phase: phase,
        onRetry: onRetry,
        empty: EmptyStateView(icon: emptyIcon, title: emptyText),
        builder: builder,
      ),
    );
  }
}

/// One Manage item as a card: emoji, name, description, optional badge.
typedef ItemCardData = ({
  Object key,
  String emoji,
  String title,
  String? description,
  String? badge,
  VoidCallback onTap,
});

/// Items as [ItemCard]s in two columns, scrolling, with room under the
/// last row for the floating button.
class ItemCardGrid extends StatelessWidget {
  const ItemCardGrid({super.key, required this.items, this.trailing});

  final List<ItemCardData> items;

  /// Under the grid, scrolling with it (the events' Archived part).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    // Room for the floating button under the last row.
    padding: const EdgeInsets.only(top: 12, bottom: 88),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ItemCardColumns(items: items),
        ),
        ?trailing,
      ],
    ),
  );
}

/// [items] as two columns of [ItemCard]s, not scrolling: for a grid inside
/// another scroll view (the events' Archived part).
class ItemCardColumns extends StatelessWidget {
  const ItemCardColumns({super.key, required this.items});

  final List<ItemCardData> items;

  @override
  Widget build(BuildContext context) => TwoColumnMasonry(
    children: [
      for (final item in items)
        ItemCard(
          key: ValueKey(item.key),
          emoji: item.emoji,
          title: item.title,
          description: item.description,
          badge: item.badge,
          onTap: item.onTap,
        ),
    ],
  );
}
