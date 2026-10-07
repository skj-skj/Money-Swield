import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/ui/core/emit_if_open.dart';

/// Loads a value across an await, like every cubit using the mixin.
class _Loader extends CubitSignal<int> with EmitIfOpen<int> {
  _Loader() : super(initialState: 0);

  final gate = Completer<int>();

  Future<void> load() async => emitIfOpen(await gate.future);
}

void main() {
  test('emits while open', () async {
    final cubit = _Loader();
    addTearDown(cubit.close);
    final load = cubit.load();
    cubit.gate.complete(5);
    await load;
    expect(cubit.value, 5);
  });

  test('a result arriving after close is dropped, without the debug '
      'assert a plain emit hits', () async {
    final cubit = _Loader();
    final load = cubit.load();
    await cubit.close();
    cubit.gate.complete(5);
    await expectLater(load, completes);
    expect(cubit.isClosed, isTrue);
  });
}
