import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/popularity.dart';
import 'package:my_expense_tracker_app/ui/core/builtin_names.dart';
import 'package:my_expense_tracker_app/ui/core/picker_order.dart';

void main() {
  /// Items 1..n named "Item 1" …, in that (popularity) order.
  List<PickerItem> items(int count) => [
    for (var i = 1; i <= count; i++)
      PickerItem(id: i, emoji: '🔹', name: 'Item $i'),
  ];

  List<int> ids(List<PickerItem> items) => [for (final i in items) i.id];

  group('pickerTiles, single select', () {
    test('shows the top 8', () {
      expect(ids(pickerTiles(items(12), {}, multiSelect: false)), [
        1, 2, 3, 4, 5, 6, 7, 8, //
      ]);
    });

    test('a selection inside the top 8 changes nothing', () {
      expect(ids(pickerTiles(items(12), {3}, multiSelect: false)), [
        1, 2, 3, 4, 5, 6, 7, 8, //
      ]);
    });

    test('a selection outside the top 8 takes the 8th slot', () {
      expect(ids(pickerTiles(items(12), {11}, multiSelect: false)), [
        1, 2, 3, 4, 5, 6, 7, 11, //
      ]);
    });

    test('fewer than 8 items are all shown', () {
      expect(ids(pickerTiles(items(3), {2}, multiSelect: false)), [1, 2, 3]);
      expect(pickerTiles(items(0), {}, multiSelect: false), isEmpty);
    });
  });

  group('pickerTiles, multi select', () {
    test('selected events outside the top 8 take the slots from the end', () {
      expect(ids(pickerTiles(items(12), {10, 12}, multiSelect: true)), [
        1, 2, 3, 4, 5, 6, 12, 10, //
      ]);
    });

    test('never pushes out a selected tile inside the top 8', () {
      expect(ids(pickerTiles(items(12), {8, 7, 11}, multiSelect: true)), [
        1, 2, 3, 4, 5, 11, 7, 8, //
      ]);
    });

    test('more than 8 selected: the rest stay out of the grid', () {
      final selected = {for (var i = 3; i <= 12; i++) i};
      final tiles = ids(pickerTiles(items(12), selected, multiSelect: true));
      expect(tiles, hasLength(8));
      expect(tiles.every(selected.contains), isTrue);
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
