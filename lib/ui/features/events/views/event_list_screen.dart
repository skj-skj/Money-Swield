import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/event_repository.dart';
import '../../../../domain/models/event.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/widgets/item_card.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/two_column_masonry.dart';
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
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text(l10n.eventsTitle)),
        floatingActionButton: state is EventListLoaded
            ? FloatingActionButton.extended(
                onPressed: () => _openForm(all: state.all),
                icon: const Icon(Icons.add),
                label: Text(l10n.addEvent),
              )
            : null,
        body: switch (state) {
          EventListLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          EventListFailed() => LoadFailedView(onRetry: () => _cubit?.load()),
          EventListLoaded(:final active, :final archived)
              when active.isEmpty && archived.isEmpty =>
            Center(child: Text(l10n.listEmpty)),
          EventListLoaded(:final active, :final archived, :final all) =>
            SingleChildScrollView(
              // Room for the floating button under the last row.
              padding: const EdgeInsets.only(top: 12, bottom: 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _EventGrid(
                      events: active,
                      onTap: (event) => _openForm(event: event, all: all),
                    ),
                  ),
                  if (archived.isNotEmpty)
                    ExpansionTile(
                      title: Text(l10n.archivedSection(archived.length)),
                      childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      children: [
                        _EventGrid(
                          events: archived,
                          onTap: (event) => _openForm(event: event, all: all),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        },
      ),
    );
  }
}

class _EventGrid extends StatelessWidget {
  const _EventGrid({required this.events, required this.onTap});

  final List<Event> events;
  final void Function(Event event) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TwoColumnMasonry(
      children: [
        for (final event in events)
          ItemCard(
            emoji: event.emoji,
            title: eventName(l10n, event),
            description: event.description,
            onTap: () => onTap(event),
          ),
      ],
    );
  }
}
