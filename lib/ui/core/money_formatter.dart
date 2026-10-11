import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/currency.dart';
import '../../domain/models/money.dart';
import 'formatting_locale.dart';

/// The one place that turns [Money] and totals into text (phase-2.md
/// §4.4, phase-5.md §5.7): `₹1,10,050.00`, `$85.00`, `¥500`.
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
  final _wholeFormats = <String, NumberFormat>{};

  /// Every digit exactly, for any amount (phase-5.md §5.7, R2): the major
  /// part goes through intl's integer path, and the minor digits are put
  /// after its last digit with the locale's decimal separator. No
  /// `double`, so even a total beyond 2⁵³ keeps its last digits.
  String format(Money money) {
    assert(money.amountMinor >= 0, 'amounts are never negative');
    final scale = minorUnitsPerMajor(_minorDigits(money.currencyCode));
    return _splice(
      money.currencyCode,
      money.amountMinor ~/ scale,
      money.amountMinor % scale,
    );
  }

  /// [format] for a total, which may be larger than an `int`. Null when
  /// even its major part isn't one (above 2⁶³ − 1 major units), shown as
  /// "Too large" (R3).
  String? formatTotal(String currencyCode, BigInt amountMinor) {
    assert(amountMinor >= BigInt.zero, 'totals are never negative');
    final scale = BigInt.from(minorUnitsPerMajor(_minorDigits(currencyCode)));
    final major = amountMinor ~/ scale;
    if (!major.isValidInt) return null;
    return _splice(currencyCode, major.toInt(), (amountMinor % scale).toInt());
  }

  /// Every digit of a total, for an export (phase-8.md R7): [formatTotal]
  /// when it can, else the code and every digit with the locale's decimal
  /// separator, ungrouped (`INR 276701161105643274.21`): an export never
  /// says "Too large".
  String exactTotal(String currencyCode, BigInt amountMinor) {
    final shown = formatTotal(currencyCode, amountMinor);
    if (shown != null) return shown;
    final digits = _minorDigits(currencyCode);
    final text = amountMinor.toString().padLeft(digits + 1, '0');
    final whole = text.substring(0, text.length - digits);
    if (digits == 0) return '$currencyCode $whole';
    final separator = _whole(currencyCode).symbols.DECIMAL_SEP;
    return '$currencyCode $whole$separator'
        '${text.substring(text.length - digits)}';
  }

  /// Like [format], but a whole amount without its zero decimals: `₹50`,
  /// while `₹12.50` stays as it is. For the amount chips, where six have to
  /// share one row (found on the Oppo: `₹10.00` let only 3½ show).
  String formatShort(Money money) {
    final code = money.currencyCode;
    final scale = minorUnitsPerMajor(_minorDigits(code));
    if (money.amountMinor % scale != 0) return format(money);
    return _whole(code).format(money.amountMinor ~/ scale);
  }

  /// [major] through the cached whole-number format, then, for a currency
  /// with decimals, the separator and [minor] zero-padded, right after the
  /// last digit (`₹1,10,050` → `₹1,10,050.00`, `110.050 €` → `110.050,00 €`).
  String _splice(String code, int major, int minor) {
    final whole = _whole(code);
    final text = whole.format(major);
    final digits = _minorDigits(code);
    if (digits == 0) return text;
    final symbols = whole.symbols;
    final zero = symbols.ZERO_DIGIT.codeUnitAt(0);
    // In the locale's own digits, like the rest of the number.
    final decimals = String.fromCharCodes([
      for (final unit in minor.toString().padLeft(digits, '0').codeUnits)
        zero + unit - 0x30,
    ]);
    final last = text.lastIndexOf(
      RegExp(
        '[${symbols.ZERO_DIGIT}-'
        '${String.fromCharCode(zero + 9)}]',
      ),
    );
    return '${text.substring(0, last + 1)}${symbols.DECIMAL_SEP}$decimals'
        '${text.substring(last + 1)}';
  }

  NumberFormat _whole(String code) =>
      _wholeFormats.putIfAbsent(code, () => _build(code, decimalDigits: 0));

  /// The cached whole-number `NumberFormat` for [currencyCode], the one
  /// every amount goes through.
  @visibleForTesting
  NumberFormat numberFormat(String currencyCode) => _whole(currencyCode);

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
