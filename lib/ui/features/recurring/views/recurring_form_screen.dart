import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/repeat_input.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/item_labels.dart';
import '../../../core/picker_order.dart';
import '../../../core/pickers.dart';
import '../../../core/widgets/back_guard.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/show_message.dart';
import '../../../core/widgets/tile_picker.dart';
import '../../expenses/view_models/expense_form_cubit.dart'
    show maxExpenseDescriptionLength, maxTitleLength, TitleError;
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/recurring_form_cubit.dart';

enum _Searching { none, category, events }

/// Edit a running recurring item (phase-7a.md §8.5): title, description,
/// category, events, payment method, time, end. "Changes apply to payments
/// added from now on." No draft (P7a-15): Back with changes asks. Pops
/// true when saved.
class RecurringFormScreen extends StatefulWidget {
  const RecurringFormScreen({
    super.key,
    required this.dependencies,
    required this.itemId,
  });

  final AppDependencies dependencies;
  final int itemId;

  @override
  State<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends State<RecurringFormScreen> {
  RecurringFormCubit? _cubit;
  RecurringFormCubit get _form => _cubit!;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _scaffold = GlobalKey<ScaffoldState>();
  var _searching = _Searching.none;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = widget.dependencies;
    _cubit = RecurringFormCubit(
      itemId: widget.itemId,
      recurring: deps.recurring,
      categories: deps.categories,
      events: deps.events,
      paymentMethods: deps.paymentMethods,
      l10n: AppLocalizations.of(context),
      now: deps.now,
    )..load();
  }

  @override
  void dispose() {
    _cubit?.close();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, RecurringFormState state) {
    switch (state) {
      case RecurringFormReady(:final fields) when !_filled:
        _filled = true;
        _title.text = fields.title;
        _description.text = fields.description;
      case RecurringFormGone():
        showMessage(
          ScaffoldMessenger.maybeOf(context),
          AppLocalizations.of(context).recurringGone,
        );
        Navigator.pop(context, false);
      case _:
        break;
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    var saved = false;
    await saveOrShowError(
      _scaffold.currentContext ?? context,
      () async => saved = await _form.save(),
    );
    if (saved && mounted) Navigator.pop(context, true);
  }

  /// Back: closes a picker's search first; with changes, asks.
  Future<void> _onBack() async {
    if (_searching != _Searching.none) {
      _setSearching(_Searching.none);
      return;
    }
    if (_form.isDirty) {
      final l10n = AppLocalizations.of(context);
      final discard = await confirmAction(
        context,
        title: l10n.discardChangesTitle,
        confirmLabel: l10n.discard,
        cancelLabel: l10n.keepEditing,
      );
      if (!discard || !mounted) return;
    }
    Navigator.pop(context, false);
  }

  void _setSearching(_Searching searching) {
    if (searching == _Searching.none) FocusScope.of(context).unfocus();
    setState(() => _searching = searching);
  }

  Future<void> _pickTime(int minutes) async {
    final picked = await pickTimeOfDay(
      context,
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );
    if (picked != null) _form.timeChanged(picked.hour, picked.minute);
  }

  Future<void> _pickEnd(RecurringFormReady state) async {
    final picked = await pickDay(
      context,
      initial: state.fields.endOn ?? state.earliestEnd,
      first: state.earliestEnd,
      last: lastEndOn,
      helpText: AppLocalizations.of(context).repeatEndDate,
    );
    if (picked != null) _form.endDateChanged(parseDay(picked));
  }

  /// [minutes] past midnight as a wall clock, for [timeText].
  static DateTime _wallClockOf(int minutes) =>
      DateTime.utc(2000, 1, 1, minutes ~/ 60, minutes % 60);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalListener<RecurringFormCubit, RecurringFormState>(
      bloc: _form,
      listener: _onState,
      child: BlocSignalBuilder<RecurringFormCubit, RecurringFormState>(
        bloc: _form,
        builder: (context, state) => BackGuard(
          onBack: _onBack,
          child: ScaffoldMessenger(
            key: _messenger,
            child: Scaffold(
              key: _scaffold,
              appBar: AppBar(
                title: Text(l10n.editRecurring),
                actions: [
                  TextButton(
                    key: const ValueKey('saveRecurring'),
                    onPressed: _form.canSave ? _save : null,
                    child: Text(l10n.save),
                  ),
                ],
              ),
              body: switch (state) {
                RecurringFormReady() => _body(state),
                RecurringFormFailed() => LoadFailedView(onRetry: _form.load),
                RecurringFormLoading() || RecurringFormGone() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(RecurringFormReady state) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = dateLocaleOf(context);
    final settings = context.read<SettingsCubit>().value;
    final fields = state.fields;
    final endError = _form.endError;
    final methodId =
        state.paymentMethods.any((m) => m.id == fields.paymentMethodId)
        ? fields.paymentMethodId
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          l10n.recurringChangesApplyLater,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('recurringTitle'),
          controller: _title,
          onChanged: _form.titleChanged,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.fieldTitle,
            errorText: switch (_form.titleError) {
              null => null,
              TitleError.required => l10n.titleRequired,
              TitleError.tooLong => l10n.errorTooLong(maxTitleLength),
            },
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _description,
          onChanged: _form.descriptionChanged,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.fieldDescription,
            errorText: _form.descriptionTooLong
                ? l10n.errorTooLong(maxExpenseDescriptionLength)
                : null,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        // The time, then the payment method: each the full width, so a
        // large font or a long method name never overflows (a plain
        // dropdown next to the time overflowed by 95 dp at font 2.0;
        // phase-7a.md §12a).
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('recurringTime'),
            onPressed: () => _pickTime(fields.timeOfDayMinutes),
            icon: const Icon(Icons.schedule),
            label: Text(
              '${l10n.fieldTime}: '
              '${timeText(locale, _wallClockOf(fields.timeOfDayMinutes))}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.fieldPaymentMethod,
            border: const OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const ValueKey('recurringMethod'),
              value: methodId,
              isDense: true,
              isExpanded: true,
              onChanged: (id) {
                if (id != null) _form.paymentMethodSelected(id);
              },
              items: [
                for (final m in state.paymentMethods)
                  DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      paymentMethodLabel(l10n, m),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SectionHeading(
          l10n.fieldCategory,
          error: _form.categoryMissing ? l10n.categoryRequired : null,
        ),
        TilePicker(
          items: [
            for (final c in state.categories)
              PickerItem(id: c.id, emoji: c.emoji, name: categoryName(l10n, c)),
          ],
          selectedIds: {fields.categoryId},
          multiSelect: false,
          tileShape: settings.tileShape,
          buttonShape: settings.buttonShape,
          searching: _searching == _Searching.category,
          onSearchingChanged: (on) =>
              _setSearching(on ? _Searching.category : _Searching.none),
          onTap: _form.categorySelected,
          searchHint: l10n.searchCategories,
          allTitle: l10n.allCategories,
        ),
        const SizedBox(height: 24),
        SectionHeading(l10n.fieldEvents),
        TilePicker(
          items: [
            for (final e in state.events)
              PickerItem(id: e.id, emoji: e.emoji, name: eventName(l10n, e)),
          ],
          selectedIds: fields.eventIds,
          multiSelect: true,
          tileShape: settings.tileShape,
          buttonShape: settings.buttonShape,
          noneLabel: l10n.noneEvent,
          onNone: _form.eventsCleared,
          searching: _searching == _Searching.events,
          onSearchingChanged: (on) =>
              _setSearching(on ? _Searching.events : _Searching.none),
          onTap: _form.eventToggled,
          searchHint: l10n.searchEvents,
          allTitle: l10n.allEvents,
        ),
        const SizedBox(height: 24),
        Text(l10n.repeatEnds, style: theme.textTheme.titleSmall),
        RadioGroup<RepeatEnd>(
          groupValue: fields.end,
          onChanged: (end) {
            if (end == null) return;
            _form.endChanged(end);
            if (end == RepeatEnd.onDate) _pickEnd(state);
          },
          child: Column(
            children: [
              RadioListTile<RepeatEnd>(
                contentPadding: EdgeInsets.zero,
                value: RepeatEnd.never,
                title: Text(l10n.repeatEndsNever),
              ),
              RadioListTile<RepeatEnd>(
                contentPadding: EdgeInsets.zero,
                value: RepeatEnd.onDate,
                title: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l10n.repeatEndsOn),
                    OutlinedButton.icon(
                      key: const ValueKey('recurringEndDate'),
                      onPressed: () => _pickEnd(state),
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(
                        // The date "On" would end on (the earliest allowed)
                        // rather than "—" (Oppo, phase-7a.md §12a).
                        shortDateText(
                          locale,
                          parseDay(fields.endOn ?? state.earliestEnd),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (endError != null)
          Text(
            switch (endError) {
              EndError.missing => l10n.repeatEndMissing,
              EndError.beforeEarliest => l10n.recurringEndNotBefore(
                shortDateText(locale, parseDay(state.earliestEnd)),
              ),
              EndError.tooLate => l10n.repeatEndTooLate(
                shortDateText(locale, parseDay(lastEndOn)),
              ),
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}
