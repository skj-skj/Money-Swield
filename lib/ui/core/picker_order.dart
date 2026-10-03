/// One tile of a `TilePicker`: a category, an event, or (in the move
/// dialog) the target of a move.
class PickerItem {
  const PickerItem({required this.id, required this.emoji, required this.name});

  final int id;
  final String emoji;

  /// The display name in the current language.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is PickerItem &&
      other.id == id &&
      other.emoji == emoji &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, emoji, name);

  @override
  String toString() => 'PickerItem($id, $emoji $name)';
}

/// How many tiles the picker grid shows: two rows of four.
const pickerGridSize = 8;

/// The tiles of the grid in its normal state, from [ordered] (most popular
/// first): the top [pickerGridSize], except that selected items are always
/// visible (phase-2.md §6.2).
///
/// With [multiSelect] off, a selected item outside the top 8 takes the 8th
/// slot. With it on, selected items outside the top 8 take the slots from
/// the end (8th, 7th …), never pushing out another selected one; any left
/// over stay selected and are reachable through search.
///
/// [size] is smaller than [pickerGridSize] when a "None" tile takes a slot.
List<PickerItem> pickerTiles(
  List<PickerItem> ordered,
  Set<int> selectedIds, {
  required bool multiSelect,
  int size = pickerGridSize,
}) {
  final tiles = ordered.take(size).toList();
  final shown = {for (final tile in tiles) tile.id};
  final outside = [
    for (final item in ordered.skip(size))
      if (selectedIds.contains(item.id) && !shown.contains(item.id)) item,
  ];
  if (outside.isEmpty) return tiles;
  if (!multiSelect) {
    tiles[tiles.length - 1] = outside.first;
    return tiles;
  }
  for (var slot = tiles.length - 1; slot >= 0 && outside.isNotEmpty; slot--) {
    if (!selectedIds.contains(tiles[slot].id)) {
      tiles[slot] = outside.removeAt(0);
    }
  }
  return tiles;
}

/// The items of [ordered] (most popular first) whose name matches [query],
/// ignoring case: names that start with it first, then names that contain
/// it, each group keeping the popularity order. An empty query matches
/// everything, which is how Search → ⋯ browses all items.
List<PickerItem> searchPickerItems(List<PickerItem> ordered, String query) {
  final text = query.trim().toLowerCase();
  if (text.isEmpty) return ordered;
  final starting = <PickerItem>[];
  final containing = <PickerItem>[];
  for (final item in ordered) {
    final name = item.name.toLowerCase();
    if (name.startsWith(text)) {
      starting.add(item);
    } else if (name.contains(text)) {
      containing.add(item);
    }
  }
  return [...starting, ...containing];
}
