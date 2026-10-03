import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/form_validation.dart';

/// The add/edit category form's fields as typed.
class CategoryFormState {
  const CategoryFormState({
    required this.name,
    required this.description,
    required this.emoji,
    this.showErrors = false,
    this.saving = false,
  });

  final String name;
  final String description;
  final String emoji;

  /// False until the first save attempt, so an empty new form isn't shown
  /// full of errors. After that, errors update as the user types.
  final bool showErrors;

  /// A save or delete is in progress; the buttons are disabled.
  final bool saving;

  CategoryFormState copyWith({
    String? name,
    String? description,
    String? emoji,
    bool? showErrors,
    bool? saving,
  }) => CategoryFormState(
    name: name ?? this.name,
    description: description ?? this.description,
    emoji: emoji ?? this.emoji,
    showErrors: showErrors ?? this.showErrors,
    saving: saving ?? this.saving,
  );
}

/// The add/edit category form (phase-1.md §8, §9.5).
class CategoryFormCubit extends CubitSignal<CategoryFormState> {
  /// [original] is the category being edited, or null to add one.
  /// [existing] is every category (the list screen already has them), used
  /// to refuse a duplicate name.
  CategoryFormCubit({
    required this._repository,
    required this._l10n,
    required this.original,
    required List<Category> existing,
    // Only used when adding: the expense form's picker passes its search
    // text, so "chai" isn't typed twice (phase-2.md §6.4).
    String initialName = '',
  }) : _otherNames = [
         for (final category in existing)
           if (category.id != original?.id) categoryName(_l10n, category),
       ],
       super(
         initialState: CategoryFormState(
           // A built-in shows its localized name, ready to be renamed.
           name: original == null ? initialName : categoryName(_l10n, original),
           description: original?.description ?? '',
           emoji: original?.emoji ?? '',
         ),
       );

  final CategoryRepository _repository;
  final AppLocalizations _l10n;
  final Category? original;
  final List<String> _otherNames;

  bool get isEditing => original != null;

  NameError? get nameError =>
      value.showErrors ? validateName(value.name, _otherNames) : null;
  EmojiError? get emojiError =>
      value.showErrors ? validateEmoji(value.emoji) : null;
  DescriptionError? get descriptionError =>
      value.showErrors ? validateDescription(value.description) : null;

  /// The localized name of the built-in being edited, or null for the
  /// user's own categories.
  String? get _builtinName => switch (original?.builtinKey) {
    final String key => categoryBuiltinName(_l10n, key),
    null => null,
  };

  /// "Reset to default name" is offered for a built-in whose name field
  /// differs from its localized name.
  bool get canResetName {
    final builtinName = _builtinName;
    return builtinName != null && value.name.trim() != builtinName;
  }

  void nameChanged(String name) => _emitIfOpen(value.copyWith(name: name));

  void descriptionChanged(String description) =>
      _emitIfOpen(value.copyWith(description: description));

  void emojiChanged(String emoji) => _emitIfOpen(value.copyWith(emoji: emoji));

  /// Puts the localized built-in name back in the field. Saving then stores
  /// NULL, so the name follows the language again.
  void resetName() {
    final builtinName = _builtinName;
    if (builtinName != null) _emitIfOpen(value.copyWith(name: builtinName));
  }

  /// Validates and saves. Returns the saved category, or null if a field is
  /// invalid (the errors are then shown) or a save is already running.
  /// Rethrows database errors; the screen tells the user.
  Future<Category?> save() async {
    final state = value;
    if (state.saving) return null;
    final hasErrors =
        validateName(state.name, _otherNames) != null ||
        validateEmoji(state.emoji) != null ||
        validateDescription(state.description) != null;
    if (hasErrors) {
      _emitIfOpen(state.copyWith(showErrors: true));
      return null;
    }

    _emitIfOpen(state.copyWith(saving: true));
    try {
      final name = state.name.trim();
      final description = descriptionToStore(state.description);
      final emoji = state.emoji.trim();
      final original = this.original;
      if (original == null) {
        return await _repository.add(
          name: name,
          description: description,
          emoji: emoji,
        );
      }
      return await _repository.update(
        Category(
          id: original.id,
          builtinKey: original.builtinKey,
          // A built-in whose name equals its localized name keeps NULL, so
          // it keeps following the language (phase-1.md §6).
          name: name == _builtinName ? null : name,
          description: description,
          emoji: emoji,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
        ),
      );
    } finally {
      _emitIfOpen(value.copyWith(saving: false));
    }
  }

  /// Deletes the category being edited. Only for an unused one: a used one
  /// goes through [moveExpensesAndDelete] (the FK would refuse it anyway).
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

  /// How many expenses use the edited category, binned ones included.
  Future<({int active, int binned})> usage() => _repository.usage(original!.id);

  /// Moves the edited category's expenses to [toId] and deletes it, in one
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

  // save() and delete() keep going across an await, and the screen closes
  // the cubit when it pops. Emitting after close() asserts in debug mode.
  void _emitIfOpen(CategoryFormState state) {
    if (!isClosed) emit(state);
  }
}
