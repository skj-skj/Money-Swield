import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/core/languages.dart';

void main() {
  test('every list of supported languages names the same ones', () {
    // Adding a language means touching all three (and adding its ARB file).
    final fromArb = [
      for (final locale in AppLocalizations.supportedLocales)
        locale.languageCode,
    ];
    expect(languageNames.keys, fromArb);
    expect(supportedLanguageCodes, fromArb);
  });

  group('systemLanguageCode', () {
    test('a supported device language is used', () {
      expect(systemLanguageCode(const [Locale('hi', 'IN')]), 'hi');
      expect(systemLanguageCode(const [Locale('es', 'MX')]), 'es');
    });

    test('an unsupported device language falls back to English', () {
      expect(systemLanguageCode(const [Locale('fr', 'FR')]), 'en');
    });

    test(
      'the first supported language in the device list wins, as in MaterialApp',
      () {
        expect(
          systemLanguageCode(const [Locale('fr', 'FR'), Locale('hi', 'IN')]),
          'hi',
        );
      },
    );
  });
}
