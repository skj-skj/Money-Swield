import 'package:bloc_signals/bloc_signals.dart';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show setEquals;

import '../../../../data/repositories/category_repository.dart';
import '../../../../data/repositories/event_repository.dart';
import '../../../../data/repositories/payment_method_repository.dart';
import '../../../../data/repositories/recurring_repository.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/event.dart';
import '../../../../domain/models/payment_method.dart';
import '../../../../domain/models/recurring_item.dart';
import '../../../../domain/periods.dart';
import '../../../../domain/recurring_plan.dart';
import '../../../../domain/repeat_input.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/builtin_names.dart';
import '../../../core/emit_if_open.dart';
import '../../expenses/view_models/expense_form_cubit.dart'
    show maxExpenseDescriptionLength, maxTitleLength, TitleError;

/// The Edit screen's fields (phase-7a.md §7.4).
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

  RecurringFields copyWith({
    String? title,
    String? description,
    int? categoryId,
    Set<int>? eventIds,
    int? paymentMethodId,
    int? timeOfDayMinutes,
    RepeatEnd? end,
    String? endOn,
  }) => RecurringFields(
    title: title ?? this.title,
    description: description ?? this.description,
    categoryId: categoryId ?? this.categoryId,
    eventIds: eventIds ?? this.eventIds,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    timeOfDayMinutes: timeOfDayMinutes ?? this.timeOfDayMinutes,
    end: end ?? this.end,
    endOn: endOn ?? this.endOn,
  );

  /// The end the item gets: null = never.
  String? get effectiveEndOn => end == RepeatEnd.onDate ? endOn : null;

  /// Dirtiness compares what Save writes: an end date kept while Never is
  /// chosen isn't a change.
  @override
  bool operator ==(Object other) =>
      other is RecurringFields &&
      other.title == title &&
      other.description == description &&
      other.categoryId == categoryId &&
      setEquals(other.eventIds, eventIds) &&
      other.paymentMethodId == paymentMethodId &&
      other.timeOfDayMinutes == timeOfDayMinutes &&
      other.effectiveEndOn == effectiveEndOn;

  @override
  int get hashCode => Object.hash(
    title,
    description,
    categoryId,
    Object.hashAllUnordered(eventIds),
    paymentMethodId,
    timeOfDayMinutes,
    effectiveEndOn,
  );
}

/// Why the end can't be saved.
enum EndError { missing, beforeEarliest, tooLate }

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
    this.showErrors = false,
    this.saving = false,
  });

  final RecurringItem item;
  final RecurringFields fields;

  /// By name.
  final List<Category> categories;

  /// Unarchived ones, plus the item's own archived ones (shown selected,
  /// so saving doesn't drop them silently; A10).
  final List<Event> events;
  final List<PaymentMethod> paymentMethods;

  /// The earliest end allowed (P7a-27).
  final String earliestEnd;
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
    showErrors: showErrors ?? this.showErrors,
    saving: saving ?? this.saving,
  );
}

/// The Edit screen of a running item (phase-7a.md §7.4): title,
/// description, category, events, payment method, time, end. No draft
/// (P7a-15): Back with changes asks. Changes apply to payments added from
/// now on.
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
      );
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
            today: todayOn(_now()),
          ),
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
    final ready = _ready;
    if (ready == null) return;
    _change(
      (f) => f.copyWith(
        end: end,
        endOn: f.endOn ?? (end == RepeatEnd.onDate ? ready.earliestEnd : null),
      ),
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

  static EndError? _endError(RecurringFormReady ready) {
    final fields = ready.fields;
    if (fields.end == RepeatEnd.never) return null;
    final endOn = fields.endOn;
    if (endOn == null || !isValidDay(endOn)) return EndError.missing;
    if (endOn.compareTo(ready.earliestEnd) < 0) return EndError.beforeEarliest;
    if (endOn.compareTo(lastEndOn) > 0) return EndError.tooLate;
    return null;
  }

  /// Validates and saves. Returns true when saved; false when a field is
  /// invalid (the errors show) or nothing to save. Emits
  /// [RecurringFormGone] when the item was archived or deleted meanwhile;
  /// rethrows other failures (the screen says "Couldn't save").
  Future<bool> save() async {
    final ready = _ready;
    if (ready == null || ready.saving) return false;
    if (_titleError(ready) != null ||
        _descriptionTooLong(ready) != null ||
        _categoryMissing(ready) != null ||
        _endError(ready) != null) {
      emitIfOpen(ready.copyWith(showErrors: true));
      return false;
    }
    final fields = ready.fields;
    emitIfOpen(ready.copyWith(saving: true));
    try {
      await _recurring.update(
        itemId,
        RecurringEdit(
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
        ),
      );
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
