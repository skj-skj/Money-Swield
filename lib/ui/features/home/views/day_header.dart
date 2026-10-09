import 'package:material_ui/material_ui.dart';

import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/period_names.dart';
import '../../../core/widgets/list_frames.dart';
import '../view_models/expense_list_cubit.dart';
import 'group_frame.dart';

/// A day inside a week, month or year frame (phase-5.md §8.3, P5-3): the
/// date and the day's subtotal on one line, `Sat, 17 Oct – ₹5,000.00`, or
/// the date and a **Show subtotal** button when they don't fit. Sticky
/// below the frame top until its day ends ([DayHeaderBar]).
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.day,
    required this.names,
    required this.cubit,
    required this.defaultCurrency,
  });

  /// `occurred_on`.
  final String day;

  final PeriodNames names;
  final ExpenseListCubit cubit;
  final String defaultCurrency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = names.day(day);
    return DayHeaderBar(
      child: SubtotalView(
        cubit: cubit,
        subtotalKey: periodOf(day, Period.day, WeekStart.monday),
        title: date,
        defaultCurrency: defaultCurrency,
        style: DayHeaderBar.dateStyle(context),
        semanticsName: names.spokenDay(day),
        prefix: (amounts) => l10n.dayWithSubtotal(date, amounts),
      ),
    );
  }
}
