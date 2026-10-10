import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show debugPrint, listEquals, setEquals;
import 'package:path/path.dart' as p;

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/expense_draft_repository.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../../../data/services/photo_service.dart';
import '../../../../data/services/photo_store.dart';
import '../../../../domain/amount_expression.dart';
import '../../../../domain/amount_input.dart';
import '../../../../domain/itemize.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/currency.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/expense_draft.dart';
import '../../../../domain/models/money.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/photo_sizing.dart';
import '../../../../domain/photos.dart';
import '../../../../domain/popularity.dart';
import '../../../../domain/recurrence.dart';
import '../../../../domain/repeat_input.dart';
import '../../../../domain/selection.dart';
import '../../../../domain/title_suggestions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/emit_if_open.dart';
import '../../../core/picker_order.dart';
import '../../../core/recent_currencies.dart';

const maxTitleLength = 100;
const maxExpenseDescriptionLength = 1000;

enum TitleError { required, tooLong }

/// What the form screen pops with. Home acts on it (phase-2.md §6.1).
sealed class ExpenseFormResult {
  const ExpenseFormResult();
}

final class ExpenseSaved extends ExpenseFormResult {
  const ExpenseSaved(
    this.expense, {
    this.photosNotKept = 0,
    this.repeating = false,
    this.pastAdded = 0,
    this.schedule,
    this.updated = false,
  });

  final Expense expense;

  /// An Edit's Update, not an Add's Save: "Updated. Repeats: …"
  /// (phase-7b.md §8.5).
  final bool updated;

  /// Photos the save couldn't link: their row went meanwhile (phase-6.md
  /// §7.1). Home says so.
  final int photosNotKept;

  /// Saved with Repeats (phase-7a.md §7.1): Home says "Saved. Repeats: …"
  /// or "Saved with 2 earlier payments."
  final bool repeating;

  /// Earlier payments the save added with it.
  final int pastAdded;

  /// The rule it repeats by, when [repeating].
  final Schedule? schedule;
}

final class ExpenseBinned extends ExpenseFormResult {
  const ExpenseBinned(this.id);

  final int id;
}

/// The edited expense was binned or deleted meanwhile. Home says so: like
/// "Moved to bin", the message is shown after the pop, on Home's own
/// messenger. [draftKept]: the edits were kept as an Add draft (P4-12).
final class ExpenseGone extends ExpenseFormResult {
  const ExpenseGone({this.draftKept = false});

  final bool draftKept;
}

/// Back with unsaved changes: they're in the draft slot. Home says "Draft
/// saved" (P4-13).
final class ExpenseDraftKept extends ExpenseFormResult {
  const ExpenseDraftKept();
}

/// What the Add/Edit form shows. States don't override `==`, so every
/// emitted state reaches the screen.
sealed class ExpenseFormState {
  const ExpenseFormState();
}

final class ExpenseFormLoading extends ExpenseFormState {
  const ExpenseFormLoading();
}

final class ExpenseFormLoadFailed extends ExpenseFormState {
  const ExpenseFormLoadFailed(this.error);

  final Object error;
}

/// The edited expense was binned or deleted meanwhile: the screen says so
/// and pops (phase-2.md §6.3). [draftKept] as for [ExpenseGone].
final class ExpenseFormGone extends ExpenseFormState {
  const ExpenseFormGone({this.draftKept = false});

  final bool draftKept;
}

/// The last Itemize: the line put first in the description, its labels and
/// the canonical terms they belong to (phase-4.md §5.2).
class ItemizeMemory {
  const ItemizeMemory({
    required this.line,
    required this.labels,
    required this.terms,
  });

  static const none = ItemizeMemory(line: null, labels: [], terms: []);

  /// The line as inserted; replaced by the next Itemize while the
  /// description's first line still equals it.
  final String? line;
  final List<String> labels;
  final List<String> terms;
}

/// What the form is doing with photos (phase-6.md §7.1). While picking,
/// processing or reviewing, Save is off and Back waits (P6-15); saving to
/// Pictures blocks neither.
sealed class PhotoWork {
  const PhotoWork();

  /// Save / Update and new photo actions wait for it.
  bool get blocksSave => false;
}

final class PhotoIdle extends PhotoWork {
  const PhotoIdle();
}

/// The camera or the picker is open.
final class PhotoPicking extends PhotoWork {
  const PhotoPicking();

  @override
  bool get blocksSave => true;
}

/// [done] of [total] picked pictures are processed.
final class PhotoProcessing extends PhotoWork {
  const PhotoProcessing(this.done, this.total);

  final int done;
  final int total;

  @override
  bool get blocksSave => true;
}

/// A camera shot waits for Use photo or Discard (§8.2a). [previewPath] is
/// its small copy; [recovered]: the app was killed while it waited, and it
/// is offered again ("The photo you took is back").
final class PhotoReviewing extends PhotoWork {
  const PhotoReviewing({
    required this.captureName,
    required this.previewPath,
    this.recovered = false,
  });

  final String captureName;
  final String previewPath;
  final bool recovered;

  @override
  bool get blocksSave => true;
}

/// Copies to Pictures are being written: [done] of [total].
final class PhotoSavingToPictures extends PhotoWork {
  const PhotoSavingToPictures(this.done, this.total);

  final int done;
  final int total;
}

/// What adding photos did, for the screen's message (§7.1).
typedef PhotoAddReport = ({
  int added,
  int duplicates,
  int overflow,
  int failed,
  PhotoError? error,
});

/// Save could not copy the photos into place: nothing was saved, the draft
/// and its staged files are untouched (§6.4 step 2).
class PhotoSaveFailed implements Exception {
  const PhotoSaveFailed(this.cause);

  final Object cause;

  @override
  String toString() => 'PhotoSaveFailed: $cause';
}

/// The form's fields as typed, plus the lists the pickers show.
final class ExpenseFormReady extends ExpenseFormState {
  const ExpenseFormReady({
    required this.fields,
    required this.categories,
    required this.events,
    required this.paymentMethods,
    this.touched = const {},
    this.itemize = ItemizeMemory.none,
    this.textRevision = 0,
    this.suggestions = const [],
    this.restoredAt,
    this.showErrors = false,
    this.saving = false,
    this.photoWork = const PhotoIdle(),
    this.selection,
    this.droppedDraftPhotos = 0,
  });

  final ExpenseFields fields;

  /// Most popular first.
  final List<Category> categories;

  /// Most popular first. Archived events are left out, except those already
  /// on the edited expense or the resumed draft (A10, R7).
  final List<Event> events;

  /// The default first, then by name (P2-9).
  final List<PaymentMethod> paymentMethods;

  /// Fields the user changed, a chip set, or that came from a saved
  /// expense or a resumed draft. Prefill fills only the others (D13).
  final Set<DraftField> touched;

  final ItemizeMemory itemize;

  /// Bumped when the cubit changes a text (prefill, Itemize, resume,
  /// Clear, Discard draft, Undo): the screen then copies the texts into
  /// its controllers. Typing never bumps it, so the cursor never jumps.
  final int textRevision;

  /// Title suggestions for what was typed; empty when hidden.
  final List<TitleSuggestion> suggestions;

  /// When the resumed draft was last saved, for the banner; null when
  /// there is no banner (it goes on the first change).
  final DateTime? restoredAt;

  /// False until the first save attempt, so an empty new form isn't shown
  /// full of errors. After that, errors update as the user types.
  final bool showErrors;

  /// A save or delete is in progress; the buttons are disabled.
  final bool saving;

  final PhotoWork photoWork;

  /// The photos selected in the Photos sheet, by index; null when not
  /// selecting (§8.10).
  final Set<int>? selection;

  /// Photos of the resumed draft that couldn't be found (P6-22), said once
  /// when the form opens; 0 after.
  final int droppedDraftPhotos;

  ExpenseFormReady copyWith({
    ExpenseFields? fields,
    List<Category>? categories,
    List<Event>? events,
    Set<DraftField>? touched,
    ItemizeMemory? itemize,
    int? textRevision,
    List<TitleSuggestion>? suggestions,
    bool clearRestored = false,
    bool? showErrors,
    bool? saving,
    PhotoWork? photoWork,
    Set<int>? Function()? selection,
  }) => ExpenseFormReady(
    fields: fields ?? this.fields,
    categories: categories ?? this.categories,
    events: events ?? this.events,
    paymentMethods: paymentMethods,
    touched: touched ?? this.touched,
    itemize: itemize ?? this.itemize,
    textRevision: textRevision ?? this.textRevision,
    suggestions: suggestions ?? this.suggestions,
    restoredAt: clearRestored ? null : restoredAt,
    showErrors: showErrors ?? this.showErrors,
    saving: saving ?? this.saving,
    photoWork: photoWork ?? this.photoWork,
    selection: selection == null ? this.selection : selection(),
  );
}

/// Every value the user can change. Compared with the baseline (a new
/// form, or the stored expense) to tell whether the form has changes.
class ExpenseFields {
  const ExpenseFields({
    required this.title,
    required this.expression,
    required this.description,
    required this.categoryId,
    required this.eventIds,
    required this.paymentMethodId,
    required this.currencyCode,
    required this.wallClock,
    this.photos = const [],
    this.repeat,
  });

  final String title;

  /// The amount as the field shows it (field form, phase-4.md §5.1):
  /// `50+60×2`, `.` or `,` as typed.
  final String expression;

  final String description;
  final int? categoryId;
  final Set<int> eventIds;
  final int? paymentMethodId;
  final String currencyCode;

  /// The date and time shown, as a UTC `DateTime` whose fields are the
  /// wall-clock time (like `Expense.wallClock`).
  final DateTime wallClock;

  /// In the order added (phase-6.md §5.2).
  final List<FormPhoto> photos;

  /// The Repeats section as typed (phase-7a.md §7.1); null = off. Add only.
  final RepeatChoice? repeat;

  /// [expression] in canonical form, as stored and compared.
  String get canonicalExpression => fieldToCanonical(expression);

  /// Without what a title suggestion never fills or removes (photos,
  /// P6-27; Repeats, phase-7a.md §7.1): adding either doesn't stop the
  /// picks, and a pick keeps both.
  ExpenseFields get withoutExtras =>
      copyWith(photos: const [], repeat: () => null);

  ExpenseFields copyWith({
    String? title,
    String? expression,
    String? description,
    int? categoryId,
    Set<int>? eventIds,
    int? paymentMethodId,
    String? currencyCode,
    DateTime? wallClock,
    List<FormPhoto>? photos,
    RepeatChoice? Function()? repeat,
  }) => ExpenseFields(
    title: title ?? this.title,
    expression: expression ?? this.expression,
    description: description ?? this.description,
    categoryId: categoryId ?? this.categoryId,
    eventIds: eventIds ?? this.eventIds,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    currencyCode: currencyCode ?? this.currencyCode,
    wallClock: wallClock ?? this.wallClock,
    photos: photos ?? this.photos,
    repeat: repeat == null ? this.repeat : repeat(),
  );

  /// The canonical expression is compared, so `1,5` and `1.5` typed for the
  /// same number aren't a change.
  @override
  bool operator ==(Object other) =>
      other is ExpenseFields &&
      other.title == title &&
      other.canonicalExpression == canonicalExpression &&
      other.description == description &&
      other.categoryId == categoryId &&
      setEquals(other.eventIds, eventIds) &&
      other.paymentMethodId == paymentMethodId &&
      other.currencyCode == currencyCode &&
      other.wallClock == wallClock &&
      samePhotos(other.photos, photos) &&
      other.repeat == repeat;

  @override
  int get hashCode => Object.hash(
    title,
    canonicalExpression,
    description,
    categoryId,
    Object.hashAllUnordered(eventIds),
    paymentMethodId,
    currencyCode,
    wallClock,
    Object.hashAll([for (final p in photos) p.sha256]),
    repeat,
  );
}

/// What Clear and Discard draft put back on Undo (phase-4.md §7.6).
typedef _Snapshot = ({
  ExpenseFields fields,
  Set<DraftField> touched,
  ItemizeMemory itemize,
  DateTime? pickedLocal,
  _Prefill? prefill,
  ExpenseFields? opening,
  bool suggestionsBlocked,
  bool titleChanged,
});

/// The last prefill (phase-4.md §7.1): the form just before it, and the
/// fields it left.
typedef _Prefill = ({
  ExpenseFields before,
  Set<DraftField> touched,
  ItemizeMemory itemize,
  ExpenseFields filled,
});

/// The Add/Edit expense form (phase-2.md §6, phase-4.md §7).
class ExpenseFormCubit extends CubitSignal<ExpenseFormState>
    with EmitIfOpen<ExpenseFormState> {
  /// [expenseId] is the expense to edit, or null to add one. New expenses
  /// start with the default currency and payment method passed in.
  ///
  /// `openingDraft` is the slot's draft when the form is opened from it
  /// (an Add draft for Add, this expense's Edit draft for Edit); the form
  /// then owns the slot. `chipAmount` is a Home chip's amount
  /// (phase-4.md §8.1).
  /// [decimalSeparator] is the formatting locale's, for amounts the form
  /// writes into the field.
  ExpenseFormCubit({
    required this._expenses,
    required this._categories,
    required this._events,
    required this._paymentMethods,
    required this._drafts,
    required this._l10n,
    required this._defaultCurrency,
    required this._defaultPaymentMethodId,
    this._recurring,
    this.startRepeating = false,
    PhotoStore? photos,
    this._cameraSizing = defaultPhotoSizing,
    this._gallerySizing = defaultPhotoSizing,
    this.decimalSeparator = '.',
    this.expenseId,
    this._openingDraft,
    this._chipAmount,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _photos = photos ?? PhotoStore.none,
       super(initialState: const ExpenseFormLoading());

  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final EventRepository _events;
  final PaymentMethodRepository _paymentMethods;
  final ExpenseDraftRepository _drafts;
  final PhotoStore _photos;

  /// For the link row of a payment's Edit (phase-7a.md §7.1). Null in
  /// tests that don't need it: no link row.
  final RecurringRepository? _recurring;

  /// Opened from Recurring → New (§8.3): Repeats starts on. A new form's
  /// baseline then has it on, so the form isn't a draft until it changes.
  final bool startRepeating;

  /// Settings → Photos, as they were when the form opened.
  final PhotoSizing _cameraSizing;
  final PhotoSizing _gallerySizing;

  final AppLocalizations _l10n;
  final String _defaultCurrency;
  final int? _defaultPaymentMethodId;
  final DateTime Function() _now;
  final ExpenseDraft? _openingDraft;
  final Money? _chipAmount;
  final String decimalSeparator;
  final int? expenseId;

  bool get isEditing => expenseId != null;

  /// Whether the Repeats section shows: on Add, and on the Edit of a plain
  /// expense (phase-7b.md §6.2, P7b-2). A payment's Edit shows its link row
  /// instead (P7a-5). False until the edited expense is loaded.
  bool get canRepeat =>
      !isEditing ||
      (_original != null && _original!.recurringExpenseId == null);

  /// The recurring item the edited expense is a payment of, for the link
  /// row (§8.1 E); null for a plain expense, an Add, or an item gone.
  RecurringItem? get linkedItem => _linkedItem;
  RecurringItem? _linkedItem;

  /// The Repeats settings last switched off, so switching on again finds
  /// them (only while the form is open: a draft keeps Repeats only when
  /// on).
  RepeatChoice? _lastRepeat;

  /// The expense being edited, once loaded.
  Expense? _original;

  /// Its photos as stored: the Edit baseline's (and Discard draft's).
  List<SavedPhoto> _originalPhotos = const [];

  /// The resumed draft's photos still there, and how many weren't.
  List<FormPhoto> _draftPhotos = const [];
  int _droppedDraftPhotos = 0;

  /// A Save to Pictures in flight: a Save waits for it before deleting
  /// staged files it may still be copying.
  Future<void>? _picturesSave;

  /// Photos of the form the store can show and save.
  PhotoStore get photoStore => _photos;

  /// What dirtiness is measured against: a new form (Add) or the stored
  /// expense (Edit), never the draft (phase-4.md §7.3).
  ExpenseFields? _baseline;

  /// The picked date and time as device-local time, or null while the user
  /// hasn't touched date or time on an edit, so an expense recorded in
  /// another time zone keeps its moment and offset (phase-2.md §3.3).
  DateTime? _pickedLocal;

  /// Whether the draft slot holds this form's draft: opened from it, or
  /// written by it. Only then may the form clear the slot or save with
  /// `clearDraft` (phase-4.md §7.3).
  bool _ownsDraft = false;
  bool get ownsDraft => _ownsDraft;

  /// What Undo after Clear / Discard draft puts back.
  _Snapshot? _undo;

  /// Every event, archived ones included: a new event's name must differ
  /// from all of them.
  List<Event> get allEvents => _allEvents;
  List<Event> _allEvents = const [];

  Map<int, ItemUsage> _categoryUsage = const {};
  Map<int, ItemUsage> _eventUsage = const {};

  /// Past titles, once read (after the form shows).
  List<TitleSuggestion>? _history;

  /// The user typed in the title in this form: suggestions only show then,
  /// not for a title that came with an Edit or a resumed draft.
  bool _titleTyped = false;

  /// The last prefill in this form, or null. Once the user changes a field
  /// it filled (to a different value), suggestions stop until the form is
  /// cleared again (owner, 2026-10-04): a pick would overwrite their work.
  _Prefill? _prefill;

  /// The form as it opened, when that can be had again without a draft: a
  /// new form (with its chip) or the stored expense. Null when it came
  /// from the draft slot: only the draft has those values.
  ExpenseFields? _opening;

  /// A resumed draft was changed after a prefill: no suggestions until the
  /// form is back to its baseline (Clear). The prefill itself isn't kept.
  bool _suggestionsBlocked = false;

  /// After a prefill, the title was left (focus moved away, or back)
  /// without a pick and differs from the picked one: it is the user's own
  /// title now, not a search, so it counts like any other change (owner,
  /// 2026-10-04). While the title has focus, typing there is a search.
  bool _titleChanged = false;

  /// Loads the lists, their usage and, when editing, the expense; then the
  /// title history. Runs once when the screen opens.
  Future<void> load() async {
    try {
      final original = expenseId == null
          ? null
          : await _expenses.byId(expenseId!);
      if (expenseId != null && original == null) {
        emitIfOpen(const ExpenseFormGone());
        return;
      }
      final categories = await _categories.all();
      final events = await _events.all();
      final paymentMethods = await _paymentMethods.all();
      _categoryUsage = await _expenses.categoryUsage();
      _eventUsage = await _expenses.eventUsage();
      _originalPhotos = original == null
          ? const []
          : await _expenses.photosOf(original.id);
      _linkedItem = await _linkedItemOf(original);
      await _checkDraftPhotos();
      _original = original;
      _allEvents = events;
      emitIfOpen(_opened(categories, paymentMethods));
    } catch (error) {
      emitIfOpen(ExpenseFormLoadFailed(error));
      return;
    }
    await _offerPendingCapture();
    await _loadTitleHistory();
  }

  /// The item [original] is a payment of. A failed read only loses the
  /// link row: the form works without it.
  Future<RecurringItem?> _linkedItemOf(Expense? original) async {
    final itemId = original?.recurringExpenseId;
    final recurring = _recurring;
    if (itemId == null || recurring == null) return null;
    try {
      return await recurring.byId(itemId);
    } catch (error) {
      debugPrint('Reading the recurring item of the expense failed: $error');
      return null;
    }
  }

  /// Keeps the resumed draft's photos that still exist (P6-22): a saved
  /// photo whose row is gone, or a staged one whose file is gone, is
  /// dropped, and the form says how many.
  Future<void> _checkDraftPhotos() async {
    final photos = _openingDraft?.photos ?? const <FormPhoto>[];
    if (photos.isEmpty) return;
    final rows = await _expenses.existingPhotoIds([
      for (final p in photos)
        if (p is SavedPhoto) p.id,
    ]);
    final missingFiles = await _photos.missingStaged(photos.whereType());
    _draftPhotos = [
      for (final photo in photos)
        if (switch (photo) {
          SavedPhoto(:final id) => rows.contains(id),
          StagedPhoto(:final stagingName) => !missingFiles.contains(
            stagingName,
          ),
        })
          photo,
    ];
    _droppedDraftPhotos = photos.length - _draftPhotos.length;
  }

  /// A camera shot left waiting for this form (the app was killed while
  /// the camera or the review was open) comes back into the review, so it
  /// can still be turned (§7.1). A shot for another form waits for that
  /// one.
  Future<void> _offerPendingCapture() async {
    try {
      final capture = await _photos.pendingCapture();
      if (capture == null || capture.editingExpenseId != expenseId) return;
      if (!await _photos.captureExists(capture.name)) {
        await _photos.clearPendingCapture();
        return;
      }
      final preview = await _photos.preview(capture.name);
      final ready = _ready;
      if (ready == null || ready.photoWork is! PhotoIdle) {
        await _photos.deleteStaged([p.basename(preview)]);
        return;
      }
      emitIfOpen(
        ready.copyWith(
          photoWork: PhotoReviewing(
            captureName: capture.name,
            previewPath: preview,
            recovered: true,
          ),
        ),
      );
    } catch (error) {
      // The form works without it; the sweep keeps the file 30 days.
      debugPrint('Offering the pending camera shot failed: $error');
    }
  }

  /// The first ready state: the baseline, then the draft and the chip on
  /// top of it.
  ExpenseFormReady _opened(
    List<Category> categories,
    List<PaymentMethod> paymentMethods,
  ) {
    final original = _original;
    final baseline = original == null
        ? _newFields(paymentMethods)
        : _fieldsOf(original);
    _baseline = baseline;
    var fields = baseline;
    var touched = original == null ? <DraftField>{} : DraftField.values.toSet();
    var itemize = original == null
        ? ItemizeMemory.none
        : _recognizedItemize(original.description ?? '', fields);
    final draft = _openingDraft;
    if (draft != null) {
      fields = _cleanedDraft(draft, baseline, categories, paymentMethods);
      touched = original == null
          ? (draft.touched ?? _differing(fields, baseline))
          : DraftField.values.toSet();
      itemize = ItemizeMemory(
        line: draft.itemizeLine,
        labels: draft.itemizeLabels,
        terms: draft.itemizeTerms,
      );
      _ownsDraft = true;
      // Recurring → New with an Add draft in the slot: the draft as it
      // was, Repeats switched on only if it has none (§8.3).
      if (startRepeating && fields.repeat == null) {
        fields = fields.copyWith(repeat: () => RepeatChoice.defaults);
      }
    }
    // A chip is an explicit choice: it sets the amount and its currency,
    // whatever a resumed draft had there (owner, 2026-10-04). The chip
    // shows exactly what is saved.
    final chip = _chipAmount;
    if (chip != null) {
      fields = fields.copyWith(
        expression: _amountText(chip.amountMinor, chip.currencyCode),
        currencyCode: chip.currencyCode,
      );
      touched = {...touched, DraftField.amount, DraftField.currency};
    }
    _opening = draft == null ? fields : null;
    _suggestionsBlocked = draft?.suggestionsBlocked ?? false;
    return ExpenseFormReady(
      fields: fields,
      categories: _categoriesByPopularity(categories),
      events: _visibleEvents(_allEvents, fields.eventIds),
      paymentMethods: _paymentMethodOrder(paymentMethods),
      touched: touched,
      itemize: itemize,
      textRevision: 1,
      restoredAt: draft?.updatedAt,
      droppedDraftPhotos: _droppedDraftPhotos,
    );
  }

  ExpenseFields _newFields(List<PaymentMethod> paymentMethods) {
    final now = _now().toLocal();
    _pickedLocal = now;
    final defaultMethod =
        paymentMethods.any((m) => m.id == _defaultPaymentMethodId)
        ? _defaultPaymentMethodId
        : paymentMethods.firstOrNull?.id;
    return ExpenseFields(
      title: '',
      expression: '',
      description: '',
      categoryId: null,
      eventIds: const {},
      paymentMethodId: defaultMethod,
      currencyCode: _defaultCurrency,
      wallClock: _wallClockOf(now),
      repeat: startRepeating ? RepeatChoice.defaults : null,
    );
  }

  ExpenseFields _fieldsOf(Expense expense) => ExpenseFields(
    title: expense.title,
    expression: _storedAmountText(expense),
    description: expense.description ?? '',
    categoryId: expense.categoryId,
    eventIds: expense.eventIds,
    paymentMethodId: expense.paymentMethodId,
    currencyCode: expense.amount.currencyCode,
    wallClock: expense.wallClock,
    photos: _originalPhotos,
  );

  /// [expense]'s amount for the field: its expression if it is valid and
  /// worth exactly the stored amount, else the plain amount. The stored
  /// amount always wins (phase-4.md §5.1), so an untouched Edit saves the
  /// same minor units.
  String _storedAmountText(Expense expense) {
    final Money(:amountMinor, :currencyCode) = expense.amount;
    final stored = expense.amountExpression;
    if (stored == null) return _amountText(amountMinor, currencyCode);
    return switch (evaluateExpression(
      stored,
      minorDigits: _minorDigits(currencyCode),
    )) {
      ExpressionValue(amountMinor: final value) when value == amountMinor =>
        canonicalToField(stored, decimalSeparator),
      _ => _amountText(amountMinor, currencyCode),
    };
  }

  /// [amountMinor] as the field shows a plain amount.
  String _amountText(int amountMinor, String currencyCode) => canonicalToField(
    formatAmountForInput(amountMinor, _minorDigits(currencyCode)),
    decimalSeparator,
  );

  /// [draft] as fields, cleaned against what exists now (phase-4.md §7.5):
  /// a category or payment method that's gone falls back to the
  /// expense's (Edit) or the new form's (Add); events that are gone are
  /// dropped; texts over a limit and an unknown currency are kept.
  ExpenseFields _cleanedDraft(
    ExpenseDraft draft,
    ExpenseFields baseline,
    List<Category> categories,
    List<PaymentMethod> paymentMethods,
  ) {
    final categoryOk = categories.any((c) => c.id == draft.categoryId);
    final methodOk = paymentMethods.any((m) => m.id == draft.paymentMethodId);
    final eventIds = {
      for (final id in draft.eventIds)
        if (_allEvents.any((e) => e.id == id)) id,
    };
    final picked = draft.pickedWallClock;
    // An untouched date: Add gets now (P4-16), Edit keeps the expense's
    // moment and offset.
    if (picked != null) _pickedLocal = picked;
    return ExpenseFields(
      title: draft.title,
      expression: canonicalToField(draft.amountExpression, decimalSeparator),
      description: draft.description,
      categoryId: categoryOk ? draft.categoryId : baseline.categoryId,
      eventIds: eventIds,
      paymentMethodId: methodOk
          ? draft.paymentMethodId
          : baseline.paymentMethodId,
      currencyCode: draft.currencyCode.isEmpty
          ? baseline.currencyCode
          : draft.currencyCode,
      wallClock: picked == null ? baseline.wallClock : _wallClockOf(picked),
      photos: _draftPhotos,
      // A payment's Edit has no Repeats (P7a-5); a plain expense's may
      // (phase-7b.md §6.2).
      repeat: canRepeat ? draft.repeat : null,
    );
  }

  /// The fields of [fields] that differ from [baseline]: what counts as
  /// touched for a draft that didn't record it.
  static Set<DraftField> _differing(
    ExpenseFields fields,
    ExpenseFields baseline,
  ) => {
    if (fields.title != baseline.title) DraftField.title,
    if (fields.canonicalExpression != baseline.canonicalExpression)
      DraftField.amount,
    if (fields.description != baseline.description) DraftField.description,
    if (fields.categoryId != baseline.categoryId) DraftField.category,
    if (!setEquals(fields.eventIds, baseline.eventIds)) DraftField.events,
    if (fields.paymentMethodId != baseline.paymentMethodId)
      DraftField.paymentMethod,
    if (fields.currencyCode != baseline.currencyCode) DraftField.currency,
    if (fields.wallClock != baseline.wallClock) DraftField.dateTime,
  };

  /// Whether a suggestion may fill in its amount in [currencyCode]: the
  /// amount is untouched or empty (typed, then cleared: owner,
  /// 2026-10-04), and the currency is untouched or the same (P4-14).
  static bool _mayFillAmount(
    Set<DraftField> touched,
    ExpenseFields fields,
    String currencyCode,
  ) =>
      (!touched.contains(DraftField.amount) ||
          fields.expression.trim().isEmpty) &&
      (!touched.contains(DraftField.currency) ||
          fields.currencyCode == currencyCode);

  /// The Itemize memory recovered from [description]'s first line when it
  /// is the line for [fields]' expression (Edit, prefill, phase-4.md §5.2).
  ItemizeMemory _recognizedItemize(String description, ExpenseFields fields) {
    final terms = _termsOf(fields);
    if (terms == null) return ItemizeMemory.none;
    final first = firstLineOf(description);
    final labels = parseItemizeLine(first, terms);
    if (labels == null) return ItemizeMemory.none;
    return ItemizeMemory(line: first, labels: labels, terms: terms);
  }

  Future<void> _loadTitleHistory() async {
    try {
      _history = groupTitleHistory(await _expenses.titleHistory());
    } catch (error) {
      // No suggestions; the form works without them.
      debugPrint('Reading the title history failed: $error');
      return;
    }
    // Typed before the history arrived: suggest for it now.
    final ready = _ready;
    if (ready != null && _titleTyped) {
      emitIfOpen(ready.copyWith(suggestions: _suggestionsFor(ready.fields)));
    }
  }

  /// Suggestions for [fields]' title, or none while a pick isn't offered.
  List<TitleSuggestion> _suggestionsFor(ExpenseFields fields) =>
      _maySuggest(fields)
      ? matchTitles(_history ?? const [], fields.title)
      : const [];

  /// Whether a pick is offered (owner, 2026-10-04): always before the
  /// first prefill; after it, only while every field but the title still
  /// has the value that prefill left (changed and changed back counts as
  /// unchanged), or once the form is cleared back to its baseline.
  ///
  /// Photos don't count here: a suggestion never fills or removes them
  /// (P6-27), so adding one doesn't stop the picks. They still count for
  /// the draft ([_needsDraft]).
  bool _maySuggest(ExpenseFields fields) {
    final withoutExtras = fields.withoutExtras;
    if (_sameButTitle(withoutExtras, _baseline?.withoutExtras)) {
      return true;
    }
    if (_suggestionsBlocked) return false;
    final prefill = _prefill;
    return prefill == null ||
        _sameAsPrefill(
          withoutExtras,
          prefill,
          filled: prefill.filled.withoutExtras,
        );
  }

  /// Whether [fields] hold something only a draft can give back (owner,
  /// 2026-10-04). Not a form as it opened (a new form, a chip, the stored
  /// expense), nor one that only a suggestion filled since: picking it
  /// again gives the same. Anything the user put in before the pick, a
  /// change after it, or a resumed draft does.
  bool _needsDraft(ExpenseFields fields) {
    if (fields == _baseline) return false;
    final opening = _opening;
    if (opening == null) return true;
    if (fields == opening) return false;
    final prefill = _prefill;
    return prefill == null ||
        !_sameAsPrefill(fields, prefill) ||
        !_sameButTitle(prefill.before, opening);
  }

  /// Whether [fields] are what [prefill] left: the title too once the user
  /// made it their own ([_titleChanged]); spaces around it don't count.
  bool _sameAsPrefill(
    ExpenseFields fields,
    _Prefill prefill, {
    ExpenseFields? filled,
  }) =>
      _sameButTitle(fields, filled ?? prefill.filled) &&
      (!_titleChanged || fields.title.trim() == prefill.filled.title.trim());

  /// The title field lost the focus, or the form is closing: a title
  /// typed after a prefill and not picked is the user's own from now on
  /// (saved as a draft, no more suggestions until Clear); one that is the
  /// picked title again is not.
  void titleLeft() {
    final ready = _ready;
    final prefill = _prefill;
    if (ready == null || prefill == null) return;
    final changed = ready.fields.title.trim() != prefill.filled.title.trim();
    if (changed == _titleChanged) return;
    _titleChanged = changed;
    if (changed && ready.suggestions.isNotEmpty) {
      emitIfOpen(ready.copyWith(suggestions: const []));
    }
    _syncDraft();
  }

  static bool _sameButTitle(ExpenseFields a, ExpenseFields? b) =>
      b != null && a.copyWith(title: '') == b.copyWith(title: '');

  ExpenseFormReady? get _ready => switch (value) {
    final ExpenseFormReady ready => ready,
    _ => null,
  };

  /// Whether anything differs from the baseline.
  bool get isDirty {
    final ready = _ready;
    return ready != null && ready.fields != _baseline;
  }

  /// Whether Save / Update does anything: always on a new form (it shows
  /// what's missing), only with changes on an existing expense.
  bool get canSave {
    final ready = _ready;
    return ready != null &&
        !ready.saving &&
        !ready.photoWork.blocksSave &&
        (!isEditing || isDirty);
  }

  /// Back waits while photos are being added or a picture is being saved
  /// to Pictures (§7.1).
  bool get photosBusy {
    final work = _ready?.photoWork;
    return work != null && work is! PhotoIdle;
  }

  /// More photos than an expense may have (a damaged draft): Save says
  /// how many to remove (§5.2). Shown after the first save attempt.
  int? get photosOverLimit {
    final ready = _ready;
    if (ready == null || !ready.showErrors) return null;
    final extra = ready.fields.photos.length - maxPhotosPerExpense;
    return extra > 0 ? extra : null;
  }

  // Validation. The errors are computed from the fields every time, so
  // changing the currency re-validates the amount against its digits.

  TitleError? get titleError => _shown(_titleError);
  ExpressionError? get amountError => _shown(_amountError);
  bool get descriptionTooLong => _shown(_descriptionTooLong) ?? false;
  bool get categoryMissing => _shown(_categoryMissing) ?? false;

  T? _shown<T>(T? Function(ExpenseFields fields) check) {
    final ready = _ready;
    return ready != null && ready.showErrors ? check(ready.fields) : null;
  }

  static TitleError? _titleError(ExpenseFields fields) {
    final title = fields.title.trim();
    if (title.isEmpty) return TitleError.required;
    if (title.characters.length > maxTitleLength) return TitleError.tooLong;
    return null;
  }

  ExpressionError? _amountError(ExpenseFields fields) =>
      switch (_evaluate(fields)) {
        ExpressionRejected(:final error) => error,
        ExpressionValue() => null,
      };

  static bool? _descriptionTooLong(ExpenseFields fields) =>
      fields.description.trim().characters.length > maxExpenseDescriptionLength
      ? true
      : null;

  bool? _categoryMissing(ExpenseFields fields) {
    final categories = _ready?.categories ?? const [];
    return categories.any((c) => c.id == fields.categoryId) ? null : true;
  }

  /// The amount field's value. A build asks for it several times (error,
  /// result line, Itemize), so the last result is kept.
  ExpressionResult _evaluate(ExpenseFields fields) {
    final last = _lastEvaluated;
    if (last != null &&
        last.expression == fields.expression &&
        last.currencyCode == fields.currencyCode) {
      return last.result;
    }
    final result = evaluateField(
      fields.expression,
      minorDigits: _minorDigits(fields.currencyCode),
      decimalSeparator: decimalSeparator,
    );
    _lastEvaluated = (
      expression: fields.expression,
      currencyCode: fields.currencyCode,
      result: result,
    );
    return result;
  }

  ({String expression, String currencyCode, ExpressionResult result})?
  _lastEvaluated;

  /// What the result line under the amount shows, or null when it is
  /// hidden: shown for an operator, a `,` or two separators (R8), before
  /// the first save too.
  ExpressionResult? get amountResult {
    final ready = _ready;
    if (ready == null || !needsResultLine(ready.fields.expression)) {
      return null;
    }
    return _evaluate(ready.fields);
  }

  /// The additive terms when Itemize is offered (≥ 2 terms and the
  /// expression evaluates), else null.
  List<String>? get itemizeTerms {
    final ready = _ready;
    return ready == null ? null : _termsOf(ready.fields);
  }

  List<String>? _termsOf(ExpenseFields fields) => switch (_evaluate(fields)) {
    ExpressionValue(:final terms) when terms.length >= 2 => terms,
    _ => null,
  };

  /// The labels the Itemize sheet opens with: the last Itemize's when the
  /// terms are the same canonical terms, else none.
  List<String> get itemizeLabels {
    final ready = _ready;
    final terms = itemizeTerms;
    if (ready == null || terms == null) return const [];
    return listEquals(ready.itemize.terms, terms)
        ? ready.itemize.labels
        : List.filled(terms.length, '');
  }

  /// Digits after the decimal point for [currencyCode]; 2 for a code from a
  /// newer app's catalog.
  static int _minorDigits(String currencyCode) =>
      findCurrency(currencyCode)?.minorDigits ?? 2;

  // Pickers.

  List<PickerItem> get categoryItems => [
    for (final c in _ready?.categories ?? const <Category>[])
      PickerItem(id: c.id, emoji: c.emoji, name: categoryName(_l10n, c)),
  ];

  List<PickerItem> get eventItems => [
    for (final e in _ready?.events ?? const <Event>[])
      PickerItem(id: e.id, emoji: e.emoji, name: eventName(_l10n, e)),
  ];

  /// The emoji of category [id], for a suggestion row; null if unknown.
  String? categoryEmoji(int id) =>
      _ready?.categories.where((c) => c.id == id).firstOrNull?.emoji;

  /// The currencies of the latest entered expenses, for the currency
  /// sheet's Recent section. Empty if they can't be read: the sheet still
  /// works without them.
  Future<List<String>> recentCurrencies() => recentCurrenciesOrEmpty(_expenses);

  // Field changes. Each marks its field touched and updates the draft.

  void titleChanged(String title) {
    _titleTyped = true;
    final fields = _ready?.fields.copyWith(title: title);
    _change(
      DraftField.title,
      (f) => f.copyWith(title: title),
      suggestions: fields == null ? null : _suggestionsFor(fields),
    );
  }

  void amountChanged(String text) =>
      _change(DraftField.amount, (f) => f.copyWith(expression: text));

  void descriptionChanged(String description) => _change(
    DraftField.description,
    (f) => f.copyWith(description: description),
  );

  void categorySelected(int id) =>
      _change(DraftField.category, (f) => f.copyWith(categoryId: id));

  void eventToggled(int id) => _change(
    DraftField.events,
    (f) => f.copyWith(
      eventIds: f.eventIds.contains(id)
          ? ({...f.eventIds}..remove(id))
          : {...f.eventIds, id},
    ),
  );

  /// The "None" event tile: the expense has no events.
  void eventsCleared() =>
      _change(DraftField.events, (f) => f.copyWith(eventIds: const {}));

  void paymentMethodSelected(int id) =>
      _change(DraftField.paymentMethod, (f) => f.copyWith(paymentMethodId: id));

  /// Changes the currency of this expense only. Never converts or rounds
  /// the amount; it is re-validated against the new currency's digits.
  void currencyChanged(String code) =>
      _change(DraftField.currency, (f) => f.copyWith(currencyCode: code));

  /// Sets the date, keeping the time. Read as device-local time.
  void dateChanged(DateTime date) {
    final ready = _ready;
    if (ready == null) return;
    final shown = ready.fields.wallClock;
    _setLocal(
      DateTime(date.year, date.month, date.day, shown.hour, shown.minute),
    );
  }

  /// Sets the time, keeping the date. Read as device-local time.
  void timeChanged(int hour, int minute) {
    final ready = _ready;
    if (ready == null) return;
    final shown = ready.fields.wallClock;
    _setLocal(DateTime(shown.year, shown.month, shown.day, hour, minute));
  }

  /// [local] is already normalized by Dart: a time that doesn't exist (in
  /// a DST gap) has moved forward. The form shows it as normalized, so what
  /// is saved is exactly what was shown (phase-2.md §3.3).
  void _setLocal(DateTime local) {
    _pickedLocal = local;
    _change(
      DraftField.dateTime,
      (f) => f.copyWith(wallClock: _wallClockOf(local)),
    );
  }

  /// A category created from the picker: added to the list and selected.
  void categoryAdded(Category category) {
    final ready = _ready;
    if (ready == null) return;
    _apply(
      ready.copyWith(
        categories: _categoriesByPopularity([...ready.categories, category]),
        fields: ready.fields.copyWith(categoryId: category.id),
        touched: {...ready.touched, DraftField.category},
        clearRestored: true,
      ),
    );
  }

  /// An event created from the picker: added to the list and selected.
  void eventAdded(Event event) {
    final ready = _ready;
    if (ready == null) return;
    _allEvents = [..._allEvents, event];
    _apply(
      ready.copyWith(
        events: _eventsByPopularity([...ready.events, event]),
        fields: ready.fields.copyWith(
          eventIds: {...ready.fields.eventIds, event.id},
        ),
        touched: {...ready.touched, DraftField.events},
        clearRestored: true,
      ),
    );
  }

  void _change(
    DraftField field,
    ExpenseFields Function(ExpenseFields fields) change, {
    List<TitleSuggestion>? suggestions,
  }) {
    final ready = _ready;
    if (ready == null) return;
    final fields = change(ready.fields);
    _apply(
      ready.copyWith(
        fields: fields,
        touched: {...ready.touched, field},
        itemize: switch (field) {
          DraftField.description ||
          DraftField.amount ||
          DraftField.currency => _liveItemize(fields, ready.itemize),
          _ => null,
        },
        suggestions: suggestions,
        clearRestored: true,
      ),
    );
  }

  /// The Itemize memory after the description or the amount changed: when
  /// the first line still reads as the Itemize line for the amount, its
  /// labels as typed there now (an edit inside the brackets shows in the
  /// sheet at once); else [current], unchanged.
  ItemizeMemory _liveItemize(ExpenseFields fields, ItemizeMemory current) {
    final recognized = _recognizedItemize(fields.description, fields);
    return recognized.line == null ? current : recognized;
  }

  /// Emits [next] and mirrors it to the draft slot.
  void _apply(ExpenseFormReady next) {
    emitIfOpen(next);
    _syncDraft();
  }

  // Title suggestions and prefill.

  /// Hides the suggestions until the title is typed in again (back).
  void dismissSuggestions() {
    final ready = _ready;
    if (ready == null || ready.suggestions.isEmpty) return;
    emitIfOpen(ready.copyWith(suggestions: const []));
  }

  /// Sets the title to [suggestion]'s spelling, then fills the untouched
  /// fields from the newest expense with that title (D13, phase-4.md §7.1).
  /// Fields it fills stay untouched, so a second pick replaces them (P4-3).
  /// Ignored while a pick isn't offered ([_maySuggest]).
  Future<void> pickSuggestion(TitleSuggestion suggestion) async {
    final ready = _ready;
    if (ready == null || !_maySuggest(ready.fields)) return;
    _apply(
      ready.copyWith(
        fields: ready.fields.copyWith(title: suggestion.title),
        touched: {...ready.touched, DraftField.title},
        textRevision: ready.textRevision + 1,
        suggestions: const [],
        clearRestored: true,
      ),
    );
    final Expense? source;
    try {
      source = await _expenses.prefillSource(suggestion.spellings);
    } catch (error) {
      debugPrint('Reading the prefill source failed: $error');
      return;
    }
    if (source != null) _prefillFrom(source);
  }

  void _prefillFrom(Expense source) {
    final ready = _ready;
    if (ready == null) return;
    // Nothing changed since the last prefill: start from the form as it
    // was before it, so this one replaces everything that one filled,
    // an amount it filled into an emptied field too (P4-3).
    final last = _prefill;
    // Photos and Repeats set since don't make it a new start, and are
    // kept: the form before the last prefill knew nothing of them (§12a;
    // phase-7a.md §12a).
    final again =
        last != null &&
        _sameButTitle(ready.fields.withoutExtras, last.filled.withoutExtras);
    final start = again
        ? last.before.copyWith(
            title: ready.fields.title,
            photos: ready.fields.photos,
            repeat: () => ready.fields.repeat,
          )
        : ready.fields;
    final touched = again ? {...last.touched, DraftField.title} : ready.touched;
    final startItemize = again ? last.itemize : ready.itemize;
    bool untouched(DraftField field) => !touched.contains(field);
    var fields = start;
    var itemize = startItemize;

    final copyAmount = _mayFillAmount(
      touched,
      fields,
      source.amount.currencyCode,
    );
    if (copyAmount) {
      fields = fields.copyWith(
        expression: _storedAmountText(source),
        currencyCode: source.amount.currencyCode,
      );
    }
    if (untouched(DraftField.description)) {
      fields = fields.copyWith(description: source.description ?? '');
      itemize = _recognizedItemize(fields.description, fields);
    }
    if (untouched(DraftField.category) &&
        ready.categories.any((c) => c.id == source.categoryId)) {
      fields = fields.copyWith(categoryId: source.categoryId);
    }
    if (untouched(DraftField.events)) {
      // Archived events are left out (A10).
      fields = fields.copyWith(
        eventIds: {
          for (final e in _allEvents)
            if (!e.isArchived && source.eventIds.contains(e.id)) e.id,
        },
      );
    }
    if (untouched(DraftField.paymentMethod) &&
        ready.paymentMethods.any((m) => m.id == source.paymentMethodId)) {
      fields = fields.copyWith(paymentMethodId: source.paymentMethodId);
    }
    _suggestionsBlocked = false;
    _titleChanged = false;
    _prefill = (
      before: start,
      touched: touched,
      itemize: startItemize,
      filled: fields,
    );
    _apply(
      ready.copyWith(
        fields: fields,
        touched: touched,
        itemize: itemize,
        textRevision: ready.textRevision + 1,
      ),
    );
  }

  // Itemize.

  /// Puts the Itemize line for the current terms with [labels] first in
  /// the description: in place of the last one if the user hasn't changed
  /// it, else above it (phase-4.md §5.2).
  void itemize(List<String> labels) {
    final ready = _ready;
    final terms = itemizeTerms;
    if (ready == null || terms == null) return;
    final line = buildItemizeLine(terms, labels, decimalSeparator);
    final description = putItemizeLine(
      ready.fields.description,
      line,
      ready.itemize.line,
    );
    _apply(
      ready.copyWith(
        fields: ready.fields.copyWith(description: description),
        touched: {...ready.touched, DraftField.description},
        itemize: ItemizeMemory(
          line: line,
          labels: [for (final l in labels) l.trim()],
          terms: terms,
        ),
        textRevision: ready.textRevision + 1,
        clearRestored: true,
      ),
    );
  }

  // Clear, Discard draft, Undo (phase-4.md §7.6).

  /// Whether Clear does anything: the Add form differs from a new form.
  bool get canClear => !isEditing && isDirty;

  /// Add: back to a new form (date now, default currency and payment
  /// method), and the slot emptied if this form owns it.
  Future<void> clear() async {
    final ready = _ready;
    if (ready == null || isEditing) return;
    _undo = _snapshotOf(ready);
    _prefill = null;
    _suggestionsBlocked = false;
    _titleChanged = false;
    final fields = _newFields(ready.paymentMethods);
    _baseline = fields;
    _opening = fields;
    await _resetTo(ready, fields, const {}, ItemizeMemory.none);
  }

  /// Edit opened from a draft: back to the stored expense, and the slot
  /// emptied. The form stays open; Update is disabled until a change.
  Future<void> discardDraft() async {
    final ready = _ready;
    final original = _original;
    if (ready == null || original == null) return;
    _undo = _snapshotOf(ready);
    _prefill = null;
    _suggestionsBlocked = false;
    _titleChanged = false;
    _pickedLocal = null;
    final fields = _fieldsOf(original);
    _opening = fields;
    await _resetTo(
      ready,
      fields,
      DraftField.values.toSet(),
      _recognizedItemize(fields.description, fields),
    );
  }

  /// Puts back what the last Clear or Discard draft changed, and so the
  /// draft too, through the normal update.
  void undoReset() {
    final ready = _ready;
    final undo = _undo;
    if (ready == null || undo == null) return;
    _undo = null;
    _pickedLocal = undo.pickedLocal;
    _prefill = undo.prefill;
    _opening = undo.opening;
    _suggestionsBlocked = undo.suggestionsBlocked;
    _titleChanged = undo.titleChanged;
    _apply(
      ready.copyWith(
        fields: undo.fields,
        // The reset dropped an archived event only the undone fields had;
        // list it again, or it would be saved without being shown (R7).
        events: _visibleEvents(_allEvents, undo.fields.eventIds),
        touched: undo.touched,
        itemize: undo.itemize,
        textRevision: ready.textRevision + 1,
        suggestions: const [],
      ),
    );
  }

  _Snapshot _snapshotOf(ExpenseFormReady ready) => (
    fields: ready.fields,
    touched: ready.touched,
    itemize: ready.itemize,
    pickedLocal: _pickedLocal,
    prefill: _prefill,
    opening: _opening,
    suggestionsBlocked: _suggestionsBlocked,
    titleChanged: _titleChanged,
  );

  Future<void> _resetTo(
    ExpenseFormReady ready,
    ExpenseFields fields,
    Set<DraftField> touched,
    ItemizeMemory itemize,
  ) async {
    _titleTyped = false;
    emitIfOpen(
      ready.copyWith(
        fields: fields,
        touched: touched,
        itemize: itemize,
        events: _visibleEvents(_allEvents, fields.eventIds),
        textRevision: ready.textRevision + 1,
        suggestions: const [],
        clearRestored: true,
        showErrors: false,
      ),
    );
    if (_ownsDraft) {
      _ownsDraft = false;
      await _drafts.clear();
    }
  }

  // The draft slot (phase-4.md §7.3).

  /// Mirrors the form to the slot: a form that needs a draft writes (and
  /// so takes the slot, replacing another form's draft, P4-1); one that no
  /// longer does (clean again, or only a suggestion's values) empties the
  /// slot if it holds this form's draft.
  /// Nothing is written while loading, saving, or after close.
  void _syncDraft() {
    final ready = _ready;
    if (ready == null || ready.saving || isClosed) return;
    if (_needsDraft(ready.fields)) {
      _drafts.update(_draftOf(ready));
      _ownsDraft = true;
    } else if (_ownsDraft) {
      _ownsDraft = false;
      unawaited(_drafts.clear());
    }
  }

  ExpenseDraft _draftOf(ExpenseFormReady ready, {bool asAdd = false}) {
    final fields = ready.fields;
    final dateTouched = ready.touched.contains(DraftField.dateTime);
    return ExpenseDraft(
      editingExpenseId: asAdd ? null : expenseId,
      title: fields.title,
      amountExpression: fields.canonicalExpression,
      description: fields.description,
      categoryId: fields.categoryId,
      eventIds: fields.eventIds,
      paymentMethodId: fields.paymentMethodId,
      currencyCode: fields.currencyCode,
      pickedWallClock: dateTouched ? _pickedLocal : null,
      touched: ready.touched,
      itemizeLine: ready.itemize.line,
      itemizeLabels: ready.itemize.labels,
      itemizeTerms: ready.itemize.terms,
      updatedAt: _now().toUtc(),
      suggestionsBlocked: !_maySuggest(fields),
      photos: fields.photos,
      repeat: fields.repeat,
    );
  }

  /// Writes the draft now (the form closes, or the app goes to the
  /// background). Never throws: a failed write stays due and is logged.
  Future<void> flushDraft() => _drafts.flush();

  /// [flushDraft] when the app goes to the background, where it may be
  /// killed: a title still being typed after a prefill isn't the user's
  /// own yet ([titleLeft]), but it is kept in the slot too, so a kill
  /// doesn't lose it. Suggestions stay on; a pick on return removes it.
  Future<void> flushDraftInBackground() {
    final ready = _ready;
    final prefill = _prefill;
    if (ready != null &&
        prefill != null &&
        !ready.saving &&
        !isClosed &&
        ready.fields.title.trim() != prefill.filled.title.trim() &&
        !_needsDraft(ready.fields)) {
      _drafts.update(_draftOf(ready));
      _ownsDraft = true;
    }
    return _drafts.flush();
  }

  // Repeats (phase-7a.md §7.1): on Add and on a plain expense's Edit
  // (phase-7b.md §7.1); a change like any field, so the draft follows and
  // Update is enabled by Repeats alone.

  /// Switches Repeats on (the settings last switched off, else every 1
  /// month, never ending) or off. Off keeps the settings for switching on
  /// again while the form is open.
  void repeatToggled(bool on) {
    final ready = _ready;
    if (ready == null || !canRepeat) return;
    final current = ready.fields.repeat;
    if (on == (current != null)) return;
    if (!on) _lastRepeat = current;
    _setRepeat(ready, on ? _lastRepeat ?? RepeatChoice.defaults : null);
  }

  void repeatFrequencyChanged(Frequency frequency) =>
      _updateRepeat((r) => r.copyWith(frequency: frequency));

  /// The Every field as typed (the field takes digits only, two at most);
  /// checked at Save (P7a-26).
  void repeatIntervalChanged(String text) =>
      _updateRepeat((r) => r.copyWith(intervalText: text));

  /// Never, On date or After N payments. On without a date yet gets one:
  /// six months after the form's date (clamped to the month's end), so the
  /// row always shows one and the picker opens on it. After with nothing
  /// typed gets [defaultRepeatCountText] the same way (phase-7b.md §12a).
  void repeatEndChanged(RepeatEnd end) => _updateRepeat(
    (r) => r.copyWith(
      end: end,
      endOn: r.endOn ?? (end == RepeatEnd.onDate ? _defaultEndOn() : null),
      countText: end == RepeatEnd.afterCount && r.countText.isEmpty
          ? defaultRepeatCountText
          : null,
    ),
  );

  /// The After field as typed (digits only, three at most; phase-7b.md
  /// §7.1); checked at Save, like Every.
  void repeatCountChanged(String text) => _updateRepeat(
    (r) => r.copyWith(end: RepeatEnd.afterCount, countText: text),
  );

  /// The end date picked: ends on it.
  void repeatEndDateChanged(DateTime date) => _updateRepeat(
    (r) => r.copyWith(end: RepeatEnd.onDate, endOn: isoDay(date)),
  );

  void _updateRepeat(RepeatChoice Function(RepeatChoice repeat) change) {
    final ready = _ready;
    final repeat = ready?.fields.repeat;
    if (ready == null || repeat == null) return;
    _setRepeat(ready, change(repeat));
  }

  void _setRepeat(ExpenseFormReady ready, RepeatChoice? repeat) => _apply(
    ready.copyWith(
      fields: ready.fields.copyWith(repeat: () => repeat),
      clearRestored: true,
    ),
  );

  /// The end "On" gets when picked with no date yet, and shows meanwhile.
  String get defaultEndOn => _defaultEndOn();

  String _defaultEndOn() => occurrenceAt(
    Schedule(
      frequency: Frequency.monthly,
      interval: 6,
      startOn: repeatStartOn ?? todayOn(_now()),
    ),
    1,
  );

  /// The first payment's date: the form's date (§6.2 takes the saved
  /// row's, which is this one).
  String? get repeatStartOn {
    final ready = _ready;
    return ready == null ? null : isoDay(ready.fields.wallClock);
  }

  /// Today on the device, for the section's texts.
  String get today => todayOn(_now());

  /// What the section says under the rule (§8.2): the earlier payments a
  /// Save adds (at most [maxPastPayments]; `pastCount` is them all), the
  /// next one after those and, with an end, the last one (phase-7b.md
  /// §8.2). Null while Repeats is off, or Every or After N isn't valid
  /// ([scheduleOrNull]). Live, before any Save attempt.
  RepeatSummary? get repeatSummary {
    final repeat = _ready?.fields.repeat;
    final startOn = repeatStartOn;
    if (repeat == null || startOn == null) return null;
    final today = this.today;
    final key = (repeat, startOn, today);
    final cached = _summaryCache;
    if (cached != null && cached.key == key) return cached.summary;
    final schedule = scheduleOrNull(repeat, startOn);
    final RepeatSummary? summary;
    if (schedule == null) {
      summary = null;
    } else {
      final (:past, :next) = repeatPreview(
        repeat,
        startOn: startOn,
        today: today,
      );
      summary = (
        past: past,
        pastCount: pastPaymentCount(repeat, startOn: startOn, today: today),
        next: next,
        last: lastOccurrence(schedule),
      );
    }
    _summaryCache = (key: key, summary: summary);
    return summary;
  }

  /// The last [repeatSummary] and what it was computed from: the form
  /// rebuilds on every keystroke, and a back-dated daily item walks up to
  /// 1,000 dates (≈9 ms each time in a debug test run).
  ({(RepeatChoice, String, String) key, RepeatSummary? summary})? _summaryCache;

  /// What's wrong with the Repeats settings, after the first Save attempt
  /// (like the other errors). Too many earlier payments shows live in the
  /// preview instead.
  RepeatError? get repeatError => _shown(_repeatError);

  RepeatError? _repeatError(ExpenseFields fields) {
    final repeat = fields.repeat;
    if (repeat == null || !canRepeat) return null;
    return validateRepeat(
      repeat,
      startOn: isoDay(fields.wallClock),
      today: todayOn(_now()),
    );
  }

  /// Whether the last save repeats, and how many earlier payments it
  /// added: the screen pops with them (§8.9).
  bool get lastSaveRepeating => _lastSaveRepeating;
  bool _lastSaveRepeating = false;
  int get lastPastAdded => _lastPastAdded;
  int _lastPastAdded = 0;
  Schedule? get lastSavedSchedule => _lastSavedSchedule;
  Schedule? _lastSavedSchedule;

  // Saving.

  /// Validates and saves. Returns the saved expense, or null if a field is
  /// invalid (the errors are then shown) or a save is already running.
  /// Emits [ExpenseFormGone] and returns null if the edited expense was
  /// binned or deleted meanwhile; the edits are then kept as an Add draft
  /// (P4-12). Rethrows other database errors (the draft is kept); the
  /// screen tells the user.
  Future<Expense?> save() async {
    final ready = _ready;
    if (ready == null || ready.saving) return null;
    final fields = ready.fields;
    final amount = _evaluate(fields);
    final paymentMethodId = fields.paymentMethodId;
    if (ready.photoWork.blocksSave) return null;
    if (_titleError(fields) != null ||
        amount is! ExpressionValue ||
        _descriptionTooLong(fields) != null ||
        _categoryMissing(fields) != null ||
        paymentMethodId == null ||
        fields.photos.length > maxPhotosPerExpense ||
        _repeatError(fields) != null) {
      emitIfOpen(ready.copyWith(showErrors: true));
      return null;
    }

    final (occurredAt, offset) = _moment();

    emitIfOpen(ready.copyWith(saving: true));
    var saved = false;
    try {
      final owns = await _settleDraft();
      // Staged photos are copied into place first (§6.4 step 2).
      final links = await _photoLinks(fields.photos);
      final input = ExpenseInput(
        title: fields.title.trim(),
        description: switch (fields.description.trim()) {
          '' => null,
          final text => text,
        },
        amount: Money(amount.amountMinor, fields.currencyCode),
        amountExpression: amount.stored,
        occurredAt: occurredAt,
        utcOffsetMinutes: offset,
        categoryId: fields.categoryId!,
        paymentMethodId: paymentMethodId,
        eventIds: fields.eventIds,
        photos: links,
      );
      final id = expenseId;
      final repeat = canRepeat ? fields.repeat : null;
      final Expense expense;
      if (repeat != null) {
        final result = id == null
            ? await _expenses.addRepeating(input, repeat, clearDraft: owns)
            : await _expenses.updateRepeating(
                id,
                input,
                repeat,
                clearDraft: owns,
              );
        expense = result.expense;
        _lastPastAdded = result.pastAdded;
        _lastSavedSchedule = scheduleFor(repeat, expense.occurredOn);
      } else {
        expense = id == null
            ? await _expenses.add(input, clearDraft: owns)
            : await _expenses.update(id, input, clearDraft: owns);
        _lastPastAdded = 0;
        _lastSavedSchedule = null;
      }
      _lastSaveRepeating = repeat != null;
      saved = true;
      _afterDraftDeleted(owns);
      _baseline = fields;
      _lastPhotosNotKept = links.length - expense.photoCount;
      await _deleteSavedStaged(fields.photos);
      return expense;
    } on RepeatRefused {
      // Checked again inside the save (a Save across midnight can tip the
      // count over the cap): nothing was written; the error shows.
      final current = _ready;
      if (current != null) emitIfOpen(current.copyWith(showErrors: true));
      return null;
    } on ExpenseNotFound {
      // `update` refuses a binned or deleted expense: the edits become an
      // Add draft, so nothing typed is lost.
      _drafts.update(_draftOf(ready, asAdd: true));
      _ownsDraft = true;
      emitIfOpen(const ExpenseFormGone(draftKept: true));
      return null;
    } finally {
      final current = _ready;
      if (current != null) emitIfOpen(current.copyWith(saving: false));
      // Changes typed while saving reach the draft now.
      if (!saved) _syncDraft();
    }
  }

  /// Moves the edited expense to the bin (no confirm: it is recoverable,
  /// A4), its draft with it. Returns its id, or null on a new form or
  /// while saving. Emits [ExpenseFormGone] and returns null if it was
  /// already binned or gone (R14).
  Future<int?> moveToBin() async {
    final ready = _ready;
    final id = expenseId;
    if (ready == null || id == null || ready.saving) return null;
    emitIfOpen(ready.copyWith(saving: true));
    try {
      final owns = await _settleDraft();
      await _expenses.moveToBin(id, clearDraft: owns);
      _afterDraftDeleted(owns);
      return id;
    } on ExpenseNotFound {
      if (_ownsDraft) {
        _ownsDraft = false;
        await _drafts.clear();
      }
      emitIfOpen(const ExpenseFormGone());
      return null;
    } finally {
      final current = _ready;
      if (current != null) emitIfOpen(current.copyWith(saving: false));
    }
  }

  /// How many photos the last save couldn't link (a row gone meanwhile).
  int get lastPhotosNotKept => _lastPhotosNotKept;
  int _lastPhotosNotKept = 0;

  /// §6.4 step 2: each staged photo copied into `photos/` (its name is its
  /// hash), each saved one by id. A copy that fails (no space, I/O) stops
  /// the save before anything is written: [PhotoSaveFailed].
  Future<List<PhotoLinkInput>> _photoLinks(List<FormPhoto> photos) async {
    final links = <PhotoLinkInput>[];
    for (final photo in photos) {
      switch (photo) {
        case SavedPhoto(:final id):
          links.add(LinkSavedPhoto(id));
        case StagedPhoto():
          final String path;
          try {
            path = await _photos.promote(photo);
          } catch (error) {
            throw PhotoSaveFailed(error);
          }
          links.add(
            LinkNewPhoto(
              relativePath: path,
              sha256: photo.sha256,
              byteSize: photo.byteSize,
            ),
          );
      }
    }
    return links;
  }

  /// After the commit: the staged files of the photos just saved are no
  /// longer needed (their copies are in `photos/`). A Save to Pictures
  /// still copying one is waited for. Best effort: the sweep deletes what
  /// is left.
  Future<void> _deleteSavedStaged(List<FormPhoto> photos) async {
    try {
      await _picturesSave;
      await _photos.deleteStaged([
        for (final photo in photos.whereType<StagedPhoto>()) photo.stagingName,
      ]);
    } catch (error) {
      debugPrint('Deleting staged photos after a save failed: $error');
    }
  }

  // Photos (phase-6.md §7.1).

  int get remainingPhotoSlotsNow =>
      remainingPhotoSlots(_ready?.fields.photos ?? const []);

  /// Whether a new photo may be added now: the form is ready, idle, not
  /// saving, and has room.
  bool get canAddPhotos {
    final ready = _ready;
    return ready != null &&
        _photos.isAvailable &&
        !ready.saving &&
        ready.photoWork is PhotoIdle &&
        remainingPhotoSlots(ready.fields.photos) > 0;
  }

  /// Opens the camera (§7.1). The marker is written and the draft flushed
  /// first, so a shot survives the app being killed while the camera is
  /// open; it is not the draft slot, so another expense's draft stays.
  /// Returns an error to show, or null. A taken picture goes to the review
  /// ([PhotoReviewing]); the screen then calls [useCapture] or
  /// [discardCapture].
  Future<PhotoError?> addFromCamera() async {
    if (!canAddPhotos) return null;
    final name = _photos.newCaptureName();
    _setWork(const PhotoPicking());
    try {
      await _photos.markPendingCapture(name, expenseId);
      await _drafts.flush();
      final taken = await _photos.service.capture(_photos.stagingFile(name));
      if (!taken) {
        await _forgetCapture(name);
        _setWork(const PhotoIdle());
        return null;
      }
      final preview = await _photos.preview(name);
      _setWork(PhotoReviewing(captureName: name, previewPath: preview));
      return null;
    } on PhotoServiceException catch (e) {
      await _forgetCapture(name);
      _setWork(const PhotoIdle());
      return e.error;
    } catch (error) {
      debugPrint('Taking a photo failed: $error');
      await _forgetCapture(name);
      _setWork(const PhotoIdle());
      return PhotoError.ioError;
    }
  }

  /// Use photo (or Back) on the review: the camera's file, turned by
  /// [quarterTurns], is processed with the camera's sizing and added.
  ///
  /// The marker and the camera's file go only once the draft **row** names
  /// the staged copy: the draft is written with a debounce, so it is
  /// flushed first. Killed before that, the next open offers the shot
  /// again (the staged copy, unnamed, is swept); never neither.
  ///
  /// On a full form (a shot that came back to a form that has 10 photos
  /// since) nothing is added and the shot is kept: it is offered again
  /// once a photo is removed, or the next time this form opens.
  Future<PhotoAddReport?> useCapture(int quarterTurns) async {
    final ready = _ready;
    final work = ready?.photoWork;
    if (ready == null || work is! PhotoReviewing) return null;
    if (remainingPhotoSlots(ready.fields.photos) == 0) {
      _heldCapture = true;
      await _photos.deleteStaged([p.basename(work.previewPath)]);
      _setWork(const PhotoIdle());
      return (added: 0, duplicates: 0, overflow: 1, failed: 0, error: null);
    }
    _setWork(const PhotoProcessing(0, 1));
    try {
      final staged = await _photos.stageCapture(
        work.captureName,
        _cameraSizing,
        quarterTurns,
      );
      final report = _addStaged([staged], failed: 0, overflow: 0);
      await _drafts.flush();
      if (_drafts.writeDue) {
        // The row couldn't be written: the marker keeps the shot. At worst
        // it is offered again, never lost.
        debugPrint('The draft isn\'t written; the camera shot is kept');
      } else {
        await _forgetCapture(work.captureName, preview: work.previewPath);
      }
      return report;
    } on PhotoServiceException catch (e) {
      // Not a picture at all: nothing to come back to. Otherwise (no
      // space, I/O) the shot and its marker stay, to be offered again.
      if (e.error == PhotoError.notAnImage) {
        await _forgetCapture(work.captureName, preview: work.previewPath);
      }
      _setWork(const PhotoIdle());
      return (added: 0, duplicates: 0, overflow: 0, failed: 1, error: e.error);
    } catch (error) {
      debugPrint('Adding the camera photo failed: $error');
      _setWork(const PhotoIdle());
      return (
        added: 0,
        duplicates: 0,
        overflow: 0,
        failed: 1,
        error: PhotoError.ioError,
      );
    }
  }

  /// A camera shot kept because the form was full ([useCapture]): offered
  /// again when a photo is removed.
  bool _heldCapture = false;

  /// A photo was removed: a shot held for lack of room comes back.
  void _offerHeldCapture() {
    if (!_heldCapture) return;
    _heldCapture = false;
    unawaited(_offerPendingCapture());
  }

  /// Discard on the review: the shot, its preview and its marker go.
  Future<void> discardCapture() async {
    final work = _ready?.photoWork;
    if (work is! PhotoReviewing) return;
    await _forgetCapture(work.captureName, preview: work.previewPath);
    _setWork(const PhotoIdle());
  }

  Future<void> _forgetCapture(String name, {String? preview}) async {
    try {
      await _photos.deleteStaged([
        name,
        if (preview != null) p.basename(preview),
      ]);
      await _photos.clearPendingCapture();
    } catch (error) {
      debugPrint('Forgetting a camera shot failed: $error');
    }
  }

  /// Opens the photo picker for the free slots, then processes what was
  /// picked with the gallery's sizing, one at a time with progress, and
  /// adds them in one change (§7.1). The document picker may return more
  /// than asked: only the first ones that fit are processed. A photo that
  /// fails is counted; the rest go in.
  Future<PhotoAddReport?> addFromGallery() async {
    if (!canAddPhotos) return null;
    final slots = remainingPhotoSlotsNow;
    _setWork(const PhotoPicking());
    final List<String> picked;
    try {
      picked = await _photos.service.pick(slots);
    } on PhotoServiceException catch (e) {
      _setWork(const PhotoIdle());
      return (added: 0, duplicates: 0, overflow: 0, failed: 0, error: e.error);
    }
    if (picked.isEmpty) {
      _setWork(const PhotoIdle());
      return null;
    }
    final taken = picked.take(slots).toList();
    final staged = <StagedPhoto>[];
    var failed = 0;
    for (final (i, uri) in taken.indexed) {
      _setWork(PhotoProcessing(i, taken.length));
      try {
        staged.add(
          await _photos
              .stageFromGallery(uri, _gallerySizing)
              .timeout(photoTimeout),
        );
      } catch (error) {
        debugPrint('Adding a picked photo failed: $error');
        failed++;
      }
    }
    return _addStaged(
      staged,
      failed: failed,
      overflow: picked.length - taken.length,
    );
  }

  /// One picture may take this long to process before it counts as failed.
  static const photoTimeout = Duration(seconds: 30);

  /// Adds [staged] to the form in one change; a duplicate's staged file is
  /// deleted at once (nothing names it).
  PhotoAddReport _addStaged(
    List<StagedPhoto> staged, {
    required int failed,
    required int overflow,
  }) {
    final ready = _ready;
    if (ready == null) {
      return (
        added: 0,
        duplicates: 0,
        overflow: 0,
        failed: failed,
        error: null,
      );
    }
    final out = addPhotos(ready.fields.photos, staged);
    final kept = {for (final p in out.photos) p};
    final unused = [
      for (final p in staged)
        if (!kept.contains(p)) p.stagingName,
    ];
    if (unused.isNotEmpty) unawaited(_photos.deleteStaged(unused));
    _setPhotos(out.photos, ready: ready.copyWith(photoWork: const PhotoIdle()));
    return (
      added: out.photos.length - ready.fields.photos.length,
      duplicates: out.duplicates,
      overflow: overflow + out.overflow,
      failed: failed,
      error: null,
    );
  }

  void _setWork(PhotoWork work) {
    final ready = _ready;
    if (ready != null) emitIfOpen(ready.copyWith(photoWork: work));
  }

  /// The photos changed: a change like any other field (owner note 3),
  /// so the draft and Update follow.
  void _setPhotos(
    List<FormPhoto> photos, {
    ExpenseFormReady? ready,
    Set<int>? Function()? selection,
  }) {
    final current = ready ?? _ready;
    if (current == null) return;
    _apply(
      current.copyWith(
        fields: current.fields.copyWith(photos: photos),
        clearRestored: true,
        selection: selection,
      ),
    );
  }

  // Selection (§8.10).

  /// A long press: selection starts with photo [index].
  void startSelection(int index) {
    final ready = _ready;
    if (ready == null || index >= ready.fields.photos.length) return;
    emitIfOpen(ready.copyWith(selection: () => {index}));
  }

  /// A tap while selecting; unselecting the last one ends selection.
  void toggleSelected(int index) {
    final ready = _ready;
    final selection = ready?.selection;
    if (ready == null || selection == null) return;
    emitIfOpen(
      ready.copyWith(selection: () => toggledSelection(selection, index)),
    );
  }

  void selectAll() {
    final ready = _ready;
    if (ready == null || ready.selection == null) return;
    emitIfOpen(
      ready.copyWith(
        selection: () => {
          for (var i = 0; i < ready.fields.photos.length; i++) i,
        },
      ),
    );
  }

  void clearSelection() {
    final ready = _ready;
    if (ready == null || ready.selection == null) return;
    emitIfOpen(ready.copyWith(selection: () => null));
  }

  /// Delete in the selection bar, after the screen's confirm: the photos
  /// leave the form (on a saved expense they go on Update), selection
  /// ends. Returns how many.
  int removeSelected() {
    final ready = _ready;
    final selection = ready?.selection;
    if (ready == null || selection == null) return 0;
    _setPhotos(
      removePhotos(ready.fields.photos, selection),
      ready: ready,
      selection: () => null,
    );
    _offerHeldCapture();
    return selection.length;
  }

  /// Delete in the viewer, after its confirm.
  void removePhotoAt(int index) {
    final ready = _ready;
    if (ready == null || index >= ready.fields.photos.length) return;
    _setPhotos(
      removePhotos(ready.fields.photos, {index}),
      ready: ready,
      selection: () => null,
    );
    _offerHeldCapture();
  }

  /// Save in the selection bar: copies to Pictures, no confirm (P6-49);
  /// selection stays. Not an edit: nothing in the form or the draft
  /// changes (P6-47).
  Future<SaveToPicturesResult?> saveSelectedToPictures() {
    final selection = _ready?.selection;
    if (selection == null) return Future.value();
    return _saveToPictures(selection.toList()..sort());
  }

  /// Save to Pictures in the viewer.
  Future<SaveToPicturesResult?> savePhotoToPictures(int index) =>
      _saveToPictures([index]);

  Future<SaveToPicturesResult?> _saveToPictures(List<int> indexes) async {
    final ready = _ready;
    if (ready == null || ready.photoWork is! PhotoIdle) return null;
    final photos = ready.fields.photos;
    if (indexes.any((i) => i >= photos.length)) return null;
    final fields = ready.fields;
    final (moment, offset) = _moment();
    final items = [
      for (final i in indexes)
        (
          photo: photos[i],
          title: fields.title.trim(),
          day: isoDay(fields.wallClock),
          wallClock: fields.wallClock,
          utcOffsetMinutes: offset,
          moment: moment,
        ),
    ];
    _setWork(PhotoSavingToPictures(0, items.length));
    final done = Completer<void>();
    _picturesSave = done.future;
    try {
      return await _photos.saveToPictures(
        items,
        fallbackTitle: _l10n.defaultPictureTitle,
        onProgress: (n, total) => _setWork(PhotoSavingToPictures(n, total)),
      );
    } finally {
      done.complete();
      _setWork(const PhotoIdle());
    }
  }

  /// Before a save that deletes the draft row in its own transaction: no
  /// draft write may still be running, or it could put the row back after
  /// the commit (a duplicate on the next Add). Returns whether this form
  /// owns the slot.
  Future<bool> _settleDraft() async {
    if (!_ownsDraft) return false;
    await _drafts.settle();
    return true;
  }

  /// The save deleted the row: forget the memory copy too (§6.3).
  void _afterDraftDeleted(bool owned) {
    if (!owned) return;
    _ownsDraft = false;
    _drafts.forget();
  }

  /// The moment to save: unchanged when an edit's date and time weren't
  /// touched, else the picked device-local time with the device's offset
  /// at that moment (so a date across a DST change gets that day's offset).
  (DateTime occurredAt, int offsetMinutes) _moment() {
    final original = _original;
    final local = _pickedLocal;
    if (local == null && original != null) {
      return (original.occurredAt, original.utcOffsetMinutes);
    }
    final moment = local ?? _now().toLocal();
    return (moment.toUtc(), moment.timeZoneOffset.inMinutes);
  }

  // Ordering.

  List<Category> _categoriesByPopularity(List<Category> categories) =>
      _byPopularity(
        categories,
        _categoryUsage,
        id: (c) => c.id,
        name: (c) => categoryName(_l10n, c),
      );

  List<Event> _eventsByPopularity(List<Event> events) => _byPopularity(
    events,
    _eventUsage,
    id: (e) => e.id,
    name: (e) => eventName(_l10n, e),
  );

  static List<T> _byPopularity<T>(
    List<T> items,
    Map<int, ItemUsage> usage, {
    required int Function(T item) id,
    required String Function(T item) name,
  }) {
    final keyed = [
      for (final item in items)
        (
          item: item,
          key: (
            usage: usage[id(item)] ?? noUsage,
            name: name(item),
            id: id(item),
          ),
        ),
    ];
    keyed.sort(
      (a, b) => comparePopularity(a.key, b.key, compareNames: compareNames),
    );
    return [for (final entry in keyed) entry.item];
  }

  /// Unarchived events, plus archived ones already on the edited expense
  /// or in [selected] (a resumed draft): shown as selected, so saving
  /// doesn't drop them silently (A10, R7).
  List<Event> _visibleEvents(List<Event> events, Set<int> selected) {
    final onExpense = _original?.eventIds ?? const <int>{};
    return _eventsByPopularity([
      for (final e in events)
        if (!e.isArchived ||
            onExpense.contains(e.id) ||
            selected.contains(e.id))
          e,
    ]);
  }

  List<PaymentMethod> _paymentMethodOrder(List<PaymentMethod> methods) =>
      [...methods]..sort((a, b) {
        if (a.id == _defaultPaymentMethodId) return -1;
        if (b.id == _defaultPaymentMethodId) return 1;
        final byName = compareNames(
          paymentMethodName(_l10n, a),
          paymentMethodName(_l10n, b),
        );
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });

  static DateTime _wallClockOf(DateTime local) => DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
  );
}
