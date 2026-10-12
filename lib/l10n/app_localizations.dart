import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('hi'),
  ];

  /// App name. Placeholder until the real name is chosen (phase-1.md §12).
  ///
  /// In en, this message translates to:
  /// **'Expense Tracker'**
  String get appTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @copyErrorReport.
  ///
  /// In en, this message translates to:
  /// **'Copy error report'**
  String get copyErrorReport;

  /// No description provided for @reportCopied.
  ///
  /// In en, this message translates to:
  /// **'Report copied'**
  String get reportCopied;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please try again.'**
  String get saveFailed;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this list.'**
  String get loadFailed;

  /// No description provided for @migrationChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking your data…'**
  String get migrationChecking;

  /// No description provided for @migrationBackingUp.
  ///
  /// In en, this message translates to:
  /// **'Backing up your data…'**
  String get migrationBackingUp;

  /// No description provided for @migrationUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating your data ({current} of {total})'**
  String migrationUpdating(int current, int total);

  /// No description provided for @migrationVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying your data…'**
  String get migrationVerifying;

  /// No description provided for @migrationDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get migrationDone;

  /// No description provided for @migrationKeepOpen.
  ///
  /// In en, this message translates to:
  /// **'Please keep the app open.'**
  String get migrationKeepOpen;

  /// No description provided for @migrationQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'One quick question'**
  String get migrationQuestionTitle;

  /// No description provided for @migrationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Updating your data failed'**
  String get migrationFailedTitle;

  /// No description provided for @migrationFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your data was not changed by the failed step. Please copy the report below and send it to us so we can fix it in the next update.'**
  String get migrationFailedMessage;

  /// No description provided for @migrationFailedStep.
  ///
  /// In en, this message translates to:
  /// **'Failed migration: {migration}'**
  String migrationFailedStep(String migration);

  /// No description provided for @startupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data couldn\'t be opened'**
  String get startupFailedTitle;

  /// No description provided for @startupFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed. Please copy the report below and send it to us so we can fix it in the next update.'**
  String get startupFailedMessage;

  /// No description provided for @onboardingStep.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStep(int current, int total);

  /// No description provided for @onboardingLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onboardingLanguageTitle;

  /// No description provided for @onboardingCurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your currency'**
  String get onboardingCurrencyTitle;

  /// No description provided for @onboardingCurrencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'New expenses use this currency. You can change it anytime in Settings.'**
  String get onboardingCurrencySubtitle;

  /// No description provided for @onboardingPaymentMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you usually pay?'**
  String get onboardingPaymentMethodTitle;

  /// No description provided for @onboardingPaymentMethodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New expenses use this payment method. You can change it anytime in Settings.'**
  String get onboardingPaymentMethodSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageSystemDetected.
  ///
  /// In en, this message translates to:
  /// **'System default (detected: {language})'**
  String languageSystemDetected(String language);

  /// No description provided for @searchCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Search by code or name'**
  String get searchCurrencies;

  /// No description provided for @noCurrencyFound.
  ///
  /// In en, this message translates to:
  /// **'No currency matches \"{query}\"'**
  String noCurrencyFound(String query);

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get navManage;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap Add expense to record your first one.'**
  String get homeEmptyMessage;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @eventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get eventsTitle;

  /// No description provided for @paymentMethodsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get paymentMethodsTitle;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @addEvent.
  ///
  /// In en, this message translates to:
  /// **'Add event'**
  String get addEvent;

  /// No description provided for @addPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Add payment method'**
  String get addPaymentMethod;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEvent;

  /// No description provided for @editPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Edit payment method'**
  String get editPaymentMethod;

  /// No description provided for @listEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Tap + to add one.'**
  String get listEmpty;

  /// No description provided for @archivedSection.
  ///
  /// In en, this message translates to:
  /// **'Archived ({count})'**
  String archivedSection(int count);

  /// No description provided for @defaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultBadge;

  /// No description provided for @fieldEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get fieldEmoji;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get fieldDescription;

  /// No description provided for @errorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get errorNameRequired;

  /// No description provided for @errorTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters'**
  String errorTooLong(int max);

  /// No description provided for @errorNameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" already exists'**
  String errorNameDuplicate(String name);

  /// No description provided for @errorEmojiRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick an emoji'**
  String get errorEmojiRequired;

  /// No description provided for @errorEmojiNotSingle.
  ///
  /// In en, this message translates to:
  /// **'Use exactly one emoji'**
  String get errorEmojiNotSingle;

  /// No description provided for @resetToDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Reset to default name'**
  String get resetToDefaultName;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteConfirmTitle(String name);

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get deleteConfirmMessage;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// No description provided for @cannotDeleteDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Set another method as default first'**
  String get cannotDeleteDefaultHint;

  /// No description provided for @pickEmojiTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick an emoji'**
  String get pickEmojiTitle;

  /// No description provided for @typeAnyEmoji.
  ///
  /// In en, this message translates to:
  /// **'Type any emoji'**
  String get typeAnyEmoji;

  /// No description provided for @useEmoji.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get useEmoji;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingLanguage;

  /// No description provided for @settingTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingTheme;

  /// No description provided for @settingDefaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default currency'**
  String get settingDefaultCurrency;

  /// No description provided for @settingDefaultPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Default payment method'**
  String get settingDefaultPaymentMethod;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpense;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get fieldEvents;

  /// No description provided for @fieldPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get fieldPaymentMethod;

  /// No description provided for @fieldCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get fieldCurrency;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fieldTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get fieldTime;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldNotes;

  /// No description provided for @fieldDeletedAt.
  ///
  /// In en, this message translates to:
  /// **'Deleted on'**
  String get fieldDeletedAt;

  /// No description provided for @amountErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get amountErrorEmpty;

  /// No description provided for @amountErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount like 110.50 or 50 + 60'**
  String get amountErrorInvalid;

  /// No description provided for @amountErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} digits before the decimal point'**
  String amountErrorTooLarge(int max);

  /// No description provided for @amountErrorTooManyDecimals.
  ///
  /// In en, this message translates to:
  /// **'{digits, plural, =0{{currency} has no decimals} =1{{currency} has only 1 decimal} other{{currency} has only {digits} decimals}}'**
  String amountErrorTooManyDecimals(int digits, String currency);

  /// No description provided for @amountErrorNotPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero'**
  String get amountErrorNotPositive;

  /// No description provided for @amountPreview.
  ///
  /// In en, this message translates to:
  /// **'= {amount}'**
  String amountPreview(String amount);

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get titleRequired;

  /// No description provided for @categoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get categoryRequired;

  /// No description provided for @expenseGone.
  ///
  /// In en, this message translates to:
  /// **'This expense no longer exists'**
  String get expenseGone;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @cleared.
  ///
  /// In en, this message translates to:
  /// **'Form cleared'**
  String get cleared;

  /// No description provided for @draftDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Draft discarded'**
  String get draftDiscarded;

  /// No description provided for @discardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get discardDraft;

  /// No description provided for @draftRestoredAdd.
  ///
  /// In en, this message translates to:
  /// **'Unsaved expense restored ({age})'**
  String draftRestoredAdd(String age);

  /// No description provided for @draftRestoredEdit.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes restored ({age})'**
  String draftRestoredEdit(String age);

  /// No description provided for @draftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get draftSaved;

  /// No description provided for @draftKeptExpenseGone.
  ///
  /// In en, this message translates to:
  /// **'The expense was deleted; your changes were kept. Tap + to add them as a new expense'**
  String get draftKeptExpenseGone;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @itemize.
  ///
  /// In en, this message translates to:
  /// **'Itemize'**
  String get itemize;

  /// No description provided for @itemizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Describe the items'**
  String get itemizeTitle;

  /// No description provided for @amountErrorDivideByZero.
  ///
  /// In en, this message translates to:
  /// **'Can\'t divide by zero'**
  String get amountErrorDivideByZero;

  /// No description provided for @amountApprox.
  ///
  /// In en, this message translates to:
  /// **'≈ {amount}'**
  String amountApprox(String amount);

  /// No description provided for @keyPlus.
  ///
  /// In en, this message translates to:
  /// **'plus'**
  String get keyPlus;

  /// No description provided for @keyMinus.
  ///
  /// In en, this message translates to:
  /// **'minus'**
  String get keyMinus;

  /// No description provided for @keyTimes.
  ///
  /// In en, this message translates to:
  /// **'times'**
  String get keyTimes;

  /// No description provided for @keyDivide.
  ///
  /// In en, this message translates to:
  /// **'divided by'**
  String get keyDivide;

  /// No description provided for @keyDecimal.
  ///
  /// In en, this message translates to:
  /// **'decimal point'**
  String get keyDecimal;

  /// No description provided for @amountChipsLabel.
  ///
  /// In en, this message translates to:
  /// **'Usual amounts'**
  String get amountChipsLabel;

  /// No description provided for @titleSuggestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Past titles'**
  String get titleSuggestionsLabel;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @searchCategories.
  ///
  /// In en, this message translates to:
  /// **'Search categories…'**
  String get searchCategories;

  /// No description provided for @searchEvents.
  ///
  /// In en, this message translates to:
  /// **'Search events…'**
  String get searchEvents;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get newEvent;

  /// No description provided for @moreResults.
  ///
  /// In en, this message translates to:
  /// **'More results'**
  String get moreResults;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @allEvents.
  ///
  /// In en, this message translates to:
  /// **'All events'**
  String get allEvents;

  /// No description provided for @noMoreMatches.
  ///
  /// In en, this message translates to:
  /// **'No more matches'**
  String get noMoreMatches;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get noCategoriesYet;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @movedToBin.
  ///
  /// In en, this message translates to:
  /// **'Moved to bin'**
  String get movedToBin;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @loadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more expenses.'**
  String get loadMoreFailed;

  /// No description provided for @bin.
  ///
  /// In en, this message translates to:
  /// **'Bin'**
  String get bin;

  /// No description provided for @binSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted expenses are kept for 30 days'**
  String get binSubtitle;

  /// No description provided for @binEmpty.
  ///
  /// In en, this message translates to:
  /// **'Deleted expenses stay here for 30 days.'**
  String get binEmpty;

  /// No description provided for @deletedToday.
  ///
  /// In en, this message translates to:
  /// **'Deleted today'**
  String get deletedToday;

  /// No description provided for @deletedYesterday.
  ///
  /// In en, this message translates to:
  /// **'Deleted yesterday'**
  String get deletedYesterday;

  /// No description provided for @deletedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Deleted {days, plural, =1{1 day ago} other{{days} days ago}}'**
  String deletedDaysAgo(int days);

  /// No description provided for @removedInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{removed in 1 day} other{removed in {days} days}}'**
  String removedInDays(int days);

  /// No description provided for @removedOnNextStart.
  ///
  /// In en, this message translates to:
  /// **'removed on next start'**
  String get removedOnNextStart;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore all'**
  String get restoreAll;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deletePermanently;

  /// No description provided for @deletePermanentlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\" permanently?'**
  String deletePermanentlyTitle(String title);

  /// No description provided for @emptyBin.
  ///
  /// In en, this message translates to:
  /// **'Empty bin'**
  String get emptyBin;

  /// No description provided for @emptyBinTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty the bin?'**
  String get emptyBinTitle;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get cannotBeUndone;

  /// No description provided for @usedByExpenses.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is used by {count, plural, =1{1 expense} other{{count} expenses}}.'**
  String usedByExpenses(String name, int count);

  /// No description provided for @usedByExpensesWithBin.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is used by {count, plural, =1{1 expense} other{{count} expenses}} ({binned} in the bin).'**
  String usedByExpensesWithBin(String name, int count, int binned);

  /// No description provided for @moveExpensesTo.
  ///
  /// In en, this message translates to:
  /// **'Move them to:'**
  String get moveExpensesTo;

  /// No description provided for @moveAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Move and delete'**
  String get moveAndDelete;

  /// No description provided for @addAnotherFirst.
  ///
  /// In en, this message translates to:
  /// **'Add another one first, so its expenses have somewhere to go.'**
  String get addAnotherFirst;

  /// No description provided for @eventDeleteWithCount.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from {count, plural, =1{1 expense} other{{count} expenses}}. The expenses stay.'**
  String eventDeleteWithCount(int count);

  /// No description provided for @recentCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentCurrencies;

  /// No description provided for @allCurrencies.
  ///
  /// In en, this message translates to:
  /// **'All currencies'**
  String get allCurrencies;

  /// No description provided for @noneEvent.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneEvent;

  /// No description provided for @settingTileShape.
  ///
  /// In en, this message translates to:
  /// **'Tile shape'**
  String get settingTileShape;

  /// No description provided for @settingButtonShape.
  ///
  /// In en, this message translates to:
  /// **'Button shape'**
  String get settingButtonShape;

  /// No description provided for @shapeSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get shapeSquare;

  /// No description provided for @shapeRounded.
  ///
  /// In en, this message translates to:
  /// **'Rounded square'**
  String get shapeRounded;

  /// No description provided for @shapeCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get shapeCircle;

  /// No description provided for @settingCustomizeTiles.
  ///
  /// In en, this message translates to:
  /// **'Customize tiles'**
  String get settingCustomizeTiles;

  /// No description provided for @settingCustomizeTilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shapes of the category and event pickers'**
  String get settingCustomizeTilesSubtitle;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @settingThemeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get settingThemeColor;

  /// No description provided for @themeColorWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper colors'**
  String get themeColorWallpaper;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorTeal;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorAmber;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// No description provided for @restoreDefaultLook.
  ///
  /// In en, this message translates to:
  /// **'Restore default look'**
  String get restoreDefaultLook;

  /// No description provided for @restoreDefaultLookSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme color and tile shapes'**
  String get restoreDefaultLookSubtitle;

  /// No description provided for @restoreDefaultLookTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore the default look?'**
  String get restoreDefaultLookTitle;

  /// No description provided for @restoreDefaultLookMessage.
  ///
  /// In en, this message translates to:
  /// **'The theme color goes back to the wallpaper colors, tiles to rounded squares and buttons to circles.'**
  String get restoreDefaultLookMessage;

  /// No description provided for @migrationInstalledTitle.
  ///
  /// In en, this message translates to:
  /// **'Database initialized'**
  String get migrationInstalledTitle;

  /// No description provided for @migrationInstalledMessage.
  ///
  /// In en, this message translates to:
  /// **'Everything is ready.'**
  String get migrationInstalledMessage;

  /// No description provided for @migrationUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update done successfully'**
  String get migrationUpdatedTitle;

  /// No description provided for @migrationUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your data is up to date.'**
  String get migrationUpdatedMessage;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get backupAndRestore;

  /// No description provided for @lastBackupNever.
  ///
  /// In en, this message translates to:
  /// **'Never backed up'**
  String get lastBackupNever;

  /// No description provided for @lastBackupToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get lastBackupToday;

  /// No description provided for @lastBackupYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get lastBackupYesterday;

  /// No description provided for @lastBackupDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ago} other{{days} days ago}}'**
  String lastBackupDaysAgo(int days);

  /// No description provided for @lastBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {when}'**
  String lastBackupSubtitle(String when);

  /// No description provided for @backUpNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backUpNow;

  /// No description provided for @preparingBackup.
  ///
  /// In en, this message translates to:
  /// **'Preparing backup…'**
  String get preparingBackup;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaved;

  /// No description provided for @backupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup failed'**
  String get backupFailedTitle;

  /// No description provided for @backupFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved, and your data on this phone is unchanged. Please copy the report below and send it to us so we can fix it.'**
  String get backupFailedMessage;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get restoreFromBackup;

  /// No description provided for @restoreFromBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replaces all data on this phone with a backup file.'**
  String get restoreFromBackupSubtitle;

  /// No description provided for @undoLastRestore.
  ///
  /// In en, this message translates to:
  /// **'Undo last restore'**
  String get undoLastRestore;

  /// No description provided for @undoLastRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Go back to your data from before the restore on {date}.'**
  String undoLastRestoreSubtitle(String date);

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get restoreConfirmTitle;

  /// No description provided for @undoConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo the last restore?'**
  String get undoConfirmTitle;

  /// No description provided for @restoreBackupFrom.
  ///
  /// In en, this message translates to:
  /// **'Backup from {date}'**
  String restoreBackupFrom(String date);

  /// No description provided for @restoreCopyFrom.
  ///
  /// In en, this message translates to:
  /// **'Your data from before the restore on {date}'**
  String restoreCopyFrom(String date);

  /// No description provided for @restoreExpenseCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No expenses} =1{1 expense} other{{count} expenses}}'**
  String restoreExpenseCount(int count);

  /// No description provided for @restoreBinCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{plus 1 in the bin} other{plus {count} in the bin}}'**
  String restoreBinCount(int count);

  /// No description provided for @restoreLatestOn.
  ///
  /// In en, this message translates to:
  /// **'Latest on {date}'**
  String restoreLatestOn(String date);

  /// No description provided for @restoreReplacesData.
  ///
  /// In en, this message translates to:
  /// **'All data on this phone ({count, plural, =0{no expenses} =1{1 expense} other{{count} expenses}}) is replaced.'**
  String restoreReplacesData(int count);

  /// No description provided for @restoreKeepsCopy.
  ///
  /// In en, this message translates to:
  /// **'A copy is kept, and you can undo the restore.'**
  String get restoreKeepsCopy;

  /// Confirms restoring a backup. Its own key, not the bin's "restore": some languages use a different word.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreBackupButton;

  /// No description provided for @checkingBackup.
  ///
  /// In en, this message translates to:
  /// **'Checking the backup…'**
  String get checkingBackup;

  /// No description provided for @restoringData.
  ///
  /// In en, this message translates to:
  /// **'Restoring your data…'**
  String get restoringData;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupRestored;

  /// Snackbar on Home after restoring a backup whose settings table was missing or damaged: the expenses were restored, the settings were reset to defaults.
  ///
  /// In en, this message translates to:
  /// **'Backup restored. Its settings were missing or unreadable, so the default settings are used. You can change them in Settings.'**
  String get backupRestoredDefaultSettings;

  /// No description provided for @restoreFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get restoreFailedTitle;

  /// No description provided for @restoreFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your data on this phone is unchanged. Please copy the report below and send it to us so we can fix it.'**
  String get restoreFailedMessage;

  /// No description provided for @restoreFailedRestartMessage.
  ///
  /// In en, this message translates to:
  /// **'Your data on this phone is unchanged. The app restarts to open it again. Please copy the report below and send it to us so we can fix it.'**
  String get restoreFailedRestartMessage;

  /// No description provided for @restartApp.
  ///
  /// In en, this message translates to:
  /// **'Restart the app'**
  String get restartApp;

  /// No description provided for @restoreRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t restore this file'**
  String get restoreRejectedTitle;

  /// No description provided for @notABackup.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a backup from Expense Tracker.'**
  String get notABackup;

  /// No description provided for @backupTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of the app. Update the app, then try again.'**
  String get backupTooNew;

  /// No description provided for @backupDamaged.
  ///
  /// In en, this message translates to:
  /// **'This backup is damaged and can\'t be restored.'**
  String get backupDamaged;

  /// No description provided for @periodDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get periodDay;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// A week named by its number in the year (Settings → Home → Week names).
  ///
  /// In en, this message translates to:
  /// **'Week {number}'**
  String weekNumber(int number);

  /// A week of another year, by number. year is written by intl.
  ///
  /// In en, this message translates to:
  /// **'Week {number}, {year}'**
  String weekNumberWithYear(int number, String year);

  /// A week named by its month: "Oct Week 3". month is intl's short month, with the year when it isn't this year ("Dec 2025").
  ///
  /// In en, this message translates to:
  /// **'{month} Week {number}'**
  String weekOfMonth(String month, int number);

  /// A day header with the day's total: "Sat, 17 Oct – ₹5,000.00".
  ///
  /// In en, this message translates to:
  /// **'{date} – {amount}'**
  String dayWithSubtotal(String date, String amount);

  /// What TalkBack reads for a day header: the full date, then the total.
  ///
  /// In en, this message translates to:
  /// **'{date}, {amount}'**
  String daySubtotalSemantics(String date, String amount);

  /// No description provided for @trendEmptyWeek.
  ///
  /// In en, this message translates to:
  /// **'No expenses this week'**
  String get trendEmptyWeek;

  /// No description provided for @trendEmptyMonth.
  ///
  /// In en, this message translates to:
  /// **'No expenses this month'**
  String get trendEmptyMonth;

  /// No description provided for @trendEmptyYear.
  ///
  /// In en, this message translates to:
  /// **'No expenses this year'**
  String get trendEmptyYear;

  /// No description provided for @trendNoMatchWeek.
  ///
  /// In en, this message translates to:
  /// **'No matching expenses this week'**
  String get trendNoMatchWeek;

  /// No description provided for @trendNoMatchMonth.
  ///
  /// In en, this message translates to:
  /// **'No matching expenses this month'**
  String get trendNoMatchMonth;

  /// No description provided for @trendNoMatchYear.
  ///
  /// In en, this message translates to:
  /// **'No matching expenses this year'**
  String get trendNoMatchYear;

  /// Next to the trend card's title while filters are active: its total covers the filtered expenses only.
  ///
  /// In en, this message translates to:
  /// **'Filtered'**
  String get trendFiltered;

  /// The tapped day (or month) of the chart and its total.
  ///
  /// In en, this message translates to:
  /// **'{date} · {amount}'**
  String trendPointLabel(String date, String amount);

  /// What TalkBack reads for the trend card.
  ///
  /// In en, this message translates to:
  /// **'{period}, total {amount}'**
  String trendCardSemantics(String period, String amount);

  /// Same while filters are active.
  ///
  /// In en, this message translates to:
  /// **'{period}, filtered, total {amount}'**
  String trendCardSemanticsFiltered(String period, String amount);

  /// No description provided for @totalsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load totals'**
  String get totalsLoadFailed;

  /// TalkBack action on the trend card: Week → Month → Year.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get nextPeriod;

  /// No description provided for @previousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get previousPeriod;

  /// No description provided for @nextCurrency.
  ///
  /// In en, this message translates to:
  /// **'Next currency'**
  String get nextCurrency;

  /// No description provided for @previousCurrency.
  ///
  /// In en, this message translates to:
  /// **'Previous currency'**
  String get previousCurrency;

  /// The trend card's currency as TalkBack reads it: "US dollar, $85.00".
  ///
  /// In en, this message translates to:
  /// **'{currency}, {amount}'**
  String chartCurrencyAnnounce(String currency, String amount);

  /// Totals in several currencies on one line: "₹4,560.00 + $85.00".
  ///
  /// In en, this message translates to:
  /// **'{first} + {rest}'**
  String totalsJoin(String first, String rest);

  /// The same, as TalkBack reads it.
  ///
  /// In en, this message translates to:
  /// **'{first} and {rest}'**
  String totalsJoinSpoken(String first, String rest);

  /// Shown instead of a total too large to print.
  ///
  /// In en, this message translates to:
  /// **'Too large'**
  String get totalTooLarge;

  /// A button shown instead of the subtotals when they don't fit on the line.
  ///
  /// In en, this message translates to:
  /// **'Show subtotal'**
  String get showSubtotal;

  /// No description provided for @subtotalLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the subtotal'**
  String get subtotalLoadFailed;

  /// What TalkBack reads for a group's top: "Oct Week 2, subtotal ₹4,560.00".
  ///
  /// In en, this message translates to:
  /// **'{name}, subtotal {amount}'**
  String groupSubtotalSemantics(String name, String amount);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @filterSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles and descriptions'**
  String get filterSearchHint;

  /// No description provided for @filterCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get filterCategories;

  /// No description provided for @filterEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get filterEvents;

  /// No description provided for @filterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get filterArchived;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get groupBy;

  /// The filter bar's grouping chip.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get groupedByDay;

  /// No description provided for @groupedByWeek.
  ///
  /// In en, this message translates to:
  /// **'By week'**
  String get groupedByWeek;

  /// No description provided for @groupedByMonth.
  ///
  /// In en, this message translates to:
  /// **'By month'**
  String get groupedByMonth;

  /// No description provided for @groupedByYear.
  ///
  /// In en, this message translates to:
  /// **'By year'**
  String get groupedByYear;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @showResults.
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get showResults;

  /// No description provided for @noFilterMatches.
  ///
  /// In en, this message translates to:
  /// **'No expenses match these filters'**
  String get noFilterMatches;

  /// A filter chip for several categories or events: the first one and how many more.
  ///
  /// In en, this message translates to:
  /// **'{name} +{count}'**
  String filterMore(String name, int count);

  /// The filter bar's chip for the search text.
  ///
  /// In en, this message translates to:
  /// **'\"{text}\"'**
  String filterSearchChip(String text);

  /// No description provided for @removeFilter.
  ///
  /// In en, this message translates to:
  /// **'Remove filter'**
  String get removeFilter;

  /// No description provided for @settingsLook.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get settingsLook;

  /// The Settings tile for Home's chart, card and weeks.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get settingsHome;

  /// No description provided for @settingsDefaults.
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get settingsDefaults;

  /// No description provided for @settingWeekStart.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get settingWeekStart;

  /// No description provided for @settingWeekNames.
  ///
  /// In en, this message translates to:
  /// **'Week names'**
  String get settingWeekNames;

  /// No description provided for @settingTrendChart.
  ///
  /// In en, this message translates to:
  /// **'Trend chart'**
  String get settingTrendChart;

  /// No description provided for @chartLineFilled.
  ///
  /// In en, this message translates to:
  /// **'Smooth line, filled'**
  String get chartLineFilled;

  /// No description provided for @chartLine.
  ///
  /// In en, this message translates to:
  /// **'Smooth line'**
  String get chartLine;

  /// No description provided for @chartBars.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get chartBars;

  /// Trend chart style: a dot on a thin stem per day.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get chartDots;

  /// Trend chart style: a line that climbs through the period to its total.
  ///
  /// In en, this message translates to:
  /// **'Running total'**
  String get chartRunningTotal;

  /// No description provided for @settingTrendCardSize.
  ///
  /// In en, this message translates to:
  /// **'Card size'**
  String get settingTrendCardSize;

  /// No description provided for @cardSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get cardSizeSmall;

  /// No description provided for @cardSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get cardSizeMedium;

  /// No description provided for @cardSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get cardSizeLarge;

  /// Settings → Home: the tick felt as the trend card's reel clicks into a week, month or year.
  ///
  /// In en, this message translates to:
  /// **'Card vibration'**
  String get settingCardHaptics;

  /// No description provided for @hapticsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get hapticsOff;

  /// No description provided for @hapticsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get hapticsLight;

  /// No description provided for @hapticsMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get hapticsMedium;

  /// No description provided for @hapticsStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get hapticsStrong;

  /// The tapped day of the running-total chart and the total up to it.
  ///
  /// In en, this message translates to:
  /// **'Up to {date} · {amount}'**
  String trendRunningTotalPoint(String date, String amount);

  /// No description provided for @restoreHomeDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get restoreHomeDefaults;

  /// No description provided for @restoreHomeDefaultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Chart, card and weeks as they were at first'**
  String get restoreHomeDefaultsSubtitle;

  /// No description provided for @restoreHomeDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore the Home defaults?'**
  String get restoreHomeDefaultsTitle;

  /// No description provided for @restoreHomeDefaultsMessage.
  ///
  /// In en, this message translates to:
  /// **'The trend chart, trend card, card size, week start and week names go back to their defaults.'**
  String get restoreHomeDefaultsMessage;

  /// No description provided for @settingTrendCard.
  ///
  /// In en, this message translates to:
  /// **'Trend card'**
  String get settingTrendCard;

  /// No description provided for @trendCardLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked at the top'**
  String get trendCardLocked;

  /// No description provided for @trendCardScrolls.
  ///
  /// In en, this message translates to:
  /// **'Scrolls with the list'**
  String get trendCardScrolls;

  /// The Home tile's summary: the trend card stays at the top.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get trendCardLockedShort;

  /// No description provided for @trendCardScrollsShort.
  ///
  /// In en, this message translates to:
  /// **'Scrolls'**
  String get trendCardScrollsShort;

  /// No description provided for @binTileSummary.
  ///
  /// In en, this message translates to:
  /// **'Kept for 30 days'**
  String get binTileSummary;

  /// Joins the parts of a Settings tile's summary line.
  ///
  /// In en, this message translates to:
  /// **'{first} · {rest}'**
  String settingsTileSummary(String first, String rest);

  /// No description provided for @addPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get addPhotos;

  /// TalkBack label of the form's photo button when it has photos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo, open} other{{count} photos, open}}'**
  String photosCountOpen(int count);

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @photosAddedOf.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} added'**
  String photosAddedOf(int count, int max);

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @photosOfMax.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max}'**
  String photosOfMax(int count, int max);

  /// No description provided for @photosMaxReached.
  ///
  /// In en, this message translates to:
  /// **'{max} photos is the most for one expense'**
  String photosMaxReached(int max);

  /// No description provided for @photoAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'That photo is already here'**
  String get photoAlreadyAdded;

  /// No description provided for @photoCouldNotBeAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A photo couldn\'t be added} other{{count} photos couldn\'t be added}}'**
  String photoCouldNotBeAdded(int count);

  /// No description provided for @photosOverflow.
  ///
  /// In en, this message translates to:
  /// **'Only {max} photos per expense: {added, plural, =0{none was added} =1{1 was added} other{{added} were added}}.'**
  String photosOverflow(int max, int added);

  /// No description provided for @noCameraApp.
  ///
  /// In en, this message translates to:
  /// **'No camera app found'**
  String get noCameraApp;

  /// No description provided for @addingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Adding photos…'**
  String get addingPhotos;

  /// No description provided for @addingPhotosProgress.
  ///
  /// In en, this message translates to:
  /// **'Adding photos ({done} of {total})'**
  String addingPhotosProgress(int done, int total);

  /// No description provided for @draftPhotosMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo from the draft couldn\'t be found} other{{count} photos from the draft couldn\'t be found}}'**
  String draftPhotosMissing(int count);

  /// No description provided for @photosMax.
  ///
  /// In en, this message translates to:
  /// **'At most {max} photos. Remove {extra, plural, =1{1 photo} other{{extra} photos}} to save.'**
  String photosMax(int max, int extra);

  /// No description provided for @photosNotKept.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo couldn\'t be kept: it was deleted meanwhile} other{{count} photos couldn\'t be kept: they were deleted meanwhile}}'**
  String photosNotKept(int count);

  /// No description provided for @imageMissing.
  ///
  /// In en, this message translates to:
  /// **'Image missing'**
  String get imageMissing;

  /// No description provided for @photosSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the photos. Nothing was saved.'**
  String get photosSaveFailed;

  /// No description provided for @photosCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String photosCount(int count);

  /// TalkBack name of a photo in an expense's Photos sheet.
  ///
  /// In en, this message translates to:
  /// **'Photo {index} of {total}'**
  String photoNumber(int index, int total);

  /// The viewer's title: which photo of how many.
  ///
  /// In en, this message translates to:
  /// **'{index} / {total}'**
  String photoCounter(int index, int total);

  /// The selection bar's title.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// TalkBack reads this for the selection bar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo selected} other{{count} photos selected}}'**
  String photosSelectedCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @endSelection.
  ///
  /// In en, this message translates to:
  /// **'End selection'**
  String get endSelection;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// No description provided for @photosDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete this photo?} other{Delete {count} photos?}}'**
  String photosDeleteTitle(int count);

  /// Delete confirm on the Photos screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It will be deleted permanently from its expense. Copies you saved to Pictures stay.} other{They will be deleted permanently from their expenses. Copies you saved to Pictures stay.}}'**
  String photosDeleteWarningScreen(int count);

  /// Delete confirm in a saved expense's Photos sheet or viewer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It will be deleted permanently from this expense when you tap Update. Copies you saved to Pictures stay.} other{They will be deleted permanently from this expense when you tap Update. Copies you saved to Pictures stay.}}'**
  String photosDeleteWarningForm(int count);

  /// Delete confirm in a new expense's Photos sheet or viewer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It will be deleted permanently from this expense when you save it. Copies you saved to Pictures stay.} other{They will be deleted permanently from this expense when you save it. Copies you saved to Pictures stay.}}'**
  String photosDeleteWarningNew(int count);

  /// No description provided for @photosDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo deleted} other{{count} photos deleted}}'**
  String photosDeleted(int count);

  /// Copies a photo to the phone's Pictures folder, where gallery apps show it.
  ///
  /// In en, this message translates to:
  /// **'Save to Pictures'**
  String get saveToPictures;

  /// No description provided for @savedToPictures.
  ///
  /// In en, this message translates to:
  /// **'Saved to {folder}'**
  String savedToPictures(String folder);

  /// No description provided for @photosSavedToPictures.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo saved to {folder}} other{{count} photos saved to {folder}}}'**
  String photosSavedToPictures(int count, String folder);

  /// No description provided for @photosSavedSomeFailed.
  ///
  /// In en, this message translates to:
  /// **'{saved} saved; {failed, plural, =1{1 couldn\'t be saved} other{{failed} couldn\'t be saved}}'**
  String photosSavedSomeFailed(int saved, int failed);

  /// No description provided for @photosMissingNotSaved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo is missing and wasn\'t saved} other{{count} photos are missing and weren\'t saved}}'**
  String photosMissingNotSaved(int count);

  /// No description provided for @noSpaceToSavePhotos.
  ///
  /// In en, this message translates to:
  /// **'Not enough space to save these photos'**
  String get noSpaceToSavePhotos;

  /// No description provided for @savingToPictures.
  ///
  /// In en, this message translates to:
  /// **'Saving {done} / {total}'**
  String savingToPictures(int done, int total);

  /// Name of a picture saved from an expense without a title.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get defaultPictureTitle;

  /// Title of the screen shown right after taking a photo.
  ///
  /// In en, this message translates to:
  /// **'Your photo'**
  String get reviewPhoto;

  /// No description provided for @rotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get rotateLeft;

  /// No description provided for @rotateRight.
  ///
  /// In en, this message translates to:
  /// **'Rotate right'**
  String get rotateRight;

  /// No description provided for @rotatedDegrees.
  ///
  /// In en, this message translates to:
  /// **'Rotated {degrees} degrees'**
  String rotatedDegrees(int degrees);

  /// No description provided for @usePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use photo'**
  String get usePhoto;

  /// No description provided for @discardPhoto.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardPhoto;

  /// Shown when the app was closed while reviewing a camera photo, and the photo is offered again.
  ///
  /// In en, this message translates to:
  /// **'The photo you took is back'**
  String get photoFromCameraBack;

  /// No description provided for @noPhotosMatchTooltip.
  ///
  /// In en, this message translates to:
  /// **'No photos match the filters'**
  String get noPhotosMatchTooltip;

  /// No description provided for @photoOfExpense.
  ///
  /// In en, this message translates to:
  /// **'Photo of {title}, {date}'**
  String photoOfExpense(String title, String date);

  /// No description provided for @noPhotosMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No photos match the filters on Home.'**
  String get noPhotosMatchFilters;

  /// No description provided for @cameraPhotos.
  ///
  /// In en, this message translates to:
  /// **'Camera photos'**
  String get cameraPhotos;

  /// No description provided for @galleryPhotos.
  ///
  /// In en, this message translates to:
  /// **'Gallery photos'**
  String get galleryPhotos;

  /// No description provided for @photoSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get photoSizeLabel;

  /// No description provided for @photoQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get photoQualityLabel;

  /// No description provided for @photoSizeOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get photoSizeOriginal;

  /// No description provided for @photoSizeNotRecommended.
  ///
  /// In en, this message translates to:
  /// **'{size} (not recommended)'**
  String photoSizeNotRecommended(String size);

  /// No description provided for @settingDefaultValue.
  ///
  /// In en, this message translates to:
  /// **'{value} (default)'**
  String settingDefaultValue(String value);

  /// No description provided for @photoResizedAbove.
  ///
  /// In en, this message translates to:
  /// **'Larger photos are resized to this size; smaller ones are kept as they are'**
  String get photoResizedAbove;

  /// No description provided for @originalWarning.
  ///
  /// In en, this message translates to:
  /// **'Keeping originals is not recommended: a phone photo is 5–10 MB, so after about 1,000 photos they take several GB on the phone and in backups with photos. Originals also keep the photo\'s location.'**
  String get originalWarning;

  /// No description provided for @photosUse.
  ///
  /// In en, this message translates to:
  /// **'Photos use {size} ({count, plural, =1{1 photo}other{{count} photos}}).'**
  String photosUse(String size, int count);

  /// No description provided for @noPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'No photos yet.'**
  String get noPhotosYet;

  /// No description provided for @photosKeptInApp.
  ///
  /// In en, this message translates to:
  /// **'Photos are kept inside the app and leave with it. To keep one for yourself, open it and use Save to Pictures.'**
  String get photosKeptInApp;

  /// No description provided for @photoChangesApplyToNew.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to photos you add from now on.'**
  String get photoChangesApplyToNew;

  /// Part of the Photos tile's summary: the camera photos' size.
  ///
  /// In en, this message translates to:
  /// **'Camera {size}'**
  String photosTileCamera(String size);

  /// Part of the Photos tile's summary: the gallery photos' size.
  ///
  /// In en, this message translates to:
  /// **'Gallery {size}'**
  String photosTileGallery(String size);

  /// No description provided for @restorePhotoDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get restorePhotoDefaults;

  /// No description provided for @restorePhotoDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore the photo defaults?'**
  String get restorePhotoDefaultsTitle;

  /// No description provided for @restorePhotoDefaultsMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera and gallery photos go back to 1080p and quality 85.'**
  String get restorePhotoDefaultsMessage;

  /// No description provided for @includePhotos.
  ///
  /// In en, this message translates to:
  /// **'Include photos'**
  String get includePhotos;

  /// No description provided for @photosNotInBackup.
  ///
  /// In en, this message translates to:
  /// **'Photos won\'t be in this backup. Restored on another phone or after reinstalling, they show as missing.'**
  String get photosNotInBackup;

  /// No description provided for @backupPhotosProgress.
  ///
  /// In en, this message translates to:
  /// **'Adding photos to the backup ({done} of {total})'**
  String backupPhotosProgress(int done, int total);

  /// No description provided for @savingBackup.
  ///
  /// In en, this message translates to:
  /// **'Saving backup…'**
  String get savingBackup;

  /// No description provided for @backupNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough space on this phone to make this backup'**
  String get backupNoSpace;

  /// No description provided for @backupSavedMissingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Backup saved. {count, plural, =1{1 photo was missing and isn\'t in it} other{{count} photos were missing and aren\'t in it}}.'**
  String backupSavedMissingPhotos(int count);

  /// No description provided for @saveTargetNoSpace.
  ///
  /// In en, this message translates to:
  /// **'There isn\'t enough space where you chose to save it'**
  String get saveTargetNoSpace;

  /// No description provided for @restoreIncludesPhotos.
  ///
  /// In en, this message translates to:
  /// **'Includes {count, plural, =1{1 photo} other{{count} photos}} ({size}).'**
  String restoreIncludesPhotos(int count, String size);

  /// No description provided for @restoreNoSpaceForPhotos.
  ///
  /// In en, this message translates to:
  /// **'There isn\'t enough space for its photos (needs {size} more).'**
  String restoreNoSpaceForPhotos(String size);

  /// No description provided for @restoreWithoutPhotos.
  ///
  /// In en, this message translates to:
  /// **'Restore without photos'**
  String get restoreWithoutPhotos;

  /// No description provided for @restoreBackupWithoutPhotos.
  ///
  /// In en, this message translates to:
  /// **'This backup has no photos. Photos this phone doesn\'t have will show as missing.'**
  String get restoreBackupWithoutPhotos;

  /// No description provided for @restoringPhotosProgress.
  ///
  /// In en, this message translates to:
  /// **'Restoring photos ({done} of {total})'**
  String restoringPhotosProgress(int done, int total);

  /// No description provided for @backupRestoredFailedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Backup restored. {count, plural, =1{1 photo couldn\'t be restored and shows as missing} other{{count} photos couldn\'t be restored and show as missing}}.'**
  String backupRestoredFailedPhotos(int count);

  /// No description provided for @openBackupNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough space on this phone to open this backup'**
  String get openBackupNoSpace;

  /// A file size in bytes; size is already formatted.
  ///
  /// In en, this message translates to:
  /// **'{size} B'**
  String sizeBytes(String size);

  /// No description provided for @sizeKilobytes.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String sizeKilobytes(String size);

  /// No description provided for @sizeMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String sizeMegabytes(String size);

  /// No description provided for @sizeGigabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String sizeGigabytes(String size);

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryDrinks.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get categoryDrinks;

  /// No description provided for @categoryGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get categoryGroceries;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categoryClothes.
  ///
  /// In en, this message translates to:
  /// **'Clothes'**
  String get categoryClothes;

  /// No description provided for @categoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryTransport;

  /// No description provided for @categoryFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get categoryFuel;

  /// No description provided for @categoryRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get categoryRent;

  /// No description provided for @categoryHouse.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get categoryHouse;

  /// No description provided for @categoryBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get categoryBills;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categoryTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryTravel;

  /// No description provided for @categoryGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get categoryGifts;

  /// No description provided for @categoryPersonalCare.
  ///
  /// In en, this message translates to:
  /// **'Personal care'**
  String get categoryPersonalCare;

  /// No description provided for @categorySubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get categorySubscription;

  /// No description provided for @categoryLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get categoryLoan;

  /// No description provided for @categoryInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get categoryInvestment;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get paymentMethodUpi;

  /// No description provided for @paymentMethodDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Debit card'**
  String get paymentMethodDebitCard;

  /// No description provided for @paymentMethodCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get paymentMethodCreditCard;

  /// No description provided for @eventBirthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get eventBirthday;

  /// No description provided for @eventAnniversary.
  ///
  /// In en, this message translates to:
  /// **'Anniversary'**
  String get eventAnniversary;

  /// No description provided for @eventParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get eventParty;

  /// No description provided for @eventFestival.
  ///
  /// In en, this message translates to:
  /// **'Festival'**
  String get eventFestival;

  /// No description provided for @eventTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get eventTrip;

  /// No description provided for @eventWedding.
  ///
  /// In en, this message translates to:
  /// **'Wedding'**
  String get eventWedding;

  /// No description provided for @eventDiningOut.
  ///
  /// In en, this message translates to:
  /// **'Dining out'**
  String get eventDiningOut;

  /// No description provided for @scheduleDaily.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every day} other{Every {count} days}}'**
  String scheduleDaily(int count);

  /// weekday: the start's weekday, e.g. Monday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week on {weekday}} other{Every {count} weeks on {weekday}}}'**
  String scheduleWeekly(int count, String weekday);

  /// 'Day 9', not 'the 9th': ordinals don't translate (P7a-21).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every month on day {day}} other{Every {count} months on day {day}}}'**
  String scheduleMonthly(int count, int day);

  /// For a start on the 29th to 31st, which shorter months don't have.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every month on day {day} (or the month\'s last day)} other{Every {count} months on day {day} (or the month\'s last day)}}'**
  String scheduleMonthlyClamped(int count, int day);

  /// date: day and month, e.g. 9 Oct.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every year on {date}} other{Every {count} years on {date}}}'**
  String scheduleYearly(int count, String date);

  /// A start on 29 Feb; fallback is 28 Feb.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every year on {date} ({fallback} in other years)} other{Every {count} years on {date} ({fallback} in other years)}}'**
  String scheduleYearlyLeap(int count, String date, String fallback);

  /// No description provided for @repeatShortDaily.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Daily} other{Every {count} days}}'**
  String repeatShortDaily(int count);

  /// No description provided for @repeatShortWeekly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Weekly} other{Every {count} weeks}}'**
  String repeatShortWeekly(int count);

  /// No description provided for @repeatShortMonthly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Monthly} other{Every {count} months}}'**
  String repeatShortMonthly(int count);

  /// No description provided for @repeatShortYearly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Yearly} other{Every {count} years}}'**
  String repeatShortYearly(int count);

  /// No description provided for @endsNever.
  ///
  /// In en, this message translates to:
  /// **'Never ends'**
  String get endsNever;

  /// No description provided for @endsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String endsOn(String date);

  /// No description provided for @nextOn.
  ///
  /// In en, this message translates to:
  /// **'Next: {date}'**
  String nextOn(String date);

  /// No description provided for @noMorePayments.
  ///
  /// In en, this message translates to:
  /// **'No more payments'**
  String get noMorePayments;

  /// After the schedule in an Archive row: 'Monthly · stopped 9 Oct'.
  ///
  /// In en, this message translates to:
  /// **'stopped {date}'**
  String archivedStopped(String date);

  /// After the schedule in an Archive row: 'Monthly · expired 15 Oct' (its end date).
  ///
  /// In en, this message translates to:
  /// **'expired {date}'**
  String archivedExpired(String date);

  /// No description provided for @repeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get repeats;

  /// No description provided for @repeatEvery.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get repeatEvery;

  /// No description provided for @repeatUnitDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day} other{days}}'**
  String repeatUnitDays(int count);

  /// No description provided for @repeatUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{week} other{weeks}}'**
  String repeatUnitWeeks(int count);

  /// No description provided for @repeatUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{month} other{months}}'**
  String repeatUnitMonths(int count);

  /// No description provided for @repeatUnitYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{year} other{years}}'**
  String repeatUnitYears(int count);

  /// No description provided for @repeatEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get repeatEnds;

  /// No description provided for @repeatEndsNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get repeatEndsNever;

  /// No description provided for @repeatEndsOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get repeatEndsOn;

  /// No description provided for @repeatEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get repeatEndDate;

  /// No description provided for @repeatIntervalError.
  ///
  /// In en, this message translates to:
  /// **'1 to {max}'**
  String repeatIntervalError(int max);

  /// No description provided for @repeatEndMissing.
  ///
  /// In en, this message translates to:
  /// **'Pick an end date'**
  String get repeatEndMissing;

  /// No description provided for @repeatEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'Ends before the first payment ({date})'**
  String repeatEndBeforeStart(String date);

  /// No description provided for @repeatEndTooLate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date up to {date}'**
  String repeatEndTooLate(String date);

  /// No description provided for @repeatTooManyPast.
  ///
  /// In en, this message translates to:
  /// **'That\'s {count} earlier payments; at most {max}. Pick a later date or a longer interval.'**
  String repeatTooManyPast(int count, int max);

  /// dates: the first three, e.g. '31 Aug, 30 Sep', then 'and 4 more'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Also adds 1 earlier payment: {dates}} other{Also adds {count} earlier payments: {dates}}}'**
  String repeatAlsoAdds(int count, String dates);

  /// No description provided for @repeatAndMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 more} other{and {count} more}}'**
  String repeatAndMore(int count);

  /// No description provided for @repeatThisPaymentOnly.
  ///
  /// In en, this message translates to:
  /// **'Changes here are for this payment only.'**
  String get repeatThisPaymentOnly;

  /// No description provided for @repeatLinkSemantics.
  ///
  /// In en, this message translates to:
  /// **'Recurring item {title}, {schedule}. Opens its page.'**
  String repeatLinkSemantics(String title, String schedule);

  /// No description provided for @repeatsMark.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get repeatsMark;

  /// No description provided for @savedRepeats.
  ///
  /// In en, this message translates to:
  /// **'Saved. Repeats: {schedule}'**
  String savedRepeats(String schedule);

  /// No description provided for @savedWithEarlier.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved with 1 earlier payment.} other{Saved with {count} earlier payments.}}'**
  String savedWithEarlier(int count);

  /// No description provided for @addedRecurring.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 recurring expense} other{Added {count} recurring expenses}}'**
  String addedRecurring(int count);

  /// No description provided for @heldOne.
  ///
  /// In en, this message translates to:
  /// **'{title} has {count, plural, =1{1 payment} other{{count} payments}} waiting'**
  String heldOne(String title, int count);

  /// No description provided for @heldMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} recurring items have payments waiting}}'**
  String heldMany(int count);

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @usedByTemplatesOnly.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is used by {count, plural, =1{1 recurring item} other{{count} recurring items}}.'**
  String usedByTemplatesOnly(String name, int count);

  /// After usedByExpenses in the move dialog.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It is also used by 1 recurring item: its later payments use the one you pick.} other{It is also used by {count} recurring items: their later payments use the one you pick.}}'**
  String alsoUsedByTemplates(int count);

  /// After usedByTemplatesOnly in the move dialog.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Its later payments use the one you pick.} other{Their later payments use the one you pick.}}'**
  String templatesMoveToo(int count);

  /// No description provided for @eventDeleteTemplates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It will be removed from 1 recurring item: its later payments come without it.} other{It will be removed from {count} recurring items: their later payments come without it.}}'**
  String eventDeleteTemplates(int count);

  /// No description provided for @recurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringTitle;

  /// No description provided for @recurringRunning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None running} =1{1 running} other{{count} running}}'**
  String recurringRunning(int count);

  /// No description provided for @recurringEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing repeats yet. Turn on Repeats when you add an expense.'**
  String get recurringEmpty;

  /// No description provided for @recurringWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get recurringWaiting;

  /// No description provided for @recurringActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get recurringActive;

  /// No description provided for @recurringPaymentsWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment waiting} other{{count} payments waiting}}'**
  String recurringPaymentsWaiting(int count);

  /// No description provided for @recurringRowNext.
  ///
  /// In en, this message translates to:
  /// **'{schedule} · next {date}'**
  String recurringRowNext(String schedule, String date);

  /// No description provided for @recurringRowEnds.
  ///
  /// In en, this message translates to:
  /// **'No more payments · ends {date}'**
  String recurringRowEnds(String date);

  /// No description provided for @recurringBroken.
  ///
  /// In en, this message translates to:
  /// **'This recurring item can\'t be read, so it adds no payments.'**
  String get recurringBroken;

  /// No description provided for @recurringPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get recurringPrice;

  /// No description provided for @recurringScheduled.
  ///
  /// In en, this message translates to:
  /// **'scheduled'**
  String get recurringScheduled;

  /// No description provided for @priceFromDate.
  ///
  /// In en, this message translates to:
  /// **'from {date}'**
  String priceFromDate(String date);

  /// No description provided for @removeScheduledPrice.
  ///
  /// In en, this message translates to:
  /// **'Remove scheduled price'**
  String get removeScheduledPrice;

  /// No description provided for @recurringPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments ({count})'**
  String recurringPayments(int count);

  /// No description provided for @recurringNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments (deleted ones aren\'t listed).'**
  String get recurringNoPayments;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @changePrice.
  ///
  /// In en, this message translates to:
  /// **'Change price'**
  String get changePrice;

  /// No description provided for @newPrice.
  ///
  /// In en, this message translates to:
  /// **'New price'**
  String get newPrice;

  /// No description provided for @priceFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get priceFrom;

  /// No description provided for @priceKeepsPast.
  ///
  /// In en, this message translates to:
  /// **'Payments already added keep their price.'**
  String get priceKeepsPast;

  /// No description provided for @priceReplaces.
  ///
  /// In en, this message translates to:
  /// **'Replaces {amount} from {date}'**
  String priceReplaces(String amount, String date);

  /// No description provided for @priceInForce.
  ///
  /// In en, this message translates to:
  /// **'A price from that date is already in force'**
  String get priceInForce;

  /// No description provided for @priceBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'Pick {date} or later'**
  String priceBeforeStart(String date);

  /// No description provided for @priceChanged.
  ///
  /// In en, this message translates to:
  /// **'Price changed'**
  String get priceChanged;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @recurringStopped.
  ///
  /// In en, this message translates to:
  /// **'{title} stopped and archived.'**
  String recurringStopped(String title);

  /// No description provided for @undoStopRefused.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t undo: it was restored, deleted or switched for another item since.'**
  String get undoStopRefused;

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTitle;

  /// No description provided for @archivedBadge.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedBadge;

  /// No description provided for @restoreRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore {title}?'**
  String restoreRecurringTitle(String title);

  /// No description provided for @restoreRecurringText.
  ///
  /// In en, this message translates to:
  /// **'It adds payments again from {date}.'**
  String restoreRecurringText(String date);

  /// No description provided for @restoreRecurringNoMore.
  ///
  /// In en, this message translates to:
  /// **'It has no payment left before its end.'**
  String get restoreRecurringNoMore;

  /// No description provided for @restoreEndPassed.
  ///
  /// In en, this message translates to:
  /// **'Its end, {date}, has passed: it restores with no end. Edit it to set one.'**
  String restoreEndPassed(String date);

  /// No description provided for @recurringRestored.
  ///
  /// In en, this message translates to:
  /// **'{title} restored. Next: {date}'**
  String recurringRestored(String title, String date);

  /// No description provided for @recurringRestoredNoNext.
  ///
  /// In en, this message translates to:
  /// **'{title} restored.'**
  String recurringRestoredNoNext(String title);

  /// No description provided for @deleteForGood.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get deleteForGood;

  /// No description provided for @deleteForGoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {title} for good?'**
  String deleteForGoodTitle(String title);

  /// No description provided for @deleteForGoodText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{It has no payments. This can\'t be undone.} =1{Its payment stays, without the repeat mark. This can\'t be undone.} other{Its {count} payments stay, without the repeat mark. This can\'t be undone.}}'**
  String deleteForGoodText(int count);

  /// No description provided for @recurringDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{{title} deleted.} =1{{title} deleted. Its payment stays.} other{{title} deleted. Its {count} payments stay.}}'**
  String recurringDeleted(String title, int count);

  /// No description provided for @recurringGone.
  ///
  /// In en, this message translates to:
  /// **'This recurring item no longer exists.'**
  String get recurringGone;

  /// No description provided for @editRecurring.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring item'**
  String get editRecurring;

  /// No description provided for @recurringChangesApplyLater.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to payments added from now on.'**
  String get recurringChangesApplyLater;

  /// No description provided for @recurringEndNotBefore.
  ///
  /// In en, this message translates to:
  /// **'Pick {date} or later: a payment until then is already added'**
  String recurringEndNotBefore(String date);

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// range: '3 Aug – 5 Oct 2026', or one date.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment is due, {range}.} other{{count} payments are due, {range}.}}'**
  String recurringHoldText(int count, String range);

  /// No description provided for @recurringHoldMany.
  ///
  /// In en, this message translates to:
  /// **'More than {max} payments are due, {range}.'**
  String recurringHoldMany(int max, String range);

  /// No description provided for @addAllN.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add it} other{Add all {count}}}'**
  String addAllN(int count);

  /// No description provided for @addFirstN.
  ///
  /// In en, this message translates to:
  /// **'Add the first {count}'**
  String addFirstN(int count);

  /// No description provided for @skipThem.
  ///
  /// In en, this message translates to:
  /// **'Skip them'**
  String get skipThem;

  /// No description provided for @addedPayments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No payment added} =1{Added 1 payment} other{Added {count} payments}}'**
  String addedPayments(int count);

  /// No description provided for @skippedPayments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Skipped 1. Next: {date}} other{Skipped {count}. Next: {date}}}'**
  String skippedPayments(int count, String date);

  /// No description provided for @skippedPaymentsNoNext.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Skipped 1. No more payments.} other{Skipped {count}. No more payments.}}'**
  String skippedPaymentsNoNext(int count);

  /// No description provided for @recurringGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add its payments. They will be tried again.'**
  String get recurringGenerateFailed;

  /// No description provided for @binPaymentOf.
  ///
  /// In en, this message translates to:
  /// **'Payment of {title} ({schedule})'**
  String binPaymentOf(String title, String schedule);

  /// No description provided for @restoreRecurringCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recurring item} other{{count} recurring items}}'**
  String restoreRecurringCount(int count);

  /// No description provided for @changesSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get changesSaved;

  /// No description provided for @newRecurring.
  ///
  /// In en, this message translates to:
  /// **'New recurring expense'**
  String get newRecurring;

  /// No description provided for @recurringNoneWaiting.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting for a decision.'**
  String get recurringNoneWaiting;

  /// No description provided for @recurringNoneActive.
  ///
  /// In en, this message translates to:
  /// **'Nothing is running. Turn on Repeats when you add an expense.'**
  String get recurringNoneActive;

  /// No description provided for @recurringNoneArchived.
  ///
  /// In en, this message translates to:
  /// **'Nothing is archived. Stopped and ended items go here.'**
  String get recurringNoneArchived;

  /// Before the count field in 'After [12] payments'. Hindi: 'कुल [12] भुगतानों के बाद' (after 12 payments in all).
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get repeatEndsAfter;

  /// After the count field in 'After [12] payments'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{payment} other{payments}}'**
  String repeatEndsAfterUnit(int count);

  /// The count field's label for TalkBack: payments in all, this one included.
  ///
  /// In en, this message translates to:
  /// **'Number of payments'**
  String get repeatCountLabel;

  /// No description provided for @repeatCountError.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max}'**
  String repeatCountError(int min, int max);

  /// After 'Next: 9 Nov' when the item ends: 'Next: 9 Nov · last 9 Sep 2027'.
  ///
  /// In en, this message translates to:
  /// **'last {date}'**
  String repeatLast(String date);

  /// No description provided for @repeatCountTooLate.
  ///
  /// In en, this message translates to:
  /// **'The last payment would be after {date}. Use fewer payments.'**
  String repeatCountTooLate(String date);

  /// An existing expense made to repeat (phase-7b.md §8.5).
  ///
  /// In en, this message translates to:
  /// **'Updated. Repeats: {schedule}'**
  String updatedRepeats(String schedule);

  /// No description provided for @updatedWithEarlier.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated with 1 earlier payment.} other{Updated with {count} earlier payments.}}'**
  String updatedWithEarlier(int count);

  /// No description provided for @howOften.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get howOften;

  /// No description provided for @firstPayment.
  ///
  /// In en, this message translates to:
  /// **'First payment'**
  String get firstPayment;

  /// Under How often once it differs from the item's (phase-7b.md §8.2).
  ///
  /// In en, this message translates to:
  /// **'Saving makes a new recurring item; this one is archived.'**
  String get newItemNotice;

  /// No description provided for @scheduleLockedNotice.
  ///
  /// In en, this message translates to:
  /// **'Payments are waiting. Add or skip them on the item\'s page before changing how often.'**
  String get scheduleLockedNotice;

  /// The First payment of a new schedule must be after the old item's last handled payment and not before today.
  ///
  /// In en, this message translates to:
  /// **'Pick {date} or later'**
  String firstPaymentTooEarly(String date);

  /// No description provided for @newItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Make a new recurring item?'**
  String get newItemTitle;

  /// name: 'Netflix · Every week on Monday'; date: the First payment.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Changing how often creates a new item, {name}, from {date}. This one is archived: it adds nothing more, and you can restore or delete it from the Archive.} =1{Changing how often creates a new item, {name}, from {date}. This one is archived: it adds nothing more, and you can restore or delete it from the Archive. Its payment stays.} other{Changing how often creates a new item, {name}, from {date}. This one is archived: it adds nothing more, and you can restore or delete it from the Archive. Its {count} payments stay.}}'**
  String newItemText(int count, String name, String date);

  /// No description provided for @createNew.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get createNew;

  /// No description provided for @recurringArchivedShort.
  ///
  /// In en, this message translates to:
  /// **'{title} archived'**
  String recurringArchivedShort(String title);

  /// After the schedule in an Archive row: 'Monthly · replaced 9 Oct'.
  ///
  /// In en, this message translates to:
  /// **'replaced {date}'**
  String archivedReplaced(String date);

  /// name: 'Netflix · Every month'.
  ///
  /// In en, this message translates to:
  /// **'Switch back to {name}?'**
  String swapTitle(String name);

  /// name: the item switched out, 'Netflix · Every week on Monday'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{{name} is archived: it adds nothing more. It added no payments.} =1{{name} is archived: it adds nothing more. Its 1 payment already added stays. Delete it from the list if you don\'t want it.} other{{name} is archived: it adds nothing more. Its {count} payments already added stay. Delete the ones you don\'t want from the list.}}'**
  String swapText(int count, String name);

  /// No description provided for @switchBack.
  ///
  /// In en, this message translates to:
  /// **'Switch back'**
  String get switchBack;

  /// No description provided for @switchedBack.
  ///
  /// In en, this message translates to:
  /// **'Switched back to {name}'**
  String switchedBack(String name);

  /// No description provided for @addSelected.
  ///
  /// In en, this message translates to:
  /// **'Add selected'**
  String get addSelected;

  /// No description provided for @whichPaymentsToAdd.
  ///
  /// In en, this message translates to:
  /// **'Which payments to add?'**
  String get whichPaymentsToAdd;

  /// Unticks every payment in the Add selected sheet.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get selectNone;

  /// No description provided for @addN.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1} other{Add {count}}}'**
  String addN(int count);

  /// The Add selected sheet's button when nothing is ticked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Skip it} other{Skip all {count}}}'**
  String skipAllN(int count);

  /// No description provided for @addedAndSkipped.
  ///
  /// In en, this message translates to:
  /// **'{added} added, {skipped} skipped. Next: {date}'**
  String addedAndSkipped(int added, int skipped, String date);

  /// No description provided for @addedAndSkippedNoNext.
  ///
  /// In en, this message translates to:
  /// **'{added} added, {skipped} skipped. No more payments.'**
  String addedAndSkippedNoNext(int added, int skipped);

  /// More than 1,000 were waiting: the rest are asked about next.
  ///
  /// In en, this message translates to:
  /// **'{added} added, {skipped} skipped. More are waiting.'**
  String addedAndSkippedMore(int added, int skipped);

  /// No description provided for @upcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming payments'**
  String get upcomingTitle;

  /// Home's icon left of the photos icon (phase-7b.md §8.3).
  ///
  /// In en, this message translates to:
  /// **'Upcoming payments'**
  String get upcomingTooltip;

  /// No description provided for @upcomingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing coming up. Recurring items you add show here.'**
  String get upcomingEmpty;

  /// No description provided for @upcomingEnd.
  ///
  /// In en, this message translates to:
  /// **'Shows the next 12 months.'**
  String get upcomingEnd;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @skipDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip {title} on {date}?'**
  String skipDialogTitle(String title, String date);

  /// No description provided for @skipOnlyThis.
  ///
  /// In en, this message translates to:
  /// **'Skip only this payment'**
  String get skipOnlyThis;

  /// No description provided for @stopItem.
  ///
  /// In en, this message translates to:
  /// **'Stop {title}: no more payments'**
  String stopItem(String title);

  /// An upcoming payment skipped once: its row's second line.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @skippedOn.
  ///
  /// In en, this message translates to:
  /// **'Skipped {title} on {date}'**
  String skippedOn(String title, String date);

  /// Undoes a skip of one upcoming payment.
  ///
  /// In en, this message translates to:
  /// **'Bring back'**
  String get bringBack;

  /// No description provided for @paymentBack.
  ///
  /// In en, this message translates to:
  /// **'{title} on {date} is back'**
  String paymentBack(String title, String date);

  /// What TalkBack reads for an Upcoming row: 'Netflix, ₹649, 9 November'.
  ///
  /// In en, this message translates to:
  /// **'{title}, {amount}, {date}'**
  String upcomingRowSemantics(String title, String amount, String date);

  /// The filter sheet's switch: the list, totals and trend show payments of recurring items only.
  ///
  /// In en, this message translates to:
  /// **'Only recurring'**
  String get onlyRecurring;

  /// Home's chip while Only recurring is on; its ✕ turns it off.
  ///
  /// In en, this message translates to:
  /// **'🔁 Recurring'**
  String get filterChipRecurring;

  /// No description provided for @noUpcomingMatchTooltip.
  ///
  /// In en, this message translates to:
  /// **'No upcoming payments match the filters'**
  String get noUpcomingMatchTooltip;

  /// No description provided for @noUpcomingMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No upcoming payments match the filters on Home.'**
  String get noUpcomingMatchFilters;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// The period row's fourth choice: From / To or All time.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get reportPeriodRange;

  /// TalkBack hint of the period's name: a tap goes back to this week, month or year.
  ///
  /// In en, this message translates to:
  /// **'Back to the current period'**
  String get reportBackToCurrent;

  /// No description provided for @reportRangeDates.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String reportRangeDates(String from, String to);

  /// The range row for All time, with the first and last day of the expenses.
  ///
  /// In en, this message translates to:
  /// **'All time · {from} – {to}'**
  String reportAllTimeSpan(String from, String to);

  /// TalkBack label of the range row's edit button.
  ///
  /// In en, this message translates to:
  /// **'Change the range'**
  String get reportChangeRange;

  /// No description provided for @reportRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Report range'**
  String get reportRangeTitle;

  /// No description provided for @reportFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get reportFrom;

  /// No description provided for @reportTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get reportTo;

  /// No description provided for @reportAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get reportAllTime;

  /// No description provided for @reportShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get reportShow;

  /// No description provided for @reportGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get reportGroupBy;

  /// No description provided for @reportGroupCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get reportGroupCategory;

  /// No description provided for @reportGroupEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get reportGroupEvent;

  /// No description provided for @reportGroupPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get reportGroupPaymentMethod;

  /// No description provided for @reportNoEvent.
  ///
  /// In en, this message translates to:
  /// **'No event'**
  String get reportNoEvent;

  /// No description provided for @reportFilterPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get reportFilterPaymentMethods;

  /// No description provided for @searchPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Search payment methods…'**
  String get searchPaymentMethods;

  /// No description provided for @allPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'All payment methods'**
  String get allPaymentMethods;

  /// No description provided for @reportExpenseCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense} other{{count} expenses}}'**
  String reportExpenseCount(int count);

  /// The Other slice: how many groups it holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Other ({count})}}'**
  String reportOtherGroups(int count);

  /// A share, already formatted with one decimal (33.3).
  ///
  /// In en, this message translates to:
  /// **'{share} %'**
  String reportSharePercent(String share);

  /// A share under 0.1 % that isn't 0: '< 0.1 %'.
  ///
  /// In en, this message translates to:
  /// **'< {share} %'**
  String reportShareTiny(String share);

  /// TalkBack: a slice or bar of the card. The share ends in % already (TalkBack reads it as percent).
  ///
  /// In en, this message translates to:
  /// **'{name}, {amount}, {share}'**
  String reportSliceSemantics(String name, String amount, String share);

  /// Under the card's total: the tapped slice or bar.
  ///
  /// In en, this message translates to:
  /// **'{name} · {amount} · {share}'**
  String reportSliceDetail(String name, String amount, String share);

  /// No description provided for @reportFaceBars.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get reportFaceBars;

  /// No description provided for @reportFaceDonut.
  ///
  /// In en, this message translates to:
  /// **'Donut'**
  String get reportFaceDonut;

  /// No description provided for @nextChart.
  ///
  /// In en, this message translates to:
  /// **'Next chart'**
  String get nextChart;

  /// No description provided for @previousChart.
  ///
  /// In en, this message translates to:
  /// **'Previous chart'**
  String get previousChart;

  /// No description provided for @reportCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{range}, {chart}, total {amount}'**
  String reportCardSemantics(String range, String chart, String amount);

  /// No description provided for @reportCardSemanticsFiltered.
  ///
  /// In en, this message translates to:
  /// **'{range}, filtered, {chart}, total {amount}'**
  String reportCardSemanticsFiltered(String range, String chart, String amount);

  /// No description provided for @reportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No expenses in {range}.'**
  String reportEmpty(String range);

  /// No description provided for @reportEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'Nothing in {range} matches the filter.'**
  String reportEmptyFiltered(String range);

  /// No description provided for @reportNoExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet.'**
  String get reportNoExpensesYet;

  /// No description provided for @reportLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the report.'**
  String get reportLoadFailed;

  /// No description provided for @reportFilterChanged.
  ///
  /// In en, this message translates to:
  /// **'Filter changed: {name} was deleted.'**
  String reportFilterChanged(String name);

  /// No description provided for @reportFilterChangedMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Filter changed: a chosen item was deleted.} other{Filter changed: {count} chosen items were deleted.}}'**
  String reportFilterChangedMany(int count);

  /// No description provided for @reportFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get reportFormat;

  /// No description provided for @reportFormatPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get reportFormatPdf;

  /// No description provided for @reportFormatExcel.
  ///
  /// In en, this message translates to:
  /// **'Excel (.xlsx)'**
  String get reportFormatExcel;

  /// No description provided for @reportShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get reportShare;

  /// No description provided for @reportSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get reportSaveAs;

  /// No description provided for @reportSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get reportSave;

  /// No description provided for @reportMakingPdf.
  ///
  /// In en, this message translates to:
  /// **'Making the PDF…'**
  String get reportMakingPdf;

  /// No description provided for @reportMakingPdfPage.
  ///
  /// In en, this message translates to:
  /// **'Making the PDF… page {page} of {pages}'**
  String reportMakingPdfPage(int page, int pages);

  /// No description provided for @reportMakingExcel.
  ///
  /// In en, this message translates to:
  /// **'Making the Excel file…'**
  String get reportMakingExcel;

  /// No description provided for @reportSaved.
  ///
  /// In en, this message translates to:
  /// **'Report saved'**
  String get reportSaved;

  /// No description provided for @reportPdfFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make the PDF. Try again.'**
  String get reportPdfFailed;

  /// No description provided for @reportExcelFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make the Excel file. Try again.'**
  String get reportExcelFailed;

  /// No description provided for @reportTooManyRows.
  ///
  /// In en, this message translates to:
  /// **'Too many expenses for one sheet. Pick a shorter range.'**
  String get reportTooManyRows;

  /// No description provided for @reportSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the file. Try again.'**
  String get reportSaveFailed;

  /// No description provided for @reportNoShareTarget.
  ///
  /// In en, this message translates to:
  /// **'No app on this phone can receive the file.'**
  String get reportNoShareTarget;

  /// No description provided for @reportNothingToExport.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export'**
  String get reportNothingToExport;

  /// No description provided for @reportDocTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense report'**
  String get reportDocTitle;

  /// No description provided for @reportDocMadeOn.
  ///
  /// In en, this message translates to:
  /// **'Made on {date}'**
  String reportDocMadeOn(String date);

  /// No description provided for @reportDocFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter: {parts}'**
  String reportDocFilter(String parts);

  /// No description provided for @reportDocSearch.
  ///
  /// In en, this message translates to:
  /// **'Search: {text}'**
  String reportDocSearch(String text);

  /// No description provided for @reportDocCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories: {names}'**
  String reportDocCategories(String names);

  /// No description provided for @reportDocEvents.
  ///
  /// In en, this message translates to:
  /// **'Events: {names}'**
  String reportDocEvents(String names);

  /// No description provided for @reportDocPaidWith.
  ///
  /// In en, this message translates to:
  /// **'Paid with: {names}'**
  String reportDocPaidWith(String names);

  /// No description provided for @reportDocNoFilter.
  ///
  /// In en, this message translates to:
  /// **'No filter'**
  String get reportDocNoFilter;

  /// No description provided for @reportDocGrouping.
  ///
  /// In en, this message translates to:
  /// **'Grouped by {grouping}'**
  String reportDocGrouping(String grouping);

  /// No description provided for @reportDocTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get reportDocTotal;

  /// No description provided for @reportDocAlsoIn.
  ///
  /// In en, this message translates to:
  /// **'also in {names}'**
  String reportDocAlsoIn(String names);

  /// The PDF's footer; Kotlin fills both numbers per page.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String reportDocPageOf(String page, String pages);

  /// No description provided for @reportColDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportColDate;

  /// No description provided for @reportColTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get reportColTime;

  /// No description provided for @reportColTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reportColTitle;

  /// No description provided for @reportColCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get reportColCategory;

  /// No description provided for @reportColEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get reportColEvents;

  /// No description provided for @reportColPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get reportColPaymentMethod;

  /// No description provided for @reportColCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get reportColCurrency;

  /// No description provided for @reportColAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get reportColAmount;

  /// No description provided for @reportColSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get reportColSubtotal;

  /// No description provided for @reportColCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get reportColCount;

  /// No description provided for @reportColShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get reportColShare;

  /// No description provided for @reportColRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get reportColRecurring;

  /// No description provided for @reportGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate report'**
  String get reportGenerate;

  /// No description provided for @reportGenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate a report'**
  String get reportGenerateTitle;

  /// No description provided for @reportChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get reportChart;

  /// No description provided for @reportChartPie.
  ///
  /// In en, this message translates to:
  /// **'Pie'**
  String get reportChartPie;

  /// No description provided for @reportGroupOthers.
  ///
  /// In en, this message translates to:
  /// **'Group small items as Others'**
  String get reportGroupOthers;

  /// No description provided for @reportGroupOthersHint.
  ///
  /// In en, this message translates to:
  /// **'Off: every item has its own bar or slice and legend line'**
  String get reportGroupOthersHint;

  /// No description provided for @reportOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'In Other'**
  String get reportOtherTitle;

  /// No description provided for @reportOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get reportOverall;

  /// No description provided for @reportSectionsOverlap.
  ///
  /// In en, this message translates to:
  /// **'An expense in two events is in both sections: section totals can add up to more than the overall total, which counts it once.'**
  String get reportSectionsOverlap;

  /// No description provided for @reportColNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get reportColNote;

  /// No description provided for @reportSavedNoViewer.
  ///
  /// In en, this message translates to:
  /// **'Saved to Download/Expense Tracker. No app on this phone can open it.'**
  String get reportSavedNoViewer;

  /// No description provided for @reportHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get reportHighlights;

  /// No description provided for @reportHiExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get reportHiExpenses;

  /// No description provided for @reportHiPerDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get reportHiPerDay;

  /// Under the average per day: how many days it is over.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{over {count} days}}'**
  String reportHiOverDays(int count);

  /// No description provided for @reportHiLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest expense'**
  String get reportHiLargest;

  /// No description provided for @reportHiTopMethod.
  ///
  /// In en, this message translates to:
  /// **'Most paid with'**
  String get reportHiTopMethod;

  /// No description provided for @reportHiTopEvent.
  ///
  /// In en, this message translates to:
  /// **'Top event'**
  String get reportHiTopEvent;

  /// No description provided for @smsSuggestions.
  ///
  /// In en, this message translates to:
  /// **'SMS suggestions'**
  String get smsSuggestions;

  /// Tooltip of Home's SMS icon while suggestions wait.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new SMS suggestion} other{{count} new SMS suggestions}}'**
  String smsNewCount(int count);

  /// No description provided for @smsNone.
  ///
  /// In en, this message translates to:
  /// **'No new bank SMS'**
  String get smsNone;

  /// Under the empty SMS screen and in Settings → SMS: when the inbox was last read.
  ///
  /// In en, this message translates to:
  /// **'Checked {time}'**
  String smsLastChecked(String time);

  /// Tooltip of a suggestion card's dismiss icon.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get smsDismiss;

  /// No description provided for @smsDismissed.
  ///
  /// In en, this message translates to:
  /// **'Suggestion dismissed'**
  String get smsDismissed;

  /// No description provided for @smsPermissionOff.
  ///
  /// In en, this message translates to:
  /// **'SMS permission is off'**
  String get smsPermissionOff;

  /// No description provided for @smsAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get smsAllow;

  /// No description provided for @smsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get smsOpenSettings;

  /// No description provided for @smsPermissionRefused.
  ///
  /// In en, this message translates to:
  /// **'Without the SMS permission the app can\'t suggest expenses. You can turn it on in Settings → SMS.'**
  String get smsPermissionRefused;

  /// No description provided for @smsAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'This SMS was already added'**
  String get smsAlreadyAdded;

  /// Banner above an Add form filled from an SMS: the sender ID and when it came.
  ///
  /// In en, this message translates to:
  /// **'From SMS · {sender} · {time}'**
  String smsFromBanner(String sender, String time);

  /// No description provided for @smsDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved draft'**
  String get smsDraftTitle;

  /// No description provided for @smsDraftMessage.
  ///
  /// In en, this message translates to:
  /// **'You have an unsaved expense. Dismiss it to add this SMS? The draft can\'t be brought back.'**
  String get smsDraftMessage;

  /// No description provided for @smsEditDraftMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes to \"{title}\". Dismiss them to add this SMS?'**
  String smsEditDraftMessage(String title);

  /// No description provided for @smsDismissDraft.
  ///
  /// In en, this message translates to:
  /// **'Dismiss draft'**
  String get smsDismissDraft;

  /// No description provided for @smsOnboardingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Suggest expenses from bank SMS?'**
  String get smsOnboardingQuestion;

  /// No description provided for @smsPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'The app reads bank SMS on this phone and keeps only the amount, payee and time. Suggestions not added are removed after 30 days.'**
  String get smsPrivacyNote;

  /// No description provided for @backupWaitingForSms.
  ///
  /// In en, this message translates to:
  /// **'Waiting for SMS reading to finish…'**
  String get backupWaitingForSms;

  /// Settings grid tile and screen title.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get smsTile;

  /// No description provided for @smsTileOn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{On} =1{On · 1 waiting} other{On · {count} waiting}}'**
  String smsTileOn(int count);

  /// No description provided for @smsTileOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get smsTileOff;

  /// No description provided for @smsNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get smsNotNow;

  /// No description provided for @smsYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get smsYes;

  /// No description provided for @smsAiSetting.
  ///
  /// In en, this message translates to:
  /// **'Use on-device AI'**
  String get smsAiSetting;

  /// No description provided for @smsAiHelp.
  ///
  /// In en, this message translates to:
  /// **'Reads bank SMS with Google\'s on-device model. Nothing leaves the phone. May be slow on some phones.'**
  String get smsAiHelp;

  /// No description provided for @smsAiDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the model…'**
  String get smsAiDownloading;

  /// No description provided for @backupWaitingForSmsCount.
  ///
  /// In en, this message translates to:
  /// **'Waiting for SMS reading to finish… ({done} of {total})'**
  String backupWaitingForSmsCount(int done, int total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
