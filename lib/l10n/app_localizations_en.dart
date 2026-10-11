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
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Updating your data ($currentString of $totalString)';
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
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Step $currentString of $totalString';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Archived ($countString)';
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
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Use at most $maxString characters';
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
  String get amountErrorInvalid => 'Enter an amount like 110.50 or 50 + 60';

  @override
  String amountErrorTooLarge(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'Use at most $maxString digits before the decimal point';
  }

  @override
  String amountErrorTooManyDecimals(int digits, String currency) {
    final intl.NumberFormat digitsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String digitsString = digitsNumberFormat.format(digits);

    String _temp0 = intl.Intl.pluralLogic(
      digits,
      locale: localeName,
      other: '$currency has only $digitsString decimals',
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
  String get expenseGone => 'This expense no longer exists';

  @override
  String get clear => 'Clear';

  @override
  String get update => 'Update';

  @override
  String get done => 'Done';

  @override
  String get cleared => 'Form cleared';

  @override
  String get draftDiscarded => 'Draft discarded';

  @override
  String get discardDraft => 'Discard draft';

  @override
  String draftRestoredAdd(String age) {
    return 'Unsaved expense restored ($age)';
  }

  @override
  String draftRestoredEdit(String age) {
    return 'Unsaved changes restored ($age)';
  }

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get draftKeptExpenseGone =>
      'The expense was deleted; your changes were kept. Tap + to add them as a new expense';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get itemize => 'Itemize';

  @override
  String get itemizeTitle => 'Describe the items';

  @override
  String get amountErrorDivideByZero => 'Can\'t divide by zero';

  @override
  String amountApprox(String amount) {
    return '≈ $amount';
  }

  @override
  String get keyPlus => 'plus';

  @override
  String get keyMinus => 'minus';

  @override
  String get keyTimes => 'times';

  @override
  String get keyDivide => 'divided by';

  @override
  String get keyDecimal => 'decimal point';

  @override
  String get amountChipsLabel => 'Usual amounts';

  @override
  String get titleSuggestionsLabel => 'Past titles';

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
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days ago',
      one: '1 day ago',
    );
    return 'Deleted $_temp0';
  }

  @override
  String removedInDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'removed in $daysString days',
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString expenses',
      one: '1 expense',
    );
    return '\"$name\" is used by $_temp0.';
  }

  @override
  String usedByExpensesWithBin(String name, int count, int binned) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat binnedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String binnedString = binnedNumberFormat.format(binned);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString expenses',
      one: '1 expense',
    );
    return '\"$name\" is used by $_temp0 ($binnedString in the bin).';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString expenses',
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
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days ago',
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString expenses',
      one: '1 expense',
      zero: 'No expenses',
    );
    return '$_temp0';
  }

  @override
  String restoreBinCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plus $countString in the bin',
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString expenses',
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
  String get periodDay => 'Day';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String weekNumber(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Week $numberString';
  }

  @override
  String weekNumberWithYear(int number, String year) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Week $numberString, $year';
  }

  @override
  String weekOfMonth(String month, int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return '$month Week $numberString';
  }

  @override
  String dayWithSubtotal(String date, String amount) {
    return '$date – $amount';
  }

  @override
  String daySubtotalSemantics(String date, String amount) {
    return '$date, $amount';
  }

  @override
  String get trendEmptyWeek => 'No expenses this week';

  @override
  String get trendEmptyMonth => 'No expenses this month';

  @override
  String get trendEmptyYear => 'No expenses this year';

  @override
  String get trendNoMatchWeek => 'No matching expenses this week';

  @override
  String get trendNoMatchMonth => 'No matching expenses this month';

  @override
  String get trendNoMatchYear => 'No matching expenses this year';

  @override
  String get trendFiltered => 'Filtered';

  @override
  String trendPointLabel(String date, String amount) {
    return '$date · $amount';
  }

  @override
  String trendCardSemantics(String period, String amount) {
    return '$period, total $amount';
  }

  @override
  String trendCardSemanticsFiltered(String period, String amount) {
    return '$period, filtered, total $amount';
  }

  @override
  String get totalsLoadFailed => 'Couldn\'t load totals';

  @override
  String get nextPeriod => 'Next period';

  @override
  String get previousPeriod => 'Previous period';

  @override
  String get nextCurrency => 'Next currency';

  @override
  String get previousCurrency => 'Previous currency';

  @override
  String chartCurrencyAnnounce(String currency, String amount) {
    return '$currency, $amount';
  }

  @override
  String totalsJoin(String first, String rest) {
    return '$first + $rest';
  }

  @override
  String totalsJoinSpoken(String first, String rest) {
    return '$first and $rest';
  }

  @override
  String get totalTooLarge => 'Too large';

  @override
  String get showSubtotal => 'Show subtotal';

  @override
  String get subtotalLoadFailed => 'Couldn\'t load the subtotal';

  @override
  String groupSubtotalSemantics(String name, String amount) {
    return '$name, subtotal $amount';
  }

  @override
  String get close => 'Close';

  @override
  String get filters => 'Filters';

  @override
  String get filterSearchHint => 'Search titles and descriptions';

  @override
  String get filterCategories => 'Categories';

  @override
  String get filterEvents => 'Events';

  @override
  String get filterArchived => 'Archived';

  @override
  String get groupBy => 'Group by';

  @override
  String get groupedByDay => 'By day';

  @override
  String get groupedByWeek => 'By week';

  @override
  String get groupedByMonth => 'By month';

  @override
  String get groupedByYear => 'By year';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get showResults => 'Show results';

  @override
  String get noFilterMatches => 'No expenses match these filters';

  @override
  String filterMore(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$name +$countString';
  }

  @override
  String filterSearchChip(String text) {
    return '\"$text\"';
  }

  @override
  String get removeFilter => 'Remove filter';

  @override
  String get settingsLook => 'Look';

  @override
  String get settingsHome => 'Home';

  @override
  String get settingsDefaults => 'Defaults';

  @override
  String get settingWeekStart => 'Week starts on';

  @override
  String get settingWeekNames => 'Week names';

  @override
  String get settingTrendChart => 'Trend chart';

  @override
  String get chartLineFilled => 'Smooth line, filled';

  @override
  String get chartLine => 'Smooth line';

  @override
  String get chartBars => 'Bars';

  @override
  String get chartDots => 'Dots';

  @override
  String get chartRunningTotal => 'Running total';

  @override
  String get settingTrendCardSize => 'Card size';

  @override
  String get cardSizeSmall => 'Small';

  @override
  String get cardSizeMedium => 'Medium';

  @override
  String get cardSizeLarge => 'Large';

  @override
  String get settingCardHaptics => 'Card vibration';

  @override
  String get hapticsOff => 'Off';

  @override
  String get hapticsLight => 'Light';

  @override
  String get hapticsMedium => 'Medium';

  @override
  String get hapticsStrong => 'Strong';

  @override
  String trendRunningTotalPoint(String date, String amount) {
    return 'Up to $date · $amount';
  }

  @override
  String get restoreHomeDefaults => 'Restore defaults';

  @override
  String get restoreHomeDefaultsSubtitle =>
      'Chart, card and weeks as they were at first';

  @override
  String get restoreHomeDefaultsTitle => 'Restore the Home defaults?';

  @override
  String get restoreHomeDefaultsMessage =>
      'The trend chart, trend card, card size, week start and week names go back to their defaults.';

  @override
  String get settingTrendCard => 'Trend card';

  @override
  String get trendCardLocked => 'Locked at the top';

  @override
  String get trendCardScrolls => 'Scrolls with the list';

  @override
  String get trendCardLockedShort => 'Locked';

  @override
  String get trendCardScrollsShort => 'Scrolls';

  @override
  String get binTileSummary => 'Kept for 30 days';

  @override
  String settingsTileSummary(String first, String rest) {
    return '$first · $rest';
  }

  @override
  String get addPhotos => 'Add photos';

  @override
  String photosCountOpen(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos, open',
      one: '1 photo, open',
    );
    return '$_temp0';
  }

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String photosAddedOf(int count, int max) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$countString of $maxString added';
  }

  @override
  String get photos => 'Photos';

  @override
  String photosOfMax(int count, int max) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$countString of $maxString';
  }

  @override
  String photosMaxReached(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$maxString photos is the most for one expense';
  }

  @override
  String get photoAlreadyAdded => 'That photo is already here';

  @override
  String photoCouldNotBeAdded(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos couldn\'t be added',
      one: 'A photo couldn\'t be added',
    );
    return '$_temp0';
  }

  @override
  String photosOverflow(int max, int added) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);
    final intl.NumberFormat addedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String addedString = addedNumberFormat.format(added);

    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$addedString were added',
      one: '1 was added',
      zero: 'none was added',
    );
    return 'Only $maxString photos per expense: $_temp0.';
  }

  @override
  String get noCameraApp => 'No camera app found';

  @override
  String get addingPhotos => 'Adding photos…';

  @override
  String addingPhotosProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Adding photos ($doneString of $totalString)';
  }

  @override
  String draftPhotosMissing(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos from the draft couldn\'t be found',
      one: '1 photo from the draft couldn\'t be found',
    );
    return '$_temp0';
  }

  @override
  String photosMax(int max, int extra) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);
    final intl.NumberFormat extraNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String extraString = extraNumberFormat.format(extra);

    String _temp0 = intl.Intl.pluralLogic(
      extra,
      locale: localeName,
      other: '$extraString photos',
      one: '1 photo',
    );
    return 'At most $maxString photos. Remove $_temp0 to save.';
  }

  @override
  String photosNotKept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$countString photos couldn\'t be kept: they were deleted meanwhile',
      one: '1 photo couldn\'t be kept: it was deleted meanwhile',
    );
    return '$_temp0';
  }

  @override
  String get imageMissing => 'Image missing';

  @override
  String get photosSaveFailed =>
      'Couldn\'t save the photos. Nothing was saved.';

  @override
  String photosCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String photoNumber(int index, int total) {
    final intl.NumberFormat indexNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Photo $indexString of $totalString';
  }

  @override
  String photoCounter(int index, int total) {
    final intl.NumberFormat indexNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$indexString / $totalString';
  }

  @override
  String selectedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString selected';
  }

  @override
  String photosSelectedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos selected',
      one: '1 photo selected',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get endSelection => 'End selection';

  @override
  String get selected => 'Selected';

  @override
  String get notSelected => 'Not selected';

  @override
  String photosDeleteTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $countString photos?',
      one: 'Delete this photo?',
    );
    return '$_temp0';
  }

  @override
  String photosDeleteWarningScreen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They will be deleted permanently from their expenses. Copies you saved to Pictures stay.',
      one: 'It will be deleted permanently from its expense. Copies you saved to Pictures stay.',
    );
    return '$_temp0';
  }

  @override
  String photosDeleteWarningForm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They will be deleted permanently from this expense when you tap Update. Copies you saved to Pictures stay.',
      one: 'It will be deleted permanently from this expense when you tap Update. Copies you saved to Pictures stay.',
    );
    return '$_temp0';
  }

  @override
  String photosDeleteWarningNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They will be deleted permanently from this expense when you save it. Copies you saved to Pictures stay.',
      one: 'It will be deleted permanently from this expense when you save it. Copies you saved to Pictures stay.',
    );
    return '$_temp0';
  }

  @override
  String photosDeleted(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos deleted',
      one: '1 photo deleted',
    );
    return '$_temp0';
  }

  @override
  String get saveToPictures => 'Save to Pictures';

  @override
  String savedToPictures(String folder) {
    return 'Saved to $folder';
  }

  @override
  String photosSavedToPictures(int count, String folder) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos saved to $folder',
      one: '1 photo saved to $folder',
    );
    return '$_temp0';
  }

  @override
  String photosSavedSomeFailed(int saved, int failed) {
    final intl.NumberFormat savedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String savedString = savedNumberFormat.format(saved);
    final intl.NumberFormat failedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String failedString = failedNumberFormat.format(failed);

    String _temp0 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failedString couldn\'t be saved',
      one: '1 couldn\'t be saved',
    );
    return '$savedString saved; $_temp0';
  }

  @override
  String photosMissingNotSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos are missing and weren\'t saved',
      one: '1 photo is missing and wasn\'t saved',
    );
    return '$_temp0';
  }

  @override
  String get noSpaceToSavePhotos => 'Not enough space to save these photos';

  @override
  String savingToPictures(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Saving $doneString / $totalString';
  }

  @override
  String get defaultPictureTitle => 'Expense';

  @override
  String get reviewPhoto => 'Your photo';

  @override
  String get rotateLeft => 'Rotate left';

  @override
  String get rotateRight => 'Rotate right';

  @override
  String rotatedDegrees(int degrees) {
    final intl.NumberFormat degreesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String degreesString = degreesNumberFormat.format(degrees);

    return 'Rotated $degreesString degrees';
  }

  @override
  String get usePhoto => 'Use photo';

  @override
  String get discardPhoto => 'Discard';

  @override
  String get photoFromCameraBack => 'The photo you took is back';

  @override
  String get noPhotosMatchTooltip => 'No photos match the filters';

  @override
  String photoOfExpense(String title, String date) {
    return 'Photo of $title, $date';
  }

  @override
  String get noPhotosMatchFilters => 'No photos match the filters on Home.';

  @override
  String get cameraPhotos => 'Camera photos';

  @override
  String get galleryPhotos => 'Gallery photos';

  @override
  String get photoSizeLabel => 'Size';

  @override
  String get photoQualityLabel => 'Quality';

  @override
  String get photoSizeOriginal => 'Original';

  @override
  String photoSizeNotRecommended(String size) {
    return '$size (not recommended)';
  }

  @override
  String settingDefaultValue(String value) {
    return '$value (default)';
  }

  @override
  String get photoResizedAbove =>
      'Larger photos are resized to this size; smaller ones are kept as they are';

  @override
  String get originalWarning =>
      'Keeping originals is not recommended: a phone photo is 5–10 MB, so after about 1,000 photos they take several GB on the phone and in backups with photos. Originals also keep the photo\'s location.';

  @override
  String photosUse(String size, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos',
      one: '1 photo',
    );
    return 'Photos use $size ($_temp0).';
  }

  @override
  String get noPhotosYet => 'No photos yet.';

  @override
  String get photosKeptInApp =>
      'Photos are kept inside the app and leave with it. To keep one for yourself, open it and use Save to Pictures.';

  @override
  String get photoChangesApplyToNew =>
      'Changes apply to photos you add from now on.';

  @override
  String photosTileCamera(String size) {
    return 'Camera $size';
  }

  @override
  String photosTileGallery(String size) {
    return 'Gallery $size';
  }

  @override
  String get restorePhotoDefaults => 'Restore defaults';

  @override
  String get restorePhotoDefaultsTitle => 'Restore the photo defaults?';

  @override
  String get restorePhotoDefaultsMessage =>
      'Camera and gallery photos go back to 1080p and quality 85.';

  @override
  String get includePhotos => 'Include photos';

  @override
  String get photosNotInBackup =>
      'Photos won\'t be in this backup. Restored on another phone or after reinstalling, they show as missing.';

  @override
  String backupPhotosProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Adding photos to the backup ($doneString of $totalString)';
  }

  @override
  String get savingBackup => 'Saving backup…';

  @override
  String get backupNoSpace =>
      'Not enough space on this phone to make this backup';

  @override
  String backupSavedMissingPhotos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos were missing and aren\'t in it',
      one: '1 photo was missing and isn\'t in it',
    );
    return 'Backup saved. $_temp0.';
  }

  @override
  String get saveTargetNoSpace =>
      'There isn\'t enough space where you chose to save it';

  @override
  String restoreIncludesPhotos(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos',
      one: '1 photo',
    );
    return 'Includes $_temp0 ($size).';
  }

  @override
  String restoreNoSpaceForPhotos(String size) {
    return 'There isn\'t enough space for its photos (needs $size more).';
  }

  @override
  String get restoreWithoutPhotos => 'Restore without photos';

  @override
  String get restoreBackupWithoutPhotos =>
      'This backup has no photos. Photos this phone doesn\'t have will show as missing.';

  @override
  String restoringPhotosProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Restoring photos ($doneString of $totalString)';
  }

  @override
  String backupRestoredFailedPhotos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString photos couldn\'t be restored and show as missing',
      one: '1 photo couldn\'t be restored and shows as missing',
    );
    return 'Backup restored. $_temp0.';
  }

  @override
  String get openBackupNoSpace =>
      'Not enough space on this phone to open this backup';

  @override
  String sizeBytes(String size) {
    return '$size B';
  }

  @override
  String sizeKilobytes(String size) {
    return '$size KB';
  }

  @override
  String sizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String sizeGigabytes(String size) {
    return '$size GB';
  }

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

  @override
  String get eventWedding => 'Wedding';

  @override
  String get eventDiningOut => 'Dining out';

  @override
  String scheduleDaily(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $countString days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String scheduleWeekly(int count, String weekday) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $countString weeks on $weekday',
      one: 'Every week on $weekday',
    );
    return '$_temp0';
  }

  @override
  String scheduleMonthly(int count, int day) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String dayString = dayNumberFormat.format(day);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $countString months on day $dayString',
      one: 'Every month on day $dayString',
    );
    return '$_temp0';
  }

  @override
  String scheduleMonthlyClamped(int count, int day) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String dayString = dayNumberFormat.format(day);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Every $countString months on day $dayString (or the month\'s last day)',
      one: 'Every month on day $dayString (or the month\'s last day)',
    );
    return '$_temp0';
  }

  @override
  String scheduleYearly(int count, String date) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $countString years on $date',
      one: 'Every year on $date',
    );
    return '$_temp0';
  }

  @override
  String scheduleYearlyLeap(int count, String date, String fallback) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $countString years on $date ($fallback in other years)',
      one: 'Every year on $date ($fallback in other years)',
    );
    return '$_temp0';
  }

  @override
  String repeatShortDaily(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $countString days',
      one: 'Daily',
    );
    return '$_temp0';
  }

  @override
  String repeatShortWeekly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $countString weeks',
      one: 'Weekly',
    );
    return '$_temp0';
  }

  @override
  String repeatShortMonthly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $countString months',
      one: 'Monthly',
    );
    return '$_temp0';
  }

  @override
  String repeatShortYearly(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $countString years',
      one: 'Yearly',
    );
    return '$_temp0';
  }

  @override
  String get endsNever => 'Never ends';

  @override
  String endsOn(String date) {
    return 'Ends $date';
  }

  @override
  String nextOn(String date) {
    return 'Next: $date';
  }

  @override
  String get noMorePayments => 'No more payments';

  @override
  String archivedStopped(String date) {
    return 'stopped $date';
  }

  @override
  String archivedExpired(String date) {
    return 'expired $date';
  }

  @override
  String get repeats => 'Repeats';

  @override
  String get repeatEvery => 'Every';

  @override
  String repeatUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'weeks',
      one: 'week',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$_temp0';
  }

  @override
  String repeatUnitYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'years',
      one: 'year',
    );
    return '$_temp0';
  }

  @override
  String get repeatEnds => 'Ends';

  @override
  String get repeatEndsNever => 'Never';

  @override
  String get repeatEndsOn => 'On';

  @override
  String get repeatEndDate => 'End date';

  @override
  String repeatIntervalError(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '1 to $maxString';
  }

  @override
  String get repeatEndMissing => 'Pick an end date';

  @override
  String repeatEndBeforeStart(String date) {
    return 'Ends before the first payment ($date)';
  }

  @override
  String repeatEndTooLate(String date) {
    return 'Pick a date up to $date';
  }

  @override
  String repeatTooManyPast(int count, int max) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'That\'s $countString earlier payments; at most $maxString. Pick a later date or a longer interval.';
  }

  @override
  String repeatAlsoAdds(int count, String dates) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Also adds $countString earlier payments: $dates',
      one: 'Also adds 1 earlier payment: $dates',
    );
    return '$_temp0';
  }

  @override
  String repeatAndMore(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $countString more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get repeatThisPaymentOnly => 'Changes here are for this payment only.';

  @override
  String repeatLinkSemantics(String title, String schedule) {
    return 'Recurring item $title, $schedule. Opens its page.';
  }

  @override
  String get repeatsMark => 'Repeats';

  @override
  String savedRepeats(String schedule) {
    return 'Saved. Repeats: $schedule';
  }

  @override
  String savedWithEarlier(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved with $countString earlier payments.',
      one: 'Saved with 1 earlier payment.',
    );
    return '$_temp0';
  }

  @override
  String addedRecurring(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $countString recurring expenses',
      one: 'Added 1 recurring expense',
    );
    return '$_temp0';
  }

  @override
  String heldOne(String title, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString payments',
      one: '1 payment',
    );
    return '$title has $_temp0 waiting';
  }

  @override
  String heldMany(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString recurring items have payments waiting',
    );
    return '$_temp0';
  }

  @override
  String get review => 'Review';

  @override
  String usedByTemplatesOnly(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString recurring items',
      one: '1 recurring item',
    );
    return '\"$name\" is used by $_temp0.';
  }

  @override
  String alsoUsedByTemplates(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'It is also used by $countString recurring items: their later payments use the one you pick.',
      one: 'It is also used by 1 recurring item: its later payments use the one you pick.',
    );
    return '$_temp0';
  }

  @override
  String templatesMoveToo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Their later payments use the one you pick.',
      one: 'Its later payments use the one you pick.',
    );
    return '$_temp0';
  }

  @override
  String eventDeleteTemplates(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'It will be removed from $countString recurring items: their later payments come without it.',
      one: 'It will be removed from 1 recurring item: its later payments come without it.',
    );
    return '$_temp0';
  }

  @override
  String get recurringTitle => 'Recurring';

  @override
  String recurringRunning(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString running',
      one: '1 running',
      zero: 'None running',
    );
    return '$_temp0';
  }

  @override
  String get recurringEmpty =>
      'Nothing repeats yet. Turn on Repeats when you add an expense.';

  @override
  String get recurringWaiting => 'Waiting';

  @override
  String get recurringActive => 'Active';

  @override
  String recurringPaymentsWaiting(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString payments waiting',
      one: '1 payment waiting',
    );
    return '$_temp0';
  }

  @override
  String recurringRowNext(String schedule, String date) {
    return '$schedule · next $date';
  }

  @override
  String recurringRowEnds(String date) {
    return 'No more payments · ends $date';
  }

  @override
  String get recurringBroken =>
      'This recurring item can\'t be read, so it adds no payments.';

  @override
  String get recurringPrice => 'Price';

  @override
  String get recurringScheduled => 'scheduled';

  @override
  String priceFromDate(String date) {
    return 'from $date';
  }

  @override
  String get removeScheduledPrice => 'Remove scheduled price';

  @override
  String recurringPayments(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Payments ($countString)';
  }

  @override
  String get recurringNoPayments =>
      'No payments (deleted ones aren\'t listed).';

  @override
  String get showAll => 'Show all';

  @override
  String get changePrice => 'Change price';

  @override
  String get newPrice => 'New price';

  @override
  String get priceFrom => 'From';

  @override
  String get priceKeepsPast => 'Payments already added keep their price.';

  @override
  String priceReplaces(String amount, String date) {
    return 'Replaces $amount from $date';
  }

  @override
  String get priceInForce => 'A price from that date is already in force';

  @override
  String priceBeforeStart(String date) {
    return 'Pick $date or later';
  }

  @override
  String get priceChanged => 'Price changed';

  @override
  String get stop => 'Stop';

  @override
  String recurringStopped(String title) {
    return '$title stopped and archived.';
  }

  @override
  String get undoStopRefused =>
      'Couldn\'t undo: it was restored, deleted or switched for another item since.';

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archivedBadge => 'Archived';

  @override
  String restoreRecurringTitle(String title) {
    return 'Restore $title?';
  }

  @override
  String restoreRecurringText(String date) {
    return 'It adds payments again from $date.';
  }

  @override
  String get restoreRecurringNoMore => 'It has no payment left before its end.';

  @override
  String restoreEndPassed(String date) {
    return 'Its end, $date, has passed: it restores with no end. Edit it to set one.';
  }

  @override
  String recurringRestored(String title, String date) {
    return '$title restored. Next: $date';
  }

  @override
  String recurringRestoredNoNext(String title) {
    return '$title restored.';
  }

  @override
  String get deleteForGood => 'Delete for good';

  @override
  String deleteForGoodTitle(String title) {
    return 'Delete $title for good?';
  }

  @override
  String deleteForGoodText(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Its $countString payments stay, without the repeat mark. This can\'t be undone.',
      one: 'Its payment stays, without the repeat mark. This can\'t be undone.',
      zero: 'It has no payments. This can\'t be undone.',
    );
    return '$_temp0';
  }

  @override
  String recurringDeleted(String title, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$title deleted. Its $countString payments stay.',
      one: '$title deleted. Its payment stays.',
      zero: '$title deleted.',
    );
    return '$_temp0';
  }

  @override
  String get recurringGone => 'This recurring item no longer exists.';

  @override
  String get editRecurring => 'Edit recurring item';

  @override
  String get recurringChangesApplyLater =>
      'Changes apply to payments added from now on.';

  @override
  String recurringEndNotBefore(String date) {
    return 'Pick $date or later: a payment until then is already added';
  }

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Discard';

  @override
  String recurringHoldText(int count, String range) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString payments are due, $range.',
      one: '1 payment is due, $range.',
    );
    return '$_temp0';
  }

  @override
  String recurringHoldMany(int max, String range) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'More than $maxString payments are due, $range.';
  }

  @override
  String addAllN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add all $countString',
      one: 'Add it',
    );
    return '$_temp0';
  }

  @override
  String addFirstN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Add the first $countString';
  }

  @override
  String get skipThem => 'Skip them';

  @override
  String addedPayments(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $countString payments',
      one: 'Added 1 payment',
      zero: 'No payment added',
    );
    return '$_temp0';
  }

  @override
  String skippedPayments(int count, String date) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skipped $countString. Next: $date',
      one: 'Skipped 1. Next: $date',
    );
    return '$_temp0';
  }

  @override
  String skippedPaymentsNoNext(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skipped $countString. No more payments.',
      one: 'Skipped 1. No more payments.',
    );
    return '$_temp0';
  }

  @override
  String get recurringGenerateFailed =>
      'Couldn\'t add its payments. They will be tried again.';

  @override
  String binPaymentOf(String title, String schedule) {
    return 'Payment of $title ($schedule)';
  }

  @override
  String restoreRecurringCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString recurring items',
      one: '1 recurring item',
    );
    return '$_temp0';
  }

  @override
  String get changesSaved => 'Changes saved';

  @override
  String get newRecurring => 'New recurring expense';

  @override
  String get recurringNoneWaiting => 'Nothing is waiting for a decision.';

  @override
  String get recurringNoneActive =>
      'Nothing is running. Turn on Repeats when you add an expense.';

  @override
  String get recurringNoneArchived =>
      'Nothing is archived. Stopped and ended items go here.';

  @override
  String get repeatEndsAfter => 'After';

  @override
  String repeatEndsAfterUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'payments',
      one: 'payment',
    );
    return '$_temp0';
  }

  @override
  String get repeatCountLabel => 'Number of payments';

  @override
  String repeatCountError(int min, int max) {
    final intl.NumberFormat minNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String minString = minNumberFormat.format(min);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$minString to $maxString';
  }

  @override
  String repeatLast(String date) {
    return 'last $date';
  }

  @override
  String repeatCountTooLate(String date) {
    return 'The last payment would be after $date. Use fewer payments.';
  }

  @override
  String updatedRepeats(String schedule) {
    return 'Updated. Repeats: $schedule';
  }

  @override
  String updatedWithEarlier(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated with $countString earlier payments.',
      one: 'Updated with 1 earlier payment.',
    );
    return '$_temp0';
  }

  @override
  String get howOften => 'How often';

  @override
  String get firstPayment => 'First payment';

  @override
  String get newItemNotice =>
      'Saving makes a new recurring item; this one is archived.';

  @override
  String get scheduleLockedNotice =>
      'Payments are waiting. Add or skip them on the item\'s page before changing how often.';

  @override
  String firstPaymentTooEarly(String date) {
    return 'Pick $date or later';
  }

  @override
  String get newItemTitle => 'Make a new recurring item?';

  @override
  String newItemText(int count, String name, String date) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Changing how often creates a new item, $name, from $date. This one is archived: it adds nothing more, and you can restore or delete it from the Archive. Its $countString payments stay.',
      one:
          'Changing how often creates a new item, $name, from $date. This one is archived: it adds nothing more, and you can restore or delete it from the Archive. Its payment stays.',
      zero:
          'Changing how often creates a new item, $name, from $date. This one is archived: it adds nothing more, and you can restore or delete it from the Archive.',
    );
    return '$_temp0';
  }

  @override
  String get createNew => 'Create new';

  @override
  String recurringArchivedShort(String title) {
    return '$title archived';
  }

  @override
  String archivedReplaced(String date) {
    return 'replaced $date';
  }

  @override
  String swapTitle(String name) {
    return 'Switch back to $name?';
  }

  @override
  String swapText(int count, String name) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$name is archived: it adds nothing more. Its $countString payments already added stay. Delete the ones you don\'t want from the list.',
      one:
          '$name is archived: it adds nothing more. Its 1 payment already added stays. Delete it from the list if you don\'t want it.',
      zero: '$name is archived: it adds nothing more. It added no payments.',
    );
    return '$_temp0';
  }

  @override
  String get switchBack => 'Switch back';

  @override
  String switchedBack(String name) {
    return 'Switched back to $name';
  }

  @override
  String get addSelected => 'Add selected';

  @override
  String get whichPaymentsToAdd => 'Which payments to add?';

  @override
  String get selectNone => 'None';

  @override
  String addN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $countString',
      one: 'Add 1',
    );
    return '$_temp0';
  }

  @override
  String skipAllN(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skip all $countString',
      one: 'Skip it',
    );
    return '$_temp0';
  }

  @override
  String addedAndSkipped(int added, int skipped, String date) {
    final intl.NumberFormat addedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String addedString = addedNumberFormat.format(added);
    final intl.NumberFormat skippedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String skippedString = skippedNumberFormat.format(skipped);

    return '$addedString added, $skippedString skipped. Next: $date';
  }

  @override
  String addedAndSkippedNoNext(int added, int skipped) {
    final intl.NumberFormat addedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String addedString = addedNumberFormat.format(added);
    final intl.NumberFormat skippedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String skippedString = skippedNumberFormat.format(skipped);

    return '$addedString added, $skippedString skipped. No more payments.';
  }

  @override
  String addedAndSkippedMore(int added, int skipped) {
    final intl.NumberFormat addedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String addedString = addedNumberFormat.format(added);
    final intl.NumberFormat skippedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String skippedString = skippedNumberFormat.format(skipped);

    return '$addedString added, $skippedString skipped. More are waiting.';
  }

  @override
  String get upcomingTitle => 'Upcoming payments';

  @override
  String get upcomingTooltip => 'Upcoming payments';

  @override
  String get upcomingEmpty =>
      'Nothing coming up. Recurring items you add show here.';

  @override
  String get upcomingEnd => 'Shows the next 12 months.';

  @override
  String get skip => 'Skip';

  @override
  String skipDialogTitle(String title, String date) {
    return 'Skip $title on $date?';
  }

  @override
  String get skipOnlyThis => 'Skip only this payment';

  @override
  String stopItem(String title) {
    return 'Stop $title: no more payments';
  }

  @override
  String get skipped => 'Skipped';

  @override
  String skippedOn(String title, String date) {
    return 'Skipped $title on $date';
  }

  @override
  String get bringBack => 'Bring back';

  @override
  String paymentBack(String title, String date) {
    return '$title on $date is back';
  }

  @override
  String upcomingRowSemantics(String title, String amount, String date) {
    return '$title, $amount, $date';
  }

  @override
  String get onlyRecurring => 'Only recurring';

  @override
  String get filterChipRecurring => '🔁 Recurring';

  @override
  String get noUpcomingMatchTooltip => 'No upcoming payments match the filters';

  @override
  String get noUpcomingMatchFilters =>
      'No upcoming payments match the filters on Home.';

  @override
  String get navReports => 'Reports';

  @override
  String get reportPeriodRange => 'Range';

  @override
  String get reportBackToCurrent => 'Back to the current period';

  @override
  String reportRangeDates(String from, String to) {
    return '$from – $to';
  }

  @override
  String reportAllTimeSpan(String from, String to) {
    return 'All time · $from – $to';
  }

  @override
  String get reportChangeRange => 'Change the range';

  @override
  String get reportRangeTitle => 'Report range';

  @override
  String get reportFrom => 'From';

  @override
  String get reportTo => 'To';

  @override
  String get reportAllTime => 'All time';

  @override
  String get reportShow => 'Show';

  @override
  String get reportGroupBy => 'Group by';

  @override
  String get reportGroupCategory => 'Category';

  @override
  String get reportGroupEvent => 'Event';

  @override
  String get reportGroupPaymentMethod => 'Payment method';

  @override
  String get reportNoEvent => 'No event';

  @override
  String get reportFilterPaymentMethods => 'Payment methods';

  @override
  String get searchPaymentMethods => 'Search payment methods…';

  @override
  String get allPaymentMethods => 'All payment methods';

  @override
  String reportExpenseCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString expenses',
      one: '1 expense',
    );
    return '$_temp0';
  }

  @override
  String reportOtherGroups(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Other ($countString)',
    );
    return '$_temp0';
  }

  @override
  String reportSharePercent(String share) {
    return '$share %';
  }

  @override
  String reportShareTiny(String share) {
    return '< $share %';
  }

  @override
  String reportSliceSemantics(String name, String amount, String share) {
    return '$name, $amount, $share';
  }

  @override
  String reportSliceDetail(String name, String amount, String share) {
    return '$name · $amount · $share';
  }

  @override
  String get reportFaceBars => 'Bars';

  @override
  String get reportFaceDonut => 'Donut';

  @override
  String get nextChart => 'Next chart';

  @override
  String get previousChart => 'Previous chart';

  @override
  String reportCardSemantics(String range, String chart, String amount) {
    return '$range, $chart, total $amount';
  }

  @override
  String reportCardSemanticsFiltered(
    String range,
    String chart,
    String amount,
  ) {
    return '$range, filtered, $chart, total $amount';
  }

  @override
  String reportEmpty(String range) {
    return 'No expenses in $range.';
  }

  @override
  String reportEmptyFiltered(String range) {
    return 'Nothing in $range matches the filter.';
  }

  @override
  String get reportNoExpensesYet => 'No expenses yet.';

  @override
  String get reportLoadFailed => 'Couldn\'t load the report.';

  @override
  String reportFilterChanged(String name) {
    return 'Filter changed: $name was deleted.';
  }

  @override
  String reportFilterChangedMany(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Filter changed: $countString chosen items were deleted.',
      one: 'Filter changed: a chosen item was deleted.',
    );
    return '$_temp0';
  }

  @override
  String get reportFormat => 'Format';

  @override
  String get reportFormatPdf => 'PDF';

  @override
  String get reportFormatExcel => 'Excel (.xlsx)';

  @override
  String get reportShare => 'Share';

  @override
  String get reportSaveAs => 'Save as…';

  @override
  String get reportSave => 'Save';

  @override
  String get reportMakingPdf => 'Making the PDF…';

  @override
  String reportMakingPdfPage(int page, int pages) {
    final intl.NumberFormat pageNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String pageString = pageNumberFormat.format(page);
    final intl.NumberFormat pagesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String pagesString = pagesNumberFormat.format(pages);

    return 'Making the PDF… page $pageString of $pagesString';
  }

  @override
  String get reportMakingExcel => 'Making the Excel file…';

  @override
  String get reportSaved => 'Report saved';

  @override
  String get reportPdfFailed => 'Couldn\'t make the PDF. Try again.';

  @override
  String get reportExcelFailed => 'Couldn\'t make the Excel file. Try again.';

  @override
  String get reportTooManyRows =>
      'Too many expenses for one sheet. Pick a shorter range.';

  @override
  String get reportSaveFailed => 'Couldn\'t save the file. Try again.';

  @override
  String get reportNoShareTarget =>
      'No app on this phone can receive the file.';

  @override
  String get reportNothingToExport => 'Nothing to export';

  @override
  String get reportDocTitle => 'Expense report';

  @override
  String reportDocMadeOn(String date) {
    return 'Made on $date';
  }

  @override
  String reportDocFilter(String parts) {
    return 'Filter: $parts';
  }

  @override
  String reportDocSearch(String text) {
    return 'Search: $text';
  }

  @override
  String reportDocCategories(String names) {
    return 'Categories: $names';
  }

  @override
  String reportDocEvents(String names) {
    return 'Events: $names';
  }

  @override
  String reportDocPaidWith(String names) {
    return 'Paid with: $names';
  }

  @override
  String get reportDocNoFilter => 'No filter';

  @override
  String reportDocGrouping(String grouping) {
    return 'Grouped by $grouping';
  }

  @override
  String get reportDocTotal => 'Total';

  @override
  String reportDocAlsoIn(String names) {
    return 'also in $names';
  }

  @override
  String reportDocPageOf(String page, String pages) {
    return 'Page $page of $pages';
  }

  @override
  String get reportColDate => 'Date';

  @override
  String get reportColTime => 'Time';

  @override
  String get reportColTitle => 'Title';

  @override
  String get reportColCategory => 'Category';

  @override
  String get reportColEvents => 'Events';

  @override
  String get reportColPaymentMethod => 'Payment method';

  @override
  String get reportColCurrency => 'Currency';

  @override
  String get reportColAmount => 'Amount';

  @override
  String get reportColSubtotal => 'Subtotal';

  @override
  String get reportColCount => 'Count';

  @override
  String get reportColShare => 'Share';

  @override
  String get reportColRecurring => 'Recurring';

  @override
  String get reportGenerate => 'Generate report';

  @override
  String get reportGenerateTitle => 'Generate a report';

  @override
  String get reportChart => 'Chart';

  @override
  String get reportChartPie => 'Pie';

  @override
  String get reportGroupOthers => 'Group small items as Others';

  @override
  String get reportGroupOthersHint =>
      'Off: every item has its own bar or slice and legend line';

  @override
  String get reportOtherTitle => 'In Other';

  @override
  String get reportOverall => 'Overall';

  @override
  String get reportSectionsOverlap =>
      'An expense in two events is in both sections: section totals can add up to more than the overall total, which counts it once.';

  @override
  String get reportColNote => 'Note';

  @override
  String get reportSavedNoViewer =>
      'Saved to Download/Expense Tracker. No app on this phone can open it.';

  @override
  String get reportHighlights => 'Highlights';

  @override
  String get reportHiExpenses => 'Expenses';

  @override
  String get reportHiPerDay => 'Per day';

  @override
  String reportHiOverDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'over $countString days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get reportHiLargest => 'Largest expense';

  @override
  String get reportHiTopMethod => 'Most paid with';

  @override
  String get reportHiTopEvent => 'Top event';
}
