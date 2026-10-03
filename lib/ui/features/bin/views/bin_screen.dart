import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/expense.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/money_formatter.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/save_error.dart';
import '../view_models/bin_cubit.dart';
import 'bin_detail_screen.dart';

/// Settings → Bin: deleted expenses, most recently deleted first, kept for
/// 30 days (phase-2.md §9.2, application-design.md §5.4.1). Restores don't
/// ask; permanent deletes do, because they can't be undone.
class BinScreen extends StatefulWidget {
  const BinScreen({super.key, required this.dependencies, this.now});

  final AppDependencies dependencies;

  /// The clock for "Deleted N days ago"; tests pass their own.
  final DateTime Function()? now;

  @override
  State<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends State<BinScreen> {
  late final BinCubit _cubit = BinCubit(
    expenses: widget.dependencies.expenses,
    categories: widget.dependencies.categories,
    events: widget.dependencies.events,
    paymentMethods: widget.dependencies.paymentMethods,
  )..load();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _emptyBin() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.emptyBinTitle,
      message: l10n.cannotBeUndone,
      confirmLabel: l10n.emptyBin,
    );
    if (!confirmed || !mounted) return;
    await saveOrShowError(context, _cubit.emptyBin);
  }

  Future<void> _openDetail(Expense expense, BinLookups lookups) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BinDetailScreen(
          expense: expense,
          lookups: lookups,
          onRestore: () => _cubit.restore(expense.id),
          onDeletePermanently: () => _cubit.deletePermanently(expense.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalBuilder<BinCubit, BinState>(
      bloc: _cubit,
      builder: (context, state) {
        final hasItems = state is BinLoaded && state.expenses.isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.bin),
            actions: [
              if (hasItems) ...[
                IconButton(
                  icon: const Icon(Icons.restore),
                  tooltip: l10n.restoreAll,
                  onPressed: () => saveOrShowError(context, _cubit.restoreAll),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever_outlined),
                  tooltip: l10n.emptyBin,
                  onPressed: _emptyBin,
                ),
              ],
            ],
          ),
          body: switch (state) {
            BinLoading() => const Center(child: CircularProgressIndicator()),
            BinFailed() => LoadFailedView(onRetry: _cubit.load),
            BinLoaded(:final expenses) when expenses.isEmpty => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.binEmpty, textAlign: TextAlign.center),
              ),
            ),
            BinLoaded(:final expenses, :final lookups) => ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return ListTile(
                  key: ValueKey(expense.id),
                  leading: Text(
                    lookups.categories[expense.categoryId]?.emoji ?? '❓',
                    style: const TextStyle(fontSize: 28),
                  ),
                  title: Text(
                    expense.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    binAgeText(
                      l10n,
                      binAge(
                        expense.deletedAt!,
                        (widget.now ?? DateTime.now)(),
                      ),
                    ),
                  ),
                  trailing: Text(
                    MoneyFormatter.of(context).format(expense.amount),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => _openDetail(expense, lookups),
                );
              },
            ),
          },
        );
      },
    );
  }
}

/// "Deleted 3 days ago · removed in 27 days".
String binAgeText(AppLocalizations l10n, BinAge age) {
  final deleted = switch (age.daysAgo) {
    <= 0 => l10n.deletedToday,
    1 => l10n.deletedYesterday,
    final days => l10n.deletedDaysAgo(days),
  };
  final removed = switch (age.daysLeft) {
    null => l10n.removedOnNextStart,
    final days => l10n.removedInDays(days),
  };
  return '$deleted · $removed';
}
