/// The Photos screen's months and days. Pure Dart.
library;

import 'home_list.dart';
import 'models/expense.dart';
import 'periods.dart';
import 'photos.dart';

/// An expense with its photos, in order: a row of the Photos screen's
/// read (`ExpenseRepository.photoExpensesPage`).
typedef PhotoExpense = ({Expense expense, List<SavedPhoto> photos});

/// One photo on the Photos screen. A photo shared by two expenses is two tiles,
/// told apart by [tileKeyOf].
typedef PhotoTile = ({Expense expense, SavedPhoto photo});

/// What selects a tile: its expense and photo (owner revs 5–6).
typedef PhotoTileKey = ({int expenseId, int photoId});

PhotoTileKey tileKeyOf(PhotoTile tile) =>
    (expenseId: tile.expense.id, photoId: tile.photo.id);

/// A month frame: "Oct 2026".
final class PhotoMonth {
  const PhotoMonth({
    required this.range,
    required this.days,
    required this.open,
  });

  final PeriodRange range;

  /// Newest first.
  final List<PhotoDay> days;

  /// More pages may add to it: no frame bottom yet.
  final bool open;
}

/// A day inside a month: its photos, which the grid lays out two per row,
/// starting a new row.
final class PhotoDay {
  const PhotoDay({required this.day, required this.tiles});

  /// `occurred_on`.
  final String day;

  /// The day's expenses in list order, each one's photos in order.
  final List<PhotoTile> tiles;
}

/// [loaded] (in Home's list order) as month frames holding days, cut
/// exactly as Home cuts them (it is [homeGroups] by month: the stored
/// `occurred_on`, so a traveller's day is one day). The last month and day
/// stay open while [hasMore]. Always by month, whatever Home's grouping;
/// the week start doesn't matter for months.
List<PhotoMonth> photoGroups(
  List<PhotoExpense> loaded, {
  required bool hasMore,
}) {
  final photosOf = {for (final e in loaded) e.expense.id: e.photos};
  final groups = homeGroups(
    [for (final e in loaded) e.expense],
    grouping: Period.month,
    weekStart: WeekStart.monday,
    hasMore: hasMore,
  );
  return [
    for (final group in groups)
      PhotoMonth(
        range: group.range,
        open: group.open,
        days: [
          for (final day in group.days)
            PhotoDay(
              day: day.day,
              tiles: [
                for (final expense in day.expenses)
                  for (final photo in photosOf[expense.id] ?? const [])
                    (expense: expense, photo: photo),
              ],
            ),
        ],
      ),
  ];
}
