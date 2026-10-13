import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/amount_chips.dart';

void main() {
  List<int> inr(List<int> popular) =>
      amountChips(popular, currencyCode: 'INR', minorDigits: 2);

  test('no popular amounts: the fallback list, in minor units', () {
    expect(inr([]), [1000, 5000, 10000, 20000, 50000, 100000]);
    expect(amountChips([], currencyCode: 'JPY', minorDigits: 0), [
      100,
      500,
      1000,
      2000,
      5000,
      10000,
    ]);
  });

  test('popular amounts are topped up without duplicates, ascending', () {
    // ₹50 is popular and in the fallback list: once.
    expect(inr([5000, 3500]), [1000, 3500, 5000, 10000, 20000, 50000]);
  });

  test('six popular amounts leave no room for fallbacks', () {
    final popular = [700, 100, 600, 200, 500, 300];
    expect(inr(popular), [100, 200, 300, 500, 600, 700]);
  });

  test('more than six popular: the six most used are kept', () {
    expect(inr([7, 6, 5, 4, 3, 2, 1]), [2, 3, 4, 5, 6, 7]);
  });

  test('an unknown currency gets popular amounts only', () {
    expect(amountChips([], currencyCode: 'KWD', minorDigits: 3), isEmpty);
    expect(amountChips([2500, 1000], currencyCode: 'KWD', minorDigits: 3), [
      1000,
      2500,
    ]);
  });
}
