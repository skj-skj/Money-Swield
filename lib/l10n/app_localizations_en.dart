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
  String get homeEmptyMessage => 'Tap Add expense to record your first one.';

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
  String get ok => 'OK';

  @override
  String get addExpense => 'Add expense';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldEvents => 'Events';

  @override
  String get fieldPaymentMethod => 'Payment method';

  @override
  String get fieldCurrency => 'Currency';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldTime => 'Time';

  @override
  String get fieldNotes => 'Description';

  @override
  String get fieldDeletedAt => 'Deleted on';

  @override
  String get amountErrorEmpty => 'Enter an amount';

  @override
  String get amountErrorInvalid => 'Enter a plain number, like 110.50';

  @override
  String amountErrorTooLarge(int max) {
    return 'Use at most $max digits before the decimal point';
  }

  @override
  String amountErrorTooManyDecimals(int digits, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      digits,
      locale: localeName,
      other: '$currency has only $digits decimals',
      one: '$currency has only 1 decimal',
      zero: '$currency has no decimals',
    );
    return '$_temp0';
  }

  @override
  String get amountErrorNotPositive => 'Enter an amount above zero';

  @override
  String amountPreview(String amount) {
    return '= $amount';
  }

  @override
  String get titleRequired => 'Enter a title';

  @override
  String get categoryRequired => 'Pick a category';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discard => 'Discard';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get expenseGone => 'This expense no longer exists';

  @override
  String get search => 'Search';

  @override
  String get closeSearch => 'Close search';

  @override
  String get searchCategories => 'Search categories…';

  @override
  String get searchEvents => 'Search events…';

  @override
  String get newCategory => 'New category';

  @override
  String get newEvent => 'New event';

  @override
  String get moreResults => 'More results';

  @override
  String get allCategories => 'All categories';

  @override
  String get allEvents => 'All events';

  @override
  String get noMoreMatches => 'No more matches';

  @override
  String get noCategoriesYet => 'No categories yet';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get movedToBin => 'Moved to bin';

  @override
  String get undo => 'Undo';

  @override
  String get loadMoreFailed => 'Couldn\'t load more expenses.';

  @override
  String get bin => 'Bin';

  @override
  String get binSubtitle => 'Deleted expenses are kept for 30 days';

  @override
  String get binEmpty => 'Deleted expenses stay here for 30 days.';

  @override
  String get deletedToday => 'Deleted today';

  @override
  String get deletedYesterday => 'Deleted yesterday';

  @override
  String deletedDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return 'Deleted $_temp0';
  }

  @override
  String removedInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'removed in $days days',
      one: 'removed in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get removedOnNextStart => 'removed on next start';

  @override
  String get restore => 'Restore';

  @override
  String get restoreAll => 'Restore all';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String deletePermanentlyTitle(String title) {
    return 'Delete \"$title\" permanently?';
  }

  @override
  String get emptyBin => 'Empty bin';

  @override
  String get emptyBinTitle => 'Empty the bin?';

  @override
  String get cannotBeUndone => 'This can\'t be undone.';

  @override
  String usedByExpenses(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return '\"$name\" is used by $_temp0.';
  }

  @override
  String usedByExpensesWithBin(String name, int count, int binned) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return '\"$name\" is used by $_temp0 ($binned in the bin).';
  }

  @override
  String get moveExpensesTo => 'Move them to:';

  @override
  String get moveAndDelete => 'Move and delete';

  @override
  String get addAnotherFirst =>
      'Add another one first, so its expenses have somewhere to go.';

  @override
  String eventDeleteWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return 'It will be removed from $_temp0. The expenses stay.';
  }

  @override
  String get recentCurrencies => 'Recent';

  @override
  String get allCurrencies => 'All currencies';

  @override
  String get noneEvent => 'None';

  @override
  String get settingTileShape => 'Tile shape';

  @override
  String get settingButtonShape => 'Button shape';

  @override
  String get shapeSquare => 'Square';

  @override
  String get shapeRounded => 'Rounded square';

  @override
  String get shapeCircle => 'Circle';

  @override
  String get settingCustomizeTiles => 'Customize tiles';

  @override
  String get settingCustomizeTilesSubtitle =>
      'Shapes of the category and event pickers';

  @override
  String get preview => 'Preview';

  @override
  String get settingThemeColor => 'Theme color';

  @override
  String get themeColorWallpaper => 'Wallpaper colors';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorRed => 'Red';

  @override
  String get colorPink => 'Pink';

  @override
  String get restoreDefaultLook => 'Restore default look';

  @override
  String get restoreDefaultLookSubtitle => 'Theme color and tile shapes';

  @override
  String get restoreDefaultLookTitle => 'Restore the default look?';

  @override
  String get restoreDefaultLookMessage =>
      'The theme color goes back to the wallpaper colors, tiles to rounded squares and buttons to circles.';

  @override
  String get migrationInstalledTitle => 'Database initialized';

  @override
  String get migrationInstalledMessage => 'Everything is ready.';

  @override
  String get migrationUpdatedTitle => 'Update done successfully';

  @override
  String get migrationUpdatedMessage => 'Your data is up to date.';

  @override
  String get backupAndRestore => 'Backup & restore';

  @override
  String get lastBackupNever => 'Never backed up';

  @override
  String get lastBackupToday => 'today';

  @override
  String get lastBackupYesterday => 'yesterday';

  @override
  String lastBackupDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String lastBackupSubtitle(String when) {
    return 'Last backup: $when';
  }

  @override
  String get backUpNow => 'Back up now';

  @override
  String get preparingBackup => 'Preparing backup…';

  @override
  String get backupSaved => 'Backup saved';

  @override
  String get backupFailedTitle => 'Backup failed';

  @override
  String get backupFailedMessage =>
      'Nothing was saved, and your data on this phone is unchanged. Please copy the report below and send it to us so we can fix it.';

  @override
  String get restoreFromBackup => 'Restore from a backup';

  @override
  String get restoreFromBackupSubtitle =>
      'Replaces all data on this phone with a backup file.';

  @override
  String get undoLastRestore => 'Undo last restore';

  @override
  String undoLastRestoreSubtitle(String date) {
    return 'Go back to your data from before the restore on $date.';
  }

  @override
  String get restoreConfirmTitle => 'Restore this backup?';

  @override
  String get undoConfirmTitle => 'Undo the last restore?';

  @override
  String restoreBackupFrom(String date) {
    return 'Backup from $date';
  }

  @override
  String restoreCopyFrom(String date) {
    return 'Your data from before the restore on $date';
  }

  @override
  String restoreExpenseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
      zero: 'No expenses',
    );
    return '$_temp0';
  }

  @override
  String restoreBinCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plus $count in the bin',
      one: 'plus 1 in the bin',
    );
    return '$_temp0';
  }

  @override
  String restoreLatestOn(String date) {
    return 'Latest on $date';
  }

  @override
  String restoreReplacesData(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
      zero: 'no expenses',
    );
    return 'All data on this phone ($_temp0) is replaced.';
  }

  @override
  String get restoreKeepsCopy =>
      'A copy is kept, and you can undo the restore.';

  @override
  String get restoreBackupButton => 'Restore';

  @override
  String get checkingBackup => 'Checking the backup…';

  @override
  String get restoringData => 'Restoring your data…';

  @override
  String get backupRestored => 'Backup restored';

  @override
  String get backupRestoredDefaultSettings =>
      'Backup restored. Its settings were missing or unreadable, so the default settings are used. You can change them in Settings.';

  @override
  String get restoreFailedTitle => 'Restore failed';

  @override
  String get restoreFailedMessage =>
      'Your data on this phone is unchanged. Please copy the report below and send it to us so we can fix it.';

  @override
  String get restoreFailedRestartMessage =>
      'Your data on this phone is unchanged. The app restarts to open it again. Please copy the report below and send it to us so we can fix it.';

  @override
  String get restartApp => 'Restart the app';

  @override
  String get restoreRejectedTitle => 'Can\'t restore this file';

  @override
  String get notABackup => 'This file isn\'t a backup from Expense Tracker.';

  @override
  String get backupTooNew =>
      'This backup was made by a newer version of the app. Update the app, then try again.';

  @override
  String get backupDamaged => 'This backup is damaged and can\'t be restored.';

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
