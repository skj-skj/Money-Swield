import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/services/photo_store.dart';
import '../../../../domain/models/currency.dart';
import '../../../../domain/models/expense.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/item_labels.dart';
import '../../../core/money_formatter.dart';
import '../../../core/recurrence_text.dart';
import '../../../core/widgets/back_guard.dart';
import '../../../core/widgets/confirm_then_save.dart';
import '../../../core/widgets/photos/photo_grid.dart';
import '../../../core/widgets/photos/photo_selection_bar.dart';
import '../../../core/widgets/photos/photo_viewer.dart';
import '../../../core/widgets/photos/saved_to_pictures_message.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/show_message.dart';
import '../view_models/bin_cubit.dart';
import '../view_models/expense_photos_cubit.dart';

/// A binned expense, read-only: binned expenses can't be edited, only
/// restored or deleted for good (database.md §3.5). Pops after either.
/// Its photos show too, read-only: a long press selects them to Save to
/// Pictures (no Delete), and the viewer has Save only (phase-6.md §8.5,
/// P6-24, P6-43), so they can be kept before the expense is purged.
class BinDetailScreen extends StatelessWidget {
  const BinDetailScreen({
    super.key,
    required this.expense,
    required this.lookups,
    required this.photos,
    required this.onRestore,
    required this.onDeletePermanently,
  });

  final Expense expense;
  final BinLookups lookups;
  final ExpensePhotosCubit photos;
  final Future<void> Function() onRestore;
  final Future<void> Function() onDeletePermanently;

  Future<void> _restore(BuildContext context) async {
    final done = await saveOrShowError(context, onRestore);
    if (done && context.mounted) Navigator.pop(context);
  }

  Future<void> _deletePermanently(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final done = await confirmThenSave(
      context,
      title: l10n.deletePermanentlyTitle(expense.title),
      message: l10n.cannotBeUndone,
      confirmLabel: l10n.delete,
      action: onDeletePermanently,
    );
    if (done && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = dateLocaleOf(context);
    final category = lookups.categories[expense.categoryId];
    final method = lookups.paymentMethods[expense.paymentMethodId];
    final events = [
      for (final id in expense.eventIds)
        if (lookups.events[id] case final event?) eventLabel(l10n, event),
    ];
    final description = expense.description;
    final item = lookups.recurring[expense.recurringExpenseId];
    final schedule = item?.schedule;
    return BlocSignalBuilder<ExpensePhotosCubit, ExpensePhotosState>(
      bloc: photos,
      builder: (context, photoState) => BackGuard(
        // Back leaves selection first.
        intercept: photoState.selection != null,
        onBack: photos.clearSelection,
        child: Scaffold(
          appBar: AppBar(title: Text(expense.title)),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _Row(
                label: l10n.fieldAmount,
                value: MoneyFormatter.of(context).format(expense.amount),
              ),
              if (item != null && schedule != null)
                _Row(
                  label: l10n.repeatsMark,
                  value: l10n.binPaymentOf(
                    item.title,
                    shortScheduleText(
                      l10n,
                      schedule.frequency,
                      schedule.interval,
                    ),
                  ),
                ),
              _Row(
                label: l10n.fieldCurrency,
                value:
                    findCurrency(expense.amount.currencyCode)?.englishName ??
                    expense.amount.currencyCode,
              ),
              _Row(
                label: l10n.fieldCategory,
                value: category == null ? '❓' : categoryLabel(l10n, category),
              ),
              if (events.isNotEmpty)
                _Row(label: l10n.fieldEvents, value: events.join(', ')),
              _Row(
                label: l10n.fieldPaymentMethod,
                value: method == null ? '❓' : paymentMethodLabel(l10n, method),
              ),
              // The time as it was on the clock where it was recorded.
              _Row(
                label: l10n.fieldDate,
                value: longDateText(locale, expense.wallClock),
              ),
              _Row(
                label: l10n.fieldTime,
                value: timeText(locale, expense.wallClock),
              ),
              if (description != null)
                _Row(label: l10n.fieldNotes, value: description),
              if (photoState.photos.isNotEmpty)
                _photosSection(context, photoState),
              _Row(
                label: l10n.fieldDeletedAt,
                value: dateTimeText(locale, expense.deletedAt!),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: FilledButton.icon(
                  onPressed: () => _restore(context),
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.restore),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _deletePermanently(context),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(l10n.deletePermanently),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photosSection(BuildContext context, ExpensePhotosState state) {
    final l10n = AppLocalizations.of(context);
    final selection = state.selection;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selection == null)
            SectionHeading(l10n.photos)
          else
            PhotoSelectionBar(
              count: selection.length,
              busy: state.saving,
              onClose: photos.clearSelection,
              onSelectAll: photos.selectAll,
              onSave: () => _save(context, photos.saveSelected),
            ),
          PhotoGrid(
            count: state.photos.length,
            imageOf: (i, maxPx) => photos.store.image(state.photos[i], maxPx),
            selection: selection,
            onTap: (i) => selection == null
                ? _openViewer(context, state, i)
                : photos.toggleSelected(i),
            onLongPress: photos.startSelection,
            semanticsOf: (i) =>
                AppLocalizations.of(context)
                    .photoNumber(i + 1, state.photos.length),
          ),
        ],
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    Future<SaveToPicturesResult?> Function() save,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await saveToPicturesMessage(
      AppLocalizations.of(context),
      save,
    );
    if (message != null) showMessage(messenger, message);
  }

  Future<void> _openViewer(
    BuildContext context,
    ExpensePhotosState state,
    int index,
  ) {
    final l10n = AppLocalizations.of(context);
    return PhotoViewer.open(
      context,
      count: state.photos.length,
      initial: index,
      imageOf: (i, maxPx) => photos.store.image(state.photos[i], maxPx),
      onSave: (i) => saveToPicturesMessage(l10n, () => photos.save([i])),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(value), subtitle: Text(label));
  }
}
