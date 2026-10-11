import 'package:material_ui/material_ui.dart';

import '../period_names.dart';
import 'list_frames.dart';

/// Month frames ("Oct 2026") with sticky day headers, as slivers: the
/// Photos screen (phase-6.md §8.9) and the SMS screen (phase-9a.md §8.2)
/// lay out their months alike and differ only in what a day holds.
///
/// [months] are newest first; a month is drawn open (no bottom) while
/// [isOpen] says more pages may add to it, and [openFooter] (a spinner or
/// a retry row) then shows at its end. [dayBody] is the day's content, as
/// a sliver, inside the frame's side lines.
List<Widget> framedMonthSlivers<M, D>(
  BuildContext context, {
  required List<M> months,
  required String Function(M month) monthStart,
  required bool Function(M month) isOpen,
  required List<D> Function(M month) daysOf,
  required String Function(D day) dayOf,
  required Widget Function(BuildContext context, D day) dayBody,
  required PeriodNames names,
  Widget? openFooter,
}) {
  final outline = Theme.of(context).colorScheme.outlineVariant;
  return [
    for (final month in months)
      DecoratedSliver(
        key: ValueKey('month ${monthStart(month)}'),
        decoration: FrameDecoration(color: outline, open: isOpen(month)),
        sliver: SliverMainAxisGroup(
          slivers: [
            PinnedHeaderSliver(
              child: FrameTop(name: names.monthWithYear(monthStart(month))),
            ),
            for (final day in daysOf(month))
              SliverMainAxisGroup(
                slivers: [
                  PinnedHeaderSliver(
                    child: DayHeaderBar(
                      child: Text(
                        names.day(dayOf(day)),
                        semanticsLabel: names.spokenDay(dayOf(day)),
                        style: DayHeaderBar.dateStyle(context),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      frameMargin + frameInset,
                      4,
                      frameMargin + frameInset,
                      8,
                    ),
                    sliver: dayBody(context, day),
                  ),
                ],
              ),
            if (isOpen(month) && openFooter != null)
              SliverToBoxAdapter(child: openFooter),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
  ];
}
