import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/owner_usage.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../manage/view_models/item_form_cubit.dart';
import '../../settings/view_models/settings_cubit.dart';

/// The add/edit payment method form: the shared form ([ItemFormCubit], without
/// a description) plus "Set as default", delete, or move the expenses then
/// delete.
class PaymentMethodFormCubit extends ItemFormCubit<PaymentMethod> {
  /// [original] is the method being edited, or null to add one. [existing]
  /// is every method, used to refuse a duplicate name.
  PaymentMethodFormCubit({
    required this._repository,
    required this._settings,
    required AppLocalizations l10n,
    required super.original,
    required List<PaymentMethod> existing,
  }) : super(
         otherNames: [
           for (final method in existing)
             if (method.id != original?.id) paymentMethodName(l10n, method),
         ],
         builtinName: switch (original?.builtinKey) {
           final String key => paymentMethodBuiltinName(l10n, key),
           null => null,
         },
         hasDescription: false,
         initialState: ItemFormState(
           // A built-in shows its localized name, ready to be renamed.
           name: original == null ? '' : paymentMethodName(l10n, original),
           description: '',
           emoji: original?.emoji ?? '',
         ),
       );

  final PaymentMethodRepository _repository;

  /// Holds which method is the default, and sets it.
  ///
  /// The cubit, not `SettingsRepository`, on purpose: it is the one owner
  /// of the settings the app shows, so "Set as default" updates the badge
  /// on the list and the Settings tab at once through its write-then-emit.
  final SettingsCubit _settings;

  /// Whether the edited method is the current default. It can't be deleted
  /// then, and "Set as default" is hidden.
  bool get isDefault =>
      original != null &&
      _settings.value.defaultPaymentMethodId == original!.id;

  @override
  Future<PaymentMethod> addItem({
    required String name,
    required String? description,
    required String emoji,
  }) => _repository.add(name: name, emoji: emoji);

  @override
  Future<PaymentMethod> updateItem(
    PaymentMethod original, {
    required String? name,
    required String? description,
    required String emoji,
  }) => _repository.update(
    PaymentMethod(
      id: original.id,
      builtinKey: original.builtinKey,
      name: name,
      emoji: emoji,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
    ),
  );

  /// Makes the edited method the default for new expenses.
  Future<void> setAsDefault() =>
      runBusy((original) => _settings.setDefaultPaymentMethodId(original.id));

  /// Deletes the edited method. Throws `CannotDeleteDefault` for the
  /// default; the screen disables Delete then, so that only happens if the
  /// default changed in between.
  Future<void> delete() =>
      runBusy((original) => _repository.delete(original.id));

  /// How many expenses use the edited payment method, binned ones included.
  Future<OwnerUsage> usage() => _repository.usage(original!.id);

  /// Moves the edited payment method's expenses to [toId] and deletes it, in
  /// one transaction.
  Future<void> moveExpensesAndDelete(int toId) => runBusy(
    (original) => _repository.moveExpensesAndDelete(original.id, toId: toId),
  );
}
