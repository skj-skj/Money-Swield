import 'package:material_ui/material_ui.dart';

import '../../../domain/models/currency.dart';
import '../../../l10n/app_localizations.dart';
import 'app_sheet.dart';
import 'section_heading.dart';

/// Opens the currency picker as a bottom sheet and returns the picked ISO
/// code, or null if dismissed. [recent] (most recent first) fills a
/// "Recent" section above the full list while the search box is empty.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  required String selected,
  List<String> recent = const [],
}) {
  return showAppSheet<String>(
    context,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: CurrencySearchList(
        selected: selected,
        recent: recent,
        onSelected: (code) => Navigator.pop(context, code),
      ),
    ),
  );
}

/// The "Recent" section of the picker: [selected] first, then up to
/// [maxRecent] of [recent], without duplicates and without codes missing
/// from the catalog (a newer app's data). Empty when nothing but the
/// selected currency would be in it, so a fresh install shows the plain
/// list (phase-2.md §8).
List<Currency> recentSection(
  String selected,
  List<String> recent, {
  int maxRecent = 5,
}) {
  final others = <Currency>[];
  for (final code in recent) {
    if (others.length == maxRecent) break;
    final currency = findCurrency(code);
    if (currency == null || code == selected || others.contains(currency)) {
      continue;
    }
    others.add(currency);
  }
  if (others.isEmpty) return const [];
  return [?findCurrency(selected), ...others];
}

/// A search field over the currency catalog, filtering by code or name.
/// Used in the picker sheet and inline in onboarding.
class CurrencySearchList extends StatefulWidget {
  const CurrencySearchList({
    super.key,
    required this.selected,
    this.recent = const [],
    required this.onSelected,
  });

  /// ISO code of the selected currency.
  final String selected;

  /// Recently used codes, most recent first, for the "Recent" section.
  final List<String> recent;

  final ValueChanged<String> onSelected;

  @override
  State<CurrencySearchList> createState() => _CurrencySearchListState();
}

class _CurrencySearchListState extends State<CurrencySearchList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searching = _query.trim().isNotEmpty;
    final recent = searching
        ? const <Currency>[]
        : recentSection(widget.selected, widget.recent);
    // A copy: an empty search returns the const catalog itself.
    final results = [...searchCurrencies(_query)];
    // Before searching, the selected currency is shown first: the list is
    // long, and otherwise the preselected one (e.g. INR) sits off-screen.
    // With a Recent section it is already at the top there, and "All
    // currencies" keeps every currency in catalog order, so it has no gaps.
    final selected = findCurrency(widget.selected);
    if (!searching && recent.isEmpty && selected != null) {
      results.remove(selected);
      results.insert(0, selected);
    }
    // Rows of the list: a String is a section header, a Currency a row.
    final entries = <Object>[
      if (recent.isNotEmpty) ...[
        l10n.recentCurrencies,
        ...recent,
        l10n.allCurrencies,
      ],
      ...results,
    ];
    final recentCount = recent.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.searchCurrencies,
              border: const OutlineInputBorder(),
            ),
            onChanged: (text) => setState(() => _query = text),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(child: Text(l10n.noCurrencyFound(_query.trim())))
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    if (entry is String) {
                      return SectionHeading(
                        entry,
                        accent: true,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      );
                    }
                    final currency = entry as Currency;
                    final isSelected = currency.code == widget.selected;
                    final tile = ListTile(
                      key: ValueKey(currency.code),
                      leading: SizedBox(
                        width: 48,
                        child: Text(
                          currency.code,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(currency.englishName),
                      trailing: isSelected
                          ? const Icon(Icons.check)
                          : Text(currency.symbol),
                      selected: isSelected,
                      onTap: () => widget.onSelected(currency.code),
                    );
                    // A recent currency is listed again under "All
                    // currencies"; the extra key keeps siblings unique.
                    return index <= recentCount
                        ? KeyedSubtree(
                            key: ValueKey('recent:${currency.code}'),
                            child: tile,
                          )
                        : tile;
                  },
                ),
        ),
      ],
    );
  }
}
