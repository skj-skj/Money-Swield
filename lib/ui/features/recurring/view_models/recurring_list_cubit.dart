import 'package:bloc_signals/bloc_signals.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/data_version.dart';
import '../../../../data/repositories/expense_draft_repository.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/expense_draft.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../core/builtin_names.dart';
import '../../../core/emit_if_open.dart';

/// The three groups of Manage → Recurring, one tile each at the top of the
/// screen with its count (owner, 2026-10-09: the Archive as a row under a
/// long list was hard to reach).
enum RecurringSection { waiting, active, archived }

/// What Manage → Recurring shows. States don't override `==`, so every
/// emitted state reaches the screen.
sealed class RecurringListState {
  const RecurringListState();
}

final class RecurringListLoading extends RecurringListState {
  const RecurringListLoading();
}

final class RecurringListFailed extends RecurringListState {
  const RecurringListFailed(this.error);

  final Object error;
}

final class RecurringListLoaded extends RecurringListState {
  const RecurringListLoaded({
    required this.waiting,
    required this.active,
    required this.archived,
    required this.categories,
    required this.section,
  });

  /// Held items, by title.
  final List<RecurringItem> waiting;

  /// The other running ones, by next payment, then title; those with none
  /// left last.
  final List<RecurringItem> active;

  /// Stopped and expired ones, newest archived first.
  final List<RecurringItem> archived;

  /// By id, for each row's emoji.
  final Map<int, Category> categories;

  /// The tile chosen: its items are listed under the tiles.
  final RecurringSection section;

  List<RecurringItem> itemsOf(RecurringSection s) => switch (s) {
    RecurringSection.waiting => waiting,
    RecurringSection.active => active,
    RecurringSection.archived => archived,
  };

  List<RecurringItem> get shown => itemsOf(section);

  /// Nothing at all: the screen says how to start, without tiles.
  bool get isEmpty => waiting.isEmpty && active.isEmpty && archived.isEmpty;

  RecurringListLoaded withSection(RecurringSection section) =>
      RecurringListLoaded(
        waiting: waiting,
        active: active,
        archived: archived,
        categories: categories,
        section: section,
      );
}

/// Manage → Recurring: every item, in three sections (Waiting, Active, Archive)
/// the screen switches between.
class RecurringListCubit extends CubitSignal<RecurringListState>
    with EmitIfOpen<RecurringListState> {
  RecurringListCubit({
    required this._recurring,
    required this._categories,
    required this._drafts,
    required this._dataVersion,
  }) : super(initialState: const RecurringListLoading());

  final RecurringRepository _recurring;
  final CategoryRepository _categories;
  final ExpenseDraftRepository _drafts;
  final DataVersion _dataVersion;

  /// `DataVersion.value` when the rows shown were read.
  int? _loadedVersion;

  /// The tile the user picked; null until they pick one.
  RecurringSection? _chosen;

  Future<void> load() async {
    try {
      final version = _dataVersion.value;
      final running = await _recurring.all();
      final archived = await _recurring.archived();
      final categories = {for (final c in await _categories.all()) c.id: c};
      _loadedVersion = version;
      final waiting = sortedWaiting(running);
      emitIfOpen(
        RecurringListLoaded(
          waiting: waiting,
          active: sortedActive(running),
          archived: archived,
          categories: categories,
          section: _chosen ?? defaultSection(waiting),
        ),
      );
    } catch (error) {
      // A failed reload keeps the rows on screen.
      if (value is! RecurringListLoaded) emitIfOpen(RecurringListFailed(error));
    }
  }

  /// A tile was tapped: its items are listed, also after reloads.
  void select(RecurringSection section) {
    _chosen = section;
    final loaded = value;
    if (loaded is RecurringListLoaded && loaded.section != section) {
      emitIfOpen(loaded.withSection(section));
    }
  }

  /// Back from a page or the form: reads again only if something was
  /// written.
  Future<void> reloadIfChanged() async {
    if (_dataVersion.value != _loadedVersion) await load();
  }

  /// The draft slot, for New: an Add draft opens as it is.
  Future<ExpenseDraft?> pendingDraft() => _drafts.read();
}

/// The section shown until the user picks one: Waiting while anything
/// waits for a decision, else Active.
RecurringSection defaultSection(List<RecurringItem> waiting) =>
    waiting.isEmpty ? RecurringSection.active : RecurringSection.waiting;

/// Held items by title.
List<RecurringItem> sortedWaiting(List<RecurringItem> items) =>
    [
      for (final i in items)
        if (i.hold != null) i,
    ]..sort((a, b) {
      final byTitle = compareNames(a.title, b.title);
      return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
    });

/// The others by next payment, then title; no payment left (and broken
/// items) last.
List<RecurringItem> sortedActive(List<RecurringItem> items) =>
    [
      for (final i in items)
        if (i.hold == null) i,
    ]..sort((a, b) {
      final an = a.isBroken ? null : a.nextDueOn;
      final bn = b.isBroken ? null : b.nextDueOn;
      if (an != bn) {
        if (an == null) return 1;
        if (bn == null) return -1;
        return an.compareTo(bn);
      }
      final byTitle = compareNames(a.title, b.title);
      return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
    });
