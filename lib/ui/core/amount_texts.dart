import '../../domain/amount_expression.dart';
import '../../domain/amount_input.dart';
import '../../domain/models/currency.dart';
import '../../l10n/app_localizations.dart';

/// What's wrong with a typed amount in [currencyCode]: the expense form's
/// amount field and a recurring item's Change price sheet say it the same way.
/// Null for no error.
String? amountErrorText(
  AppLocalizations l10n,
  ExpressionError? error,
  String currencyCode,
) => switch (error) {
  null => null,
  ExpressionError.empty => l10n.amountErrorEmpty,
  ExpressionError.invalid => l10n.amountErrorInvalid,
  ExpressionError.tooLarge => l10n.amountErrorTooLarge(maxIntegerDigits),
  ExpressionError.tooManyDecimals => l10n.amountErrorTooManyDecimals(
    findCurrency(currencyCode)?.minorDigits ?? 2,
    currencyCode,
  ),
  ExpressionError.divideByZero => l10n.amountErrorDivideByZero,
  ExpressionError.notPositive => l10n.amountErrorNotPositive,
};
