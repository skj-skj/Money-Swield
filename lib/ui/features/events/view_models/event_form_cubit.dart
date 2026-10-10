import '../../../../data/repositories/event_repository.dart';
import '../../../../domain/models/event.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../manage/view_models/item_form_cubit.dart';

/// The add/edit event form (phase-1.md §8, §9.5): the shared form
/// ([ItemFormCubit]) plus archive / unarchive and delete.
class EventFormCubit extends ItemFormCubit<Event> {
  /// [original] is the event being edited, or null to add one. [existing]
  /// is every event, archived ones included, used to refuse a duplicate
  /// name.
  EventFormCubit({
    required this._repository,
    required AppLocalizations l10n,
    required super.original,
    required List<Event> existing,
    // Only used when adding: the expense form's picker passes its search
    // text, so "chai" isn't typed twice (phase-2.md §6.4).
    String initialName = '',
  }) : super(
         otherNames: [
           for (final event in existing)
             if (event.id != original?.id) eventName(l10n, event),
         ],
         builtinName: switch (original?.builtinKey) {
           final String key => eventBuiltinName(l10n, key),
           null => null,
         },
         hasDescription: true,
         initialState: ItemFormState(
           // A built-in shows its localized name, ready to be renamed.
           name: original == null ? initialName : eventName(l10n, original),
           description: original?.description ?? '',
           emoji: original?.emoji ?? '',
         ),
       );

  final EventRepository _repository;

  @override
  Future<Event> addItem({
    required String name,
    required String? description,
    required String emoji,
  }) => _repository.add(name: name, description: description, emoji: emoji);

  @override
  Future<Event> updateItem(
    Event original, {
    required String? name,
    required String? description,
    required String emoji,
  }) => _repository.update(
    Event(
      id: original.id,
      builtinKey: original.builtinKey,
      name: name,
      description: description,
      emoji: emoji,
      archivedAt: original.archivedAt,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
    ),
  );

  /// Archives the edited event, or brings it back if it is archived. Only
  /// the archive state changes; unsaved edits in the form are not saved.
  Future<void> toggleArchived() => runBusy(
    (original) => _repository.setArchived(original.id, !original.isArchived),
  );

  /// How many expenses and recurring items have the edited event, binned
  /// and archived ones included. Shown in the delete confirmation.
  Future<({int expenses, int templates})> usage() =>
      _repository.usage(original!.id);

  /// Deletes the edited event. Its links cascade; the expenses stay.
  Future<void> delete() =>
      runBusy((original) => _repository.delete(original.id));
}
