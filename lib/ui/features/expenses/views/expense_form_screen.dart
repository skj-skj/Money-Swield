import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../domain/amount_expression.dart';
import '../../../../domain/amount_field_input.dart';
import '../../../../domain/amount_input.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/currency.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/expense_draft.dart';
import '../../../../domain/models/money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/money_formatter.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/tile_picker.dart';
import '../../categories/views/category_form_screen.dart';
import '../../events/views/event_form_screen.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../view_models/expense_form_cubit.dart';
import 'draft_banner.dart';
import 'itemize_sheet.dart';
import 'operator_row.dart';
import 'title_suggestions_field.dart';

/// Which picker is in search mode. View state, not in the cubit: it
/// doesn't affect what gets saved (phase-2.md §6.2).
enum _Searching { none, category, events }

/// Adds an expense, or edits the one with [expenseId]. Every back pops
/// with a result: [ExpenseDraftKept] when the unsaved changes are in the
/// draft slot, else null (phase-4.md §7.7). Save, Delete and "gone" pop
/// with their own [ExpenseFormResult].
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.dependencies,
    this.expenseId,
    this.draft,
    this.chipAmount,
  });

  final AppDependencies dependencies;
  final int? expenseId;

  /// The slot's draft, when Home opens the form from it (phase-4.md §7.4).
  final ExpenseDraft? draft;

  /// A Home chip's amount (phase-4.md §8.1).
  final Money? chipAmount;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  // Created in didChangeDependencies because it needs the localizations.
  ExpenseFormCubit? _cubit;

  /// The formatting locale's decimal separator, for the row's key and the
  /// amounts the form writes.
  late String _decimalSeparator;

  // The text fields own their text while the user types; the cubit gets a
  // copy. Only its programmatic changes (textRevision) are copied back.
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();

  /// Focused once when the Add form opens. Not `autofocus`: the form is a
  /// lazy list, so the title field is disposed when scrolled away and built
  /// again later, and `autofocus` then fires again, pulling the focus (and
  /// the keyboard) back to the title, e.g. right after picking a date
  /// (found on a device).
  final _titleFocus = FocusNode();

  /// The operator row shows while this has focus and the keyboard is up.
  final _amountFocus = FocusNode();

  // For scrolling the first invalid field into view.
  final _titleKey = GlobalKey();
  final _amountKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  final _categoryKey = GlobalKey();

  /// The form's own messenger: "Cleared" and its Undo go away with the
  /// form instead of showing on Home.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  var _searching = _Searching.none;

  /// Writes the draft when the app goes to the background, so a phone call
  /// or the app being killed loses nothing (phase-4.md §7.3).
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(_onAmountFocus);
    _titleFocus.addListener(_onTitleFocus);
    _lifecycle = AppLifecycleListener(
      onHide: _flushDraftInBackground,
      onPause: _flushDraftInBackground,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = widget.dependencies;
    final settings = context.read<SettingsCubit>().value;
    _decimalSeparator = decimalSeparatorOf(context);
    _cubit = ExpenseFormCubit(
      expenses: deps.expenses,
      categories: deps.categories,
      events: deps.events,
      paymentMethods: deps.paymentMethods,
      drafts: deps.drafts,
      l10n: AppLocalizations.of(context),
      defaultCurrency: settings.defaultCurrency,
      defaultPaymentMethodId: settings.defaultPaymentMethodId,
      decimalSeparator: _decimalSeparator,
      expenseId: widget.expenseId,
      openingDraft: widget.draft,
      chipAmount: widget.chipAmount,
      now: deps.now,
    );
    _form.load();
  }

  @override
  void dispose() {
    // Whatever is due reaches the database even though the form is gone.
    _flushDraft();
    _lifecycle.dispose();
    _cubit?.close();
    _title.dispose();
    _amount.dispose();
    _description.dispose();
    _titleFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  ExpenseFormCubit get _form => _cubit!;

  void _flushDraft() => _cubit?.flushDraft();

  void _flushDraftInBackground() => _cubit?.flushDraftInBackground();

  /// Leaving the title without a pick makes a title typed after a prefill
  /// the user's own (phase-4.md §12a).
  void _onTitleFocus() {
    if (!_titleFocus.hasFocus) _cubit?.titleLeft();
  }

  void _onAmountFocus() => setState(() {});

  /// Reacts to the cubit: copies programmatic text changes into the
  /// controllers, focuses the title of a new form once, and leaves when
  /// the expense turned out to be gone.
  void _onState(BuildContext context, ExpenseFormState state) {
    switch (state) {
      case ExpenseFormReady(:final fields, :final textRevision)
          when textRevision != _appliedRevision:
        final first = _appliedRevision == 0;
        _appliedRevision = textRevision;
        _setText(_title, fields.title);
        _setText(_amount, fields.expression);
        _setText(_description, fields.description);
        if (first && !_form.isEditing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _titleFocus.requestFocus();
          });
        }
      case ExpenseFormGone(:final draftKept):
        Navigator.pop(context, ExpenseGone(draftKept: draftKept));
      case ExpenseFormReady() ||
          ExpenseFormLoading() ||
          ExpenseFormLoadFailed():
        break;
    }
  }

  int _appliedRevision = 0;

  /// Sets [text] with the cursor at the end; leaves an equal text (and
  /// its cursor) alone.
  static void _setText(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await _saveOrNull();
    if (!mounted) return;
    if (saved != null) {
      Navigator.pop(context, ExpenseSaved(saved));
    } else if (_form.value is! ExpenseFormGone) {
      _showFirstError();
    }
  }

  Future<Expense?> _saveOrNull() async {
    Expense? saved;
    await saveOrShowError(_messengerContext, () async {
      saved = await _form.save();
    });
    return saved;
  }

  /// Below the form's own messenger, so errors show on the form.
  BuildContext get _messengerContext =>
      _messenger.currentState?.context ?? context;

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
      _messengerContext,
      () async => binned = await _form.moveToBin(),
    );
    final id = binned;
    if (id != null && mounted) Navigator.pop(context, ExpenseBinned(id));
  }

  /// Back (phase-4.md §7.7): close the suggestions, then a picker's
  /// search, then leave, saying whether a draft was kept. No prompt: the
  /// changes are in the draft (D9).
  void _onBack() {
    if (_titleFocus.hasFocus && _readyState?.suggestions.isNotEmpty == true) {
      _form.dismissSuggestions();
      return;
    }
    if (_searching != _Searching.none) {
      _setSearching(_Searching.none);
      return;
    }
    // Back while the title has focus leaves it too.
    _form.titleLeft();
    Navigator.pop(context, _form.ownsDraft ? const ExpenseDraftKept() : null);
  }

  ExpenseFormReady? get _readyState => switch (_form.value) {
    final ExpenseFormReady ready => ready,
    _ => null,
  };

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

  Future<void> _clear() async {
    await _form.clear();
    if (!mounted) return;
    _titleFocus.requestFocus();
    _showUndo(AppLocalizations.of(context).cleared);
  }

  Future<void> _discardDraft() async {
    _dropFocus();
    await _form.discardDraft();
    if (mounted) _showUndo(AppLocalizations.of(context).draftDiscarded);
  }

  /// "Cleared" / "Draft discarded" with Undo: a mis-tap never loses data
  /// (phase-4.md §7.6).
  void _showUndo(String message) {
    final l10n = AppLocalizations.of(context);
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // Undo is only offered for a moment.
          persist: false,
          action: SnackBarAction(label: l10n.undo, onPressed: _form.undoReset),
        ),
      );
  }

  void _onRowKey(RowKey key) {
    final text = applyRowKeyTo(_amount, key, _decimalSeparator);
    if (text != null) _form.amountChanged(text);
  }

  Future<void> _itemize() async {
    final terms = _form.itemizeTerms;
    if (terms == null) return;
    _dropFocus();
    final labels = await showItemizeSheet(
      context,
      terms: terms,
      labels: _form.itemizeLabels,
      decimalSeparator: _decimalSeparator,
    );
    if (labels != null) _form.itemize(labels);
  }

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
      // The app language with the phone's country, like the rest of the
      // dates (and money).
      locale: formattingLocaleValueOf(context),
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
    return BlocSignalListener<ExpenseFormCubit, ExpenseFormState>(
      bloc: _form,
      listener: _onState,
      child: BlocSignalBuilder<ExpenseFormCubit, ExpenseFormState>(
        bloc: _form,
        builder: (context, state) => PopScope(
          // Every back goes through _onBack, so it can carry a result.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBack();
          },
          child: ScaffoldMessenger(
            key: _messenger,
            child: Scaffold(
              appBar: _appBar(state),
              body: switch (state) {
                ExpenseFormReady() => _body(state),
                ExpenseFormLoadFailed() => LoadFailedView(onRetry: _form.load),
                ExpenseFormLoading() || ExpenseFormGone() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(ExpenseFormState state) {
    final l10n = AppLocalizations.of(context);
    final ready = state is ExpenseFormReady ? state : null;
    final busy = ready == null || ready.saving;
    return AppBar(
      title: Text(_form.isEditing ? l10n.editExpense : l10n.addExpense),
      actions: [
        if (_form.isEditing)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: busy ? null : _delete,
          )
        else
          TextButton(
            onPressed: busy || !_form.canClear ? null : _clear,
            child: Text(l10n.clear),
          ),
        // The same button; "Update" on an existing expense (P4-18).
        TextButton(
          onPressed: _form.canSave ? _save : null,
          child: Text(_form.isEditing ? l10n.update : l10n.save),
        ),
      ],
    );
  }

  /// The form, a banner above it when it came from a draft, and the
  /// operator row below it, right on top of the keyboard (the Scaffold
  /// already shrinks the body above it).
  Widget _body(ExpenseFormReady state) {
    final restoredAt = state.restoredAt;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        if (restoredAt != null)
          DraftBanner(
            isEditing: _form.isEditing,
            savedAt: restoredAt,
            now: widget.dependencies.now(),
            onDiscard: _form.isEditing ? _discardDraft : null,
          ),
        Expanded(child: _formList(state)),
        if (_amountFocus.hasFocus && keyboardUp)
          OperatorRow(decimalSeparator: _decimalSeparator, onKey: _onRowKey),
      ],
    );
  }

  Widget _formList(ExpenseFormReady state) {
    final l10n = AppLocalizations.of(context);
    final fields = state.fields;
    final locale = dateLocaleOf(context);
    // Settings can't change while this screen is open (they're on another
    // tab), so reading them once per build is enough.
    final settings = context.read<SettingsCubit>().value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TitleSuggestionsField(
          key: _titleKey,
          focusNode: _titleFocus,
          suggestions: state.suggestions,
          categoryEmoji: _form.categoryEmoji,
          onPick: _form.pickSuggestion,
          field: TextField(
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
        ),
        const SizedBox(height: 16),
        _amountField(fields),
        _resultLine(fields),
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

  Widget _amountField(ExpenseFields fields) {
    final l10n = AppLocalizations.of(context);
    final currency = findCurrency(fields.currencyCode);
    return TextField(
      key: _amountKey,
      controller: _amount,
      focusNode: _amountFocus,
      onChanged: _form.amountChanged,
      // The system keyboard (P4-6); the operator row adds + − × ÷.
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [AmountKeyboardFormatter()],
      style: Theme.of(context).textTheme.headlineMedium,
      decoration: InputDecoration(
        labelText: l10n.fieldAmount,
        prefixText: '${currency?.symbol ?? fields.currencyCode} ',
        errorText: _amountErrorText(l10n, _form.amountError, fields),
        border: const OutlineInputBorder(),
      ),
    );
  }

  /// `= ₹170.00` / `≈ ₹1.32`, or the error right away, under the amount
  /// (R8), with Itemize next to it when the sum has ≥ 2 terms. A live
  /// region, so TalkBack reads it after a change.
  Widget _resultLine(ExpenseFields fields) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = _form.amountResult;
    final String? text;
    var isError = false;
    switch (result) {
      case null:
        text = null;
      case ExpressionValue(:final amountMinor, :final rounded):
        final shown = MoneyFormatter.of(context)
            .format(Money(amountMinor, fields.currencyCode));
        text = rounded ? l10n.amountApprox(shown) : l10n.amountPreview(shown);
      case ExpressionRejected(:final error):
        // Already under the field once errors are shown.
        isError = true;
        text = _form.amountError == null
            ? _amountErrorText(l10n, error, fields)
            : null;
    }
    final canItemize = _form.itemizeTerms != null;
    if (text == null && !canItemize) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: text == null
                ? const SizedBox.shrink()
                : Semantics(
                    liveRegion: true,
                    child: Text(
                      text,
                      key: const ValueKey('amountResult'),
                      style: isError
                          ? theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            )
                          : theme.textTheme.titleMedium,
                    ),
                  ),
          ),
          if (canItemize)
            TextButton.icon(
              icon: const Icon(Icons.format_list_bulleted),
              label: Text(l10n.itemize),
              onPressed: _itemize,
            ),
        ],
      ),
    );
  }

  static String? _amountErrorText(
    AppLocalizations l10n,
    ExpressionError? error,
    ExpenseFields fields,
  ) => switch (error) {
    null => null,
    ExpressionError.empty => l10n.amountErrorEmpty,
    ExpressionError.invalid => l10n.amountErrorInvalid,
    ExpressionError.tooLarge => l10n.amountErrorTooLarge(maxIntegerDigits),
    ExpressionError.tooManyDecimals => l10n.amountErrorTooManyDecimals(
      findCurrency(fields.currencyCode)?.minorDigits ?? 2,
      fields.currencyCode,
    ),
    ExpressionError.divideByZero => l10n.amountErrorDivideByZero,
    ExpressionError.notPositive => l10n.amountErrorNotPositive,
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
