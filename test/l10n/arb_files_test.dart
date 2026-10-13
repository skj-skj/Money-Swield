import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/l10n/app_localizations.dart';

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

  // A one-word plural branch (`=1{Daily}`, `other{days}`) is text, not a
  // placeholder: braces right after a selector are skipped (the first such
  // branches came with the recurring texts).
  Set<String> placeholdersIn(String message) => {
    for (final match in RegExp(
      r'(?<!(?:=\d+|zero|one|two|few|many|other))\{(\w+)\}',
    ).allMatches(message))
      match.group(1)!,
  };

  test('a one-word plural branch is not read as a placeholder', () {
    expect(
      placeholdersIn('{count, plural, =1{Daily} other{Every {count} days}}'),
      {'count'},
    );
    expect(placeholdersIn('{count, plural, other{days}}'), <String>{});
    expect(placeholdersIn('Hello {name}'), {'name'});
  });

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

  // Seen on the Oppo with 10,000 photos: "Photos use 169.4 MB (10000 photos)."
  // Counts take the language's digit grouping.
  test('every shown int placeholder is formatted with digit grouping', () {
    for (final key in template.keys.where((key) => key.startsWith('@'))) {
      final meta = template[key];
      if (meta is! Map<String, Object?>) continue;
      final placeholders = meta['placeholders'] as Map<String, Object?>?;
      for (final MapEntry(key: name, value: placeholder)
          in (placeholders ?? const {}).entries) {
        if (placeholder is! Map<String, Object?>) continue;
        if (placeholder['type'] != 'int') continue;
        // Only where the number is shown: a count that just picks the
        // plural form has nothing to format.
        final message = template[key.substring(1)]! as String;
        if (!message.contains('{$name}')) continue;
        expect(placeholder['format'], 'decimalPattern', reason: '$key $name');
      }
    }
  });

  test('large counts read with the language grouping', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    final hi = await AppLocalizations.delegate.load(const Locale('hi'));
    expect(en.photosUse('1 MB', 10000), 'Photos use 1 MB (10,000 photos).');
    expect(en.restoreExpenseCount(123456), '123,456 expenses');
    expect(
      es.photosUse('1 MB', 10000),
      'Las fotos ocupan 1 MB (10.000 fotos).',
    );
    // Indian grouping: lakh after the thousands.
    expect(hi.photosSelectedCount(123456), contains('1,23,456'));
    expect(en.photosSelectedCount(1), '1 photo selected');
  });
}
