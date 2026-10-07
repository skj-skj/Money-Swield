import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/currency.dart';
import '../../../../domain/models/expense.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/item_labels.dart';
import '../../../core/money_formatter.dart';
import '../../../core/widgets/confirm_then_save.dart';
import '../../../core/widgets/save_error.dart';
import '../view_models/bin_cubit.dart';

/// A binned expense, read-only: binned expenses can't be edited, only
/// restored or deleted for good (database.md §3.5). Pops after either.
class BinDetailScreen extends StatelessWidget {
  const BinDetailScreen({
    super.key,
    required this.expense,
    required this.lookups,
    required this.onRestore,
    required this.onDeletePermanently,
  });

  final Expense expense;
  final BinLookups lookups;
  final Future<void> Function() onRestore;
  final Future<void> Function() onDeletePermanently;

  Future<void> _restore(BuildContext context) async {
    final done = await saveOrShowError(context, onRestore);
    if (done && context.mounted) Navigator.pop(context);
  }

  Future<void> _deletePermanently(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final done = await confirmThenSave(
      context,
      title: l10n.deletePermanentlyTitle(expense.title),
      message: l10n.cannotBeUndone,
      confirmLabel: l10n.delete,
      action: onDeletePermanently,
    );
    if (done && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = dateLocaleOf(context);
    final category = lookups.categories[expense.categoryId];
    final method = lookups.paymentMethods[expense.paymentMethodId];
    final events = [
      for (final id in expense.eventIds)
        if (lookups.events[id] case final event?) eventLabel(l10n, event),
    ];
    final description = expense.description;
    return Scaffold(
      appBar: AppBar(title: Text(expense.title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Row(
            label: l10n.fieldAmount,
            value: MoneyFormatter.of(context).format(expense.amount),
          ),
          _Row(
            label: l10n.fieldCurrency,
            value:
                findCurrency(expense.amount.currencyCode)?.englishName ??
                expense.amount.currencyCode,
          ),
          _Row(
            label: l10n.fieldCategory,
            value: category == null ? '❓' : categoryLabel(l10n, category),
          ),
          if (events.isNotEmpty)
            _Row(label: l10n.fieldEvents, value: events.join(', ')),
          _Row(
            label: l10n.fieldPaymentMethod,
            value: method == null ? '❓' : paymentMethodLabel(l10n, method),
          ),
          // The time as it was on the clock where it was recorded.
          _Row(
            label: l10n.fieldDate,
            value: longDateText(locale, expense.wallClock),
          ),
          _Row(
            label: l10n.fieldTime,
            value: timeText(locale, expense.wallClock),
          ),
          if (description != null)
            _Row(label: l10n.fieldNotes, value: description),
          _Row(
            label: l10n.fieldDeletedAt,
            value: dateTimeText(locale, expense.deletedAt!),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: FilledButton.icon(
              onPressed: () => _restore(context),
              icon: const Icon(Icons.restore),
              label: Text(l10n.restore),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _deletePermanently(context),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(l10n.deletePermanently),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(value), subtitle: Text(label));
  }
}
