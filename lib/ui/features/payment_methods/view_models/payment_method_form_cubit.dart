import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/form_validation.dart';
import '../../settings/view_models/settings_cubit.dart';

/// The add/edit payment method form's fields as typed. Payment methods
/// have no description.
class PaymentMethodFormState {
  const PaymentMethodFormState({
    required this.name,
    required this.emoji,
    this.showErrors = false,
    this.saving = false,
  });

  final String name;
  final String emoji;

  /// False until the first save attempt, so an empty new form isn't shown
  /// full of errors. After that, errors update as the user types.
  final bool showErrors;

  /// A save, delete or "set as default" is in progress; the buttons are
  /// disabled.
  final bool saving;

  PaymentMethodFormState copyWith({
    String? name,
    String? emoji,
    bool? showErrors,
    bool? saving,
  }) => PaymentMethodFormState(
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    showErrors: showErrors ?? this.showErrors,
    saving: saving ?? this.saving,
  );
}

/// The add/edit payment method form (phase-1.md §8, §9.5), with "Set as
/// default".
class PaymentMethodFormCubit extends CubitSignal<PaymentMethodFormState> {
  /// [original] is the method being edited, or null to add one. [existing]
  /// is every method, used to refuse a duplicate name.
  PaymentMethodFormCubit({
    required this._repository,
    required this._settings,
    required this._l10n,
    required this.original,
    required List<PaymentMethod> existing,
  }) : _otherNames = [
         for (final method in existing)
           if (method.id != original?.id) paymentMethodName(_l10n, method),
       ],
       super(
         initialState: PaymentMethodFormState(
           // A built-in shows its localized name, ready to be renamed.
           name: original == null ? '' : paymentMethodName(_l10n, original),
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

  final AppLocalizations _l10n;
  final PaymentMethod? original;
  final List<String> _otherNames;

  bool get isEditing => original != null;

  /// Whether the edited method is the current default. It can't be deleted
  /// then, and "Set as default" is hidden.
  bool get isDefault =>
      original != null &&
      _settings.value.defaultPaymentMethodId == original!.id;

  NameError? get nameError =>
      value.showErrors ? validateName(value.name, _otherNames) : null;
  EmojiError? get emojiError =>
      value.showErrors ? validateEmoji(value.emoji) : null;

  /// The localized name of the built-in being edited, or null for the
  /// user's own methods.
  String? get _builtinName => switch (original?.builtinKey) {
    final String key => paymentMethodBuiltinName(_l10n, key),
    null => null,
  };

  /// "Reset to default name" is offered for a built-in whose name field
  /// differs from its localized name.
  bool get canResetName {
    final builtinName = _builtinName;
    return builtinName != null && value.name.trim() != builtinName;
  }

  void nameChanged(String name) => _emitIfOpen(value.copyWith(name: name));

  void emojiChanged(String emoji) => _emitIfOpen(value.copyWith(emoji: emoji));

  /// Puts the localized built-in name back in the field. Saving then stores
  /// NULL, so the name follows the language again.
  void resetName() {
    final builtinName = _builtinName;
    if (builtinName != null) _emitIfOpen(value.copyWith(name: builtinName));
  }

  /// Validates and saves. Returns the saved method, or null if a field is
  /// invalid (the errors are then shown) or a save is already running.
  /// Rethrows database errors; the screen tells the user.
  Future<PaymentMethod?> save() async {
    final state = value;
    if (state.saving) return null;
    final hasErrors =
        validateName(state.name, _otherNames) != null ||
        validateEmoji(state.emoji) != null;
    if (hasErrors) {
      _emitIfOpen(state.copyWith(showErrors: true));
      return null;
    }

    _emitIfOpen(state.copyWith(saving: true));
    try {
      final name = state.name.trim();
      final emoji = state.emoji.trim();
      final original = this.original;
      if (original == null) {
        return await _repository.add(name: name, emoji: emoji);
      }
      return await _repository.update(
        PaymentMethod(
          id: original.id,
          builtinKey: original.builtinKey,
          // A built-in whose name equals its localized name keeps NULL, so
          // it keeps following the language (phase-1.md §6).
          name: name == _builtinName ? null : name,
          emoji: emoji,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
        ),
      );
    } finally {
      _emitIfOpen(value.copyWith(saving: false));
    }
  }

  /// Makes the edited method the default for new expenses.
  Future<void> setAsDefault() async {
    final original = this.original;
    if (original == null || value.saving) return;
    _emitIfOpen(value.copyWith(saving: true));
    try {
      await _settings.setDefaultPaymentMethodId(original.id);
    } finally {
      _emitIfOpen(value.copyWith(saving: false));
    }
  }

  /// Deletes the edited method. Throws `CannotDeleteDefault` for the
  /// default; the screen disables Delete then, so that only happens if the
  /// default changed in between.
  Future<void> delete() async {
    final original = this.original;
    if (original == null || value.saving) return;
    _emitIfOpen(value.copyWith(saving: true));
    try {
      await _repository.delete(original.id);
    } finally {
      _emitIfOpen(value.copyWith(saving: false));
    }
  }

  /// How many expenses use the edited payment method, binned ones included.
  Future<({int active, int binned})> usage() => _repository.usage(original!.id);

  /// Moves the edited payment method's expenses to [toId] and deletes it, in one
  /// transaction (D7).
  Future<void> moveExpensesAndDelete(int toId) async {
    final original = this.original;
    if (original == null || value.saving) return;
    _emitIfOpen(value.copyWith(saving: true));
    try {
      await _repository.moveExpensesAndDelete(original.id, toId: toId);
    } finally {
      _emitIfOpen(value.copyWith(saving: false));
    }
  }

  // save(), setAsDefault() and delete() keep going across an await, and the
  // screen closes the cubit when it pops. Emitting after close() asserts.
  void _emitIfOpen(PaymentMethodFormState state) {
    if (!isClosed) emit(state);
  }
}
