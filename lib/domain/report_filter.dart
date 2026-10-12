/// The report's own filter: Home's (search text, categories, events, Only
/// recurring) plus payment methods. Remembered across starts as JSON in
/// `report_filter`, parsed here in Dart: Android 10's SQLite has no JSON
/// functions.
library;

import 'dart:convert';

import 'package:characters/characters.dart';

import 'expense_filter.dart';

final class ReportFilter {
  const ReportFilter({
    this.base = ExpenseFilter.none,
    this.paymentMethodIds = const {},
  });

  static const none = ReportFilter();

  /// Home's part: text, categories, events, Only recurring.
  final ExpenseFilter base;

  /// Empty = every payment method.
  final Set<int> paymentMethodIds;

  bool get isEmpty => base.isEmpty && paymentMethodIds.isEmpty;

  /// The SQL part only: everything but the text.
  ReportFilter get withoutText =>
      ReportFilter(base: base.withoutText, paymentMethodIds: paymentMethodIds);

  ReportFilter copyWith({ExpenseFilter? base, Set<int>? paymentMethodIds}) =>
      ReportFilter(
        base: base ?? this.base,
        paymentMethodIds: paymentMethodIds ?? this.paymentMethodIds,
      );

  /// Without the ids that aren't in [categories], [events] or [methods]
  /// (deleted since it was chosen), and which ids were dropped.
  ({
    ReportFilter filter,
    Set<int> categories,
    Set<int> events,
    Set<int> methods,
  })
  withoutMissing({
    required Set<int> categories,
    required Set<int> events,
    required Set<int> methods,
  }) {
    final goneCategories = base.categoryIds.difference(categories);
    final goneEvents = base.eventIds.difference(events);
    final goneMethods = paymentMethodIds.difference(methods);
    return (
      filter: ReportFilter(
        base: base.copyWith(
          categoryIds: base.categoryIds.difference(goneCategories),
          eventIds: base.eventIds.difference(goneEvents),
        ),
        paymentMethodIds: paymentMethodIds.difference(goneMethods),
      ),
      categories: goneCategories,
      events: goneEvents,
      methods: goneMethods,
    );
  }

  /// As stored in `report_filter`: null for no filter, else JSON with only the
  /// parts that are set. The text as it is (the screen trims it before
  /// applying).
  String? toJson() {
    if (isEmpty && base.text.isEmpty) return null;
    return jsonEncode({
      if (base.text.isNotEmpty) 'text': base.text,
      if (base.categoryIds.isNotEmpty) 'categories': _sorted(base.categoryIds),
      if (base.eventIds.isNotEmpty) 'events': _sorted(base.eventIds),
      if (paymentMethodIds.isNotEmpty) 'methods': _sorted(paymentMethodIds),
      if (base.onlyRecurring) 'recurring': true,
    });
  }

  /// A stored `report_filter`: null (no filter) when missing or unreadable:
  /// not JSON, not an object, a key of the wrong type, an id that isn't an
  /// integer. Missing keys are empty / false; unknown keys are ignored (a
  /// newer app's). The text is cut to [maxSearchLength] characters.
  static ReportFilter? fromJson(String? stored) {
    if (stored == null) return null;
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;
    final text = json['text'] ?? '';
    final recurring = json['recurring'] ?? false;
    final categories = _ids(json['categories']);
    final events = _ids(json['events']);
    final methods = _ids(json['methods']);
    if (text is! String ||
        recurring is! bool ||
        categories == null ||
        events == null ||
        methods == null) {
      return null;
    }
    return ReportFilter(
      base: ExpenseFilter(
        text: text.characters.take(maxSearchLength).toString(),
        categoryIds: categories,
        eventIds: events,
        onlyRecurring: recurring,
      ),
      paymentMethodIds: methods,
    );
  }

  /// A JSON id list; null when it isn't a list of integers. Missing is
  /// empty.
  static Set<int>? _ids(Object? value) {
    if (value == null) return {};
    if (value is! List) return null;
    final ids = <int>{};
    for (final id in value) {
      if (id is! int) return null;
      ids.add(id);
    }
    return ids;
  }

  static List<int> _sorted(Set<int> ids) => ids.toList()..sort();

  @override
  bool operator ==(Object other) =>
      other is ReportFilter &&
      other.base == base &&
      other.paymentMethodIds.length == paymentMethodIds.length &&
      other.paymentMethodIds.containsAll(paymentMethodIds);

  @override
  int get hashCode =>
      Object.hash(base, Object.hashAllUnordered(paymentMethodIds));

  @override
  String toString() => 'ReportFilter($base, methods: $paymentMethodIds)';
}
