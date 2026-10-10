import '../../domain/models/currency.dart';

/// e.g. `₹ INR · Indian Rupee`, the symbol first with one space, like an
/// item's emoji (`emojiLabel`). intl falls back to the code for
/// currencies it has no symbol for, so then the symbol is left out instead
/// of repeating it. Settings → Defaults and the form's currency box label.
String currencyLabel(String code) => switch (findCurrency(code)) {
  final Currency c when c.symbol == c.code => '${c.code} · ${c.englishName}',
  final Currency c => '${c.symbol} ${c.code} · ${c.englishName}',
  // A code from a newer app's catalog: show it as is.
  null => code,
};

/// e.g. `₹`: a recurring item's Change price field, where the currency is
/// fixed and the code would only crowd the amount (owner, 2026-10-09). The
/// code when intl has no symbol for it.
String currencySymbol(String code) => findCurrency(code)?.symbol ?? code;

/// e.g. `₹ INR`, for Home's currency chip and the form's currency box;
/// just the code when intl has no symbol for it.
String currencyShortLabel(String code) => switch (findCurrency(code)) {
  final Currency c when c.symbol != c.code => '${c.symbol} ${c.code}',
  _ => code,
};
