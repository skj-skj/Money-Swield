import 'dart:math' as math;

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
import '../../../core/currency_labels.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/item_labels.dart';
import '../../../core/money_formatter.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/show_message.dart';
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
    showMessage(
      _messenger.currentState,
      message,
      action: SnackBarAction(
        label: AppLocalizations.of(context).undo,
        onPressed: _form.undoReset,
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
        _amountRow(fields),
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
        const SizedBox(height: 16),
        _whenAndHowRow(state, locale),
        const SizedBox(height: 24),
        SectionHeading(
          l10n.fieldCategory,
          key: _categoryKey,
          error: _form.categoryMissing ? l10n.categoryRequired : null,
        ),
        TilePicker(
          items: _form.categoryItems,
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
        SectionHeading(l10n.fieldEvents),
        TilePicker(
          items: _form.eventItems,
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
      ],
    );
  }

  /// Date, time and payment method in one row under the description.
  /// Date and time take the width they need; the dropdown gets the rest,
  /// so a long method name is cut short instead of the date.
  ///
  /// With a large font the dropdown would get too narrow (and date + time
  /// overflowed the row), so it moves to a row of its own; if date and time
  /// don't fit side by side either, they stack too. They are never shrunk
  /// below their text, so they stay easy to read and tap (owner,
  /// 2026-10-05). See [_PickerField.minDropdownWidth] for "too narrow".
  Widget _whenAndHowRow(ExpenseFormReady state, String locale) {
    final l10n = AppLocalizations.of(context);
    final fields = state.fields;
    final time = timeText(locale, fields.wallClock);
    // Short, to leave the dropdown room: the year only when it isn't this
    // one. TalkBack reads the full date.
    final thisYear = fields.wallClock.year == widget.dependencies.now().year;
    final date = (thisYear ? DateFormat.MMMd(locale) : DateFormat.yMMMd(locale))
        .format(fields.wallClock);
    // An expense's method may be missing from the list (a dropdown must
    // hold its value exactly once), so then nothing shows as selected.
    final methodId =
        state.paymentMethods.any((m) => m.id == fields.paymentMethodId)
        ? fields.paymentMethodId
        : null;
    final methodNames = [
      for (final method in state.paymentMethods)
        paymentMethodLabel(l10n, method),
    ];
    final dateField = _PickerField(
      label: l10n.fieldDate,
      value: date,
      semanticsValue: longDateText(locale, fields.wallClock),
      onTap: () => _pickDate(fields.wallClock),
    );
    final timeField = _PickerField(
      label: l10n.fieldTime,
      value: time,
      semanticsValue: time,
      onTap: () => _pickTime(fields.wallClock),
    );
    final methodField = InputDecorator(
      decoration: _PickerField.decoration(l10n.fieldPaymentMethod),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: methodId,
          // One size smaller than the text fields, like the date and time
          // (see _PickerField.textStyle).
          style: _PickerField.textStyle(context),
          isDense: true,
          isExpanded: true,
          onTap: _dropFocus,
          onChanged: (id) {
            if (id != null) _form.paymentMethodSelected(id);
          },
          items: [
            for (final (i, method) in state.paymentMethods.indexed)
              DropdownMenuItem(
                value: method.id,
                child: Text(
                  methodNames[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );

    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dateWidth = _PickerField.boxWidth(context, date);
        final timeWidth = _PickerField.boxWidth(context, time);
        final whenWidth = dateWidth + gap + timeWidth;
        final minMethodWidth = _PickerField.minDropdownWidth(
          context,
          label: l10n.fieldPaymentMethod,
          names: methodNames,
          rowWidth: width,
        );
        if (whenWidth + gap + minMethodWidth <= width) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // An InputDecorator needs a bounded width; IntrinsicWidth
              // gives it its text's width (a bare one in a Row threw, and
              // the whole form went blank).
              IntrinsicWidth(child: dateField),
              const SizedBox(width: gap),
              IntrinsicWidth(child: timeField),
              const SizedBox(width: gap),
              Expanded(child: methodField),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (whenWidth <= width)
              Row(
                children: [
                  // Flex by text width, so each gets at least its own.
                  Expanded(flex: dateWidth.round(), child: dateField),
                  const SizedBox(width: gap),
                  Expanded(flex: timeWidth.round(), child: timeField),
                ],
              )
            else ...[
              dateField,
              const SizedBox(height: 16),
              timeField,
            ],
            const SizedBox(height: 16),
            methodField,
          ],
        );
      },
    );
  }

  /// This expense's currency, then the amount, like `₹ 120` is read
  /// (owner, 2026-10-04: was a chip at the end of the form). The box shows the
  /// currency, so the amount has no symbol prefix any more.
  Widget _amountRow(ExpenseFields fields) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Looks like a dropdown but opens the currency sheet: ~150
        // currencies need its search and Recent section, not a menu.
        // IntrinsicWidth: an InputDecorator in a Row needs a bounded width
        // (see _whenAndHowRow).
        IntrinsicWidth(
          child: Semantics(
            // Its own node: without it TalkBack merged the box with the
            // amount field next to it, which it then couldn't reach (probe
            // + Oppo, 2026-10-04).
            container: true,
            button: true,
            label:
                '${l10n.fieldCurrency}: ${currencyLabel(fields.currencyCode)}',
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey('formCurrency'),
              onTap: () => _pickCurrency(fields.currencyCode),
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.fieldCurrency,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                // The amount's line height, so both boxes are equally tall;
                // scaled like its text, or the box fell short at a large
                // font (Pixel, 2026-10-05).
                child: SizedBox(
                  height:
                      MediaQuery.textScalerOf(context)
                          .scale(textTheme.headlineMedium?.fontSize ?? 28) *
                      (textTheme.headlineMedium?.height ?? 1.3),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      currencyShortLabel(fields.currencyCode),
                      maxLines: 1,
                      softWrap: false,
                      style: textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _amountField(fields)),
      ],
    );
  }

  Widget _amountField(ExpenseFields fields) {
    final l10n = AppLocalizations.of(context);
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

/// A tappable, outlined box with a floating label, like the text fields
/// above it, that opens a picker.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.semanticsValue,
    required this.onTap,
  });

  final String label;
  final String value;
  final String semanticsValue;
  final VoidCallback onTap;

  /// The row's values: one size below the text fields (14 sp, not 16).
  /// At 16 sp a date with its year left "💳 Cred…" and "Payment meth…"
  /// on a 360 dp phone (Oppo A77s, 2026-10-04).
  static TextStyle? textStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium;

  /// Shared with the payment method dropdown, so the row looks even. Side
  /// padding 8, not the default 12: at 12 "Debit card" was cut short on a
  /// 360 dp phone (Oppo A77s).
  static InputDecoration decoration(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: _sidePadding,
      vertical: 16,
    ),
  );

  static const _sidePadding = 8.0;

  /// Material 3 keeps the text this far inside an outlined border, besides
  /// the content padding: `OutlineInputBorder.gapPadding`. Left out, the
  /// boxes were measured 6 too narrow and the date was cut short.
  static const _gap = 4.0;

  /// A dense `DropdownButton`'s height for [textStyle] (its own formula):
  /// 24, or the text's scaled line if that is taller.
  static double denseHeight(BuildContext context) {
    final style = textStyle(context);
    final line = (style?.fontSize ?? 14) * (style?.height ?? 1);
    return math.max(24, MediaQuery.textScalerOf(context).scale(line));
  }

  /// The width a box showing [value] takes in a row, as the InputDecorator
  /// measures it (the label isn't counted): its text, then each side the
  /// side padding and the outline's [_gap], plus a pixel each side for
  /// rounding.
  static double boxWidth(BuildContext context, String value) =>
      _textWidth(context, value, textStyle(context)) +
      (_sidePadding + _gap) * 2 +
      2;

  /// The narrowest the payment method dropdown may get next to the date
  /// and time: its whole floating [label], and its longest name (of
  /// [names]) with the arrow (24), so the menu, as wide as the box, shows
  /// every name in full. The name part is capped at half the row, so one
  /// long custom name gets "…" instead of always taking a row of its own.
  ///
  /// Room for "💳 Debit" alone was too little: at the Oppo's largest font
  /// the label read "Payment…" and the menu "Credi…" (owner, 2026-10-05).
  static double minDropdownWidth(
    BuildContext context, {
    required String label,
    required List<String> names,
    required double rowWidth,
  }) {
    final longestName = names.fold(
      0.0,
      (widest, name) => math.max(widest, boxWidth(context, name) + 24),
    );
    return math.max(
      labelBoxWidth(context, label),
      math.min(longestName, rowWidth / 2),
    );
  }

  /// The width a box needs for its floating [label]: the label is drawn at
  /// 3/4 of the field text's size (bodyLarge), in the border's notch, which
  /// has a [_gap] each side; then the same padding as [boxWidth].
  static double labelBoxWidth(BuildContext context, String label) =>
      _textWidth(context, label, Theme.of(context).textTheme.bodyLarge) * 0.75 +
      _gap * 2 +
      (_sidePadding + _gap) * 2 +
      2;

  /// [text] on one line in [style], at the phone's font size.
  static double _textWidth(
    BuildContext context,
    String text,
    TextStyle? style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Its own node, not merged with its neighbours (see _amountRow).
      container: true,
      button: true,
      label: '$label: $semanticsValue',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: decoration(label),
          // A dense dropdown's height, so the three boxes line up (with
          // 14 sp text alone these were a few pixels shorter). Its formula,
          // not a fixed 24: at the largest font the text outgrew 24 and was
          // cut off at the bottom (Pixel, 2026-10-05).
          child: SizedBox(
            height: denseHeight(context),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: textStyle(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
