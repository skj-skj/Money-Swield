import 'package:material_ui/material_ui.dart';

import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/period_names.dart';
import '../view_models/expense_list_cubit.dart';
import 'group_frame.dart';

/// A day inside a week, month or year frame (phase-5.md §8.3, P5-3): the
/// date and the day's subtotal on one line, `Sat, 17 Oct – ₹5,000.00`, or
/// the date and a **Show subtotal** button when they don't fit. Sticky
/// below the frame top until its day ends, on a page-coloured strip with
/// the frame's side lines.
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final date = names.day(day);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: CustomPaint(
        painter: _SideLines(theme.colorScheme.outlineVariant),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            frameMargin + frameInset,
            6,
            frameMargin + frameInset,
            2,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SubtotalView(
              cubit: cubit,
              subtotalKey: periodOf(day, Period.day, WeekStart.monday),
              title: date,
              defaultCurrency: defaultCurrency,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
              semanticsName: names.spokenDay(day),
              prefix: (amounts) => l10n.dayWithSubtotal(date, amounts),
            ),
          ),
        ),
      ),
    );
  }
}

/// The frame's side lines behind a pinned day header, so the frame doesn't
/// look broken where the header covers it.
class _SideLines extends CustomPainter {
  _SideLines(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        const Offset(frameMargin, 0),
        Offset(frameMargin, size.height),
        paint,
      )
      ..drawLine(
        Offset(size.width - frameMargin, 0),
        Offset(size.width - frameMargin, size.height),
        paint,
      );
  }

  @override
  bool shouldRepaint(_SideLines old) => old.color != color;
}
