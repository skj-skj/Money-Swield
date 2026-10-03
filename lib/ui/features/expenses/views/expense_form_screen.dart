import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/amount_input.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/currency.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/money_formatter.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/tile_picker.dart';
import '../../categories/views/category_form_screen.dart';
import '../../events/views/event_form_screen.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/expense_form_cubit.dart';

/// Which picker is in search mode. View state, not in the cubit: it
/// doesn't affect what gets saved (phase-2.md §6.2).
enum _Searching { none, category, events }

/// Adds an expense, or edits the one with [expenseId]. Pops with an
/// [ExpenseFormResult] after Save or Delete, or when the expense turned out
/// to be gone, and with nothing on back.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.dependencies,
    this.expenseId,
  });

  final AppDependencies dependencies;
  final int? expenseId;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  // Created in didChangeDependencies because it needs the localizations.
  ExpenseFormCubit? _cubit;

  // The text fields own their text; the cubit gets a copy on every change
  // and never writes it back, so the cursor doesn't jump.
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();

  /// Focused once when the Add form opens. Not `autofocus`: the form is a
  /// lazy list, so the title field is disposed when scrolled away and built
  /// again later, and `autofocus` then fires again, pulling the focus (and
  /// the keyboard) back to the title, e.g. right after picking a date
  /// (found on a device).
  final _titleFocus = FocusNode();

  // For scrolling the first invalid field into view.
  final _titleKey = GlobalKey();
  final _amountKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  final _categoryKey = GlobalKey();

  var _searching = _Searching.none;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = widget.dependencies;
    final settings = context.read<SettingsCubit>().value;
    final cubit = ExpenseFormCubit(
      expenses: deps.expenses,
      categories: deps.categories,
      events: deps.events,
      paymentMethods: deps.paymentMethods,
      l10n: AppLocalizations.of(context),
      defaultCurrency: settings.defaultCurrency,
      defaultPaymentMethodId: settings.defaultPaymentMethodId,
      expenseId: widget.expenseId,
    );
    _cubit = cubit;
    _load();
  }

  @override
  void dispose() {
    _cubit?.close();
    _title.dispose();
    _amount.dispose();
    _description.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  ExpenseFormCubit get _form => _cubit!;

  Future<void> _load() async {
    await _form.load();
    if (!mounted) return;
    switch (_form.value) {
      case ExpenseFormReady(:final fields):
        _title.text = fields.title;
        if (!_form.isEditing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _titleFocus.requestFocus();
          });
        }
        _amount.text = fields.amountText;
        _description.text = fields.description;
      case ExpenseFormGone():
        _leaveBecauseGone();
      case ExpenseFormLoading() || ExpenseFormLoadFailed():
        break;
    }
  }

  /// The expense was binned or deleted meanwhile (e.g. from another
  /// screen): go back; Home says so (phase-2.md §6.3).
  void _leaveBecauseGone() => Navigator.pop(context, const ExpenseGone());

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await _saveOrNull();
    if (!mounted) return;
    if (saved != null) {
      Navigator.pop(context, ExpenseSaved(saved));
    } else if (_form.value is ExpenseFormGone) {
      _leaveBecauseGone();
    } else {
      _showFirstError();
    }
  }

  Future<Expense?> _saveOrNull() async {
    Expense? saved;
    await saveOrShowError(context, () async => saved = await _form.save());
    return saved;
  }

  void _showFirstError() {
    final firstInvalid = [
      if (_form.titleError != null) _titleKey,
      if (_form.amountError != null) _amountKey,
      if (_form.descriptionTooLong) _descriptionKey,
      if (_form.categoryMissing) _categoryKey,
    ].firstOrNull;
    final target = firstInvalid?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      alignment: 0.1,
    );
  }

  Future<void> _delete() async {
    int? binned;
    await saveOrShowError(
      context,
      () async => binned = await _form.moveToBin(),
    );
    final id = binned;
    if (id != null && mounted) Navigator.pop(context, ExpenseBinned(id));
  }

  /// Back: close a picker's search first, then ask before dropping
  /// changes (Phase 4 replaces the prompt with a saved draft, D9).
  Future<void> _onBack() async {
    if (_searching != _Searching.none) {
      _setSearching(_Searching.none);
      return;
    }
    if (await confirmDiscard(context) && mounted) Navigator.pop(context);
  }

  void _setSearching(_Searching searching) {
    // Only one picker searches at a time; leaving search closes the
    // keyboard.
    if (searching == _Searching.none) FocusScope.of(context).unfocus();
    setState(() => _searching = searching);
  }

  /// Dialogs and sheets give the focus back to the field that had it when
  /// they close, so after picking a date the keyboard came back for the
  /// title (found on a device). Dropping the focus first prevents that.
  void _dropFocus() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _pickCurrency(String selected) async {
    _dropFocus();
    final recent = await _form.recentCurrencies();
    if (!mounted) return;
    final code = await showCurrencyPicker(
      context,
      selected: selected,
      recent: recent,
    );
    if (code != null) _form.currencyChanged(code);
  }

  Future<void> _pickDate(DateTime wallClock) async {
    _dropFocus();
    final settings = context.read<SettingsCubit>();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(wallClock.year, wallClock.month, wallClock.day),
      // Future dates are allowed (P2-4); no real limit either way.
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      // Opens the way the user last left it (calendar or typing).
      initialEntryMode: settings.value.datePickerKeyboard
          ? DatePickerEntryMode.input
          : DatePickerEntryMode.calendar,
      onDatePickerModeChange: (mode) => _rememberMode(
        () => settings.setDatePickerKeyboard(mode == DatePickerEntryMode.input),
      ),
    );
    if (picked != null) _form.dateChanged(picked);
  }

  Future<void> _pickTime(DateTime wallClock) async {
    _dropFocus();
    final settings = context.read<SettingsCubit>();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: wallClock.hour, minute: wallClock.minute),
      // Opens the way the user last left it (clock dial or keyboard).
      initialEntryMode: settings.value.timePickerKeyboard
          ? TimePickerEntryMode.input
          : TimePickerEntryMode.dial,
      onEntryModeChanged: (mode) => _rememberMode(
        () => settings.setTimePickerKeyboard(mode == TimePickerEntryMode.input),
      ),
    );
    if (picked != null) _form.timeChanged(picked.hour, picked.minute);
  }

  /// Remembering the picker mode is a convenience: a failed write is only
  /// logged, it mustn't disturb picking the date or time.
  static void _rememberMode(Future<void> Function() save) {
    save().catchError((Object error) {
      debugPrint('Remembering the picker mode failed: $error');
    });
  }

  Future<bool> _newCategory(String name, List<Category> existing) async {
    final created = await Navigator.push<Category>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(
          repository: widget.dependencies.categories,
          original: null,
          existing: existing,
          initialName: name.trim(),
        ),
      ),
    );
    if (created == null) return false;
    _form.categoryAdded(created);
    if (mounted) _setSearching(_Searching.none);
    return true;
  }

  Future<bool> _newEvent(String name) async {
    final created = await Navigator.push<Event>(
      context,
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          repository: widget.dependencies.events,
          original: null,
          existing: _form.allEvents,
          initialName: name.trim(),
        ),
      ),
    );
    if (created == null) return false;
    _form.eventAdded(created);
    if (mounted) _setSearching(_Searching.none);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocSignalBuilder<ExpenseFormCubit, ExpenseFormState>(
      bloc: _form,
      builder: (context, state) {
        final ready = state is ExpenseFormReady ? state : null;
        return PopScope(
          canPop: _searching == _Searching.none && !_form.isDirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBack();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_form.isEditing ? l10n.editExpense : l10n.addExpense),
              actions: [
                if (_form.isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.delete,
                    onPressed: ready == null || ready.saving ? null : _delete,
                  ),
                TextButton(
                  onPressed: ready == null || ready.saving ? null : _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
            body: switch (state) {
              ExpenseFormReady() => _formBody(state),
              ExpenseFormLoadFailed() => LoadFailedView(onRetry: _load),
              ExpenseFormLoading() || ExpenseFormGone() => const Center(
                child: CircularProgressIndicator(),
              ),
            },
          ),
        );
      },
    );
  }

  Widget _formBody(ExpenseFormReady state) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fields = state.fields;
    final currency = findCurrency(fields.currencyCode);
    final preview = _form.amountPreview;
    final locale = Localizations.localeOf(context).toString();
    // Settings can't change while this screen is open (they're on another
    // tab), so reading them once per build is enough.
    final settings = context.read<SettingsCubit>().value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TextField(
          key: _titleKey,
          controller: _title,
          focusNode: _titleFocus,
          onChanged: _form.titleChanged,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
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
          key: _amountKey,
          controller: _amount,
          onChanged: _form.amountChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
          ],
          style: theme.textTheme.headlineMedium,
          decoration: InputDecoration(
            labelText: l10n.fieldAmount,
            prefixText: '${currency?.symbol ?? fields.currencyCode} ',
            errorText: _amountErrorText(l10n, _form.amountError, fields),
            helperText: switch (preview) {
              AmountParsed(:final amountMinor) => l10n.amountPreview(
                MoneyFormatter.of(context)
                    .format(Money(amountMinor, fields.currencyCode)),
              ),
              _ => null,
            },
            border: const OutlineInputBorder(),
          ),
        ),
        // A preview that doesn't parse shows its error right away, even
        // before the first Save (phase-2.md §6.1).
        if (preview case AmountRejected(:final error)
            when _form.amountError == null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
            child: Text(
              _amountErrorText(l10n, error, fields)!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          key: _descriptionKey,
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
        const SizedBox(height: 24),
        _SectionLabel(
          key: _categoryKey,
          text: l10n.fieldCategory,
          error: _form.categoryMissing ? l10n.categoryRequired : null,
        ),
        TilePicker(
          items: _form.categoryItems,
          tiles: _form.categoryTiles,
          selectedIds: {?fields.categoryId},
          multiSelect: false,
          tileShape: settings.tileShape,
          buttonShape: settings.buttonShape,
          searching: _searching == _Searching.category,
          onSearchingChanged: (on) =>
              _setSearching(on ? _Searching.category : _Searching.none),
          onTap: _form.categorySelected,
          searchHint: l10n.searchCategories,
          allTitle: l10n.allCategories,
          emptyText: l10n.noCategoriesYet,
          newLabel: l10n.newCategory,
          onNew: (name) => _newCategory(name, state.categories),
        ),
        const SizedBox(height: 24),
        _SectionLabel(text: l10n.fieldEvents),
        TilePicker(
          items: _form.eventItems,
          tiles: _form.eventTiles,
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
          newLabel: l10n.newEvent,
          onNew: _newEvent,
        ),
        const SizedBox(height: 24),
        _SectionLabel(text: l10n.fieldPaymentMethod),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final method in state.paymentMethods)
              ChoiceChip(
                label: Text(
                  '${method.emoji}  ${paymentMethodName(l10n, method)}',
                ),
                selected: method.id == fields.paymentMethodId,
                onSelected: (_) => _form.paymentMethodSelected(method.id),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionLabel(text: l10n.fieldCurrency),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ActionChip(
            avatar: const Icon(Icons.currency_exchange, size: 18),
            label: Text(currencyLabel(fields.currencyCode)),
            onPressed: () => _pickCurrency(fields.currencyCode),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  DateFormat.yMMMEd(locale).format(fields.wallClock),
                  semanticsLabel:
                      '${l10n.fieldDate}: '
                      '${DateFormat.yMMMMEEEEd(locale).format(fields.wallClock)}',
                ),
                onPressed: () => _pickDate(fields.wallClock),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(
                DateFormat.jm(locale).format(fields.wallClock),
                semanticsLabel:
                    '${l10n.fieldTime}: '
                    '${DateFormat.jm(locale).format(fields.wallClock)}',
              ),
              onPressed: () => _pickTime(fields.wallClock),
            ),
          ],
        ),
      ],
    );
  }

  static String? _amountErrorText(
    AppLocalizations l10n,
    AmountError? error,
    ExpenseFields fields,
  ) => switch (error) {
    null => null,
    AmountError.empty => l10n.amountErrorEmpty,
    AmountError.invalid => l10n.amountErrorInvalid,
    AmountError.tooLarge => l10n.amountErrorTooLarge(maxIntegerDigits),
    AmountError.tooManyDecimals => l10n.amountErrorTooManyDecimals(
      findCurrency(fields.currencyCode)?.minorDigits ?? 2,
      fields.currencyCode,
    ),
    AmountError.notPositive => l10n.amountErrorNotPositive,
  };
}

/// A field's heading above a picker, with its error under it.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({super.key, required this.text, this.error});

  final String text;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = this.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.titleSmall),
          if (error != null)
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
