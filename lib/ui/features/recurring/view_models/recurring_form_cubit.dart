import 'package:bloc_signals/bloc_signals.dart';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show setEquals;

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/expense.dart'
    show maxExpenseDescriptionLength, maxTitleLength;
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/recurrence.dart';
import '../../../../domain/recurring_plan.dart';
import '../../../../domain/repeat_input.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/emit_if_open.dart';
import '../../expenses/view_models/expense_form_cubit.dart' show TitleError;

/// The Edit screen's fields, and how often.
class RecurringFields {
  const RecurringFields({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.eventIds,
    required this.paymentMethodId,
    required this.timeOfDayMinutes,
    required this.end,
    required this.endOn,
    required this.frequency,
    required this.intervalText,
    this.firstPaymentOn,
  });

  final String title;
  final String description;
  final int categoryId;
  final Set<int> eventIds;
  final int paymentMethodId;
  final int timeOfDayMinutes;
  final RepeatEnd end;

  /// Kept while [end] is never, like the Add form's.
  final String? endOn;

  final Frequency frequency;

  /// The Every field as typed, like the Add form's.
  final String intervalText;

  /// The First payment picked; null = the default. Used only while how
  /// often differs from the item's.
  final String? firstPaymentOn;

  /// [intervalText] when it is 1 to 99, else null.
  int? get interval => intervalOf(intervalText);

  RecurringFields copyWith({
    String? title,
    String? description,
    int? categoryId,
    Set<int>? eventIds,
    int? paymentMethodId,
    int? timeOfDayMinutes,
    RepeatEnd? end,
    String? endOn,
    Frequency? frequency,
    String? intervalText,
    String? firstPaymentOn,
  }) => RecurringFields(
    title: title ?? this.title,
    description: description ?? this.description,
    categoryId: categoryId ?? this.categoryId,
    eventIds: eventIds ?? this.eventIds,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    timeOfDayMinutes: timeOfDayMinutes ?? this.timeOfDayMinutes,
    end: end ?? this.end,
    endOn: endOn ?? this.endOn,
    frequency: frequency ?? this.frequency,
    intervalText: intervalText ?? this.intervalText,
    firstPaymentOn: firstPaymentOn ?? this.firstPaymentOn,
  );

  /// The end the item gets: null = never.
  String? get effectiveEndOn => end == RepeatEnd.onDate ? endOn : null;

  /// Dirtiness compares what Save writes: an end date kept while Never is
  /// chosen isn't a change, nor "07" typed for 7. The First payment isn't
  /// compared: it only counts when how often changed, which is a change
  /// already.
  @override
  bool operator ==(Object other) =>
      other is RecurringFields &&
      other.title == title &&
      other.description == description &&
      other.categoryId == categoryId &&
      setEquals(other.eventIds, eventIds) &&
      other.paymentMethodId == paymentMethodId &&
      other.timeOfDayMinutes == timeOfDayMinutes &&
      other.effectiveEndOn == effectiveEndOn &&
      other.frequency == frequency &&
      other._intervalKey == _intervalKey;

  Object get _intervalKey => interval ?? intervalText;

  @override
  int get hashCode => Object.hash(
    title,
    description,
    categoryId,
    Object.hashAllUnordered(eventIds),
    paymentMethodId,
    timeOfDayMinutes,
    effectiveEndOn,
    frequency,
    _intervalKey,
  );
}

/// Why the end can't be saved.
enum EndError { missing, beforeEarliest, tooLate }

/// Why the First payment can't be saved.
enum FirstPaymentError { tooEarly, tooLate }

sealed class RecurringFormState {
  const RecurringFormState();
}

final class RecurringFormLoading extends RecurringFormState {
  const RecurringFormLoading();
}

final class RecurringFormFailed extends RecurringFormState {
  const RecurringFormFailed(this.error);

  final Object error;
}

/// The item is gone or archived meanwhile: the screen says so and closes.
final class RecurringFormGone extends RecurringFormState {
  const RecurringFormGone();
}

final class RecurringFormReady extends RecurringFormState {
  const RecurringFormReady({
    required this.item,
    required this.fields,
    required this.categories,
    required this.events,
    required this.paymentMethods,
    required this.earliestEnd,
    required this.earliestFirst,
    required this.scheduleLocked,
    this.showErrors = false,
    this.saving = false,
  });

  final RecurringItem item;
  final RecurringFields fields;

  /// By name.
  final List<Category> categories;

  /// Unarchived ones, plus the item's own archived ones (shown selected, so
  /// saving doesn't drop them silently).
  final List<Event> events;
  final List<PaymentMethod> paymentMethods;

  /// The earliest end allowed.
  final String earliestEnd;

  /// The earliest First payment of a new schedule ([earliestFirstPayment]).
  final String earliestFirst;

  /// Payments are waiting ([paymentsWaiting]): how often can't change until
  /// they are added or skipped.
  final bool scheduleLocked;
  final bool showErrors;
  final bool saving;

  RecurringFormReady copyWith({
    RecurringFields? fields,
    bool? showErrors,
    bool? saving,
  }) => RecurringFormReady(
    item: item,
    fields: fields ?? this.fields,
    categories: categories,
    events: events,
    paymentMethods: paymentMethods,
    earliestEnd: earliestEnd,
    earliestFirst: earliestFirst,
    scheduleLocked: scheduleLocked,
    showErrors: showErrors ?? this.showErrors,
    saving: saving ?? this.saving,
  );
}

/// The Edit screen of a running item: title, description, category, events,
/// payment method, time, end, and how often (changing it saves a new item,
/// [saveAsNew]). No draft: Back with changes asks. Changes apply to payments
/// added from now on.
class RecurringFormCubit extends CubitSignal<RecurringFormState>
    with EmitIfOpen<RecurringFormState> {
  RecurringFormCubit({
    required this.itemId,
    required this._recurring,
    required this._categories,
    required this._events,
    required this._paymentMethods,
    required this._l10n,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(initialState: const RecurringFormLoading());

  final int itemId;
  final RecurringRepository _recurring;
  final CategoryRepository _categories;
  final EventRepository _events;
  final PaymentMethodRepository _paymentMethods;
  final AppLocalizations _l10n;
  final DateTime Function() _now;

  RecurringFields? _baseline;

  RecurringFormReady? get _ready => switch (value) {
    final RecurringFormReady ready => ready,
    _ => null,
  };

  Future<void> load() async {
    try {
      final item = await _recurring.byId(itemId);
      final schedule = item?.schedule;
      if (item == null || item.isArchived || schedule == null) {
        emitIfOpen(const RecurringFormGone());
        return;
      }
      final fields = RecurringFields(
        title: item.title,
        description: item.description ?? '',
        categoryId: item.categoryId,
        eventIds: item.eventIds,
        paymentMethodId: item.paymentMethodId,
        timeOfDayMinutes: item.timeOfDayMinutes,
        end: schedule.endOn == null ? RepeatEnd.never : RepeatEnd.onDate,
        endOn: schedule.endOn,
        frequency: schedule.frequency,
        intervalText: '${schedule.interval}',
      );
      final today = todayOn(_now());
      _baseline = fields;
      final categories = await _categories.all();
      final methods = await _paymentMethods.all();
      emitIfOpen(
        RecurringFormReady(
          item: item,
          fields: fields,
          categories: [...categories]
            ..sort(
              (a, b) =>
                  compareNames(categoryName(_l10n, a), categoryName(_l10n, b)),
            ),
          events:
              [
                for (final e in await _events.all())
                  if (!e.isArchived || item.eventIds.contains(e.id)) e,
              ]..sort(
                (a, b) =>
                    compareNames(eventName(_l10n, a), eventName(_l10n, b)),
              ),
          paymentMethods: [...methods]
            ..sort(
              (a, b) => compareNames(
                paymentMethodName(_l10n, a),
                paymentMethodName(_l10n, b),
              ),
            ),
          earliestEnd: earliestEndFor(
            startOn: schedule.startOn,
            newestPayment: await _recurring.newestPaymentOn(itemId),
            today: today,
          ),
          earliestFirst: earliestFirstPayment(
            schedule,
            cursor: item.nextDueOn,
            today: today,
          ),
          scheduleLocked: paymentsWaiting(cursor: item.nextDueOn, today: today),
        ),
      );
    } catch (error) {
      emitIfOpen(RecurringFormFailed(error));
    }
  }

  bool get isDirty {
    final ready = _ready;
    return ready != null && ready.fields != _baseline;
  }

  bool get canSave {
    final ready = _ready;
    return ready != null && !ready.saving && isDirty;
  }

  void titleChanged(String title) => _change((f) => f.copyWith(title: title));

  void descriptionChanged(String text) =>
      _change((f) => f.copyWith(description: text));

  void categorySelected(int id) => _change((f) => f.copyWith(categoryId: id));

  void eventToggled(int id) => _change(
    (f) => f.copyWith(
      eventIds: f.eventIds.contains(id)
          ? ({...f.eventIds}..remove(id))
          : {...f.eventIds, id},
    ),
  );

  void eventsCleared() => _change((f) => f.copyWith(eventIds: const {}));

  void paymentMethodSelected(int id) =>
      _change((f) => f.copyWith(paymentMethodId: id));

  void timeChanged(int hour, int minute) =>
      _change((f) => f.copyWith(timeOfDayMinutes: hour * 60 + minute));

  /// Never or On date; On without a date gets the earliest allowed.
  void endChanged(RepeatEnd end) {
    final earliest = earliestEnd;
    if (earliest == null) return;
    _change(
      (f) => f.copyWith(
        end: end,
        endOn: f.endOn ?? (end == RepeatEnd.onDate ? earliest : null),
      ),
    );
  }

  // How often.

  void frequencyChanged(Frequency frequency) {
    if (_ready?.scheduleLocked ?? true) return;
    _change((f) => f.copyWith(frequency: frequency));
  }

  /// The Every field as typed (digits, two at most); checked at Save.
  void intervalChanged(String text) {
    if (_ready?.scheduleLocked ?? true) return;
    _change((f) => f.copyWith(intervalText: text));
  }

  void firstPaymentChanged(DateTime date) =>
      _change((f) => f.copyWith(firstPaymentOn: isoDay(date)));

  /// Whether how often differs from the item's: Save then makes a new item
  /// ([saveAsNew]) after the screen asks. An Every that isn't 1 to 99
  /// counts as changed, so its error shows.
  bool get scheduleChanged {
    final ready = _ready;
    final schedule = ready?.item.schedule;
    if (ready == null || schedule == null) return false;
    final f = ready.fields;
    return f.frequency != schedule.frequency || f.interval != schedule.interval;
  }

  /// The First payment of the new schedule: the one picked, else the old
  /// item's next payment, never before [RecurringFormReady.earliestFirst].
  String? get firstPaymentOn {
    final ready = _ready;
    if (ready == null) return null;
    final picked = ready.fields.firstPaymentOn;
    if (picked != null) return picked;
    final next = ready.item.nextDueOn;
    final earliest = ready.earliestFirst;
    return next != null && next.compareTo(earliest) > 0 ? next : earliest;
  }

  /// The earliest end: the item's rule, or with a new schedule its First
  /// payment.
  String? get earliestEnd {
    final ready = _ready;
    if (ready == null) return null;
    return scheduleChanged ? firstPaymentOn : ready.earliestEnd;
  }

  /// The new schedule Save would make, or null while how often is unchanged
  /// or Every isn't valid.
  Schedule? get newSchedule {
    final ready = _ready;
    final interval = ready?.fields.interval;
    final first = firstPaymentOn;
    if (ready == null ||
        !scheduleChanged ||
        interval == null ||
        first == null) {
      return null;
    }
    return Schedule(
      frequency: ready.fields.frequency,
      interval: interval,
      startOn: first,
      endOn: ready.fields.effectiveEndOn,
    );
  }

  void endDateChanged(DateTime date) =>
      _change((f) => f.copyWith(end: RepeatEnd.onDate, endOn: isoDay(date)));

  void _change(RecurringFields Function(RecurringFields f) change) {
    final ready = _ready;
    if (ready == null) return;
    emitIfOpen(ready.copyWith(fields: change(ready.fields)));
  }

  // Validation, shown after the first Save attempt, as in the expense
  // form.

  TitleError? get titleError => _shown(_titleError);
  bool get descriptionTooLong => _shown(_descriptionTooLong) ?? false;
  bool get categoryMissing => _shown(_categoryMissing) ?? false;
  EndError? get endError => _shown(_endError);
  bool get intervalInvalid => _shown(_intervalInvalid) ?? false;
  FirstPaymentError? get firstPaymentError => _shown(_firstPaymentError);

  T? _shown<T>(T? Function(RecurringFormReady ready) check) {
    final ready = _ready;
    return ready != null && ready.showErrors ? check(ready) : null;
  }

  static TitleError? _titleError(RecurringFormReady ready) {
    final title = ready.fields.title.trim();
    if (title.isEmpty) return TitleError.required;
    if (title.characters.length > maxTitleLength) return TitleError.tooLong;
    return null;
  }

  static bool? _descriptionTooLong(RecurringFormReady ready) =>
      ready.fields.description.trim().characters.length >
          maxExpenseDescriptionLength
      ? true
      : null;

  static bool? _categoryMissing(RecurringFormReady ready) =>
      ready.categories.any((c) => c.id == ready.fields.categoryId)
      ? null
      : true;

  EndError? _endError(RecurringFormReady ready) {
    final fields = ready.fields;
    if (fields.end == RepeatEnd.never) return null;
    final endOn = fields.endOn;
    if (endOn == null || !isValidDay(endOn)) return EndError.missing;
    final earliest = earliestEnd ?? ready.earliestEnd;
    if (endOn.compareTo(earliest) < 0) return EndError.beforeEarliest;
    if (endOn.compareTo(lastEndOn) > 0) return EndError.tooLate;
    return null;
  }

  static bool? _intervalInvalid(RecurringFormReady ready) =>
      ready.fields.interval == null ? true : null;

  FirstPaymentError? _firstPaymentError(RecurringFormReady ready) {
    final first = firstPaymentOn;
    if (!scheduleChanged || first == null) return null;
    if (first.compareTo(ready.earliestFirst) < 0) {
      return FirstPaymentError.tooEarly;
    }
    if (first.compareTo(lastEndOn) > 0) return FirstPaymentError.tooLate;
    return null;
  }

  /// Checks every field; shows the errors when one fails. The screen asks
  /// before [saveAsNew] only once this passes.
  bool validate() {
    final ready = _ready;
    if (ready == null || ready.saving) return false;
    if (_titleError(ready) != null ||
        _descriptionTooLong(ready) != null ||
        _categoryMissing(ready) != null ||
        _endError(ready) != null ||
        _intervalInvalid(ready) != null ||
        _firstPaymentError(ready) != null) {
      emitIfOpen(ready.copyWith(showErrors: true));
      return false;
    }
    return true;
  }

  RecurringEdit _editOf(RecurringFields fields) => RecurringEdit(
    title: fields.title.trim(),
    description: switch (fields.description.trim()) {
      '' => null,
      final text => text,
    },
    categoryId: fields.categoryId,
    paymentMethodId: fields.paymentMethodId,
    eventIds: fields.eventIds,
    timeOfDayMinutes: fields.timeOfDayMinutes,
    endOn: fields.effectiveEndOn,
  );

  /// **Changing how often** (after the screen's dialog):
  /// a new item from the First payment, this one archived, in one write.
  /// Returns the new item's id; null when a field is invalid, a save runs,
  /// or the rules refused it (the errors show, read again). Emits
  /// [RecurringFormGone] when the item was archived or deleted meanwhile;
  /// rethrows other failures.
  Future<int?> saveAsNew() async {
    if (!validate()) return null;
    final ready = _ready!;
    final schedule = newSchedule;
    if (schedule == null) return null;
    final fields = ready.fields;
    emitIfOpen(ready.copyWith(saving: true));
    try {
      final id = await _recurring.replaceSchedule(
        itemId,
        _editOf(fields),
        schedule,
      );
      _baseline = fields;
      return id;
    } on RecurringItemUnavailable {
      emitIfOpen(const RecurringFormGone());
      return null;
    } on RecurringChangeRefused {
      // The day changed, a payment came due meanwhile: read the limits
      // again and show why.
      await load();
      final current = _ready;
      if (current != null) {
        emitIfOpen(current.copyWith(fields: fields, showErrors: true));
      }
      return null;
    } finally {
      final current = _ready;
      if (current != null && current.saving) {
        emitIfOpen(current.copyWith(saving: false));
      }
    }
  }

  /// Validates and saves. Returns true when saved; false when a field is
  /// invalid (the errors show) or nothing to save. Emits
  /// [RecurringFormGone] when the item was archived or deleted meanwhile;
  /// rethrows other failures (the screen says "Couldn't save").
  ///
  /// How often changed: nothing is saved here (false); the screen asks,
  /// then calls [saveAsNew].
  Future<bool> save() async {
    if (scheduleChanged || !validate()) return false;
    final ready = _ready!;
    final fields = ready.fields;
    emitIfOpen(ready.copyWith(saving: true));
    try {
      await _recurring.update(itemId, _editOf(fields));
      _baseline = fields;
      return true;
    } on RecurringItemUnavailable {
      emitIfOpen(const RecurringFormGone());
      return false;
    } on RecurringChangeRefused {
      // The earliest end moved meanwhile (a payment was added, or the day
      // changed): read it again and show the error.
      await load();
      final current = _ready;
      if (current != null) {
        emitIfOpen(current.copyWith(fields: fields, showErrors: true));
      }
      return false;
    } finally {
      final current = _ready;
      if (current != null && current.saving) {
        emitIfOpen(current.copyWith(saving: false));
      }
    }
  }
}
