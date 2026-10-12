import 'package:flutter/foundation.dart' show debugPrint;

import '../../data/repositories/expense_repository.dart';

/// The currencies of the latest entered expenses, for the currency sheet's
/// Recent section. Empty if they can't be read: the sheet still works without
/// them, so a failure is only logged.
///
/// Shared by every place that opens the sheet: Home's currency chip, the
/// expense form and Settings → Default currency.
Future<List<String>> recentCurrenciesOrEmpty(ExpenseRepository expenses) async {
  try {
    return await expenses.recentCurrencies();
  } catch (error) {
    debugPrint('Loading recent currencies failed: $error');
    return const [];
  }
}
