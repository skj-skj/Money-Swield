import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/currency.dart';
import '../../domain/models/money.dart';
import 'formatting_locale.dart';

/// The one place that turns [Money] into text (phase-2.md §4.4):
/// `₹1,10,050.00`, `$85.00`, `¥500`.
///
/// One instance per locale, each caching one `NumberFormat` per currency:
/// building them per row would make the expense list stutter.
class MoneyFormatter {
  MoneyFormatter._(this.localeName);

  /// The shared formatter for [localeName], e.g. `en_IN`.
  factory MoneyFormatter.forLocale(String localeName) =>
      _instances.putIfAbsent(localeName, () => MoneyFormatter._(localeName));

  /// The formatter for the app's language with the device's country
  /// ([formattingLocaleOf], shared with dates).
  static MoneyFormatter of(BuildContext context) =>
      MoneyFormatter.forLocale(formattingLocaleOf(context));

  static final _instances = <String, MoneyFormatter>{};

  final String localeName;
  final _formats = <String, NumberFormat>{};

  String format(Money money) {
    final digits = _minorDigits(money.currencyCode);
    // The only double on the money path, and display-only: any decimal of
    // at most 15 significant digits round-trips exactly through a double,
    // and parseAmount's 12-digit cap keeps every amount within that.
    // Nothing computed here is stored or summed.
    // Any digit count works (ISO 4217 has 4-digit units, e.g. CLF), not
    // only the 0, 2 and 3 the catalog uses today.
    return numberFormat(money.currencyCode)
        .format(money.amountMinor / math.pow(10, digits));
  }

  /// The cached `NumberFormat` for [currencyCode].
  @visibleForTesting
  NumberFormat numberFormat(String currencyCode) =>
      _formats.putIfAbsent(currencyCode, () => _build(currencyCode));

  NumberFormat _build(String code) {
    // An unknown code (only from a newer app's data) shows as the code
    // with 2 digits instead of crashing.
    final symbol = findCurrency(code)?.symbol ?? code;
    final format = _currencyFormat(code, symbol);
    // intl writes a symbol made of letters right against the number
    // (`din1.000`, `XYZ110.50`). A no-break space keeps it readable and on
    // one line. Symbols after the number already get a space.
    if (format.positivePrefix.isNotEmpty &&
        RegExp(r'\p{L}$', unicode: true).hasMatch(format.positivePrefix)) {
      return _currencyFormat(code, '$symbol ');
    }
    return format;
  }

  NumberFormat _currencyFormat(String code, String symbol) =>
      NumberFormat.currency(
        locale: localeName,
        name: code,
        symbol: symbol,
        decimalDigits: _minorDigits(code),
      );

  static int _minorDigits(String code) => findCurrency(code)?.minorDigits ?? 2;
}
