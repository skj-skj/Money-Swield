import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// gen-l10n only warns about a missing translation (and then shows English),
/// so these checks make a gap in es/hi a test failure instead.
void main() {
  Map<String, Object?> read(String code) =>
      jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, Object?>;

  Set<String> messageKeys(Map<String, Object?> arb) => {
    for (final key in arb.keys)
      if (!key.startsWith('@')) key,
  };

  Set<String> placeholdersIn(String message) => {
    for (final match in RegExp(r'\{(\w+)\}').allMatches(message))
      match.group(1)!,
  };

  final template = read('en');

  for (final code in ['es', 'hi']) {
    group('app_$code.arb', () {
      final arb = read(code);

      test('has every message of the English template, and no extra ones', () {
        expect(messageKeys(arb), messageKeys(template));
      });

      test('uses the same placeholders as English in every message', () {
        for (final key in messageKeys(template)) {
          final english = template[key]! as String;
          final translated = arb[key];
          if (translated is! String) continue; // Reported by the test above.
          expect(
            placeholdersIn(translated),
            placeholdersIn(english),
            reason: key,
          );
        }
      });

      test('has no empty messages', () {
        for (final key in messageKeys(arb)) {
          expect((arb[key]! as String).trim(), isNotEmpty, reason: key);
        }
      });
    });
  }

  test('every English message with a placeholder documents it', () {
    for (final key in messageKeys(template)) {
      if (placeholdersIn(template[key]! as String).isEmpty) continue;
      final meta = template['@$key'] as Map<String, Object?>?;
      expect(meta?['placeholders'], isNotNull, reason: key);
    }
  });
}
