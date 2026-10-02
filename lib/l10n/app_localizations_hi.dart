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
    return 'आपका डेटा अपडेट हो रहा है ($total में से $current)';
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
    return 'चरण $current / $total';
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
      'खर्च जोड़ने की सुविधा अगले अपडेट में आ रही है।';

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
    return 'संग्रहीत ($count)';
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
    return 'अधिकतम $max अक्षर लिखें';
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
}
