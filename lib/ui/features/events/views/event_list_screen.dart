import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/event_repository.dart';
import '../../../../domain/models/event.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/widgets/async_body.dart';
import '../../manage/views/manage_list_scaffold.dart';
import '../view_models/event_list_cubit.dart';
import 'event_form_screen.dart';

/// Every event, sorted by name, with archived ones in a collapsed section
/// at the bottom. Tap one to edit it; the button adds one.
class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key, required this.repository});

  final EventRepository repository;

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  // Created in didChangeDependencies because it needs the localizations.
  EventListCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= EventListCubit(
      repository: widget.repository,
      l10n: AppLocalizations.of(context),
    )..load();
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  Future<void> _openForm({Event? event, required List<Event> all}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EventFormScreen(
          repository: widget.repository,
          original: event,
          existing: all,
        ),
      ),
    );
    await _cubit?.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalBuilder<EventListCubit, EventListState>(
      bloc: _cubit!,
      builder: (context, state) => ManageListScaffold(
        title: l10n.eventsTitle,
        addLabel: l10n.addEvent,
        phase: switch (state) {
          EventListLoading() => LoadPhase.loading,
          EventListFailed() => LoadPhase.failed,
          EventListLoaded(:final active, :final archived)
              when active.isEmpty && archived.isEmpty =>
            LoadPhase.empty,
          EventListLoaded() => LoadPhase.loaded,
        },
        onRetry: () => _cubit?.load(),
        onAdd: () => _openForm(all: (state as EventListLoaded).all),
        emptyIcon: Icons.celebration_outlined,
        emptyText: l10n.listEmpty,
        builder: (context) {
          final EventListLoaded(:active, :archived, :all) =
              state as EventListLoaded;
          List<ItemCardData> cards(List<Event> events) => [
            for (final event in events)
              (
                key: event.id,
                emoji: event.emoji,
                title: eventName(l10n, event),
                description: event.description,
                badge: null,
                onTap: () => _openForm(event: event, all: all),
              ),
          ];
          return ItemCardGrid(
            items: cards(active),
            // Archived events in a collapsed part at the bottom.
            trailing: archived.isEmpty
                ? null
                : ExpansionTile(
                    title: Text(l10n.archivedSection(archived.length)),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [ItemCardColumns(items: cards(archived))],
                  ),
          );
        },
      ),
    );
  }
}
