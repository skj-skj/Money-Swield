import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart' show protected;

/// For a cubit whose methods keep going across awaits: the screen may
/// close the cubit (it popped, onboarding finished) before a result
/// arrives, and `emit` after `close()` asserts in debug mode. Every such
/// cubit emits its async results through [emitIfOpen].
mixin EmitIfOpen<S> on CubitSignal<S> {
  /// [emit], or nothing once the cubit is closed.
  @protected
  void emitIfOpen(S state) {
    if (!isClosed) emit(state);
  }
}
