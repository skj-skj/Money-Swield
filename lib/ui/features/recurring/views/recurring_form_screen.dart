import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/models/expense.dart'
    show maxExpenseDescriptionLength, maxTitleLength;
import '../../../../domain/periods.dart';
import '../../../../domain/repeat_input.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/item_labels.dart';
import '../../../core/picker_order.dart';
import '../../../core/pickers.dart';
import '../../../core/recurrence_text.dart';
import '../../../core/widgets/back_guard.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/repeat_every_row.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/show_message.dart';
import '../../../core/widgets/tile_picker.dart';
import '../../expenses/view_models/expense_form_cubit.dart' show TitleError;
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/recurring_form_cubit.dart';

enum _Searching { none, category, events }

/// What the Edit screen pops with when it saved (null: nothing saved).
sealed class RecurringFormResult {
  const RecurringFormResult();
}

/// The item's fields were saved.
final class RecurringEdited extends RecurringFormResult {
  const RecurringEdited();
}

/// How often changed (phase-7b.md §8.1 C): a new item [newId] was made and
/// the item [oldTitle] archived. The page opens the new one.
final class RecurringReplaced extends RecurringFormResult {
  const RecurringReplaced(this.newId, this.oldTitle);

  final int newId;
  final String oldTitle;
}

/// Edit a running recurring item (phase-7a.md §8.5): title, description,
/// category, events, payment method, time, how often (phase-7b.md §8.2:
/// a change makes a new item, after a dialog), end. "Changes apply to
/// payments added from now on." No draft (P7a-15): Back with changes asks.
/// Pops a [RecurringFormResult] when saved.
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

  /// How often's Every field (phase-7b.md §8.2).
  final _interval = TextEditingController();
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
    _interval.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, RecurringFormState state) {
    switch (state) {
      case RecurringFormReady(:final fields) when !_filled:
        _filled = true;
        _title.text = fields.title;
        _description.text = fields.description;
        _interval.text = fields.intervalText;
      case RecurringFormGone():
        showMessage(
          ScaffoldMessenger.maybeOf(context),
          AppLocalizations.of(context).recurringGone,
        );
        Navigator.pop(context);
      case _:
        break;
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_form.scheduleChanged) return _saveAsNew();
    var saved = false;
    await saveOrShowError(
      _scaffold.currentContext ?? context,
      () async => saved = await _form.save(),
    );
    if (saved && mounted) Navigator.pop(context, const RecurringEdited());
  }

  /// How often changed (§8.1 C): checked, then asked, then a new item.
  Future<void> _saveAsNew() async {
    final ready = _form.value;
    final schedule = _form.newSchedule;
    if (ready is! RecurringFormReady || !_form.validate() || schedule == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final locale = dateLocaleOf(context);
    final title = ready.fields.title.trim();
    final confirmed = await confirmAction(
      context,
      title: l10n.newItemTitle,
      message: l10n.newItemText(
        ready.item.paymentCount,
        '$title · ${scheduleText(l10n, locale, schedule)}',
        shortDateText(locale, parseDay(schedule.startOn)),
      ),
      confirmLabel: l10n.createNew,
    );
    if (!confirmed || !mounted) return;
    int? newId;
    await saveOrShowError(
      _scaffold.currentContext ?? context,
      () async => newId = await _form.saveAsNew(),
    );
    final id = newId;
    if (id != null && mounted) {
      Navigator.pop(context, RecurringReplaced(id, ready.item.title));
    }
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
    Navigator.pop(context);
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
    final earliest = _form.earliestEnd ?? state.earliestEnd;
    final picked = await pickDay(
      context,
      // pickDay opens on the first date when this one is before it.
      initial: state.fields.endOn ?? earliest,
      first: earliest,
      last: lastEndOn,
      helpText: AppLocalizations.of(context).repeatEndDate,
    );
    if (picked != null) _form.endDateChanged(parseDay(picked));
  }

  /// The new schedule's First payment: from the earliest allowed to
  /// [lastEndOn] (phase-7b.md §7.3).
  Future<void> _pickFirstPayment(RecurringFormReady state) async {
    final picked = await pickDay(
      context,
      initial: _form.firstPaymentOn ?? state.earliestFirst,
      first: state.earliestFirst,
      last: lastEndOn,
      helpText: AppLocalizations.of(context).firstPayment,
    );
    if (picked != null) _form.firstPaymentChanged(parseDay(picked));
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
        ..._howOften(state),
        const SizedBox(height: 16),
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
                          parseDay(
                            fields.endOn ??
                                _form.earliestEnd ??
                                state.earliestEnd,
                          ),
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

  /// "How often": Every, and once it differs from the item's, the First
  /// payment and "Saving makes a new recurring item" (phase-7b.md §8.2).
  /// Locked while payments wait (they would be dropped).
  List<Widget> _howOften(RecurringFormReady state) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = dateLocaleOf(context);
    final fields = state.fields;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final first = _form.firstPaymentOn;
    final firstError = _form.firstPaymentError;
    return [
      SectionHeading(l10n.howOften),
      RepeatEveryRow(
        frequency: fields.frequency,
        interval: fields.interval,
        controller: _interval,
        onInterval: _form.intervalChanged,
        onFrequency: _form.frequencyChanged,
        showError: _form.intervalInvalid,
        enabled: !state.scheduleLocked,
      ),
      // The rule in words, the new one once changed ("Every week on
      // Tuesday"): which weekday a change to weekly picks wasn't said
      // anywhere (Oppo, phase-7b.md §12a).
      if (_form.newSchedule ?? state.item.schedule case final rule?)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            scheduleText(l10n, locale, rule),
            key: const ValueKey('howOftenRule'),
            style: muted,
          ),
        ),
      if (state.scheduleLocked)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l10n.scheduleLockedNotice, style: muted),
        ),
      if (_form.scheduleChanged && first != null) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ExcludeSemantics(child: Text(l10n.firstPayment)),
            Semantics(
              container: true,
              button: true,
              label:
                  '${l10n.firstPayment}: '
                  '${longDateText(locale, parseDay(first))}',
              excludeSemantics: true,
              child: OutlinedButton.icon(
                key: const ValueKey('firstPayment'),
                onPressed: () => _pickFirstPayment(state),
                icon: const Icon(Icons.event, size: 18),
                label: Text(shortDateText(locale, parseDay(first))),
              ),
            ),
          ],
        ),
        if (firstError != null)
          Text(
            switch (firstError) {
              FirstPaymentError.tooEarly => l10n.firstPaymentTooEarly(
                shortDateText(locale, parseDay(state.earliestFirst)),
              ),
              FirstPaymentError.tooLate => l10n.repeatEndTooLate(
                shortDateText(locale, parseDay(lastEndOn)),
              ),
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        const SizedBox(height: 8),
        Semantics(
          container: true,
          liveRegion: true,
          child: Text(
            l10n.newItemNotice,
            key: const ValueKey('newItemNotice'),
            style: muted,
          ),
        ),
      ],
    ];
  }
}
