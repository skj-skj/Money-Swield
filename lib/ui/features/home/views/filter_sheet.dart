import 'package:material_ui/material_ui.dart';

import '../../../../domain/expense_filter.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/period_names.dart';
import '../../../core/widgets/filter/filter_sheet.dart';
import '../../../core/widgets/section_heading.dart';

/// Home's filter sheet (phase-5.md §8.4): the shared one
/// ([showFilterSheet]) with the list's Group by above the fields. Returns
/// both however the sheet closes (P5-18).
Future<({ExpenseFilter filter, Period grouping})> showHomeFilterSheet(
  BuildContext context, {
  required ExpenseFilter filter,
  required Period grouping,
  required Map<int, Category> categories,
  required Map<int, Event> events,
}) async {
  // Not disposed: the sheet may still build it while it slides away; it
  // has no other listener and goes with it.
  final chosen = ValueNotifier(grouping);
  final value = await showFilterSheet(
    context,
    filter: filter,
    categories: categories,
    events: events,
    leading: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(AppLocalizations.of(context).groupBy),
        ValueListenableBuilder(
          valueListenable: chosen,
          builder: (context, grouping, _) => _GroupBy(
            grouping: grouping,
            onChanged: (period) => chosen.value = period,
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
  return (filter: value.filter, grouping: chosen.value);
}

/// Home's list grouping: Day, Week, Month, Year.
class _GroupBy extends StatelessWidget {
  const _GroupBy({required this.grouping, required this.onChanged});

  final Period grouping;
  final ValueChanged<Period> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<Period>(
      key: const ValueKey('groupBy'),
      showSelectedIcon: false,
      segments: [
        for (final p in Period.values)
          ButtonSegment(
            value: p,
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(periodName(l10n, p)),
            ),
          ),
      ],
      selected: {grouping},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}
