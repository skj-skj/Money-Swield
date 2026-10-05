import '../../domain/models/category.dart';
import '../../domain/models/event.dart';
import '../../domain/models/payment_method.dart';
import '../../l10n/app_localizations.dart';

// One function per table rather than one shared switch: the built-in keys
// of different tables are separate namespaces, and a future event `travel`
// must not pick up the category's translation.

/// The name to show for [category]: the user's name if set, else the
/// localized built-in name.
String categoryName(AppLocalizations l10n, Category category) =>
    category.name ?? categoryBuiltinName(l10n, category.builtinKey ?? '');

String eventName(AppLocalizations l10n, Event event) =>
    event.name ?? eventBuiltinName(l10n, event.builtinKey ?? '');

String paymentMethodName(AppLocalizations l10n, PaymentMethod method) =>
    method.name ?? paymentMethodBuiltinName(l10n, method.builtinKey ?? '');

/// The localized name of a built-in category. An unknown key, which can
/// only come from a newer app's data, is shown as is instead of crashing.
String categoryBuiltinName(AppLocalizations l10n, String builtinKey) =>
    switch (builtinKey) {
      'food' => l10n.categoryFood,
      'drinks' => l10n.categoryDrinks,
      'groceries' => l10n.categoryGroceries,
      'shopping' => l10n.categoryShopping,
      'clothes' => l10n.categoryClothes,
      'transport' => l10n.categoryTransport,
      'fuel' => l10n.categoryFuel,
      'rent' => l10n.categoryRent,
      'house' => l10n.categoryHouse,
      'bills' => l10n.categoryBills,
      'health' => l10n.categoryHealth,
      'education' => l10n.categoryEducation,
      'entertainment' => l10n.categoryEntertainment,
      'travel' => l10n.categoryTravel,
      'gifts' => l10n.categoryGifts,
      'personal_care' => l10n.categoryPersonalCare,
      'subscription' => l10n.categorySubscription,
      'loan' => l10n.categoryLoan,
      'investment' => l10n.categoryInvestment,
      'other' => l10n.categoryOther,
      _ => builtinKey,
    };

/// See [categoryBuiltinName].
String eventBuiltinName(AppLocalizations l10n, String builtinKey) =>
    switch (builtinKey) {
      'birthday' => l10n.eventBirthday,
      'anniversary' => l10n.eventAnniversary,
      'party' => l10n.eventParty,
      'festival' => l10n.eventFestival,
      'trip' => l10n.eventTrip,
      'wedding' => l10n.eventWedding,
      'dining_out' => l10n.eventDiningOut,
      _ => builtinKey,
    };

/// See [categoryBuiltinName].
String paymentMethodBuiltinName(AppLocalizations l10n, String builtinKey) =>
    switch (builtinKey) {
      'cash' => l10n.paymentMethodCash,
      'upi' => l10n.paymentMethodUpi,
      'debit_card' => l10n.paymentMethodDebitCard,
      'credit_card' => l10n.paymentMethodCreditCard,
      _ => builtinKey,
    };

/// Orders display names alphabetically, ignoring case.
int compareNames(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());
