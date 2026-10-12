import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// "⏷ Filtered" in the app bar of a screen opened for Home's filters: the
/// Photos screen and Upcoming payments, so it is clear that not everything is
/// listed.
class FilteredChip extends StatelessWidget {
  const FilteredChip({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 16),
    // At most 45 % of the width, scaled down to fit, never cut: at 360 dp, font
    // 2.0, Hindi's "फ़िल्टर किया गया" overflowed the app bar by 172 px. The
    // title, which can be cut, keeps the rest.
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.45,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Chip(
          avatar: const Icon(Icons.filter_alt, size: 18),
          label: Text(AppLocalizations.of(context).trendFiltered),
        ),
      ),
    ),
  );
}
