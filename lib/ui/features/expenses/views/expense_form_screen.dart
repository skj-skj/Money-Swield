import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../data/repositories/sms_suggestion_repository.dart';
import '../../../../data/services/photo_service.dart';
import '../../../../domain/amount_expression.dart';
import '../../../../domain/amount_field_input.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/expense_draft.dart';
import '../../../../domain/models/money.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/models/sms_suggestion.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/photos.dart';
import '../../../../domain/repeat_input.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/amount_texts.dart';
import '../../../core/currency_labels.dart';
import '../../../core/date_texts.dart';
import '../../../core/formatting_locale.dart';
import '../../../core/item_labels.dart';
import '../../../core/money_formatter.dart';
import '../../../core/pickers.dart';
import '../../../core/recurrence_text.dart';
import '../../../core/widgets/back_guard.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/load_failed_view.dart';
import '../../../core/widgets/photos/add_photo_sheet.dart';
import '../../../core/widgets/photos/photo_review_screen.dart';
import '../../../core/widgets/photos/photo_selection_bar.dart';
import '../../../core/widgets/photos/photo_stack_button.dart';
import '../../../core/widgets/photos/photo_viewer.dart';
import '../../../core/widgets/photos/saved_to_pictures_message.dart';
import '../../../core/widgets/save_error.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/show_message.dart';
import '../../../core/widgets/tile_picker.dart';
import '../../categories/views/category_form_screen.dart';
import '../../events/views/event_form_screen.dart';
import '../../settings/view_models/settings_cubit.dart';
import '../../sms/views/sms_banner.dart';
import '../view_models/expense_form_cubit.dart';
import 'draft_banner.dart';
import 'itemize_sheet.dart';
import 'operator_row.dart';
import 'photos_sheet.dart';
import 'repeat_section.dart';
import 'title_suggestions_field.dart';

/// Which picker is in search mode. View state, not in the cubit: it doesn't
/// affect what gets saved.
enum _Searching { none, category, events }

/// Adds an expense, or edits the one with [expenseId]. Every back pops with a
/// result: [ExpenseDraftKept] when the unsaved changes are in the draft slot,
/// else null. Save, Delete and "gone" pop with their own [ExpenseFormResult].
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.dependencies,
    this.expenseId,
    this.draft,
    this.chipAmount,
    this.startRepeating = false,
    this.sms,
    this.onOpenRecurring,
  });

  final AppDependencies dependencies;
  final int? expenseId;

  /// Recurring → New: the Add form with Repeats on.
  final bool startRepeating;

  /// Opens a recurring item's page, from the link row of a payment's Edit.
  /// Null: the row doesn't open anything.
  final void Function(BuildContext context, int itemId)? onOpenRecurring;

  /// The slot's draft, when Home opens the form from it.
  final ExpenseDraft? draft;

  /// A Home chip's amount.
  final Money? chipAmount;

  /// The SMS suggestion a new Add form is filled from.
  final SmsSuggestion? sms;

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

  /// The Repeats section's Every field.
  final _interval = TextEditingController(text: '1');

  /// Its "After N payments" field.
  final _count = TextEditingController();
  final _countFocus = FocusNode();
  final _intervalFocus = FocusNode();

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
  final _repeatKey = GlobalKey();

  /// The form's own messenger: "Cleared" and its Undo go away with the
  /// form instead of showing on Home.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// The form's Scaffold, below [_messenger].
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  var _searching = _Searching.none;

  /// Writes the draft when the app goes to the background, so a phone call or
  /// the app being killed loses nothing.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(_onAmountFocus);
    _countFocus.addListener(_onRepeatFieldFocus);
    _intervalFocus.addListener(_onRepeatFieldFocus);
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
      recurring: deps.recurring,
      startRepeating: widget.startRepeating,
      l10n: AppLocalizations.of(context),
      defaultCurrency: settings.defaultCurrency,
      defaultPaymentMethodId: settings.defaultPaymentMethodId,
      photos: deps.photos,
      cameraSizing: settings.cameraPhotos,
      gallerySizing: settings.galleryPhotos,
      decimalSeparator: _decimalSeparator,
      expenseId: widget.expenseId,
      openingDraft: widget.draft,
      chipAmount: widget.chipAmount,
      sms: widget.sms,
      smsSuggestions: deps.smsSuggestions,
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
    _interval.dispose();
    _count.dispose();
    _countFocus.dispose();
    _intervalFocus.dispose();
    _repeatScroll?.cancel();
    _titleFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  ExpenseFormCubit get _form => _cubit!;

  void _flushDraft() => _cubit?.flushDraft();

  void _flushDraftInBackground() => _cubit?.flushDraftInBackground();

  /// Leaving the title without a pick makes a title typed after a prefill the
  /// user's own.
  void _onTitleFocus() {
    if (!_titleFocus.hasFocus) _cubit?.titleLeft();
  }

  void _onAmountFocus() => setState(() {});

  /// Typing Every or After N changes "Next: … · last …" at the section's end,
  /// which the keyboard covered on the Oppo: once the keyboard is up, the
  /// section's end is scrolled into view (only as far as needed, the field
  /// staying above it).
  void _onRepeatFieldFocus() {
    if (!_countFocus.hasFocus && !_intervalFocus.hasFocus) return;
    _repeatScroll?.cancel();
    // A Timer, not Future.delayed: cancelled when the form closes first.
    _repeatScroll = Timer(_keyboardDelay, () {
      final section = _repeatKey.currentContext;
      if (!mounted || section == null || !section.mounted) return;
      Scrollable.ensureVisible(
        section,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
      );
    });
  }

  /// About how long the keyboard takes to come up and shrink the form.
  static const _keyboardDelay = Duration(milliseconds: 400);
  Timer? _repeatScroll;

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
        _syncInterval(fields);
        // Not an SMS form that came with its title: everything but the category
        // is filled, and the keyboard would hide the category tiles, the one
        // thing left to pick (found on the Oppo).
        final smsFilled = _form.smsLink != null && fields.title.isNotEmpty;
        if (first && !_form.isEditing && !smsFilled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _titleFocus.requestFocus();
          });
        }
        if (first && state.droppedDraftPhotos > 0) {
          _showMessage(
            AppLocalizations.of(context)
                .draftPhotosMissing(state.droppedDraftPhotos),
          );
        }
        _maybeReview(state);
      case ExpenseFormGone(:final draftKept):
        Navigator.pop(context, ExpenseGone(draftKept: draftKept));
      case final ExpenseFormReady ready:
        _syncInterval(ready.fields);
        _maybeReview(ready);
      case ExpenseFormLoading() || ExpenseFormLoadFailed():
        break;
    }
  }

  /// The camera shot under review, so its screen is pushed once.
  String? _reviewing;

  /// A camera shot waits for its review: pushed once per shot, also when it
  /// came back after the app was killed.
  void _maybeReview(ExpenseFormReady state) {
    final work = state.photoWork;
    if (work is! PhotoReviewing || work.captureName == _reviewing) return;
    _reviewing = work.captureName;
    final l10n = AppLocalizations.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _dropFocus();
      final decision = await Navigator.push<ReviewDecision>(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoReviewScreen(
            image: _form.photoStore.imageAt(work.previewPath, 1080),
            notice: work.recovered ? l10n.photoFromCameraBack : null,
          ),
        ),
      );
      if (!mounted) return;
      _reviewing = null;
      switch (decision) {
        case DiscardReviewedPhoto():
          await _form.discardCapture();
        case UseReviewedPhoto(:final quarterTurns):
          _showAddReport(await _form.useCapture(quarterTurns));
        case null:
          // Popped without a decision (the route was removed): as Back.
          _showAddReport(await _form.useCapture(0));
      }
    });
  }

  int _appliedRevision = 0;

  /// The Every field follows the cubit when Repeats is switched on (the
  /// last settings come back) or reset; typing sends the same text the
  /// field has, so the cursor never moves.
  void _syncInterval(ExpenseFields fields) {
    final repeat = fields.repeat;
    if (repeat == null) return;
    _setText(_interval, repeat.intervalText);
    // The After field likewise: picking After fills in the default count.
    _setText(_count, repeat.countText);
  }

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
      Navigator.pop(
        context,
        ExpenseSaved(
          saved,
          photosNotKept: _form.lastPhotosNotKept,
          repeating: _form.lastSaveRepeating,
          pastAdded: _form.lastPastAdded,
          schedule: _form.lastSavedSchedule,
          updated: _form.isEditing,
        ),
      );
    } else if (_form.value is! ExpenseFormGone) {
      _showFirstError();
      if (_form.photosOverLimit case final extra?) {
        _showMessage(
          AppLocalizations.of(context).photosMax(maxPhotosPerExpense, extra),
        );
      }
    }
  }

  Future<Expense?> _saveOrNull() async {
    Expense? saved;
    await saveOrShowError(_messengerContext, () async {
      try {
        saved = await _form.save();
      } on SmsAlreadyAdded {
        // Nothing was saved; the form and its draft stay.
        if (mounted) {
          _showMessage(AppLocalizations.of(context).smsAlreadyAdded);
        }
      } on PhotoSaveFailed catch (error) {
        // Nothing was saved and the draft is as it was; said apart from
        // "Couldn't save", which suggests trying again at once.
        debugPrint('$error');
        if (mounted) {
          _showMessage(AppLocalizations.of(context).photosSaveFailed);
        }
      }
    });
    return saved;
  }

  void _showMessage(String message) =>
      showMessage(_messenger.currentState, message);

  // Photos.

  /// The photo button: the chooser while there are none, else the sheet.
  Future<void> _onPhotoButton() async {
    _dropFocus();
    final ready = _readyState;
    if (ready == null) return;
    if (ready.fields.photos.isEmpty) {
      final message = await _addPhoto();
      if (message != null) _showMessage(message);
    } else {
      await _openPhotosSheet();
    }
  }

  /// Take photo or Choose from gallery, then the native camera or picker.
  /// Returns the message to show, or null.
  Future<String?> _addPhoto() async {
    if (!_form.canAddPhotos) return null;
    final count = _readyState?.fields.photos.length ?? 0;
    final source = await showAddPhotoSheet(context, count: count);
    if (!mounted || source == null) return null;
    final l10n = AppLocalizations.of(context);
    switch (source) {
      case PhotoSource.camera:
        final error = await _form.addFromCamera();
        return error == null ? null : _photoErrorText(l10n, error);
      case PhotoSource.gallery:
        return _addReportText(l10n, await _form.addFromGallery());
    }
  }

  void _showAddReport(PhotoAddReport? report) {
    if (!mounted) return;
    final text = _addReportText(AppLocalizations.of(context), report);
    if (text != null) _showMessage(text);
  }

  /// What adding photos did, when there is something to say.
  static String? _addReportText(AppLocalizations l10n, PhotoAddReport? r) {
    if (r == null) return null;
    if (r.error case final error?) return _photoErrorText(l10n, error);
    if (r.overflow > 0) {
      return l10n.photosOverflow(maxPhotosPerExpense, r.added);
    }
    if (r.failed > 0) return l10n.photoCouldNotBeAdded(r.failed);
    if (r.duplicates > 0) return l10n.photoAlreadyAdded;
    return null;
  }

  static String? _photoErrorText(AppLocalizations l10n, PhotoError error) =>
      switch (error) {
        PhotoError.noCamera => l10n.noCameraApp,
        // A double tap, or the app went to the background: nothing to say.
        PhotoError.busy || PhotoError.noActivity => null,
        PhotoError.notAnImage ||
        PhotoError.tooLarge ||
        PhotoError.noSpace ||
        PhotoError.ioError => l10n.photoCouldNotBeAdded(1),
      };

  Future<void> _openPhotosSheet() => showPhotosSheet(
    context,
    cubit: _form,
    onAdd: _addPhoto,
    onOpen: _openViewer,
    onSaveSelected: () => saveToPicturesMessage(
      AppLocalizations.of(context),
      _form.saveSelectedToPictures,
    ),
    onDeleteSelected: () async {
      final count = _readyState?.selection?.length ?? 0;
      if (count == 0 || !await _confirmPhotoDelete(count)) return null;
      final removed = _form.removeSelected();
      if (!mounted) return null;
      return AppLocalizations.of(context).photosDeleted(removed);
    },
  );

  Future<bool> _confirmPhotoDelete(int count) => confirmPhotoDelete(
    context,
    count: count,
    place: _form.isEditing
        ? PhotoDeletePlace.savedExpense
        : PhotoDeletePlace.newExpense,
  );

  /// The viewer over the form's photos: Save to Pictures and Delete (which
  /// applies on Update, like every photo change).
  Future<void> _openViewer(int index) {
    final photos = _readyState?.fields.photos ?? const <FormPhoto>[];
    return PhotoViewer.open(
      context,
      count: photos.length,
      initial: index,
      imageOf: (i, maxPx) {
        final current = _readyState?.fields.photos ?? photos;
        return _form.photoStore.image(current[i], maxPx);
      },
      onSave: (i) => saveToPicturesMessage(
        AppLocalizations.of(context),
        () => _form.savePhotoToPictures(i),
      ),
      onDelete: (i) async {
        if (!await _confirmPhotoDelete(1)) return false;
        _form.removePhotoAt(i);
        return true;
      },
    );
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
      if (_form.repeatError != null || _tooManyPast) _repeatKey,
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

  /// Back: close the suggestions, then a picker's search, then leave, saying
  /// whether a draft was kept. No prompt: the changes are in the draft.
  void _onBack() {
    if (_titleFocus.hasFocus && _readyState?.suggestions.isNotEmpty == true) {
      _form.dismissSuggestions();
      return;
    }
    if (_searching != _Searching.none) {
      _setSearching(_Searching.none);
      return;
    }
    // Photos being added or saved to Pictures: wait; each photo has a time
    // limit, so this never lasts.
    if (_form.photosBusy) {
      _showMessage(AppLocalizations.of(context).addingPhotos);
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

  /// "Cleared" / "Draft discarded" with Undo: a mis-tap never loses data.
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
    final picked = await pickDay(
      context,
      initial: isoDay(wallClock),
      // Future dates are allowed; no real limit either way.
      first: firstExpenseDay,
      last: lastExpenseDay,
    );
    if (picked != null) _form.dateChanged(parseDay(picked));
  }

  Future<void> _pickTime(DateTime wallClock) async {
    final picked = await pickTimeOfDay(
      context,
      hour: wallClock.hour,
      minute: wallClock.minute,
    );
    if (picked != null) _form.timeChanged(picked.hour, picked.minute);
  }

  /// The end date of Repeats: from the first payment (the form's date) to
  /// [lastEndOn], opening on the date set.
  Future<void> _pickEndDate() async {
    final startOn = _form.repeatStartOn;
    final repeat = _readyState?.fields.repeat;
    if (startOn == null || repeat == null) return;
    final picked = await pickDay(
      context,
      initial: repeat.endOn ?? _form.defaultEndOn,
      first: startOn,
      last: lastEndOn,
      helpText: AppLocalizations.of(context).repeatEndDate,
    );
    if (picked != null) _form.repeatEndDateChanged(parseDay(picked));
  }

  bool get _tooManyPast =>
      (_form.repeatSummary?.pastCount ?? 0) > maxPastPayments;

  /// Repeats at the end of the Add form and of a plain expense's Edit; on a
  /// payment's Edit, the link to its recurring item instead.
  List<Widget> _repeatPart(ExpenseFormReady state) {
    if (_form.linkedItem case final item?) {
      return [const SizedBox(height: 16), _linkRow(item)];
    }
    final startOn = _form.repeatStartOn;
    if (startOn == null || !_form.canRepeat) return const [];
    return [
      const SizedBox(height: 16),
      RepeatSection(
        key: _repeatKey,
        repeat: state.fields.repeat,
        summary: _form.repeatSummary,
        error: _form.repeatError,
        startOn: startOn,
        today: _form.today,
        defaultEndOn: _form.defaultEndOn,
        intervalController: _interval,
        countController: _count,
        countFocus: _countFocus,
        intervalFocus: _intervalFocus,
        onToggled: (on) {
          _dropFocus();
          _form.repeatToggled(on);
        },
        onFrequency: _form.repeatFrequencyChanged,
        onInterval: _form.repeatIntervalChanged,
        onEnd: _form.repeatEndChanged,
        onCount: _form.repeatCountChanged,
        onPickEndDate: _pickEndDate,
      ),
    ];
  }

  /// "🔁 Netflix · Every month on day 9 ›", then "Changes here are for this
  /// payment only."
  Widget _linkRow(RecurringItem item) {
    final l10n = AppLocalizations.of(context);
    final schedule = item.schedule;
    final scheduleLine = schedule == null
        ? ''
        : scheduleText(l10n, dateLocaleOf(context), schedule);
    final open = widget.onOpenRecurring;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Semantics(
          // Its own node: merged, TalkBack read it together with the line under
          // it.
          container: true,
          label: l10n.repeatLinkSemantics(item.title, scheduleLine),
          button: open != null,
          excludeSemantics: true,
          child: ListTile(
            key: const ValueKey('recurringLink'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.repeat),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(scheduleLine),
            trailing: open == null ? null : const Icon(Icons.chevron_right),
            onTap: open == null
                ? null
                : () {
                    _dropFocus();
                    // Under the form's own messenger, so what the page
                    // did (Stop's Undo) is said on the form.
                    open(_scaffoldKey.currentContext ?? context, item.id);
                  },
          ),
        ),
        Text(
          l10n.repeatThisPaymentOnly,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
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
        builder: (context, state) => BackGuard(
          // Every back goes through _onBack, so it can carry a result.
          onBack: _onBack,
          child: ScaffoldMessenger(
            key: _messenger,
            child: Scaffold(
              key: _scaffoldKey,
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
      actions: _clampedActions([
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
        // The same button; "Update" on an existing expense.
        TextButton(
          onPressed: _form.canSave ? _save : null,
          child: Text(_form.isEditing ? l10n.update : l10n.save),
        ),
      ]),
    );
  }

  /// The app bar's buttons with their labels' text scale capped: at 360 dp and
  /// font 2.0, "Limpiar" and "Guardar" (and the Hindi labels) needed 397 dp and
  /// more, past the screen's width. The title, which can be cut, keeps the full
  /// scale.
  static List<Widget> _clampedActions(List<Widget> actions) => [
    for (final action in actions)
      MediaQuery.withClampedTextScaling(
        maxScaleFactor: _maxActionTextScale,
        child: action,
      ),
  ];

  static const _maxActionTextScale = 1.3;

  /// The form, a banner above it when it came from a draft, and the
  /// operator row below it, right on top of the keyboard (the Scaffold
  /// already shrinks the body above it).
  Widget _body(ExpenseFormReady state) {
    final restoredAt = state.restoredAt;
    final smsSource = _form.smsSource;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        if (smsSource != null) SmsBanner(sms: smsSource),
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
        // The photo button left of the description, centred on it (owner,
        // after a device run; the tops were aligned before).
        Row(
          children: [
            PhotoStackButton(
              count: fields.photos.length,
              imageOf: (i, maxPx) =>
                  _form.photoStore.image(fields.photos[i], maxPx),
              busy: state.photoWork.blocksSave,
              onTap: _onPhotoButton,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
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
            ),
          ],
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
        ..._repeatPart(state),
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
      // The system keyboard; the operator row adds + − × ÷.
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

  /// `= ₹170.00` / `≈ ₹1.32`, or the error right away, under the amount, with
  /// Itemize next to it when the sum has ≥ 2 terms. A live region, so TalkBack
  /// reads it after a change.
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
  ) => amountErrorText(l10n, error, fields.currencyCode);
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
