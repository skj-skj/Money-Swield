import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/app/app_dependencies.dart';
import 'package:money_swield/data/repositories/payment_method_repository.dart';
import 'package:money_swield/domain/models/app_settings.dart';
import 'package:money_swield/domain/models/payment_method.dart';
import 'package:money_swield/l10n/app_localizations.dart';
import 'package:money_swield/ui/core/form_validation.dart';
import 'package:money_swield/ui/features/payment_methods/view_models/payment_method_form_cubit.dart';
import 'package:money_swield/ui/features/settings/view_models/settings_cubit.dart';

import '../../../../helpers/test_database.dart';

/// Validation itself is covered in depth by the category form tests (same
/// rules, shared code). These focus on the default payment method.
void main() {
  late AppDependencies deps;
  late SettingsCubit settings;
  late List<PaymentMethod> existing;

  setUp(() async {
    deps = await openTestDependencies();
    settings = SettingsCubit(initial: AppSettings.beforeLoad);
    addTearDown(settings.close);
    await settings.load(deps.settings);
    existing = await deps.paymentMethods.all();
  });

  PaymentMethodFormCubit formFor({
    PaymentMethod? original,
    AppLocalizations? l10n,
  }) {
    final cubit = PaymentMethodFormCubit(
      repository: deps.paymentMethods,
      settings: settings,
      l10n: l10n ?? l10nFor('en'),
      original: original,
      existing: existing,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  PaymentMethod builtin(String key) =>
      existing.firstWhere((m) => m.builtinKey == key);

  test('cash is the default on a fresh install', () {
    expect(formFor(original: builtin('cash')).isDefault, isTrue);
    expect(formFor(original: builtin('upi')).isDefault, isFalse);
    expect(
      formFor().isDefault,
      isFalse,
      reason: 'a new method is never the default',
    );
  });

  test(
    '"Set as default" moves the default, so the old one becomes deletable',
    () async {
      final upiForm = formFor(original: builtin('upi'));
      await upiForm.setAsDefault();
      expect(upiForm.isDefault, isTrue);
      expect(settings.value.defaultPaymentMethodId, builtin('upi').id);

      final cashForm = formFor(original: builtin('cash'));
      expect(cashForm.isDefault, isFalse);
      await cashForm.delete();
      expect(
        (await deps.paymentMethods.all()).any((m) => m.builtinKey == 'cash'),
        isFalse,
      );
    },
  );

  test(
    'deleting the default is refused even if the screen let it through',
    () async {
      final cubit = formFor(original: builtin('cash'));
      await expectLater(cubit.delete(), throwsA(isA<CannotDeleteDefault>()));
      expect(cubit.value.saving, isFalse);
      expect(await deps.paymentMethods.all(), hasLength(4));
    },
  );

  test('a duplicate of a translated built-in is refused (Hindi)', () async {
    final cubit = formFor(l10n: l10nFor('hi'))
      ..nameChanged('नकद')
      ..emojiChanged('💵');
    expect(await cubit.save(), isNull);
    expect(cubit.nameError, NameError.duplicate);
  });

  test('renaming the default keeps it the default', () async {
    final saved = await (formFor(
      original: builtin('cash'),
    )..nameChanged('Nakad')).save();
    expect(saved!.name, 'Nakad');
    expect(settings.value.defaultPaymentMethodId, saved.id);
  });

  test(
    'UPI keeps NULL when saved with its unchanged name in every language',
    () async {
      for (final code in ['en', 'es', 'hi']) {
        existing = await deps.paymentMethods.all();
        final saved = await formFor(
          original: builtin('upi'),
          l10n: l10nFor(code),
        ).save();
        expect(saved!.name, isNull, reason: code);
      }
    },
  );
}
