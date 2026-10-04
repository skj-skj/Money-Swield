/// An amount of money: an integer in minor units plus its currency
/// (database.md §1). The only type that carries an amount; there is no
/// `double` anywhere between the text field and the database.
class Money {
  const Money(this.amountMinor, this.currencyCode);

  /// In the currency's minor units: 11050 is ₹110.50, 500 is ¥500.
  final int amountMinor;

  /// ISO 4217 code, e.g. `INR`.
  final String currencyCode;

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.amountMinor == amountMinor &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(amountMinor, currencyCode);

  @override
  String toString() => 'Money($amountMinor $currencyCode)';
}

/// Minor units in one major unit for a currency with [minorDigits]
/// decimals: 100 for INR, 1 for JPY. Integer only, no `double`.
int minorUnitsPerMajor(int minorDigits) {
  var scale = 1;
  for (var i = 0; i < minorDigits; i++) {
    scale *= 10;
  }
  return scale;
}
