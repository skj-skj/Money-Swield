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

/// The scroll offset that brings [column] fully into a [viewport] of
/// sideways-scrolling columns, each [columnExtent] wide (gap included):
/// [current] if it already is in view, else just enough to show it at the
/// nearer edge, never past `0` or [max].
double revealOffset({
  required int column,
  required double columnExtent,
  required double viewport,
  required double current,
  required double max,
}) {
  final start = column * columnExtent;
  final end = start + columnExtent;
  if (start < current) return start.clamp(0, max);
  if (end > current + viewport) return (end - viewport).clamp(0, max);
  return current;
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
