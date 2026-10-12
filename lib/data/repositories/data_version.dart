/// A counter bumped by every repository write that changes what the screens
/// list (expenses and what they point to), after its transaction commits.
/// Settings and the draft slot don't bump it.
///
/// A screen compares it with the value it last loaded at when it shows
/// again (a tab becoming visible, a pushed screen closing), so coming back
/// with nothing changed reloads nothing, even with hundreds of rows loaded.
/// A plain counter rather than a signal or stream on purpose: nothing
/// reloads while it is hidden, only when it shows again.
class DataVersion {
  int _value = 0;

  int get value => _value;

  void bump() => _value++;
}
