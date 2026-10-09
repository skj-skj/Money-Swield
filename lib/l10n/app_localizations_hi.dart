// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Expense Tracker';

  @override
  String get save => 'सहेजें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएँ';

  @override
  String get next => 'आगे';

  @override
  String get back => 'पीछे';

  @override
  String get getStarted => 'शुरू करें';

  @override
  String get continueButton => 'जारी रखें';

  @override
  String get tryAgain => 'फिर से कोशिश करें';

  @override
  String get copyErrorReport => 'त्रुटि रिपोर्ट कॉपी करें';

  @override
  String get reportCopied => 'रिपोर्ट कॉपी हो गई';

  @override
  String get saveFailed => 'सहेजा नहीं जा सका। कृपया फिर से कोशिश करें।';

  @override
  String get loadFailed => 'यह सूची लोड नहीं हो सकी।';

  @override
  String get migrationChecking => 'आपका डेटा जाँचा जा रहा है…';

  @override
  String get migrationBackingUp => 'आपके डेटा का बैकअप लिया जा रहा है…';

  @override
  String migrationUpdating(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'आपका डेटा अपडेट हो रहा है ($totalString में से $currentString)';
  }

  @override
  String get migrationVerifying => 'आपका डेटा सत्यापित हो रहा है…';

  @override
  String get migrationDone => 'हो गया';

  @override
  String get migrationKeepOpen => 'कृपया ऐप खुला रखें।';

  @override
  String get migrationQuestionTitle => 'एक छोटा-सा सवाल';

  @override
  String get migrationFailedTitle => 'आपका डेटा अपडेट नहीं हो सका';

  @override
  String get migrationFailedMessage =>
      'असफल चरण से आपका डेटा नहीं बदला। कृपया नीचे दी गई रिपोर्ट कॉपी करके हमें भेजें, ताकि हम अगले अपडेट में इसे ठीक कर सकें।';

  @override
  String migrationFailedStep(String migration) {
    return 'असफल माइग्रेशन: $migration';
  }

  @override
  String get startupFailedTitle => 'आपका डेटा खोला नहीं जा सका';

  @override
  String get startupFailedMessage =>
      'कुछ भी नहीं बदला गया। कृपया नीचे दी गई रिपोर्ट कॉपी करके हमें भेजें, ताकि हम अगले अपडेट में इसे ठीक कर सकें।';

  @override
  String onboardingStep(int current, int total) {
    final intl.NumberFormat currentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'चरण $currentString / $totalString';
  }

  @override
  String get onboardingLanguageTitle => 'अपनी भाषा चुनें';

  @override
  String get onboardingCurrencyTitle => 'आपकी मुद्रा';

  @override
  String get onboardingCurrencySubtitle =>
      'नए खर्च इसी मुद्रा में दर्ज होंगे। आप इसे कभी भी सेटिंग में बदल सकते हैं।';

  @override
  String get onboardingPaymentMethodTitle =>
      'आप आमतौर पर कैसे भुगतान करते हैं?';

  @override
  String get onboardingPaymentMethodSubtitle =>
      'नए खर्च इसी भुगतान तरीके से दर्ज होंगे। आप इसे कभी भी सेटिंग में बदल सकते हैं।';

  @override
  String get languageSystem => 'सिस्टम डिफ़ॉल्ट';

  @override
  String languageSystemDetected(String language) {
    return 'सिस्टम डिफ़ॉल्ट (पहचानी गई: $language)';
  }

  @override
  String get searchCurrencies => 'कोड या नाम से खोजें';

  @override
  String noCurrencyFound(String query) {
    return '\"$query\" से कोई मुद्रा मेल नहीं खाती';
  }

  @override
  String get navHome => 'होम';

  @override
  String get navManage => 'प्रबंधन';

  @override
  String get navSettings => 'सेटिंग';

  @override
  String get homeEmptyTitle => 'अभी तक कोई खर्च नहीं';

  @override
  String get homeEmptyMessage =>
      'पहला खर्च दर्ज करने के लिए खर्च जोड़ें दबाएँ।';

  @override
  String get categoriesTitle => 'श्रेणियाँ';

  @override
  String get eventsTitle => 'इवेंट';

  @override
  String get paymentMethodsTitle => 'भुगतान के तरीके';

  @override
  String get addCategory => 'श्रेणी जोड़ें';

  @override
  String get addEvent => 'इवेंट जोड़ें';

  @override
  String get addPaymentMethod => 'भुगतान का तरीका जोड़ें';

  @override
  String get editCategory => 'श्रेणी बदलें';

  @override
  String get editEvent => 'इवेंट बदलें';

  @override
  String get editPaymentMethod => 'भुगतान का तरीका बदलें';

  @override
  String get listEmpty => 'अभी यहाँ कुछ नहीं है। जोड़ने के लिए + दबाएँ।';

  @override
  String archivedSection(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'संग्रहीत ($countString)';
  }

  @override
  String get defaultBadge => 'डिफ़ॉल्ट';

  @override
  String get fieldEmoji => 'इमोजी';

  @override
  String get fieldName => 'नाम';

  @override
  String get fieldDescription => 'विवरण (वैकल्पिक)';

  @override
  String get errorNameRequired => 'नाम लिखें';

  @override
  String errorTooLong(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'अधिकतम $maxString अक्षर लिखें';
  }

  @override
  String errorNameDuplicate(String name) {
    return '\"$name\" पहले से मौजूद है';
  }

  @override
  String get errorEmojiRequired => 'एक इमोजी चुनें';

  @override
  String get errorEmojiNotSingle => 'ठीक एक इमोजी लिखें';

  @override
  String get resetToDefaultName => 'डिफ़ॉल्ट नाम वापस लाएँ';

  @override
  String deleteConfirmTitle(String name) {
    return '\"$name\" हटाएँ?';
  }

  @override
  String get deleteConfirmMessage => 'इसे वापस नहीं लाया जा सकता।';

  @override
  String get archive => 'संग्रहित करें';

  @override
  String get unarchive => 'संग्रह से निकालें';

  @override
  String get setAsDefault => 'डिफ़ॉल्ट बनाएँ';

  @override
  String get cannotDeleteDefaultHint =>
      'पहले किसी दूसरे तरीके को डिफ़ॉल्ट बनाएँ';

  @override
  String get pickEmojiTitle => 'एक इमोजी चुनें';

  @override
  String get typeAnyEmoji => 'कोई भी इमोजी लिखें';

  @override
  String get useEmoji => 'चुनें';

  @override
  String get settingsTitle => 'सेटिंग';

  @override
  String get settingLanguage => 'भाषा';

  @override
  String get settingTheme => 'थीम';

  @override
  String get settingDefaultCurrency => 'डिफ़ॉल्ट मुद्रा';

  @override
  String get settingDefaultPaymentMethod => 'डिफ़ॉल्ट भुगतान तरीका';

  @override
  String get themeSystem => 'सिस्टम';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeDark => 'डार्क';

  @override
  String get ok => 'ठीक है';

  @override
  String get addExpense => 'खर्च जोड़ें';

  @override
  String get editExpense => 'खर्च बदलें';

  @override
  String get fieldTitle => 'शीर्षक';

  @override
  String get fieldAmount => 'राशि';

  @override
  String get fieldCategory => 'श्रेणी';

  @override
  String get fieldEvents => 'इवेंट';

  @override
  String get fieldPaymentMethod => 'भुगतान का तरीका';

  @override
  String get fieldCurrency => 'मुद्रा';

  @override
  String get fieldDate => 'तारीख';

  @override
  String get fieldTime => 'समय';

  @override
  String get fieldNotes => 'विवरण';

  @override
  String get fieldDeletedAt => 'हटाने की तारीख';

  @override
  String get amountErrorEmpty => 'राशि दर्ज करें';

  @override
  String get amountErrorInvalid => '110.50 या 50 + 60 जैसी राशि दर्ज करें';

  @override
  String amountErrorTooLarge(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'दशमलव से पहले ज़्यादा से ज़्यादा $maxString अंक लिखें';
  }

  @override
  String amountErrorTooManyDecimals(int digits, String currency) {
    final intl.NumberFormat digitsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String digitsString = digitsNumberFormat.format(digits);

    String _temp0 = intl.Intl.pluralLogic(
      digits,
      locale: localeName,
      other: '$currency में सिर्फ़ $digitsString दशमलव अंक होते हैं',
      one: '$currency में सिर्फ़ 1 दशमलव अंक होता है',
      zero: '$currency में दशमलव नहीं होते',
    );
    return '$_temp0';
  }

  @override
  String get amountErrorNotPositive => 'शून्य से ज़्यादा राशि दर्ज करें';

  @override
  String amountPreview(String amount) {
    return '= $amount';
  }

  @override
  String get titleRequired => 'शीर्षक दर्ज करें';

  @override
  String get categoryRequired => 'एक श्रेणी चुनें';

  @override
  String get expenseGone => 'यह खर्च अब मौजूद नहीं है';

  @override
  String get clear => 'साफ़ करें';

  @override
  String get update => 'अपडेट करें';

  @override
  String get done => 'हो गया';

  @override
  String get cleared => 'फ़ॉर्म साफ़ किया गया';

  @override
  String get draftDiscarded => 'ड्राफ़्ट हटाया गया';

  @override
  String get discardDraft => 'ड्राफ़्ट हटाएँ';

  @override
  String draftRestoredAdd(String age) {
    return 'बिना सहेजा खर्च वापस लाया गया ($age)';
  }

  @override
  String draftRestoredEdit(String age) {
    return 'बिना सहेजे बदलाव वापस लाए गए ($age)';
  }

  @override
  String get draftSaved => 'ड्राफ़्ट सहेजा गया';

  @override
  String get draftKeptExpenseGone =>
      'खर्च हटा दिया गया था; आपके बदलाव रखे गए हैं। उन्हें नए खर्च के रूप में जोड़ने के लिए + दबाएँ';

  @override
  String get unsavedChanges => 'बिना सहेजे बदलाव';

  @override
  String get itemize => 'ब्योरा जोड़ें';

  @override
  String get itemizeTitle => 'चीज़ों का ब्योरा दें';

  @override
  String get amountErrorDivideByZero => 'शून्य से भाग नहीं दिया जा सकता';

  @override
  String amountApprox(String amount) {
    return '≈ $amount';
  }

  @override
  String get keyPlus => 'जोड़';

  @override
  String get keyMinus => 'घटा';

  @override
  String get keyTimes => 'गुणा';

  @override
  String get keyDivide => 'भाग';

  @override
  String get keyDecimal => 'दशमलव';

  @override
  String get amountChipsLabel => 'आम राशियाँ';

  @override
  String get titleSuggestionsLabel => 'पिछले शीर्षक';

  @override
  String get search => 'खोजें';

  @override
  String get closeSearch => 'खोज बंद करें';

  @override
  String get searchCategories => 'श्रेणियाँ खोजें…';

  @override
  String get searchEvents => 'इवेंट खोजें…';

  @override
  String get newCategory => 'नई श्रेणी';

  @override
  String get newEvent => 'नया इवेंट';

  @override
  String get moreResults => 'और नतीजे';

  @override
  String get allCategories => 'सभी श्रेणियाँ';

  @override
  String get allEvents => 'सभी इवेंट';

  @override
  String get noMoreMatches => 'और कोई मेल नहीं मिला';

  @override
  String get noCategoriesYet => 'अभी कोई श्रेणी नहीं है';

  @override
  String get today => 'आज';

  @override
  String get yesterday => 'कल';

  @override
  String get movedToBin => 'रीसायकल बिन में भेजा गया';

  @override
  String get undo => 'वापस लें';

  @override
  String get loadMoreFailed => 'और खर्च लोड नहीं हो सके।';

  @override
  String get bin => 'रीसायकल बिन';

  @override
  String get binSubtitle => 'हटाए गए खर्च 30 दिन तक रखे जाते हैं';

  @override
  String get binEmpty => 'हटाए गए खर्च 30 दिन तक यहाँ रहते हैं।';

  @override
  String get deletedToday => 'आज हटाया गया';

  @override
  String get deletedYesterday => 'कल हटाया गया';

  @override
  String deletedDaysAgo(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString दिन पहले हटाया गया',
      one: '1 दिन पहले हटाया गया',
    );
    return '$_temp0';
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
      other: '$daysString दिन में मिट जाएगा',
      one: '1 दिन में मिट जाएगा',
    );
    return '$_temp0';
  }

  @override
  String get removedOnNextStart => 'अगली बार ऐप खुलने पर मिट जाएगा';

  @override
  String get restore => 'वापस लाएँ';

  @override
  String get restoreAll => 'सब वापस लाएँ';

  @override
  String get deletePermanently => 'हमेशा के लिए हटाएँ';

  @override
  String deletePermanentlyTitle(String title) {
    return '\"$title\" को हमेशा के लिए हटाएँ?';
  }

  @override
  String get emptyBin => 'बिन खाली करें';

  @override
  String get emptyBinTitle => 'रीसायकल बिन खाली करें?';

  @override
  String get cannotBeUndone => 'इसे वापस नहीं लाया जा सकता।';

  @override
  String usedByExpenses(String name, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString खर्चों में',
      one: '1 खर्च में',
    );
    return '\"$name\" $_temp0 इस्तेमाल हुआ है।';
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
      other: '$countString खर्चों में',
      one: '1 खर्च में',
    );
    return '\"$name\" $_temp0 इस्तेमाल हुआ है ($binnedString रीसायकल बिन में)।';
  }

  @override
  String get moveExpensesTo => 'इन्हें यहाँ ले जाएँ:';

  @override
  String get moveAndDelete => 'ले जाएँ और हटाएँ';

  @override
  String get addAnotherFirst =>
      'पहले कोई दूसरा जोड़ें, ताकि इसके खर्च उसमें जा सकें।';

  @override
  String eventDeleteWithCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString खर्चों',
      one: '1 खर्च',
    );
    return 'इसे $_temp0 से हटा दिया जाएगा। खर्च बने रहेंगे।';
  }

  @override
  String get recentCurrencies => 'हाल में इस्तेमाल';

  @override
  String get allCurrencies => 'सभी मुद्राएँ';

  @override
  String get noneEvent => 'कोई नहीं';

  @override
  String get settingTileShape => 'टाइल का आकार';

  @override
  String get settingButtonShape => 'बटन का आकार';

  @override
  String get shapeSquare => 'चौकोर';

  @override
  String get shapeRounded => 'गोल कोनों वाला चौकोर';

  @override
  String get shapeCircle => 'गोल';

  @override
  String get settingCustomizeTiles => 'टाइल बदलें';

  @override
  String get settingCustomizeTilesSubtitle =>
      'श्रेणी और इवेंट चुनने वाले हिस्सों के आकार';

  @override
  String get preview => 'झलक';

  @override
  String get settingThemeColor => 'थीम का रंग';

  @override
  String get themeColorWallpaper => 'वॉलपेपर के रंग';

  @override
  String get colorPurple => 'बैंगनी';

  @override
  String get colorBlue => 'नीला';

  @override
  String get colorTeal => 'हरा-नीला';

  @override
  String get colorGreen => 'हरा';

  @override
  String get colorAmber => 'पीला';

  @override
  String get colorOrange => 'नारंगी';

  @override
  String get colorRed => 'लाल';

  @override
  String get colorPink => 'गुलाबी';

  @override
  String get restoreDefaultLook => 'डिफ़ॉल्ट रूप वापस लाएँ';

  @override
  String get restoreDefaultLookSubtitle => 'थीम का रंग और टाइल के आकार';

  @override
  String get restoreDefaultLookTitle => 'डिफ़ॉल्ट रूप वापस लाएँ?';

  @override
  String get restoreDefaultLookMessage =>
      'थीम का रंग वॉलपेपर के रंगों पर, टाइलें गोल कोनों वाले चौकोर पर और बटन गोल आकार पर लौट आएँगे।';

  @override
  String get migrationInstalledTitle => 'डेटाबेस तैयार है';

  @override
  String get migrationInstalledMessage => 'सब कुछ तैयार है।';

  @override
  String get migrationUpdatedTitle => 'अपडेट सफलतापूर्वक हो गया';

  @override
  String get migrationUpdatedMessage => 'आपका डेटा अप-टू-डेट है।';

  @override
  String get backupAndRestore => 'बैकअप और रीस्टोर';

  @override
  String get lastBackupNever => 'कभी बैकअप नहीं लिया गया';

  @override
  String get lastBackupToday => 'आज';

  @override
  String get lastBackupYesterday => 'कल';

  @override
  String lastBackupDaysAgo(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString दिन पहले',
      one: '1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String lastBackupSubtitle(String when) {
    return 'पिछला बैकअप: $when';
  }

  @override
  String get backUpNow => 'अभी बैकअप लें';

  @override
  String get preparingBackup => 'बैकअप तैयार हो रहा है…';

  @override
  String get backupSaved => 'बैकअप सेव हो गया';

  @override
  String get backupFailedTitle => 'बैकअप नहीं हो सका';

  @override
  String get backupFailedMessage =>
      'कुछ भी सेव नहीं हुआ, और इस फ़ोन का आपका डेटा नहीं बदला। कृपया नीचे दी गई रिपोर्ट कॉपी करके हमें भेजें ताकि हम इसे ठीक कर सकें।';

  @override
  String get restoreFromBackup => 'बैकअप से रीस्टोर करें';

  @override
  String get restoreFromBackupSubtitle =>
      'इस फ़ोन का सारा डेटा बैकअप फ़ाइल के डेटा से बदल देता है।';

  @override
  String get undoLastRestore => 'पिछला रीस्टोर वापस लें';

  @override
  String undoLastRestoreSubtitle(String date) {
    return '$date के रीस्टोर से पहले वाले अपने डेटा पर वापस जाएँ।';
  }

  @override
  String get restoreConfirmTitle => 'यह बैकअप रीस्टोर करें?';

  @override
  String get undoConfirmTitle => 'पिछला रीस्टोर वापस लें?';

  @override
  String restoreBackupFrom(String date) {
    return '$date का बैकअप';
  }

  @override
  String restoreCopyFrom(String date) {
    return '$date के रीस्टोर से पहले का आपका डेटा';
  }

  @override
  String restoreExpenseCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString खर्च',
      one: '1 खर्च',
      zero: 'कोई खर्च नहीं',
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
      other: 'और $countString बिन में',
      one: 'और 1 बिन में',
    );
    return '$_temp0';
  }

  @override
  String restoreLatestOn(String date) {
    return 'सबसे नया $date का';
  }

  @override
  String restoreReplacesData(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString खर्च',
      one: '1 खर्च',
      zero: 'कोई खर्च नहीं',
    );
    return 'इस फ़ोन का सारा डेटा ($_temp0) बदल दिया जाएगा।';
  }

  @override
  String get restoreKeepsCopy =>
      'एक कॉपी रखी जाती है, और आप रीस्टोर वापस ले सकते हैं।';

  @override
  String get restoreBackupButton => 'रीस्टोर करें';

  @override
  String get checkingBackup => 'बैकअप जाँचा जा रहा है…';

  @override
  String get restoringData => 'आपका डेटा रीस्टोर हो रहा है…';

  @override
  String get backupRestored => 'बैकअप रीस्टोर हो गया';

  @override
  String get backupRestoredDefaultSettings =>
      'बैकअप रीस्टोर हो गया। इसकी सेटिंग नहीं मिली या पढ़ी नहीं जा सकी, इसलिए डिफ़ॉल्ट सेटिंग लागू की गई हैं। आप इन्हें सेटिंग में बदल सकते हैं।';

  @override
  String get restoreFailedTitle => 'रीस्टोर नहीं हो सका';

  @override
  String get restoreFailedMessage =>
      'इस फ़ोन का आपका डेटा नहीं बदला। कृपया नीचे दी गई रिपोर्ट कॉपी करके हमें भेजें ताकि हम इसे ठीक कर सकें।';

  @override
  String get restoreFailedRestartMessage =>
      'इस फ़ोन का आपका डेटा नहीं बदला। उसे फिर से खोलने के लिए ऐप दोबारा शुरू होगा। कृपया नीचे दी गई रिपोर्ट कॉपी करके हमें भेजें ताकि हम इसे ठीक कर सकें।';

  @override
  String get restartApp => 'ऐप दोबारा शुरू करें';

  @override
  String get restoreRejectedTitle => 'यह फ़ाइल रीस्टोर नहीं हो सकती';

  @override
  String get notABackup => 'यह फ़ाइल Expense Tracker का बैकअप नहीं है।';

  @override
  String get backupTooNew =>
      'यह बैकअप ऐप के नए वर्ज़न से बना है। ऐप अपडेट करें, फिर दोबारा कोशिश करें।';

  @override
  String get backupDamaged => 'यह बैकअप खराब है और रीस्टोर नहीं हो सकता।';

  @override
  String get periodDay => 'दिन';

  @override
  String get periodWeek => 'सप्ताह';

  @override
  String get periodMonth => 'महीना';

  @override
  String get periodYear => 'साल';

  @override
  String weekNumber(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'सप्ताह $numberString';
  }

  @override
  String weekNumberWithYear(int number, String year) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'सप्ताह $numberString, $year';
  }

  @override
  String weekOfMonth(String month, int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return '$month सप्ताह $numberString';
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
  String get trendEmptyWeek => 'इस सप्ताह कोई खर्च नहीं';

  @override
  String get trendEmptyMonth => 'इस महीने कोई खर्च नहीं';

  @override
  String get trendEmptyYear => 'इस साल कोई खर्च नहीं';

  @override
  String get trendNoMatchWeek => 'इस सप्ताह कोई मिलता-जुलता खर्च नहीं';

  @override
  String get trendNoMatchMonth => 'इस महीने कोई मिलता-जुलता खर्च नहीं';

  @override
  String get trendNoMatchYear => 'इस साल कोई मिलता-जुलता खर्च नहीं';

  @override
  String get trendFiltered => 'फ़िल्टर किया गया';

  @override
  String trendPointLabel(String date, String amount) {
    return '$date · $amount';
  }

  @override
  String trendCardSemantics(String period, String amount) {
    return '$period, कुल $amount';
  }

  @override
  String trendCardSemanticsFiltered(String period, String amount) {
    return '$period, फ़िल्टर किया गया, कुल $amount';
  }

  @override
  String get totalsLoadFailed => 'कुल लोड नहीं हो सके';

  @override
  String get nextPeriod => 'अगली अवधि';

  @override
  String get previousPeriod => 'पिछली अवधि';

  @override
  String get nextCurrency => 'अगली मुद्रा';

  @override
  String get previousCurrency => 'पिछली मुद्रा';

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
    return '$first और $rest';
  }

  @override
  String get totalTooLarge => 'बहुत बड़ा';

  @override
  String get showSubtotal => 'उप-योग देखें';

  @override
  String get subtotalLoadFailed => 'उप-योग लोड नहीं हो सका';

  @override
  String groupSubtotalSemantics(String name, String amount) {
    return '$name, उप-योग $amount';
  }

  @override
  String get close => 'बंद करें';

  @override
  String get filters => 'फ़िल्टर';

  @override
  String get filterSearchHint => 'शीर्षक और विवरण में खोजें';

  @override
  String get filterCategories => 'श्रेणियाँ';

  @override
  String get filterEvents => 'इवेंट';

  @override
  String get filterArchived => 'संग्रहीत';

  @override
  String get groupBy => 'समूह बनाएँ';

  @override
  String get groupedByDay => 'दिन के अनुसार';

  @override
  String get groupedByWeek => 'सप्ताह के अनुसार';

  @override
  String get groupedByMonth => 'महीने के अनुसार';

  @override
  String get groupedByYear => 'साल के अनुसार';

  @override
  String get clearFilters => 'फ़िल्टर हटाएँ';

  @override
  String get showResults => 'नतीजे देखें';

  @override
  String get noFilterMatches => 'इन फ़िल्टर से कोई खर्च नहीं मिला';

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
  String get removeFilter => 'फ़िल्टर हटाएँ';

  @override
  String get settingsLook => 'रूप';

  @override
  String get settingsHome => 'होम';

  @override
  String get settingsDefaults => 'डिफ़ॉल्ट';

  @override
  String get settingWeekStart => 'सप्ताह शुरू होता है';

  @override
  String get settingWeekNames => 'सप्ताह के नाम';

  @override
  String get settingTrendChart => 'ट्रेंड चार्ट';

  @override
  String get chartLineFilled => 'स्मूद लाइन, भरी हुई';

  @override
  String get chartLine => 'स्मूद लाइन';

  @override
  String get chartBars => 'बार';

  @override
  String get chartDots => 'बिंदु';

  @override
  String get chartRunningTotal => 'चालू कुल';

  @override
  String get settingTrendCardSize => 'कार्ड का आकार';

  @override
  String get cardSizeSmall => 'छोटा';

  @override
  String get cardSizeMedium => 'मध्यम';

  @override
  String get cardSizeLarge => 'बड़ा';

  @override
  String get settingCardHaptics => 'कार्ड का कंपन';

  @override
  String get hapticsOff => 'बंद';

  @override
  String get hapticsLight => 'हल्का';

  @override
  String get hapticsMedium => 'मध्यम';

  @override
  String get hapticsStrong => 'तेज़';

  @override
  String trendRunningTotalPoint(String date, String amount) {
    return '$date तक · $amount';
  }

  @override
  String get restoreHomeDefaults => 'डिफ़ॉल्ट वापस लाएँ';

  @override
  String get restoreHomeDefaultsSubtitle => 'चार्ट, कार्ड और सप्ताह पहले जैसे';

  @override
  String get restoreHomeDefaultsTitle => 'होम के डिफ़ॉल्ट वापस लाएँ?';

  @override
  String get restoreHomeDefaultsMessage =>
      'ट्रेंड चार्ट, ट्रेंड कार्ड, कार्ड का आकार, सप्ताह की शुरुआत और सप्ताह के नाम डिफ़ॉल्ट पर लौट आते हैं।';

  @override
  String get settingTrendCard => 'ट्रेंड कार्ड';

  @override
  String get trendCardLocked => 'ऊपर स्थिर';

  @override
  String get trendCardScrolls => 'सूची के साथ स्क्रॉल हो';

  @override
  String get trendCardLockedShort => 'स्थिर';

  @override
  String get trendCardScrollsShort => 'स्क्रॉल';

  @override
  String get binTileSummary => '30 दिन तक रखे जाते हैं';

  @override
  String settingsTileSummary(String first, String rest) {
    return '$first · $rest';
  }

  @override
  String get addPhotos => 'फ़ोटो जोड़ें';

  @override
  String photosCountOpen(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो, खोलें',
      one: '1 फ़ोटो, खोलें',
    );
    return '$_temp0';
  }

  @override
  String get takePhoto => 'फ़ोटो लें';

  @override
  String get chooseFromGallery => 'गैलरी से चुनें';

  @override
  String photosAddedOf(int count, int max) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$maxString में से $countString जोड़ी गईं';
  }

  @override
  String get photos => 'फ़ोटो';

  @override
  String photosOfMax(int count, int max) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '$maxString में से $countString';
  }

  @override
  String photosMaxReached(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return 'एक खर्च में ज़्यादा से ज़्यादा $maxString फ़ोटो';
  }

  @override
  String get photoAlreadyAdded => 'यह फ़ोटो पहले से है';

  @override
  String photoCouldNotBeAdded(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो नहीं जोड़ी जा सकीं',
      one: 'एक फ़ोटो नहीं जोड़ी जा सकी',
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
      other: '$addedString जोड़ी गईं',
      one: '1 जोड़ी गई',
      zero: 'कोई नहीं जोड़ी गई',
    );
    return 'एक खर्च में सिर्फ़ $maxString फ़ोटो: $_temp0।';
  }

  @override
  String get noCameraApp => 'कोई कैमरा ऐप नहीं मिला';

  @override
  String get addingPhotos => 'फ़ोटो जोड़ी जा रही हैं…';

  @override
  String addingPhotosProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'फ़ोटो जोड़ी जा रही हैं ($totalString में से $doneString)';
  }

  @override
  String draftPhotosMissing(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ड्राफ़्ट की $countString फ़ोटो नहीं मिलीं',
      one: 'ड्राफ़्ट की 1 फ़ोटो नहीं मिली',
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
      other: '$extraString फ़ोटो',
      one: '1 फ़ोटो',
    );
    return 'ज़्यादा से ज़्यादा $maxString फ़ोटो। सहेजने के लिए $_temp0 हटाएँ।';
  }

  @override
  String photosNotKept(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो नहीं रखी जा सकीं: इस बीच हटा दी गईं',
      one: '1 फ़ोटो नहीं रखी जा सकी: इस बीच हटा दी गई',
    );
    return '$_temp0';
  }

  @override
  String get imageMissing => 'तस्वीर नहीं मिली';

  @override
  String get photosSaveFailed =>
      'फ़ोटो सहेजी नहीं जा सकीं। कुछ भी सहेजा नहीं गया।';

  @override
  String photosCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो',
      one: '1 फ़ोटो',
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

    return '$totalString में से फ़ोटो $indexString';
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

    return '$countString चुनी गईं';
  }

  @override
  String photosSelectedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो चुनी गईं',
      one: '1 फ़ोटो चुनी गई',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'सभी चुनें';

  @override
  String get endSelection => 'चुनना बंद करें';

  @override
  String get selected => 'चुनी गई';

  @override
  String get notSelected => 'नहीं चुनी गई';

  @override
  String photosDeleteTitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो हटाएँ?',
      one: 'यह फ़ोटो हटाएँ?',
    );
    return '$_temp0';
  }

  @override
  String photosDeleteWarningScreen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ये अपने खर्चों से हमेशा के लिए हट जाएँगी। Pictures में सहेजी गई कॉपी बनी रहेंगी।',
      one: 'यह अपने खर्च से हमेशा के लिए हट जाएगी। Pictures में सहेजी गई कॉपी बनी रहेंगी।',
    );
    return '$_temp0';
  }

  @override
  String photosDeleteWarningForm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'अपडेट करें दबाने पर ये इस खर्च से हमेशा के लिए हट जाएँगी। Pictures में सहेजी गई कॉपी बनी रहेंगी।',
      one: 'अपडेट करें दबाने पर यह इस खर्च से हमेशा के लिए हट जाएगी। Pictures में सहेजी गई कॉपी बनी रहेंगी।',
    );
    return '$_temp0';
  }

  @override
  String photosDeleteWarningNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'खर्च सहेजने पर ये उससे हमेशा के लिए हट जाएँगी। Pictures में सहेजी गई कॉपी बनी रहेंगी।',
      one: 'खर्च सहेजने पर यह उससे हमेशा के लिए हट जाएगी। Pictures में सहेजी गई कॉपी बनी रहेंगी।',
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
      other: '$countString फ़ोटो हटाई गईं',
      one: '1 फ़ोटो हटाई गई',
    );
    return '$_temp0';
  }

  @override
  String get saveToPictures => 'Pictures में सहेजें';

  @override
  String savedToPictures(String folder) {
    return '$folder में सहेजी गई';
  }

  @override
  String photosSavedToPictures(int count, String folder) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो $folder में सहेजी गईं',
      one: '1 फ़ोटो $folder में सहेजी गई',
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
      other: '$failedString सहेजी नहीं जा सकीं',
      one: '1 सहेजी नहीं जा सकी',
    );
    return '$savedString सहेजी गईं; $_temp0';
  }

  @override
  String photosMissingNotSaved(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो नहीं मिलीं और सहेजी नहीं गईं',
      one: '1 फ़ोटो नहीं मिली और सहेजी नहीं गई',
    );
    return '$_temp0';
  }

  @override
  String get noSpaceToSavePhotos => 'इन फ़ोटो को सहेजने के लिए जगह नहीं है';

  @override
  String savingToPictures(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'सहेजी जा रही हैं $doneString / $totalString';
  }

  @override
  String get defaultPictureTitle => 'खर्च';

  @override
  String get reviewPhoto => 'आपकी फ़ोटो';

  @override
  String get rotateLeft => 'बाईं ओर घुमाएँ';

  @override
  String get rotateRight => 'दाईं ओर घुमाएँ';

  @override
  String rotatedDegrees(int degrees) {
    final intl.NumberFormat degreesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String degreesString = degreesNumberFormat.format(degrees);

    return '$degreesString डिग्री घुमाई गई';
  }

  @override
  String get usePhoto => 'फ़ोटो रखें';

  @override
  String get discardPhoto => 'हटाएँ';

  @override
  String get photoFromCameraBack => 'आपकी ली हुई फ़ोटो वापस आ गई';

  @override
  String get noPhotosMatchTooltip => 'फ़िल्टर से कोई फ़ोटो नहीं मिली';

  @override
  String photoOfExpense(String title, String date) {
    return '$title की फ़ोटो, $date';
  }

  @override
  String get noPhotosMatchFilters => 'होम के फ़िल्टर से कोई फ़ोटो नहीं मिली।';

  @override
  String get cameraPhotos => 'कैमरे की फ़ोटो';

  @override
  String get galleryPhotos => 'गैलरी की फ़ोटो';

  @override
  String get photoSizeLabel => 'आकार';

  @override
  String get photoQualityLabel => 'क्वालिटी';

  @override
  String get photoSizeOriginal => 'ओरिजिनल';

  @override
  String photoSizeNotRecommended(String size) {
    return '$size (सलाह नहीं दी जाती)';
  }

  @override
  String settingDefaultValue(String value) {
    return '$value (डिफ़ॉल्ट)';
  }

  @override
  String get photoResizedAbove =>
      'इससे बड़ी फ़ोटो इस आकार में छोटी की जाती हैं; छोटी फ़ोटो जैसी हैं वैसी रहती हैं';

  @override
  String get originalWarning =>
      'ओरिजिनल रखने की सलाह नहीं दी जाती: फ़ोन की एक फ़ोटो 5–10 MB की होती है, इसलिए लगभग 1,000 फ़ोटो के बाद वे फ़ोन पर और फ़ोटो वाले बैकअप में कई GB ले लेती हैं। ओरिजिनल में फ़ोटो की जगह (लोकेशन) भी रहती है।';

  @override
  String photosUse(String size, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो',
      one: '1 फ़ोटो',
    );
    return 'फ़ोटो $size जगह लेती हैं ($_temp0)।';
  }

  @override
  String get noPhotosYet => 'अभी कोई फ़ोटो नहीं।';

  @override
  String get photosKeptInApp =>
      'फ़ोटो ऐप के अंदर रहती हैं और ऐप के साथ चली जाती हैं। अपने लिए कोई फ़ोटो रखने के लिए उसे खोलें और Pictures में सहेजें दबाएँ।';

  @override
  String get photoChangesApplyToNew =>
      'बदलाव अब से जोड़ी जाने वाली फ़ोटो पर लागू होंगे।';

  @override
  String photosTileCamera(String size) {
    return 'कैमरा $size';
  }

  @override
  String photosTileGallery(String size) {
    return 'गैलरी $size';
  }

  @override
  String get restorePhotoDefaults => 'डिफ़ॉल्ट वापस लाएँ';

  @override
  String get restorePhotoDefaultsTitle => 'फ़ोटो के डिफ़ॉल्ट वापस लाएँ?';

  @override
  String get restorePhotoDefaultsMessage =>
      'कैमरे और गैलरी की फ़ोटो 1080p और क्वालिटी 85 पर लौट आएँगी।';

  @override
  String get includePhotos => 'फ़ोटो शामिल करें';

  @override
  String get photosNotInBackup =>
      'फ़ोटो इस बैकअप में नहीं होंगी। दूसरे फ़ोन पर या ऐप दोबारा इंस्टॉल करके रीस्टोर करने पर वे गायब दिखेंगी।';

  @override
  String backupPhotosProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'बैकअप में फ़ोटो जोड़ी जा रही हैं ($totalString में से $doneString)';
  }

  @override
  String get savingBackup => 'बैकअप सहेजा जा रहा है…';

  @override
  String get backupNoSpace => 'यह बैकअप बनाने के लिए फ़ोन में जगह नहीं है';

  @override
  String backupSavedMissingPhotos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो नहीं मिलीं और उसमें नहीं हैं',
      one: '1 फ़ोटो नहीं मिली और उसमें नहीं है',
    );
    return 'बैकअप सहेजा गया। $_temp0।';
  }

  @override
  String get saveTargetNoSpace =>
      'जहाँ आपने सहेजना चुना वहाँ पर्याप्त जगह नहीं है';

  @override
  String restoreIncludesPhotos(int count, String size) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो',
      one: '1 फ़ोटो',
    );
    return 'इसमें $_temp0 ($size) हैं।';
  }

  @override
  String restoreNoSpaceForPhotos(String size) {
    return 'इसकी फ़ोटो के लिए पर्याप्त जगह नहीं है ($size और चाहिए)।';
  }

  @override
  String get restoreWithoutPhotos => 'फ़ोटो के बिना रीस्टोर करें';

  @override
  String get restoreBackupWithoutPhotos =>
      'इस बैकअप में फ़ोटो नहीं हैं। जो फ़ोटो इस फ़ोन में नहीं हैं वे गायब दिखेंगी।';

  @override
  String restoringPhotosProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'फ़ोटो रीस्टोर हो रही हैं ($totalString में से $doneString)';
  }

  @override
  String backupRestoredFailedPhotos(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोटो रीस्टोर नहीं हो सकीं और गायब दिखेंगी',
      one: '1 फ़ोटो रीस्टोर नहीं हो सकी और गायब दिखेगी',
    );
    return 'बैकअप रीस्टोर हो गया। $_temp0।';
  }

  @override
  String get openBackupNoSpace => 'यह बैकअप खोलने के लिए फ़ोन में जगह नहीं है';

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
  String get categoryFood => 'खाना';

  @override
  String get categoryDrinks => 'पेय';

  @override
  String get categoryGroceries => 'किराना';

  @override
  String get categoryShopping => 'खरीदारी';

  @override
  String get categoryClothes => 'कपड़े';

  @override
  String get categoryTransport => 'परिवहन';

  @override
  String get categoryFuel => 'ईंधन';

  @override
  String get categoryRent => 'किराया';

  @override
  String get categoryHouse => 'घर';

  @override
  String get categoryBills => 'बिल';

  @override
  String get categoryHealth => 'स्वास्थ्य';

  @override
  String get categoryEducation => 'शिक्षा';

  @override
  String get categoryEntertainment => 'मनोरंजन';

  @override
  String get categoryTravel => 'यात्रा';

  @override
  String get categoryGifts => 'उपहार';

  @override
  String get categoryPersonalCare => 'व्यक्तिगत देखभाल';

  @override
  String get categorySubscription => 'सदस्यता';

  @override
  String get categoryLoan => 'लोन';

  @override
  String get categoryInvestment => 'निवेश';

  @override
  String get categoryOther => 'अन्य';

  @override
  String get paymentMethodCash => 'नकद';

  @override
  String get paymentMethodUpi => 'UPI';

  @override
  String get paymentMethodDebitCard => 'डेबिट कार्ड';

  @override
  String get paymentMethodCreditCard => 'क्रेडिट कार्ड';

  @override
  String get eventBirthday => 'जन्मदिन';

  @override
  String get eventAnniversary => 'सालगिरह';

  @override
  String get eventParty => 'पार्टी';

  @override
  String get eventFestival => 'त्योहार';

  @override
  String get eventTrip => 'ट्रिप';

  @override
  String get eventWedding => 'शादी';

  @override
  String get eventDiningOut => 'बाहर खाना';
}
