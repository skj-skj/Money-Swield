import 'package:material_ui/material_ui.dart';

import '../../../domain/expense_filter.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/event.dart';
import '../../../domain/models/payment_method.dart';
import '../../../l10n/app_localizations.dart';
import '../builtin_names.dart';
import '../item_labels.dart';

/// One chip per active part of a filter, each with ✕: the text, Only recurring,
/// the categories, the events and, on Reports, the payment methods. Home's
/// filter bar and the Reports screen show the same chips. A chip's ✕ calls
/// [onChange] with that part removed; a tap on a chip calls [onOpen].
List<Widget> filterChips(
  BuildContext context, {
  required ExpenseFilter filter,
  required Map<int, Category> categories,
  required Map<int, Event> events,
  required ValueChanged<ExpenseFilter> onChange,
  required VoidCallback onOpen,
  Set<int> paymentMethodIds = const {},
  Map<int, PaymentMethod> paymentMethods = const {},
  VoidCallback? onClearPaymentMethods,
}) {
  final l10n = AppLocalizations.of(context);
  final text = searchWords(filter.text).isEmpty ? null : filter.text.trim();
  Widget chip(Key key, String label, VoidCallback onDeleted) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: InputChip(
      key: key,
      // Long names (a user's category) are cut, so the bar stays one row.
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      onDeleted: onDeleted,
      deleteButtonTooltipMessage: l10n.removeFilter,
      onPressed: onOpen,
    ),
  );
  return [
    if (text != null)
      chip(
        const ValueKey('filterChipText'),
        l10n.filterSearchChip(text),
        () => onChange(filter.copyWith(text: '')),
      ),
    // First after the text chip.
    if (filter.onlyRecurring)
      chip(
        const ValueKey('filterChipRecurring'),
        l10n.filterChipRecurring,
        () => onChange(filter.copyWith(onlyRecurring: false)),
      ),
    if (_chosen(
          namesInOrder(
            filter.categoryIds,
            categories,
            name: (c) => categoryName(l10n, c),
            show: (c) => categoryLabel(l10n, c),
          ),
        )
        case final names?)
      chip(
        const ValueKey('filterChipCategories'),
        _label(l10n, names),
        () => onChange(filter.copyWith(categoryIds: const {})),
      ),
    if (_chosen(
          namesInOrder(
            filter.eventIds,
            events,
            name: (e) => eventName(l10n, e),
            show: (e) => eventLabel(l10n, e),
          ),
        )
        case final names?)
      chip(
        const ValueKey('filterChipEvents'),
        _label(l10n, names),
        () => onChange(filter.copyWith(eventIds: const {})),
      ),
    if (onClearPaymentMethods != null)
      if (_chosen(
            namesInOrder(
              paymentMethodIds,
              paymentMethods,
              name: (m) => paymentMethodName(l10n, m),
              show: (m) => paymentMethodLabel(l10n, m),
            ),
          )
          case final names?)
        chip(
          const ValueKey('filterChipPaymentMethods'),
          _label(l10n, names),
          onClearPaymentMethods,
        ),
  ];
}

/// The first name in name order and how many more: `🍽️ Food +2`.
String _label(AppLocalizations l10n, List<String> names) => names.length == 1
    ? names.first
    : l10n.filterMore(names.first, names.length - 1);

/// Null when none of the chosen items still exists: no chip.
List<String>? _chosen(List<String> names) => names.isEmpty ? null : names;
