import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/event_repository.dart';
import '../../../../domain/models/event.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/form_validation.dart';

/// The add/edit event form's fields as typed.
class EventFormState {
  const EventFormState({
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

  /// A save, archive or delete is in progress; the buttons are disabled.
  final bool saving;

  EventFormState copyWith({
    String? name,
    String? description,
    String? emoji,
    bool? showErrors,
    bool? saving,
  }) => EventFormState(
    name: name ?? this.name,
    description: description ?? this.description,
    emoji: emoji ?? this.emoji,
    showErrors: showErrors ?? this.showErrors,
    saving: saving ?? this.saving,
  );
}

/// The add/edit event form (phase-1.md §8, §9.5), with archive/unarchive.
class EventFormCubit extends CubitSignal<EventFormState> {
  /// [original] is the event being edited, or null to add one. [existing]
  /// is every event, archived ones included, used to refuse a duplicate
  /// name.
  EventFormCubit({
    required this._repository,
    required this._l10n,
    required this.original,
    required List<Event> existing,
  }) : _otherNames = [
         for (final event in existing)
           if (event.id != original?.id) eventName(_l10n, event),
       ],
       super(
         initialState: EventFormState(
           // A built-in shows its localized name, ready to be renamed.
           name: original == null ? '' : eventName(_l10n, original),
           description: original?.description ?? '',
           emoji: original?.emoji ?? '',
         ),
       );

  final EventRepository _repository;
  final AppLocalizations _l10n;
  final Event? original;
  final List<String> _otherNames;

  bool get isEditing => original != null;

  NameError? get nameError =>
      value.showErrors ? validateName(value.name, _otherNames) : null;
  EmojiError? get emojiError =>
      value.showErrors ? validateEmoji(value.emoji) : null;
  DescriptionError? get descriptionError =>
      value.showErrors ? validateDescription(value.description) : null;

  /// The localized name of the built-in being edited, or null for the
  /// user's own events.
  String? get _builtinName => switch (original?.builtinKey) {
    final String key => eventBuiltinName(_l10n, key),
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

  /// Validates and saves. Returns the saved event, or null if a field is
  /// invalid (the errors are then shown) or a save is already running.
  /// Rethrows database errors; the screen tells the user.
  Future<Event?> save() async {
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
        Event(
          id: original.id,
          builtinKey: original.builtinKey,
          // A built-in whose name equals its localized name keeps NULL, so
          // it keeps following the language (phase-1.md §6).
          name: name == _builtinName ? null : name,
          description: description,
          emoji: emoji,
          archivedAt: original.archivedAt,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
        ),
      );
    } finally {
      _emitIfOpen(value.copyWith(saving: false));
    }
  }

  /// Archives the edited event, or brings it back if it is archived. Only
  /// the archive state changes; unsaved edits in the form are not saved.
  Future<void> toggleArchived() async {
    final original = this.original;
    if (original == null || value.saving) return;
    _emitIfOpen(value.copyWith(saving: true));
    try {
      await _repository.setArchived(original.id, !original.isArchived);
    } finally {
      _emitIfOpen(value.copyWith(saving: false));
    }
  }

  /// Deletes the edited event. Nothing can reference an event in Phase 1.
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

  // save(), toggleArchived() and delete() keep going across an await, and
  // the screen closes the cubit when it pops. Emitting after close() asserts.
  void _emitIfOpen(EventFormState state) {
    if (!isClosed) emit(state);
  }
}
