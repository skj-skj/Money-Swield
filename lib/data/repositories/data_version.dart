/// A counter bumped by every write of the expense, category, payment method
/// and event repositories, after its transaction commits (phase-2.md §5).
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
