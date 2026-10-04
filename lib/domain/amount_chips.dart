/// Home's amount chips (phase-4.md §6.2, P4-10, P4-11).
library;

import 'models/money.dart';

/// The most chips shown.
const maxAmountChips = 6;

/// Amounts offered when there aren't enough popular ones, in **major**
/// units, by currency. Other currencies get popular amounts only.
const fallbackChipAmounts = <String, List<int>>{
  'INR': [10, 50, 100, 200, 500, 1000],
  'USD': [1, 5, 10, 20, 50, 100],
  'EUR': [1, 5, 10, 20, 50, 100],
  'GBP': [1, 5, 10, 20, 50, 100],
  'JPY': [100, 500, 1000, 2000, 5000, 10000],
};

/// Up to [maxAmountChips] amounts in minor units, ascending: [popular]
/// (most used first) topped up with [currencyCode]'s fallback amounts that
/// aren't already there.
List<int> amountChips(
  List<int> popular, {
  required String currencyCode,
  required int minorDigits,
}) {
  final chips = <int>{...popular.take(maxAmountChips)};
  final scale = minorUnitsPerMajor(minorDigits);
  for (final major in fallbackChipAmounts[currencyCode] ?? const <int>[]) {
    if (chips.length >= maxAmountChips) break;
    chips.add(major * scale);
  }
  return chips.toList()..sort();
}
