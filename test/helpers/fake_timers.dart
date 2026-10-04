import 'dart:async';

/// Timers the test fires by hand.
class FakeTimers {
  final List<FakeTimer> made = [];

  Timer call(Duration duration, void Function() run) {
    final timer = FakeTimer(duration, run);
    made.add(timer);
    return timer;
  }

  List<FakeTimer> get active => [
    for (final t in made)
      if (t.isActive) t,
  ];

  /// Fires every active timer, as if the debounce ran out.
  void elapse() {
    for (final timer in active) {
      timer.fire();
    }
  }
}

/// One timer of [FakeTimers]; [fire] runs it once.
class FakeTimer implements Timer {
  FakeTimer(this.duration, this._run);

  final Duration duration;
  final void Function() _run;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _run();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}
