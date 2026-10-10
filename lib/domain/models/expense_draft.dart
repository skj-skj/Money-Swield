import 'dart:convert';

import '../photos.dart';
import '../repeat_input.dart';

/// A field of the Add/Edit form, for the touched set: prefill fills only
/// fields the user hasn't touched (D13, phase-4.md §7.1).
enum DraftField {
  title,
  amount,
  description,
  category,
  events,
  paymentMethod,
  currency,
  dateTime,
}

/// The one unsaved Add/Edit form (database.md §3.9, phase-4.md §5.4). Only
/// ever used to refill a form: never counted, listed or suggested (§6.5).
class ExpenseDraft {
  const ExpenseDraft({
    required this.editingExpenseId,
    required this.title,
    required this.amountExpression,
    required this.description,
    required this.categoryId,
    required this.eventIds,
    required this.paymentMethodId,
    required this.currencyCode,
    required this.pickedWallClock,
    required this.touched,
    required this.itemizeLine,
    required this.itemizeLabels,
    required this.itemizeTerms,
    required this.updatedAt,
    this.suggestionsBlocked = false,
    this.photos = const [],
    this.repeat,
  });

  /// The expense being edited; null for an Add draft.
  final int? editingExpenseId;

  final String title;

  /// Canonical (`50+60*2`, phase-4.md §5.1); may be unfinished: `''`,
  /// `50+`, or even invalid text, kept as typed.
  final String amountExpression;

  final String description;
  final int? categoryId;
  final Set<int> eventIds;
  final int? paymentMethodId;

  /// `''` when it couldn't be read back; the form then uses the default.
  final String currencyCode;

  /// The picked date and time as device-local wall-clock fields, or null
  /// when date and time were never touched (phase-4.md §5.4).
  final DateTime? pickedWallClock;

  /// Null when the stored draft had no readable touched set; the form then
  /// counts every field that differs from a new form as touched.
  final Set<DraftField>? touched;

  /// The Itemize line the form last put first in the description, its
  /// labels, and the canonical terms they belong to (phase-4.md §5.2).
  final String? itemizeLine;
  final List<String> itemizeLabels;
  final List<String> itemizeTerms;

  final DateTime updatedAt;

  /// The user changed the form after a suggestion filled it: no
  /// suggestions until Clear, also after a resume (phase-4.md §12a).
  final bool suggestionsBlocked;

  /// The form's photos, in order (phase-6.md §5.5): saved ones by id and
  /// path, staged ones by their staging file. A camera shot not yet used
  /// isn't here: it has its own marker, so opening the camera never takes
  /// the slot (§7.1).
  final List<FormPhoto> photos;

  /// The Add form's Repeats section as typed (phase-7a.md §5.7); null when
  /// Repeats is off.
  final RepeatChoice? repeat;

  /// The newest `form_json` version this app reads. Adding `repeat` kept
  /// it at 1: an older draft simply has no `repeat` (Repeats off), and
  /// unknown keys are ignored.
  static const version = 1;

  bool get isAdd => editingExpenseId == null;

  /// This draft with [photos] instead of its own.
  ExpenseDraft withPhotos(List<FormPhoto> photos) => ExpenseDraft(
    editingExpenseId: editingExpenseId,
    title: title,
    amountExpression: amountExpression,
    description: description,
    categoryId: categoryId,
    eventIds: eventIds,
    paymentMethodId: paymentMethodId,
    currencyCode: currencyCode,
    pickedWallClock: pickedWallClock,
    touched: touched,
    itemizeLine: itemizeLine,
    itemizeLabels: itemizeLabels,
    itemizeTerms: itemizeTerms,
    updatedAt: updatedAt,
    suggestionsBlocked: suggestionsBlocked,
    photos: photos,
    repeat: repeat,
  );

  /// `form_json`: every field but [editingExpenseId] and [updatedAt], which
  /// are columns.
  String toJson() => jsonEncode({
    'v': version,
    'title': title,
    'amount': amountExpression,
    'description': description,
    'category_id': categoryId,
    'event_ids': eventIds.toList()..sort(),
    'payment_method_id': paymentMethodId,
    'currency': currencyCode,
    'picked_wall_clock': pickedWallClock == null
        ? null
        : _localFields(pickedWallClock!).toIso8601String(),
    'touched': touched == null ? null : [for (final f in touched!) f.name],
    'itemize_line': itemizeLine,
    'itemize_labels': itemizeLabels,
    'itemize_terms': itemizeTerms,
    'suggestions_blocked': suggestionsBlocked,
    'photos': [for (final photo in photos) _photoToJson(photo)],
    if (repeat case final repeat?) 'repeat': _repeatToJson(repeat),
  });

  /// Reads `form_json` forgivingly (database.md §3.9): unknown keys are
  /// ignored, a missing or wrong-typed key gives that field's empty value
  /// (a list keeps its readable items). Null, meaning no draft, when the
  /// JSON doesn't parse, isn't an object, or has a version newer than
  /// [version].
  static ExpenseDraft? fromJson(
    String formJson, {
    required int? editingExpenseId,
    required DateTime updatedAt,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(formJson);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final json = decoded;
    if (json['v'] case final int v when v > version) return null;

    String text(String key) => switch (json[key]) {
      final String s => s,
      _ => '',
    };
    int? id(String key) => switch (json[key]) {
      final int i => i,
      _ => null,
    };
    List<T> list<T>(String key) => switch (json[key]) {
      final List<Object?> items => items.whereType<T>().toList(),
      _ => <T>[],
    };

    return ExpenseDraft(
      editingExpenseId: editingExpenseId,
      title: text('title'),
      amountExpression: text('amount'),
      description: text('description'),
      categoryId: id('category_id'),
      eventIds: list<int>('event_ids').toSet(),
      paymentMethodId: id('payment_method_id'),
      currencyCode: text('currency'),
      pickedWallClock: _readWallClock(json['picked_wall_clock']),
      touched: _readTouched(json['touched']),
      itemizeLine: switch (json['itemize_line']) {
        final String s => s,
        _ => null,
      },
      itemizeLabels: list<String>('itemize_labels'),
      itemizeTerms: list<String>('itemize_terms'),
      updatedAt: updatedAt,
      suggestionsBlocked: json['suggestions_blocked'] == true,
      photos: _readPhotos(json['photos']),
      repeat: _readRepeat(json['repeat']),
    );
  }

  static Map<String, Object?> _repeatToJson(RepeatChoice repeat) => {
    'frequency': repeat.frequency.name,
    'interval': repeat.intervalText,
    'end': switch (repeat.end) {
      RepeatEnd.never => 'never',
      RepeatEnd.onDate => 'on',
    },
    'on': repeat.endOn,
  };

  /// The Repeats section, read forgivingly (§5.7): not an object → null
  /// (Repeats off); a bad field drops to its default and the rest is kept.
  /// An unknown end kind (7b's `after`) reads as never.
  static RepeatChoice? _readRepeat(Object? value) {
    if (value is! Map<String, Object?>) return null;
    return RepeatChoice(
      frequency:
          switch (value['frequency']) {
            final String name => Frequency.values.asNameMap()[name],
            _ => null,
          } ??
          Frequency.monthly,
      // As typed, half-typed too; anything that isn't up to 3 digits is
      // damaged and back to the default.
      intervalText: switch (value['interval']) {
        final String text when _intervalText.hasMatch(text) => text,
        _ => RepeatChoice.defaults.intervalText,
      },
      end: value['end'] == 'on' ? RepeatEnd.onDate : RepeatEnd.never,
      endOn: switch (value['on']) {
        final String day when isValidDay(day) => day,
        _ => null,
      },
    );
  }

  static final _intervalText = RegExp(r'^[0-9]{0,3}$');

  static Map<String, Object?> _photoToJson(FormPhoto photo) => switch (photo) {
    SavedPhoto(:final id, :final relativePath) => {
      'photo_id': id,
      'path': relativePath,
      'sha256': photo.sha256,
      'bytes': photo.byteSize,
    },
    StagedPhoto(:final stagingName) => {
      'staged': stagingName,
      'sha256': photo.sha256,
      'bytes': photo.byteSize,
    },
  };

  /// The draft's photos, read forgivingly (§5.5): a missing or wrong-typed
  /// `photos` is none; an item that isn't an object, misses a field, has a
  /// wrong type, a bad SHA-256, a size that isn't positive, or a path or
  /// staging name that fails its check is skipped, the rest kept. The
  /// checks are what keep a crafted draft from naming any other file (§9).
  static List<FormPhoto> _readPhotos(Object? value) {
    if (value is! List<Object?>) return const [];
    return [
      for (final item in value)
        if (item is Map<String, Object?>) ?_readPhoto(item),
    ];
  }

  static FormPhoto? _readPhoto(Map<String, Object?> item) {
    final sha = item['sha256'];
    final bytes = item['bytes'];
    if (sha is! String || !isValidSha256(sha) || bytes is! int || bytes <= 0) {
      return null;
    }
    return switch (item) {
      // The path names the file by its hash; one that names another is
      // damaged.
      {'photo_id': final int id, 'path': final String path}
          when isValidPhotoPath(path) && path.startsWith('photos/$sha.') =>
        SavedPhoto(id: id, relativePath: path, sha256: sha, byteSize: bytes),
      {'staged': final String name} when isValidStagingName(name) =>
        StagedPhoto(stagingName: name, sha256: sha, byteSize: bytes),
      _ => null,
    };
  }

  /// [value]'s wall-clock fields with no zone, so the JSON holds
  /// `2026-10-04T13:05:00.000` whatever [value]'s zone flag says.
  static DateTime _localFields(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
  );

  /// A zone-less ISO date and time, read as device-local. Anything else
  /// (a `Z`, an offset, not a date) reads as untouched.
  static DateTime? _readWallClock(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null || parsed.isUtc) return null;
    return parsed;
  }

  static Set<DraftField>? _readTouched(Object? value) {
    if (value is! List<Object?>) return null;
    final byName = {for (final f in DraftField.values) f.name: f};
    final touched = <DraftField>{};
    for (final item in value) {
      // A non-string means the set can't be trusted. An unknown name may
      // be a newer app's field: skip it.
      if (item is! String) return null;
      if (byName[item] case final field?) touched.add(field);
    }
    return touched;
  }

  @override
  bool operator ==(Object other) =>
      other is ExpenseDraft &&
      other.editingExpenseId == editingExpenseId &&
      other.title == title &&
      other.amountExpression == amountExpression &&
      other.description == description &&
      other.categoryId == categoryId &&
      _sameSet(other.eventIds, eventIds) &&
      other.paymentMethodId == paymentMethodId &&
      other.currencyCode == currencyCode &&
      other.pickedWallClock == pickedWallClock &&
      _sameNullableSet(other.touched, touched) &&
      other.itemizeLine == itemizeLine &&
      _sameList(other.itemizeLabels, itemizeLabels) &&
      _sameList(other.itemizeTerms, itemizeTerms) &&
      other.updatedAt == updatedAt &&
      other.suggestionsBlocked == suggestionsBlocked &&
      _sameList(other.photos, photos) &&
      other.repeat == repeat;

  @override
  int get hashCode => Object.hash(
    editingExpenseId,
    title,
    amountExpression,
    description,
    categoryId,
    paymentMethodId,
    currencyCode,
    pickedWallClock,
    updatedAt,
    repeat,
  );

  @override
  String toString() =>
      'ExpenseDraft(${isAdd ? 'add' : 'edit $editingExpenseId'}, '
      '"$title", "$amountExpression")';
}

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _sameNullableSet<T>(Set<T>? a, Set<T>? b) =>
    a == null || b == null ? a == b : _sameSet(a, b);

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
