/// The one selection rule of the photo grids, shared by the form's Photos
/// sheet, the Bin detail and the Photos screen. Pure Dart.
library;

/// [selection] after a tap on [item] while selecting: [item] toggled, and
/// unselecting the last one ends selection (null).
Set<T>? toggledSelection<T>(Set<T> selection, T item) {
  final next = selection.contains(item)
      ? ({...selection}..remove(item))
      : {...selection, item};
  return next.isEmpty ? null : next;
}
