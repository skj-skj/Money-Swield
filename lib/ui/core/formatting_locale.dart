import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// The locale money, numbers and dates are formatted in: the app language
/// with the phone's country when intl knows that pair, else the app
/// language alone (P2-11).
///
/// The app's own locale has no country, so on its own `en` would group
/// `110,050` and write "Oct 1" for everyone. With the phone's country an
/// Indian phone gets `en_IN` (`1,10,050`, "1 Oct") and a US one `en_US`.
/// `hi` already groups the Indian way.
String formattingLocaleName({
  required Locale appLocale,
  required Locale deviceLocale,
}) {
  final language = appLocale.languageCode;
  final country = deviceLocale.countryCode;
  if (country != null && country.isNotEmpty) {
    final withCountry = '${language}_$country';
    if (NumberFormat.localeExists(withCountry)) return withCountry;
  }
  return language;
}

/// [formattingLocaleName] for the app language and the phone's locale.
String formattingLocaleOf(BuildContext context) => formattingLocaleName(
  appLocale: Localizations.localeOf(context),
  deviceLocale: WidgetsBinding.instance.platformDispatcher.locale,
);

/// [formattingLocaleOf] for `DateFormat`. Falls back to the app language if
/// intl has no date data for the pair, rather than throwing.
String dateLocaleOf(BuildContext context) {
  final name = formattingLocaleOf(context);
  return DateFormat.localeExists(name)
      ? name
      : Localizations.localeOf(context).languageCode;
}

/// [formattingLocaleOf] as a [Locale], for Material widgets that take one:
/// the date picker reads only the app locale otherwise, and would write an
/// Indian phone's dates the US way.
Locale formattingLocaleValueOf(BuildContext context) {
  final [language, ...country] = formattingLocaleOf(context).split('_');
  return Locale(language, country.firstOrNull);
}

/// The decimal separator money is typed and shown with in [localeName]:
/// `.` for en and hi, `,` for es. Only `.` and `,` are ever returned: the
/// amount parser knows no other (phase-4.md §5.1).
String decimalSeparatorFor(String localeName) {
  final separator = NumberFormat.decimalPattern(localeName).symbols.DECIMAL_SEP;
  return separator == ',' ? ',' : '.';
}

/// [decimalSeparatorFor] the formatting locale ([formattingLocaleOf]).
String decimalSeparatorOf(BuildContext context) =>
    decimalSeparatorFor(formattingLocaleOf(context));
