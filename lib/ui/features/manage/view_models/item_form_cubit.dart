import 'package:bloc_signals/bloc_signals.dart';

import '../../../core/emit_if_open.dart';
import '../../../core/form_validation.dart';

/// The add/edit form's fields as typed, for a category, an event or a
/// payment method (payment methods have no description).
class ItemFormState {
  const ItemFormState({
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

  /// A save, delete, archive or "set as default" is in progress; the
  /// buttons are disabled.
  final bool saving;

  ItemFormState copyWith({
    String? name,
    String? description,
    String? emoji,
    bool? showErrors,
    bool? saving,
  }) => ItemFormState(
    name: name ?? this.name,
    description: description ?? this.description,
    emoji: emoji ?? this.emoji,
    showErrors: showErrors ?? this.showErrors,
    saving: saving ?? this.saving,
  );
}

/// What the Manage forms share: name, emoji and (optional) description,
/// validation with a duplicate-name check, "Reset to default name" for a
/// built-in, and saving through a template the subclass completes ([addItem],
/// [updateItem]). The subclass adds its own actions (delete, move then delete,
/// archive, set as default) with [runBusy].
///
/// [T] is the item: `Category`, `Event` or `PaymentMethod`.
abstract class ItemFormCubit<T> extends CubitSignal<ItemFormState>
    with EmitIfOpen<ItemFormState> {
  /// [original] is the item being edited, or null to add one. `otherNames`
  /// are the display names of every other item, to refuse a duplicate.
  /// `builtinName` is the localized name of the built-in being edited, or
  /// null for the user's own items.
  ItemFormCubit({
    required this.original,
    required this._otherNames,
    required this._builtinName,
    required super.initialState,
    required this.hasDescription,
  });

  final T? original;
  final List<String> _otherNames;
  final String? _builtinName;

  /// Payment methods have no description.
  final bool hasDescription;

  bool get isEditing => original != null;

  NameError? get nameError =>
      value.showErrors ? validateName(value.name, _otherNames) : null;
  EmojiError? get emojiError =>
      value.showErrors ? validateEmoji(value.emoji) : null;
  DescriptionError? get descriptionError => value.showErrors && hasDescription
      ? validateDescription(value.description)
      : null;

  /// "Reset to default name" is offered for a built-in whose name field
  /// differs from its localized name.
  bool get canResetName {
    final builtinName = _builtinName;
    return builtinName != null && value.name.trim() != builtinName;
  }

  void nameChanged(String name) => emitIfOpen(value.copyWith(name: name));

  void descriptionChanged(String description) =>
      emitIfOpen(value.copyWith(description: description));

  void emojiChanged(String emoji) => emitIfOpen(value.copyWith(emoji: emoji));

  /// Puts the localized built-in name back in the field. Saving then stores
  /// NULL, so the name follows the language again.
  void resetName() {
    final builtinName = _builtinName;
    if (builtinName != null) emitIfOpen(value.copyWith(name: builtinName));
  }

  /// Inserts a new item.
  Future<T> addItem({
    required String name,
    required String? description,
    required String emoji,
  });

  /// Saves [original] with the new fields. [name] is null for a built-in whose
  /// name equals its localized name, so it keeps following the language.
  Future<T> updateItem(
    T original, {
    required String? name,
    required String? description,
    required String emoji,
  });

  /// Validates and saves. Returns the saved item, or null if a field is
  /// invalid (the errors are then shown) or a save is already running.
  /// Rethrows database errors; the screen tells the user.
  Future<T?> save() async {
    final state = value;
    if (state.saving) return null;
    final hasErrors =
        validateName(state.name, _otherNames) != null ||
        validateEmoji(state.emoji) != null ||
        (hasDescription && validateDescription(state.description) != null);
    if (hasErrors) {
      emitIfOpen(state.copyWith(showErrors: true));
      return null;
    }

    emitIfOpen(state.copyWith(saving: true));
    try {
      final name = state.name.trim();
      final description = hasDescription
          ? descriptionToStore(state.description)
          : null;
      final emoji = state.emoji.trim();
      final original = this.original;
      if (original == null) {
        return await addItem(
          name: name,
          description: description,
          emoji: emoji,
        );
      }
      return await updateItem(
        original,
        name: name == _builtinName ? null : name,
        description: description,
        emoji: emoji,
      );
    } finally {
      emitIfOpen(value.copyWith(saving: false));
    }
  }

  /// Runs [action] on the edited item while showing it busy (buttons
  /// disabled). Does nothing when adding, or while something else runs.
  /// Rethrows; the screen tells the user.
  Future<void> runBusy(Future<void> Function(T original) action) async {
    final original = this.original;
    if (original == null || value.saving) return;
    emitIfOpen(value.copyWith(saving: true));
    try {
      await action(original);
    } finally {
      emitIfOpen(value.copyWith(saving: false));
    }
  }
}
