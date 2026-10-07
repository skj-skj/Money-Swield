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
