import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/selection.dart';

/// The photo grids' selection rule.
void main() {
  test('a tap adds an unselected item and removes a selected one', () {
    expect(toggledSelection({1}, 2), {1, 2});
    expect(toggledSelection({1, 2}, 2), {1});
  });

  test('unselecting the last one ends selection', () {
    expect(toggledSelection({1}, 1), isNull);
  });

  test('the given set is never changed', () {
    final selection = {1, 2};
    toggledSelection(selection, 3);
    toggledSelection(selection, 1);
    expect(selection, {1, 2});
  });
}
