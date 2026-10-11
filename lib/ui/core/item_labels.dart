import '../../domain/models/category.dart';
import '../../domain/models/event.dart';
import '../../domain/models/payment_method.dart';
import '../../l10n/app_localizations.dart';
import 'builtin_names.dart';

/// "💵 Cash": an item's emoji and name with one space between, the one
/// way the app writes a category, event or payment method in text (a
/// dropdown, a summary line, a dialog option, a filter chip).
String emojiLabel(String emoji, String name) => '$emoji $name';

/// [emojiLabel] of [category] in the app's language.
String categoryLabel(AppLocalizations l10n, Category category) =>
    emojiLabel(category.emoji, categoryName(l10n, category));

/// [emojiLabel] of [event] in the app's language.
String eventLabel(AppLocalizations l10n, Event event) =>
    emojiLabel(event.emoji, eventName(l10n, event));

/// [emojiLabel] of [method] in the app's language.
String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) =>
    emojiLabel(method.emoji, paymentMethodName(l10n, method));

/// The items of [ids] found in [items], as [show] writes them (else their
/// [name]), in [name] order ([compareNames], the app's language). An id
/// not in [items] (deleted, or a newer app's) is [missing] at the end, one
/// per id, or left out when [missing] is null. For lists of chosen items:
/// a filter chip, a report's filter line, a row's events.
List<String> namesInOrder<T>(
  Iterable<int> ids,
  Map<int, T> items, {
  required String Function(T item) name,
  String Function(T item)? show,
  String? missing,
}) {
  final found = <T>[];
  var gone = 0;
  for (final id in ids) {
    if (items[id] case final item?) {
      found.add(item);
    } else {
      gone++;
    }
  }
  found.sort((a, b) => compareNames(name(a), name(b)));
  return [
    for (final item in found) (show ?? name)(item),
    if (missing != null)
      for (var i = 0; i < gone; i++) missing,
  ];
}
