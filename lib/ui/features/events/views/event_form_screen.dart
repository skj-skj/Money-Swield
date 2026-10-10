import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/event_repository.dart';
import '../../../../domain/models/event.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/save_error.dart';
import '../../manage/views/item_form_scaffold.dart';
import '../view_models/event_form_cubit.dart';

/// Adds an event, or edits [original] when it is set. Pops when saved
/// (with the saved event), archived/unarchived or deleted.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({
    super.key,
    required this.repository,
    required this.original,
    required this.existing,
    this.initialName = '',
  });

  final EventRepository repository;
  final Event? original;

  /// Every event, archived ones included, to refuse duplicate names.
  final List<Event> existing;

  /// The name a new event starts with; ignored when editing.
  final String initialName;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  // Created in didChangeDependencies because it needs the localizations.
  EventFormCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= EventFormCubit(
      repository: widget.repository,
      l10n: AppLocalizations.of(context),
      original: widget.original,
      existing: widget.existing,
      initialName: widget.initialName,
    );
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  Future<void> _toggleArchived() async {
    final done = await saveOrShowError(context, () => _cubit!.toggleArchived());
    if (done && mounted) Navigator.pop(context);
  }

  /// Delete: the confirmation says how many expenses and recurring items
  /// lose the event; they themselves stay (phase-2.md §10.2, phase-7a.md
  /// R3).
  Future<void> _delete(String name) async {
    final l10n = AppLocalizations.of(context);
    var usage = (expenses: 0, templates: 0);
    final read = await saveOrShowError(
      context,
      () async => usage = await _cubit!.usage(),
    );
    if (!read || !mounted) return;
    final message = [
      if (usage.expenses > 0) l10n.eventDeleteWithCount(usage.expenses),
      if (usage.templates > 0) l10n.eventDeleteTemplates(usage.templates),
    ].join(' ');
    final confirmed = await confirmDelete(
      context,
      name,
      message: message.isEmpty ? null : message,
    );
    if (!confirmed || !mounted) return;
    final deleted = await saveOrShowError(context, () => _cubit!.delete());
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = _cubit!;
    return ItemFormScaffold<Event>(
      cubit: cubit,
      title: cubit.isEditing ? l10n.editEvent : l10n.addEvent,
      actions: (context, state) {
        final original = widget.original!;
        return [
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: state.saving ? null : _toggleArchived,
            icon: Icon(
              original.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
            label: Text(original.isArchived ? l10n.unarchive : l10n.archive),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: state.saving
                ? null
                : () => _delete(eventName(l10n, original)),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.delete),
          ),
        ];
      },
    );
  }
}
