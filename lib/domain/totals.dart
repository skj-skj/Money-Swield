/// Totals per currency (phase-5.md §5.2). Never stored: every total is
/// added up here from the stored minor units of the rows it covers.
library;

/// Per currency code, the exact sum in minor units.
typedef CurrencyTotals = Map<String, BigInt>;

/// One row a total covers: its local date, currency and amount.
typedef AmountRow = (String day, String code, int amountMinor);

/// Adds up [rows] per currency. `BigInt`, so a sum can't overflow (Dart's
/// `int` wraps silently at 2⁶³, SQLite's `SUM` throws there; phase-5.md
/// R3). Only currencies that have rows appear.
CurrencyTotals sumByCurrency(Iterable<(String code, int amountMinor)> rows) {
  final totals = <String, BigInt>{};
  for (final (code, minor) in rows) {
    totals[code] = (totals[code] ?? BigInt.zero) + BigInt.from(minor);
  }
  return totals;
}

/// [sumByCurrency] of the [AmountRow]s from [from] to [to], inclusive.
CurrencyTotals sumRowsIn(Iterable<AmountRow> rows, String from, String to) =>
    sumByCurrency([
      for (final (day, code, minor) in rows)
        if (day.compareTo(from) >= 0 && day.compareTo(to) <= 0) (code, minor),
    ]);

/// [totals] in display order: [defaultCurrency] first, then by code, so
/// the order doesn't jump when amounts change.
List<(String code, BigInt amountMinor)> orderedTotals(
  CurrencyTotals totals,
  String defaultCurrency,
) => [
  for (final code in orderedCodes(totals.keys, defaultCurrency))
    (code, totals[code]!),
];

/// [codes] with [defaultCurrency] first (when present), then by code.
List<String> orderedCodes(Iterable<String> codes, String defaultCurrency) =>
    codes.toSet().toList()..sort((a, b) {
      if (a == defaultCurrency) return -1;
      if (b == defaultCurrency) return 1;
      return a.compareTo(b);
    });
