import 'package:material_ui/material_ui.dart';

import '../../../../domain/home_list.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/period_names.dart';
import '../../../core/widgets/expense_tile.dart';
import '../../../core/widgets/list_frames.dart';
import '../../../core/widgets/load_more_footer.dart';
import '../view_models/expense_list_cubit.dart';
import 'day_header.dart';
import 'group_frame.dart';

/// Home's groups as slivers (phase-5.md §8.3, P5-37): per group an outline
/// ([FrameDecoration]) around a sliver group holding the sticky frame top,
/// then per day a sticky day header and the day's rows, lazily built. Day
/// grouping has no day header: the frame's name is the date. All from
/// Flutter's own slivers, no package.
List<Widget> homeListSlivers({
  required BuildContext context,
  required ExpenseListLoaded state,
  required ExpenseListCubit cubit,
  required PeriodNames names,
  required String defaultCurrency,
  required ValueChanged<int> onOpen,
}) {
  final outline = Theme.of(context).colorScheme.outlineVariant;
  final footer = state.loadingMore || state.loadMoreFailed;
  return [
    for (final group in state.groups)
      DecoratedSliver(
        key: ValueKey('group ${group.range.period.name} ${group.range.from}'),
        decoration: FrameDecoration(color: outline, open: group.open),
        sliver: SliverMainAxisGroup(
          slivers: [
            PinnedHeaderSliver(
              child: FrameTop(
                name: names.of(group.range),
                // Reads the name with the amount to TalkBack.
                trailing: SubtotalView(
                  cubit: cubit,
                  subtotalKey: group.range,
                  title: names.of(group.range),
                  defaultCurrency: defaultCurrency,
                  style: Theme.of(context).textTheme.titleSmall,
                  semanticsName: names.of(group.range),
                ),
              ),
            ),
            for (final day in group.days)
              if (group.range.period == Period.day)
                _rows(day, state, onOpen)
              else
                SliverMainAxisGroup(
                  slivers: [
                    PinnedHeaderSliver(
                      child: DayHeader(
                        day: day.day,
                        names: names,
                        cubit: cubit,
                        defaultCurrency: defaultCurrency,
                      ),
                    ),
                    _rows(day, state, onOpen),
                  ],
                ),
            // The loading / retry row sits inside the last, open frame.
            if (group.open && footer)
              SliverToBoxAdapter(
                child: LoadMoreFooter(
                  failed: state.loadMoreFailed,
                  onRetry: cubit.loadMore,
                ),
              ),
            // Lets a week's last day header leave before the frame top
            // (probe, phase-5.md §8.3).
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
  ];
}

Widget _rows(ListDay day, ExpenseListLoaded state, ValueChanged<int> onOpen) =>
    SliverList.builder(
      itemCount: day.expenses.length,
      itemBuilder: (context, index) {
        final expense = day.expenses[index];
        return ExpenseRow(
          key: ValueKey(expense.id),
          expense: expense,
          state: state,
          hasDraft: expense.id == state.draftExpenseId,
          onTap: () => onOpen(expense.id),
        );
      },
    );

/// One expense inside a frame: emoji, title, payment method and time,
/// amount. Rows show only their time: the day header (or the Day frame)
/// above gives the date.
class ExpenseRow extends StatelessWidget {
  const ExpenseRow({
    super.key,
    required this.expense,
    required this.state,
    required this.hasDraft,
    required this.onTap,
  });

  final Expense expense;
  final ExpenseListLoaded state;

  /// The draft slot holds unsaved changes to this expense: a mark after
  /// the amount. The row still shows the stored values (P4-21).
  final bool hasDraft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final methodEmoji =
        state.paymentMethods[expense.paymentMethodId]?.emoji ??
        ExpenseTile.missingEmoji;
    // The time as it was on the clock where it was recorded.
    final time = timeText(dateLocaleOf(context), expense.wallClock);
    return ExpenseTile(
      emoji:
          state.categories[expense.categoryId]?.emoji ??
          ExpenseTile.missingEmoji,
      title: expense.title,
      subtitle: '$methodEmoji  $time',
      amount: expense.amount,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: frameMargin + frameInset,
      ),
      marks: [
        ?repeatMark(context, expense.isRecurring),
        ?photoMark(context, expense.photoCount),
        if (hasDraft)
          Icon(
            Icons.edit_note,
            key: const ValueKey('unsavedMark'),
            color: theme.colorScheme.tertiary,
            semanticLabel: AppLocalizations.of(context).unsavedChanges,
          ),
      ],
    );
  }
}
