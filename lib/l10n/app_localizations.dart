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
