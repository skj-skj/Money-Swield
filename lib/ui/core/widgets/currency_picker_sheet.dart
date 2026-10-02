import 'package:material_ui/material_ui.dart';

import '../../../domain/models/currency.dart';
import '../../../l10n/app_localizations.dart';

/// e.g. `₹  INR · Indian Rupee`, the symbol first like the payment
/// method's emoji. intl falls back to the code for currencies it has no
/// symbol for, so then the symbol is left out instead of repeating it.
String currencyLabel(String code) => switch (findCurrency(code)) {
  final Currency c when c.symbol == c.code => '${c.code} · ${c.englishName}',
  final Currency c => '${c.symbol}  ${c.code} · ${c.englishName}',
  // A code from a newer app's catalog: show it as is.
  null => code,
};

/// Opens the currency picker as a bottom sheet and returns the picked ISO
/// code, or null if dismissed.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: CurrencySearchList(
        selected: selected,
        onSelected: (code) => Navigator.pop(context, code),
      ),
    ),
  );
}

/// A search field over the currency catalog, filtering by code or name.
/// Used in the picker sheet and inline in onboarding.
class CurrencySearchList extends StatefulWidget {
  const CurrencySearchList({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// ISO code of the selected currency.
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<CurrencySearchList> createState() => _CurrencySearchListState();
}

class _CurrencySearchListState extends State<CurrencySearchList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A copy: an empty search returns the const catalog itself.
    final results = [...searchCurrencies(_query)];
    // Before searching, the selected currency is shown first: the list is
    // long, and otherwise the preselected one (e.g. INR) sits off-screen.
    final selected = findCurrency(widget.selected);
    if (_query.trim().isEmpty && selected != null) {
      results.remove(selected);
      results.insert(0, selected);
    }
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
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final currency = results[index];
                    final isSelected = currency.code == widget.selected;
                    return ListTile(
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
                  },
                ),
        ),
      ],
    );
  }
}
