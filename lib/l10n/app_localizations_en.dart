// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Expense Tracker';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get getStarted => 'Get started';

  @override
  String get continueButton => 'Continue';

  @override
  String get tryAgain => 'Try again';

  @override
  String get copyErrorReport => 'Copy error report';

  @override
  String get reportCopied => 'Report copied';

  @override
  String get saveFailed => 'Couldn\'t save. Please try again.';

  @override
  String get loadFailed => 'Couldn\'t load this list.';

  @override
  String get migrationChecking => 'Checking your data…';

  @override
  String get migrationBackingUp => 'Backing up your data…';

  @override
  String migrationUpdating(int current, int total) {
    return 'Updating your data ($current of $total)';
  }

  @override
  String get migrationVerifying => 'Verifying your data…';

  @override
  String get migrationDone => 'Done';

  @override
  String get migrationKeepOpen => 'Please keep the app open.';

  @override
  String get migrationQuestionTitle => 'One quick question';

  @override
  String get migrationFailedTitle => 'Updating your data failed';

  @override
  String get migrationFailedMessage =>
      'Your data was not changed by the failed step. Please copy the report below and send it to us so we can fix it in the next update.';

  @override
  String migrationFailedStep(String migration) {
    return 'Failed migration: $migration';
  }

  @override
  String get startupFailedTitle => 'Your data couldn\'t be opened';

  @override
  String get startupFailedMessage =>
      'Nothing was changed. Please copy the report below and send it to us so we can fix it in the next update.';

  @override
  String onboardingStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingLanguageTitle => 'Choose your language';

  @override
  String get onboardingCurrencyTitle => 'Your currency';

  @override
  String get onboardingCurrencySubtitle =>
      'New expenses use this currency. You can change it anytime in Settings.';

  @override
  String get onboardingPaymentMethodTitle => 'How do you usually pay?';

  @override
  String get onboardingPaymentMethodSubtitle =>
      'New expenses use this payment method. You can change it anytime in Settings.';

  @override
  String get languageSystem => 'System default';

  @override
  String languageSystemDetected(String language) {
    return 'System default (detected: $language)';
  }

  @override
  String get searchCurrencies => 'Search by code or name';

  @override
  String noCurrencyFound(String query) {
    return 'No currency matches \"$query\"';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navManage => 'Manage';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeEmptyTitle => 'No expenses yet';

  @override
  String get homeEmptyMessage =>
      'Adding expenses is coming in the next update.';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get eventsTitle => 'Events';

  @override
  String get paymentMethodsTitle => 'Payment methods';

  @override
  String get addCategory => 'Add category';

  @override
  String get addEvent => 'Add event';

  @override
  String get addPaymentMethod => 'Add payment method';

  @override
  String get editCategory => 'Edit category';

  @override
  String get editEvent => 'Edit event';

  @override
  String get editPaymentMethod => 'Edit payment method';

  @override
  String get listEmpty => 'Nothing here yet. Tap + to add one.';

  @override
  String archivedSection(int count) {
    return 'Archived ($count)';
  }

  @override
  String get defaultBadge => 'Default';

  @override
  String get fieldEmoji => 'Emoji';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldDescription => 'Description (optional)';

  @override
  String get errorNameRequired => 'Enter a name';

  @override
  String errorTooLong(int max) {
    return 'Use at most $max characters';
  }

  @override
  String errorNameDuplicate(String name) {
    return '\"$name\" already exists';
  }

  @override
  String get errorEmojiRequired => 'Pick an emoji';

  @override
  String get errorEmojiNotSingle => 'Use exactly one emoji';

  @override
  String get resetToDefaultName => 'Reset to default name';

  @override
  String deleteConfirmTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteConfirmMessage => 'This can\'t be undone.';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get cannotDeleteDefaultHint => 'Set another method as default first';

  @override
  String get pickEmojiTitle => 'Pick an emoji';

  @override
  String get typeAnyEmoji => 'Type any emoji';

  @override
  String get useEmoji => 'Use';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingLanguage => 'Language';

  @override
  String get settingTheme => 'Theme';

  @override
  String get settingDefaultCurrency => 'Default currency';

  @override
  String get settingDefaultPaymentMethod => 'Default payment method';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryDrinks => 'Drinks';

  @override
  String get categoryGroceries => 'Groceries';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryClothes => 'Clothes';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryFuel => 'Fuel';

  @override
  String get categoryRent => 'Rent';

  @override
  String get categoryHouse => 'House';

  @override
  String get categoryBills => 'Bills';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryGifts => 'Gifts';

  @override
  String get categoryPersonalCare => 'Personal care';

  @override
  String get categorySubscription => 'Subscription';

  @override
  String get categoryLoan => 'Loan';

  @override
  String get categoryInvestment => 'Investment';

  @override
  String get categoryOther => 'Other';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodUpi => 'UPI';

  @override
  String get paymentMethodDebitCard => 'Debit card';

  @override
  String get paymentMethodCreditCard => 'Credit card';

  @override
  String get eventBirthday => 'Birthday';

  @override
  String get eventAnniversary => 'Anniversary';

  @override
  String get eventParty => 'Party';

  @override
  String get eventFestival => 'Festival';

  @override
  String get eventTrip => 'Trip';
}
