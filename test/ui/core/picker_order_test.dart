import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/popularity.dart';
import 'package:money_swield/ui/core/builtin_names.dart';
import 'package:money_swield/ui/core/picker_order.dart';

void main() {
  List<int> ids(List<PickerItem> items) => [for (final i in items) i.id];

  group('revealOffset', () {
    // Columns 70 wide (gap included), 4 in a 280 viewport, 10 columns: the
    // rows scroll up to 420.
    double reveal(int column, double current) => revealOffset(
      column: column,
      columnExtent: 70,
      viewport: 280,
      current: current,
      max: 420,
    );

    test('a column already in view: no scroll', () {
      expect(reveal(0, 0), 0);
      expect(reveal(3, 0), 0);
      expect(reveal(5, 140), 140);
    });

    test('a column past the end: just enough to show it at the end', () {
      expect(reveal(4, 0), 70);
      expect(reveal(7, 0), 280);
    });

    test('a column before the start: it becomes the first one', () {
      expect(reveal(1, 300), 70);
    });

    test('never past the scroll range', () {
      expect(reveal(9, 0), 420);
      expect(
        revealOffset(
          column: 2,
          columnExtent: 70,
          viewport: 280,
          current: 0,
          max: 0,
        ),
        0,
        reason: 'fits without scrolling',
      );
    });
  });

  group('searchPickerItems', () {
    const ordered = [
      PickerItem(id: 1, emoji: '', name: 'Travel'),
      PickerItem(id: 2, emoji: '', name: 'Entertainment'),
      PickerItem(id: 3, emoji: '', name: 'Investment'),
      PickerItem(id: 4, emoji: '', name: 'Drinks'),
    ];

    test('names starting with the text come first, each group in order', () {
      expect(ids(searchPickerItems(ordered, 'in')), [3, 2, 4]);
    });

    test('ignores case and surrounding spaces', () {
      expect(ids(searchPickerItems(ordered, '  TRA ')), [1]);
    });

    test('an empty query matches everything, in order', () {
      expect(ids(searchPickerItems(ordered, ' ')), [1, 2, 3, 4]);
    });

    test('no match is an empty list', () {
      expect(searchPickerItems(ordered, 'xyz'), isEmpty);
    });
  });

  group('comparePopularity', () {
    final now = DateTime.utc(2026, 10, 2);

    List<int> order(List<({ItemUsage usage, String name, int id})> list) => [
      for (final e in [
        ...list,
      ]..sort((a, b) => comparePopularity(a, b, compareNames: compareNames)))
        e.id,
    ];

    test('more uses first, then most recent, then name, then id', () {
      expect(
        order([
          (usage: noUsage, name: 'b', id: 1),
          (usage: noUsage, name: 'a', id: 2),
          (usage: noUsage, name: 'A', id: 7),
          (usage: (recentCount: 0, lastUsedAt: now), name: 'z', id: 3),
          (usage: (recentCount: 2, lastUsedAt: now), name: 'z', id: 4),
          (
            usage: (
              recentCount: 2,
              lastUsedAt: now.add(const Duration(minutes: 1)),
            ),
            name: 'z',
            id: 5,
          ),
        ]),
        [5, 4, 3, 2, 7, 1],
      );
    });
  });
}
