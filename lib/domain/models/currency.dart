import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

/// An ISO 4217 currency. The list of currencies lives in code
/// ([currencies]), not in the database (database.md §1).
class Currency {
  const Currency(this.code, this.englishName, this.minorDigits);

  /// ISO 4217 code, e.g. `INR`.
  final String code;

  /// e.g. `Indian Rupee`. English in every language for now (phase-1.md §12).
  final String englishName;

  /// Digits after the decimal point: 2 for INR, 0 for JPY, 3 for KWD.
  final int minorDigits;

  /// e.g. `₹`. Falls back to the code for currencies `intl` has no symbol
  /// for.
  String get symbol =>
      _symbols[code] ??= NumberFormat.simpleCurrency(name: code).currencySymbol;

  // Cached because building a NumberFormat for each list row on every
  // rebuild would make scrolling the currency picker stutter.
  static final _symbols = <String, String>{};

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Currency($code)';
}

/// The currency with ISO [code], or null if it isn't in [currencies].
Currency? findCurrency(String code) {
  for (final currency in currencies) {
    if (currency.code == code) return currency;
  }
  return null;
}

/// The default currency for a device set to [locale]: the currency of its
/// country, or `USD` when the locale has no country or `intl` doesn't know
/// it. Only a guess to preselect in onboarding; the user confirms it there.
String deviceCurrency(Locale locale) {
  final country = locale.countryCode;
  if (country == null || country.isEmpty) return 'USD';
  final candidates = [
    '${locale.languageCode}_$country',
    // e.g. hi_GB: intl has no Hindi for Britain, but has English for it.
    'en_$country',
    // intl keeps a language's main country under the bare language code
    // (ja is Japan, fr is France), with only ~30 locales like en_IN or
    // pt_PT spelled out. So ja_JP or fr_FR are found here.
    locale.languageCode,
  ];
  for (final localeName in candidates) {
    if (!NumberFormat.localeExists(localeName)) continue;
    final code = NumberFormat.simpleCurrency(locale: localeName).currencyName;
    if (code != null && findCurrency(code) != null) return code;
  }
  return 'USD';
}

/// Currencies whose code or English name contains [query], ignoring case.
/// Codes starting with the query come first, then the rest in catalog order.
List<Currency> searchCurrencies(String query) {
  final text = query.trim().toLowerCase();
  if (text.isEmpty) return currencies;
  final byCode = <Currency>[];
  final others = <Currency>[];
  for (final currency in currencies) {
    if (currency.code.toLowerCase().startsWith(text)) {
      byCode.add(currency);
    } else if (currency.code.toLowerCase().contains(text) ||
        currency.englishName.toLowerCase().contains(text)) {
      others.add(currency);
    }
  }
  return [...byCode, ...others];
}

/// Active ISO 4217 currencies, sorted by code. Funds, precious metals and
/// withdrawn currencies (e.g. HRK, BGN, which became the euro) are left out.
const List<Currency> currencies = [
  Currency('AED', 'UAE Dirham', 2),
  Currency('AFN', 'Afghan Afghani', 2),
  Currency('ALL', 'Albanian Lek', 2),
  Currency('AMD', 'Armenian Dram', 2),
  Currency('ANG', 'Netherlands Antillean Guilder', 2),
  Currency('AOA', 'Angolan Kwanza', 2),
  Currency('ARS', 'Argentine Peso', 2),
  Currency('AUD', 'Australian Dollar', 2),
  Currency('AWG', 'Aruban Florin', 2),
  Currency('AZN', 'Azerbaijani Manat', 2),
  Currency('BAM', 'Bosnia-Herzegovina Convertible Mark', 2),
  Currency('BBD', 'Barbadian Dollar', 2),
  Currency('BDT', 'Bangladeshi Taka', 2),
  Currency('BHD', 'Bahraini Dinar', 3),
  Currency('BIF', 'Burundian Franc', 0),
  Currency('BMD', 'Bermudan Dollar', 2),
  Currency('BND', 'Brunei Dollar', 2),
  Currency('BOB', 'Bolivian Boliviano', 2),
  Currency('BRL', 'Brazilian Real', 2),
  Currency('BSD', 'Bahamian Dollar', 2),
  Currency('BTN', 'Bhutanese Ngultrum', 2),
  Currency('BWP', 'Botswanan Pula', 2),
  Currency('BYN', 'Belarusian Ruble', 2),
  Currency('BZD', 'Belize Dollar', 2),
  Currency('CAD', 'Canadian Dollar', 2),
  Currency('CDF', 'Congolese Franc', 2),
  Currency('CHF', 'Swiss Franc', 2),
  Currency('CLP', 'Chilean Peso', 0),
  Currency('CNY', 'Chinese Yuan', 2),
  Currency('COP', 'Colombian Peso', 2),
  Currency('CRC', 'Costa Rican Colón', 2),
  Currency('CUP', 'Cuban Peso', 2),
  Currency('CVE', 'Cape Verdean Escudo', 2),
  Currency('CZK', 'Czech Koruna', 2),
  Currency('DJF', 'Djiboutian Franc', 0),
  Currency('DKK', 'Danish Krone', 2),
  Currency('DOP', 'Dominican Peso', 2),
  Currency('DZD', 'Algerian Dinar', 2),
  Currency('EGP', 'Egyptian Pound', 2),
  Currency('ERN', 'Eritrean Nakfa', 2),
  Currency('ETB', 'Ethiopian Birr', 2),
  Currency('EUR', 'Euro', 2),
  Currency('FJD', 'Fijian Dollar', 2),
  Currency('FKP', 'Falkland Islands Pound', 2),
  Currency('GBP', 'British Pound', 2),
  Currency('GEL', 'Georgian Lari', 2),
  Currency('GHS', 'Ghanaian Cedi', 2),
  Currency('GIP', 'Gibraltar Pound', 2),
  Currency('GMD', 'Gambian Dalasi', 2),
  Currency('GNF', 'Guinean Franc', 0),
  Currency('GTQ', 'Guatemalan Quetzal', 2),
  Currency('GYD', 'Guyanaese Dollar', 2),
  Currency('HKD', 'Hong Kong Dollar', 2),
  Currency('HNL', 'Honduran Lempira', 2),
  Currency('HTG', 'Haitian Gourde', 2),
  Currency('HUF', 'Hungarian Forint', 2),
  Currency('IDR', 'Indonesian Rupiah', 2),
  Currency('ILS', 'Israeli New Shekel', 2),
  Currency('INR', 'Indian Rupee', 2),
  Currency('IQD', 'Iraqi Dinar', 3),
  Currency('IRR', 'Iranian Rial', 2),
  Currency('ISK', 'Icelandic Króna', 0),
  Currency('JMD', 'Jamaican Dollar', 2),
  Currency('JOD', 'Jordanian Dinar', 3),
  Currency('JPY', 'Japanese Yen', 0),
  Currency('KES', 'Kenyan Shilling', 2),
  Currency('KGS', 'Kyrgystani Som', 2),
  Currency('KHR', 'Cambodian Riel', 2),
  Currency('KMF', 'Comorian Franc', 0),
  Currency('KPW', 'North Korean Won', 2),
  Currency('KRW', 'South Korean Won', 0),
  Currency('KWD', 'Kuwaiti Dinar', 3),
  Currency('KYD', 'Cayman Islands Dollar', 2),
  Currency('KZT', 'Kazakhstani Tenge', 2),
  Currency('LAK', 'Laotian Kip', 2),
  Currency('LBP', 'Lebanese Pound', 2),
  Currency('LKR', 'Sri Lankan Rupee', 2),
  Currency('LRD', 'Liberian Dollar', 2),
  Currency('LSL', 'Lesotho Loti', 2),
  Currency('LYD', 'Libyan Dinar', 3),
  Currency('MAD', 'Moroccan Dirham', 2),
  Currency('MDL', 'Moldovan Leu', 2),
  Currency('MGA', 'Malagasy Ariary', 2),
  Currency('MKD', 'Macedonian Denar', 2),
  Currency('MMK', 'Myanmar Kyat', 2),
  Currency('MNT', 'Mongolian Tugrik', 2),
  Currency('MOP', 'Macanese Pataca', 2),
  Currency('MRU', 'Mauritanian Ouguiya', 2),
  Currency('MUR', 'Mauritian Rupee', 2),
  Currency('MVR', 'Maldivian Rufiyaa', 2),
  Currency('MWK', 'Malawian Kwacha', 2),
  Currency('MXN', 'Mexican Peso', 2),
  Currency('MYR', 'Malaysian Ringgit', 2),
  Currency('MZN', 'Mozambican Metical', 2),
  Currency('NAD', 'Namibian Dollar', 2),
  Currency('NGN', 'Nigerian Naira', 2),
  Currency('NIO', 'Nicaraguan Córdoba', 2),
  Currency('NOK', 'Norwegian Krone', 2),
  Currency('NPR', 'Nepalese Rupee', 2),
  Currency('NZD', 'New Zealand Dollar', 2),
  Currency('OMR', 'Omani Rial', 3),
  Currency('PAB', 'Panamanian Balboa', 2),
  Currency('PEN', 'Peruvian Sol', 2),
  Currency('PGK', 'Papua New Guinean Kina', 2),
  Currency('PHP', 'Philippine Peso', 2),
  Currency('PKR', 'Pakistani Rupee', 2),
  Currency('PLN', 'Polish Zloty', 2),
  Currency('PYG', 'Paraguayan Guarani', 0),
  Currency('QAR', 'Qatari Riyal', 2),
  Currency('RON', 'Romanian Leu', 2),
  Currency('RSD', 'Serbian Dinar', 2),
  Currency('RUB', 'Russian Ruble', 2),
  Currency('RWF', 'Rwandan Franc', 0),
  Currency('SAR', 'Saudi Riyal', 2),
  Currency('SBD', 'Solomon Islands Dollar', 2),
  Currency('SCR', 'Seychellois Rupee', 2),
  Currency('SDG', 'Sudanese Pound', 2),
  Currency('SEK', 'Swedish Krona', 2),
  Currency('SGD', 'Singapore Dollar', 2),
  Currency('SHP', 'St. Helena Pound', 2),
  Currency('SLE', 'Sierra Leonean Leone', 2),
  Currency('SOS', 'Somali Shilling', 2),
  Currency('SRD', 'Surinamese Dollar', 2),
  Currency('SSP', 'South Sudanese Pound', 2),
  Currency('STN', 'São Tomé & Príncipe Dobra', 2),
  Currency('SVC', 'Salvadoran Colón', 2),
  Currency('SYP', 'Syrian Pound', 2),
  Currency('SZL', 'Swazi Lilangeni', 2),
  Currency('THB', 'Thai Baht', 2),
  Currency('TJS', 'Tajikistani Somoni', 2),
  Currency('TMT', 'Turkmenistani Manat', 2),
  Currency('TND', 'Tunisian Dinar', 3),
  Currency('TOP', 'Tongan Paʻanga', 2),
  Currency('TRY', 'Turkish Lira', 2),
  Currency('TTD', 'Trinidad & Tobago Dollar', 2),
  Currency('TWD', 'New Taiwan Dollar', 2),
  Currency('TZS', 'Tanzanian Shilling', 2),
  Currency('UAH', 'Ukrainian Hryvnia', 2),
  Currency('UGX', 'Ugandan Shilling', 0),
  Currency('USD', 'US Dollar', 2),
  Currency('UYU', 'Uruguayan Peso', 2),
  Currency('UZS', 'Uzbekistani Som', 2),
  Currency('VES', 'Venezuelan Bolívar', 2),
  Currency('VND', 'Vietnamese Dong', 0),
  Currency('VUV', 'Vanuatu Vatu', 0),
  Currency('WST', 'Samoan Tala', 2),
  Currency('XAF', 'Central African CFA Franc', 0),
  Currency('XCD', 'East Caribbean Dollar', 2),
  Currency('XCG', 'Caribbean Guilder', 2),
  Currency('XOF', 'West African CFA Franc', 0),
  Currency('XPF', 'CFP Franc', 0),
  Currency('YER', 'Yemeni Rial', 2),
  Currency('ZAR', 'South African Rand', 2),
  Currency('ZMW', 'Zambian Kwacha', 2),
  Currency('ZWG', 'Zimbabwe Gold', 2),
];
