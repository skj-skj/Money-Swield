import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/event_repository.dart';
import '../../../../domain/models/event.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/form_validation.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/emoji_picker_field.dart';
import '../../../core/widgets/save_error.dart';
import '../view_models/event_form_cubit.dart';

/// Adds an event, or edits [original] when it is set. Pops when saved,
/// archived/unarchived or deleted.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({
    super.key,
    required this.repository,
    required this.original,
    required this.existing,
  });

  final EventRepository repository;
  final Event? original;

  /// Every event, archived ones included, to refuse duplicate names.
  final List<Event> existing;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  // Created in didChangeDependencies because they need the localizations.
  EventFormCubit? _cubit;
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final cubit = EventFormCubit(
      repository: widget.repository,
      l10n: AppLocalizations.of(context),
      original: widget.original,
      existing: widget.existing,
    );
    _cubit = cubit;
    _name = TextEditingController(text: cubit.value.name);
    _description = TextEditingController(text: cubit.value.description);
  }

  @override
  void dispose() {
    _cubit?.close();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    Event? saved;
    await saveOrShowError(context, () async => saved = await _cubit!.save());
    if (saved != null && mounted) Navigator.pop(context);
  }

  Future<void> _toggleArchived() async {
    final done = await saveOrShowError(context, () => _cubit!.toggleArchived());
    if (done && mounted) Navigator.pop(context);
  }

  Future<void> _delete(String name) async {
    if (!await confirmDelete(context, name) || !mounted) return;
    final deleted = await saveOrShowError(context, () => _cubit!.delete());
    if (deleted && mounted) Navigator.pop(context);
  }

  void _resetName() {
    _cubit!.resetName();
    _name.text = _cubit!.value.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = _cubit!;
    final original = widget.original;
    return BlocSignalBuilder<EventFormCubit, EventFormState>(
      bloc: cubit,
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(cubit.isEditing ? l10n.editEvent : l10n.addEvent),
          actions: [
            TextButton(
              onPressed: state.saving ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EmojiPickerField(
              emoji: state.emoji,
              onChanged: cubit.emojiChanged,
              errorText: emojiErrorText(l10n, cubit.emojiError),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('name'),
              controller: _name,
              onChanged: cubit.nameChanged,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                errorText: nameErrorText(l10n, cubit.nameError, state.name),
                border: const OutlineInputBorder(),
              ),
            ),
            if (cubit.canResetName)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _resetName,
                  child: Text(l10n.resetToDefaultName),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('description'),
              controller: _description,
              onChanged: cubit.descriptionChanged,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.fieldDescription,
                errorText: descriptionErrorText(l10n, cubit.descriptionError),
                border: const OutlineInputBorder(),
              ),
            ),
            if (original != null) ...[
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: state.saving ? null : _toggleArchived,
                icon: Icon(
                  original.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(
                  original.isArchived ? l10n.unarchive : l10n.archive,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: state.saving
                    ? null
                    : () => _delete(eventName(l10n, original)),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.delete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
