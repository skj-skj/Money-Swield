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
  final _wholeFormats = <String, NumberFormat>{};

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

  /// Like [format], but a whole amount without its zero decimals: `₹50`,
  /// while `₹12.50` stays as it is. For the amount chips, where six have to
  /// share one row (found on the Oppo: `₹10.00` let only 3½ show).
  String formatShort(Money money) {
    final code = money.currencyCode;
    final scale = minorUnitsPerMajor(_minorDigits(code));
    if (money.amountMinor % scale != 0) return format(money);
    return _wholeFormats
        .putIfAbsent(code, () => _build(code, decimalDigits: 0))
        .format(money.amountMinor ~/ scale);
  }

  /// The cached `NumberFormat` for [currencyCode].
  @visibleForTesting
  NumberFormat numberFormat(String currencyCode) =>
      _formats.putIfAbsent(currencyCode, () => _build(currencyCode));

  NumberFormat _build(String code, {int? decimalDigits}) {
    // An unknown code (only from a newer app's data) shows as the code
    // with 2 digits instead of crashing.
    final symbol = findCurrency(code)?.symbol ?? code;
    final digits = decimalDigits ?? _minorDigits(code);
    final format = _currencyFormat(code, symbol, digits);
    // intl writes a symbol made of letters right against the number
    // (`din1.000`, `XYZ110.50`). A no-break space keeps it readable and on
    // one line. Symbols after the number already get a space.
    if (format.positivePrefix.isNotEmpty &&
        RegExp(r'\p{L}$', unicode: true).hasMatch(format.positivePrefix)) {
      return _currencyFormat(code, '$symbol ', digits);
    }
    return format;
  }

  NumberFormat _currencyFormat(String code, String symbol, int digits) =>
      NumberFormat.currency(
        locale: localeName,
        name: code,
        symbol: symbol,
        decimalDigits: digits,
      );

  static int _minorDigits(String code) => findCurrency(code)?.minorDigits ?? 2;
}
