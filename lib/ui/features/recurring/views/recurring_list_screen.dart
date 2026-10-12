import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/expense_tile.dart';
import '../../../core/widgets/section_tile.dart';
import '../../expenses/expense_form_opener.dart';
import '../view_models/recurring_list_cubit.dart';
import 'recurring_navigation.dart';
import 'recurring_texts.dart';

/// Manage → Recurring: three tiles, Waiting · Active · Archive, each with its
/// count; the chosen one's items are listed under them (owner, 2026-10-09: the
/// Archive as a row under a long list was hard to reach). **New** opens the Add
/// form with Repeats on.
class RecurringListScreen extends StatefulWidget {
  const RecurringListScreen({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<RecurringListScreen> createState() => _RecurringListScreenState();
}

class _RecurringListScreenState extends State<RecurringListScreen> {
  late final _cubit = RecurringListCubit(
    recurring: widget.dependencies.recurring,
    categories: widget.dependencies.categories,
    drafts: widget.dependencies.drafts,
    dataVersion: widget.dependencies.dataVersion,
  )..load();

  /// New goes through the form opener: an Add draft in the slot opens as it is
  /// (Repeats on only if it has none), and a double tap opens one form.
  late final _opener = ExpenseFormOpener(
    dependencies: widget.dependencies,
    pendingDraft: _cubit.pendingDraft,
  );

  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  String get _today => todayOn(widget.dependencies.now());

  Future<void> _new() async {
    final (:opened, :result) = await _opener.open(
      context,
      startRepeating: true,
    );
    if (!opened || !mounted) return;
    await _cubit.reloadIfChanged();
    if (!mounted) return;
    showExpenseFormResult(
      _messenger.currentState,
      AppLocalizations.of(context),
      result,
      onUndoBin: (_) {},
    );
  }

  /// An item's page (read-only for an archived one); back here, read again
  /// if anything changed, and say what the page did.
  Future<void> _open(int id) async {
    final result = await openRecurringPage(context, widget.dependencies, id);
    await _cubit.reloadIfChanged();
    if (!mounted) return;
    showRecurringPageResult(
      _messenger.currentState,
      AppLocalizations.of(context),
      dateLocaleOf(context),
      result,
      today: _today,
      onUndoStop: (undo) =>
          undoStopOrSay(_scaffold.currentContext ?? context, () async {
            final done = await widget.dependencies.recurring.undoArchive(undo);
            await _cubit.load();
            return done;
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        key: _scaffold,
        appBar: AppBar(
          title: Text(l10n.recurringTitle),
          actions: [
            IconButton(
              key: const ValueKey('newRecurring'),
              icon: const Icon(Icons.add),
              tooltip: l10n.newRecurring,
              onPressed: _new,
            ),
          ],
        ),
        body: BlocSignalBuilder<RecurringListCubit, RecurringListState>(
          bloc: _cubit,
          builder: (context, state) => AsyncBody(
            phase: switch (state) {
              RecurringListLoading() => LoadPhase.loading,
              RecurringListFailed() => LoadPhase.failed,
              RecurringListLoaded(:final isEmpty) when isEmpty =>
                LoadPhase.empty,
              RecurringListLoaded() => LoadPhase.loaded,
            },
            onRetry: _cubit.load,
            empty: EmptyStateView(
              icon: Icons.repeat,
              title: l10n.recurringTitle,
              message: l10n.recurringEmpty,
            ),
            builder: (context) => _list(state as RecurringListLoaded),
          ),
        ),
      ),
    );
  }

  Widget _list(RecurringListLoaded state) {
    final shown = state.shown;
    // The tiles stay put above the list: with many items, the Archive is
    // still one tap away (on the Oppo they scrolled away with 59 rows).
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, section) in RecurringSection.values.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _tile(state, section)),
              ],
            ],
          ),
        ),
        Expanded(child: _rows(state, shown)),
      ],
    );
  }

  /// The chosen section's rows; each section keeps its own scroll position.
  Widget _rows(RecurringListLoaded state, List<RecurringItem> shown) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: PageStorageKey(state.section),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              switch (state.section) {
                RecurringSection.waiting => l10n.recurringNoneWaiting,
                RecurringSection.active => l10n.recurringNoneActive,
                RecurringSection.archived => l10n.recurringNoneArchived,
              },
              key: const ValueKey('sectionEmpty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final item in shown) _row(state, item),
      ],
    );
  }

  Widget _tile(RecurringListLoaded state, RecurringSection section) {
    final l10n = AppLocalizations.of(context);
    return SectionTile(
      key: ValueKey('section-${section.name}'),
      icon: switch (section) {
        RecurringSection.waiting => Icons.warning_amber_rounded,
        RecurringSection.active => Icons.repeat,
        RecurringSection.archived => Icons.inventory_2_outlined,
      },
      label: switch (section) {
        RecurringSection.waiting => l10n.recurringWaiting,
        RecurringSection.active => l10n.recurringActive,
        RecurringSection.archived => l10n.archiveTitle,
      },
      count: state.itemsOf(section).length,
      selected: state.section == section,
      // Waiting in the warning colour while anything waits.
      alert: section == RecurringSection.waiting && state.waiting.isNotEmpty,
      onTap: () => _cubit.select(section),
    );
  }

  Widget _row(RecurringListLoaded state, RecurringItem item) {
    final l10n = AppLocalizations.of(context);
    final locale = dateLocaleOf(context);
    final theme = Theme.of(context);
    final archived = state.section == RecurringSection.archived;
    return RecurringTile(
      item: item,
      emoji: _emojiOf(state.categories, item),
      subtitle: archived
          ? archiveRowSubtitle(l10n, locale, item, today: _today)
          : recurringRowSubtitle(l10n, locale, item, today: _today),
      subtitleStyle: !archived && (item.hold != null || item.isBroken)
          ? TextStyle(color: theme.colorScheme.error)
          : null,
      onTap: () => _open(item.id),
    );
  }

  static String _emojiOf(Map<int, Category> categories, RecurringItem item) =>
      categories[item.categoryId]?.emoji ?? ExpenseTile.missingEmoji;
}

/// A recurring item's row: an `ExpenseTile` with its category's emoji, title,
/// second line and current price.
class RecurringTile extends StatelessWidget {
  const RecurringTile({
    super.key,
    required this.item,
    required this.emoji,
    required this.subtitle,
    required this.onTap,
    this.subtitleStyle,
  });

  final RecurringItem item;
  final String emoji;
  final String subtitle;
  final TextStyle? subtitleStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ExpenseTile(
    key: ValueKey('recurring-${item.id}'),
    emoji: emoji,
    title: item.title,
    subtitle: subtitle,
    subtitleStyle: subtitleStyle,
    amount: item.price,
    onTap: onTap,
  );
}
