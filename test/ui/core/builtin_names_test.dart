import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/data/repositories/category_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/event_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/payment_method_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/settings_repository.dart';
import 'package:my_expense_tracker_app/domain/models/category.dart';
import 'package:my_expense_tracker_app/ui/core/builtin_names.dart';

import '../../helpers/test_database.dart';

void main() {
  // Checked against the seeded rows, not a hand-written list, so a new seed
  // without a translation fails here instead of showing its raw key.
  group('every seeded built-in has its own name in every language', () {
    for (final code in supportedLanguageCodes) {
      test(code, () async {
        final db = await openMigratedDatabase();
        final l10n = l10nFor(code);
        final names = {
          for (final c in await CategoryRepository(db).all())
            'category ${c.builtinKey}': categoryName(l10n, c),
          for (final e in await EventRepository(db).all())
            'event ${e.builtinKey}': eventName(l10n, e),
          for (final m in await PaymentMethodRepository(
            db,
            settings: SettingsRepository(db, deviceCurrency: 'INR'),
          ).all())
            'payment method ${m.builtinKey}': paymentMethodName(l10n, m),
        };

        names.forEach((what, name) {
          expect(name.trim(), isNotEmpty, reason: what);
          expect(
            what.endsWith(' $name'),
            isFalse,
            reason: '$what shows its raw key',
          );
        });
        final categoryNames = [
          for (final e in names.entries)
            if (e.key.startsWith('category')) e.value.toLowerCase(),
        ];
        expect(
          categoryNames.toSet(),
          hasLength(categoryNames.length),
          reason: 'two categories share a name',
        );
      });
    }
  });

  group('display name', () {
    final l10n = l10nFor('en');
    Category category({String? builtinKey, String? name}) => Category(
      id: 1,
      builtinKey: builtinKey,
      name: name,
      description: null,
      emoji: '📦',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    test('the user\'s own name wins over the built-in name', () {
      expect(
        categoryName(l10n, category(builtinKey: 'food', name: 'Khana')),
        'Khana',
      );
    });

    test('a built-in without a name follows the language', () {
      expect(categoryName(l10n, category(builtinKey: 'food')), 'Food');
      expect(
        categoryName(l10nFor('es'), category(builtinKey: 'food')),
        'Comida',
      );
      expect(categoryName(l10nFor('hi'), category(builtinKey: 'food')), 'खाना');
    });

    test(
      'an unknown key from a newer app shows the key instead of crashing',
      () {
        expect(categoryName(l10n, category(builtinKey: 'pets')), 'pets');
        expect(eventBuiltinName(l10n, 'graduation'), 'graduation');
        expect(paymentMethodBuiltinName(l10n, 'crypto'), 'crypto');
      },
    );

    test('keys are per table: a category key is unknown to events', () {
      expect(eventBuiltinName(l10n, 'food'), 'food');
      expect(paymentMethodBuiltinName(l10n, 'trip'), 'trip');
    });
  });
}
