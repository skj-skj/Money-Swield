import 'package:bloc_signals/bloc_signals.dart';
import 'package:characters/characters.dart';

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../domain/amount_input.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/currency.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/expense.dart';
import '../../../../domain/models/money.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/popularity.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
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
  const ExpenseSaved(this.expense);

  final Expense expense;
}

final class ExpenseBinned extends ExpenseFormResult {
  const ExpenseBinned(this.id);

  final int id;
}

/// The edited expense was binned or deleted meanwhile. Home says so: like
/// "Moved to bin", the message is shown after the pop, on Home's own
/// messenger.
final class ExpenseGone extends ExpenseFormResult {
  const ExpenseGone();
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
/// and pops (phase-2.md §6.3).
final class ExpenseFormGone extends ExpenseFormState {
  const ExpenseFormGone();
}

/// The form's fields as typed, plus the lists the pickers show.
final class ExpenseFormReady extends ExpenseFormState {
  const ExpenseFormReady({
    required this.fields,
    required this.categories,
    required this.events,
    required this.paymentMethods,
    this.showErrors = false,
    this.saving = false,
  });

  final ExpenseFields fields;

  /// Most popular first.
  final List<Category> categories;

  /// Most popular first. Archived events are left out, except those already
  /// on the expense being edited (A10).
  final List<Event> events;

  /// The default first, then by name (P2-9).
  final List<PaymentMethod> paymentMethods;

  /// False until the first save attempt, so an empty new form isn't shown
  /// full of errors. After that, errors update as the user types.
  final bool showErrors;

  /// A save or delete is in progress; the buttons are disabled.
  final bool saving;

  ExpenseFormReady copyWith({
    ExpenseFields? fields,
    List<Category>? categories,
    List<Event>? events,
    bool? showErrors,
    bool? saving,
  }) => ExpenseFormReady(
    fields: fields ?? this.fields,
    categories: categories ?? this.categories,
    events: events ?? this.events,
    paymentMethods: paymentMethods,
    showErrors: showErrors ?? this.showErrors,
    saving: saving ?? this.saving,
  );
}

/// Every value the user can change. Compared with the opening values to
/// tell whether the form has changes.
class ExpenseFields {
  const ExpenseFields({
    required this.title,
    required this.amountText,
    required this.description,
    required this.categoryId,
    required this.eventIds,
    required this.paymentMethodId,
    required this.currencyCode,
    required this.wallClock,
  });

  final String title;

  /// The amount as typed. The screen's text field owns the text; this is a
  /// copy, never written back, so the cursor doesn't jump.
  final String amountText;

  final String description;
  final int? categoryId;
  final Set<int> eventIds;
  final int? paymentMethodId;
  final String currencyCode;

  /// The date and time shown, as a UTC `DateTime` whose fields are the
  /// wall-clock time (like `Expense.wallClock`).
  final DateTime wallClock;

  ExpenseFields copyWith({
    String? title,
    String? amountText,
    String? description,
    int? categoryId,
    Set<int>? eventIds,
    int? paymentMethodId,
    String? currencyCode,
    DateTime? wallClock,
  }) => ExpenseFields(
    title: title ?? this.title,
    amountText: amountText ?? this.amountText,
    description: description ?? this.description,
    categoryId: categoryId ?? this.categoryId,
    eventIds: eventIds ?? this.eventIds,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    currencyCode: currencyCode ?? this.currencyCode,
    wallClock: wallClock ?? this.wallClock,
  );

  @override
  bool operator ==(Object other) =>
      other is ExpenseFields &&
      other.title == title &&
      other.amountText == amountText &&
      other.description == description &&
      other.categoryId == categoryId &&
      other.eventIds.length == eventIds.length &&
      other.eventIds.containsAll(eventIds) &&
      other.paymentMethodId == paymentMethodId &&
      other.currencyCode == currencyCode &&
      other.wallClock == wallClock;

  @override
  int get hashCode => Object.hash(
    title,
    amountText,
    description,
    categoryId,
    Object.hashAllUnordered(eventIds),
    paymentMethodId,
    currencyCode,
    wallClock,
  );
}

/// The Add/Edit expense form (phase-2.md §6).
class ExpenseFormCubit extends CubitSignal<ExpenseFormState> {
  /// [expenseId] is the expense to edit, or null to add one. New expenses
  /// start with the default currency and payment method passed in.
  ExpenseFormCubit({
    required this._expenses,
    required this._categories,
    required this._events,
    required this._paymentMethods,
    required this._l10n,
    required this._defaultCurrency,
    required this._defaultPaymentMethodId,
    this.expenseId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(initialState: const ExpenseFormLoading());

  final ExpenseRepository _expenses;
  final CategoryRepository _categories;
  final EventRepository _events;
  final PaymentMethodRepository _paymentMethods;
  final AppLocalizations _l10n;
  final String _defaultCurrency;
  final int? _defaultPaymentMethodId;
  final DateTime Function() _now;
  final int? expenseId;

  bool get isEditing => expenseId != null;

  /// The expense being edited, once loaded.
  Expense? _original;

  /// The values the form opened with, to tell whether it has changes.
  ExpenseFields? _initialFields;

  /// The picked date and time as device-local time, or null while the user
  /// hasn't touched date or time on an edit, so an expense recorded in
  /// another time zone keeps its moment and offset (phase-2.md §3.3).
  DateTime? _pickedLocal;

  /// Every event, archived ones included: a new event's name must differ
  /// from all of them.
  List<Event> get allEvents => _allEvents;
  List<Event> _allEvents = const [];

  Map<int, ItemUsage> _categoryUsage = const {};
  Map<int, ItemUsage> _eventUsage = const {};

  /// Loads the lists, their usage and, when editing, the expense. Runs once
  /// when the screen opens.
  Future<void> load() async {
    try {
      final original = expenseId == null
          ? null
          : await _expenses.byId(expenseId!);
      if (expenseId != null && original == null) {
        _emitIfOpen(const ExpenseFormGone());
        return;
      }
      final categories = await _categories.all();
      final events = await _events.all();
      final paymentMethods = await _paymentMethods.all();
      _categoryUsage = await _expenses.categoryUsage();
      _eventUsage = await _expenses.eventUsage();
      _original = original;
      _allEvents = events;

      final fields = original == null
          ? _newFields(paymentMethods)
          : _fieldsOf(original);
      _initialFields = fields;
      _emitIfOpen(
        ExpenseFormReady(
          fields: fields,
          categories: _categoriesByPopularity(categories),
          events: _visibleEvents(events),
          paymentMethods: _paymentMethodOrder(paymentMethods),
        ),
      );
    } catch (error) {
      _emitIfOpen(ExpenseFormLoadFailed(error));
    }
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
      amountText: '',
      description: '',
      categoryId: null,
      eventIds: const {},
      paymentMethodId: defaultMethod,
      currencyCode: _defaultCurrency,
      wallClock: _wallClockOf(now),
    );
  }

  ExpenseFields _fieldsOf(Expense expense) => ExpenseFields(
    title: expense.title,
    amountText: formatAmountForInput(
      expense.amount.amountMinor,
      _minorDigits(expense.amount.currencyCode),
    ),
    description: expense.description ?? '',
    categoryId: expense.categoryId,
    eventIds: expense.eventIds,
    paymentMethodId: expense.paymentMethodId,
    currencyCode: expense.amount.currencyCode,
    wallClock: expense.wallClock,
  );

  ExpenseFormReady? get _ready => switch (value) {
    final ExpenseFormReady ready => ready,
    _ => null,
  };

  /// Whether anything differs from what the form opened with.
  bool get isDirty {
    final ready = _ready;
    return ready != null && ready.fields != _initialFields;
  }

  // Validation. The errors are computed from the fields every time, so
  // changing the currency re-validates the amount against its digits.

  TitleError? get titleError => _shown(_titleError);
  AmountError? get amountError => _shown(_amountError);
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

  static AmountError? _amountError(ExpenseFields fields) =>
      switch (_parse(fields)) {
        AmountRejected(:final error) => error,
        AmountParsed() => null,
      };

  static bool? _descriptionTooLong(ExpenseFields fields) =>
      fields.description.trim().characters.length > maxExpenseDescriptionLength
      ? true
      : null;

  bool? _categoryMissing(ExpenseFields fields) {
    final categories = _ready?.categories ?? const [];
    return categories.any((c) => c.id == fields.categoryId) ? null : true;
  }

  static AmountParse _parse(ExpenseFields fields) => parseAmount(
    fields.amountText,
    minorDigits: _minorDigits(fields.currencyCode),
  );

  /// What the live preview under the amount shows, or null when it is
  /// hidden: only while the text has a `,` or more than one `.`, the
  /// 3-digit-currency ambiguity (phase-2.md §4.2). Shown before the first
  /// save too.
  AmountParse? get amountPreview {
    final ready = _ready;
    if (ready == null || !amountNeedsPreview(ready.fields.amountText)) {
      return null;
    }
    return _parse(ready.fields);
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

  /// The 8 tiles of the category grid: the selected category is always
  /// one of them.
  List<PickerItem> get categoryTiles => pickerTiles(categoryItems, {
    ?_ready?.fields.categoryId,
  }, multiSelect: false);

  /// The 7 event tiles after the "None" tile: selected events take the
  /// slots from the end.
  List<PickerItem> get eventTiles => pickerTiles(
    eventItems,
    _ready?.fields.eventIds ?? const {},
    multiSelect: true,
    size: pickerGridSize - 1,
  );

  /// The currencies of the latest entered expenses, for the currency
  /// sheet's Recent section. Empty if they can't be read: the sheet still
  /// works without them.
  Future<List<String>> recentCurrencies() => recentCurrenciesOrEmpty(_expenses);

  // Field changes.

  void titleChanged(String title) => _update((f) => f.copyWith(title: title));

  void amountChanged(String text) =>
      _update((f) => f.copyWith(amountText: text));

  void descriptionChanged(String description) =>
      _update((f) => f.copyWith(description: description));

  void categorySelected(int id) => _update((f) => f.copyWith(categoryId: id));

  void eventToggled(int id) => _update(
    (f) => f.copyWith(
      eventIds: f.eventIds.contains(id)
          ? ({...f.eventIds}..remove(id))
          : {...f.eventIds, id},
    ),
  );

  /// The "None" event tile: the expense has no events.
  void eventsCleared() => _update((f) => f.copyWith(eventIds: const {}));

  void paymentMethodSelected(int id) =>
      _update((f) => f.copyWith(paymentMethodId: id));

  /// Changes the currency of this expense only. Never converts or rounds
  /// the amount; it is re-validated against the new currency's digits.
  void currencyChanged(String code) =>
      _update((f) => f.copyWith(currencyCode: code));

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
    _update((f) => f.copyWith(wallClock: _wallClockOf(local)));
  }

  /// A category created from the picker: added to the list and selected.
  void categoryAdded(Category category) {
    final ready = _ready;
    if (ready == null) return;
    _emitIfOpen(
      ready.copyWith(
        categories: _categoriesByPopularity([...ready.categories, category]),
        fields: ready.fields.copyWith(categoryId: category.id),
      ),
    );
  }

  /// An event created from the picker: added to the list and selected.
  void eventAdded(Event event) {
    final ready = _ready;
    if (ready == null) return;
    _allEvents = [..._allEvents, event];
    _emitIfOpen(
      ready.copyWith(
        events: _eventsByPopularity([...ready.events, event]),
        fields: ready.fields.copyWith(
          eventIds: {...ready.fields.eventIds, event.id},
        ),
      ),
    );
  }

  void _update(ExpenseFields Function(ExpenseFields fields) change) {
    final ready = _ready;
    if (ready == null) return;
    _emitIfOpen(ready.copyWith(fields: change(ready.fields)));
  }

  // Saving.

  /// Validates and saves. Returns the saved expense, or null if a field is
  /// invalid (the errors are then shown) or a save is already running.
  /// Emits [ExpenseFormGone] and returns null if the edited expense was
  /// binned or deleted meanwhile. Rethrows other database errors; the
  /// screen tells the user.
  Future<Expense?> save() async {
    final ready = _ready;
    if (ready == null || ready.saving) return null;
    final fields = ready.fields;
    final amount = _parse(fields);
    final paymentMethodId = fields.paymentMethodId;
    if (_titleError(fields) != null ||
        amount is! AmountParsed ||
        _descriptionTooLong(fields) != null ||
        _categoryMissing(fields) != null ||
        paymentMethodId == null) {
      _emitIfOpen(ready.copyWith(showErrors: true));
      return null;
    }

    final (occurredAt, offset) = _moment();
    final input = ExpenseInput(
      title: fields.title.trim(),
      description: switch (fields.description.trim()) {
        '' => null,
        final text => text,
      },
      amount: Money(amount.amountMinor, fields.currencyCode),
      occurredAt: occurredAt,
      utcOffsetMinutes: offset,
      categoryId: fields.categoryId!,
      paymentMethodId: paymentMethodId,
      eventIds: fields.eventIds,
    );

    _emitIfOpen(ready.copyWith(saving: true));
    try {
      final id = expenseId;
      final saved = id == null
          ? await _expenses.add(input)
          : await _expenses.update(id, input);
      _initialFields = fields;
      return saved;
    } on ExpenseNotFound {
      // `update` refuses a binned or deleted expense.
      _emitIfOpen(const ExpenseFormGone());
      return null;
    } finally {
      final current = _ready;
      if (current != null) _emitIfOpen(current.copyWith(saving: false));
    }
  }

  /// Moves the edited expense to the bin (no confirm: it is recoverable,
  /// A4). Returns its id, or null on a new form or while saving.
  Future<int?> moveToBin() async {
    final ready = _ready;
    final id = expenseId;
    if (ready == null || id == null || ready.saving) return null;
    _emitIfOpen(ready.copyWith(saving: true));
    try {
      await _expenses.moveToBin(id);
      return id;
    } finally {
      final current = _ready;
      if (current != null) _emitIfOpen(current.copyWith(saving: false));
    }
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
  /// (shown as selected, so saving doesn't drop them silently).
  List<Event> _visibleEvents(List<Event> events) {
    final onExpense = _original?.eventIds ?? const <int>{};
    return _eventsByPopularity([
      for (final e in events)
        if (!e.isArchived || onExpense.contains(e.id)) e,
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

  // Every method keeps going across awaits, and the screen closes the
  // cubit when it pops. Emitting after close() asserts in debug mode.
  void _emitIfOpen(ExpenseFormState state) {
    if (!isClosed) emit(state);
  }
}
