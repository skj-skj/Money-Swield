import 'package:flutter/widgets.dart' show Locale, basicLocaleListResolution;

import '../../l10n/app_localizations.dart';

/// Each supported language in its own language ("Español", "हिन्दी").
///
/// Deliberately not in the ARB files: a language picker shows every
/// language under its own name, whatever the current language is, so that
/// someone who can't read the current one still finds theirs.
const languageNames = {'en': 'English', 'es': 'Español', 'hi': 'हिन्दी'};

/// The language the app shows when it follows a device whose language list
/// is [deviceLocales]. Uses the same rule as `MaterialApp`, so it always
/// names the language actually on screen: the first device language the
/// app supports (a device set to French, then Hindi, gets Hindi), else
/// English.
String systemLanguageCode(List<Locale> deviceLocales) =>
    basicLocaleListResolution(
      deviceLocales,
      AppLocalizations.supportedLocales,
    ).languageCode;
