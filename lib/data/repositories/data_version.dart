/// A counter bumped by every write of the expense, category, payment method
/// and event repositories, after its transaction commits (phase-2.md §5).
///
/// Home compares it with the value it last loaded at, so switching back to
/// its tab with nothing changed reloads nothing, even with hundreds of rows
/// loaded. A plain counter rather than a signal or stream on purpose: only
/// Home reads it, and only when its tab becomes visible.
class DataVersion {
  int _value = 0;

  int get value => _value;

  void bump() => _value++;
}
