import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/event_repository.dart';
import '../../../../domain/models/event.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/emit_if_open.dart';

/// What the events screen shows. States don't override `==`, so every
/// emitted state reaches the screen.
sealed class EventListState {
  const EventListState();
}

final class EventListLoading extends EventListState {
  const EventListLoading();
}

final class EventListLoaded extends EventListState {
  const EventListLoaded({required this.active, required this.archived});

  /// Not archived, sorted by display name.
  final List<Event> active;

  /// Archived, sorted by display name. Shown in a collapsed section.
  final List<Event> archived;

  List<Event> get all => [...active, ...archived];
}

final class EventListFailed extends EventListState {
  const EventListFailed(this.error);

  final Object error;
}

/// Loads the events for the list screen, sorted by display name in the
/// current language and split into active and archived.
class EventListCubit extends CubitSignal<EventListState>
    with EmitIfOpen<EventListState> {
  EventListCubit({required this._repository, required this._l10n})
    : super(initialState: const EventListLoading());

  final EventRepository _repository;

  /// The language the names are sorted in, fixed for this screen's life.
  /// The in-app language switch is only reachable after popping the screen.
  /// With "System default", a device language change can reach it while
  /// open; the cards then show the new names in the old order until the
  /// next reload (after any edit). Harmless, so not handled.
  final AppLocalizations _l10n;

  /// Loads (or reloads) the list. A reload keeps showing the old list until
  /// the new one is ready, so the screen doesn't flash a spinner.
  Future<void> load() async {
    try {
      final events = await _repository.all();
      events.sort((a, b) {
        final byName = compareNames(eventName(_l10n, a), eventName(_l10n, b));
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
      emitIfOpen(
        EventListLoaded(
          active: [
            for (final e in events)
              if (!e.isArchived) e,
          ],
          archived: [
            for (final e in events)
              if (e.isArchived) e,
          ],
        ),
      );
    } catch (error) {
      emitIfOpen(EventListFailed(error));
    }
  }
}
