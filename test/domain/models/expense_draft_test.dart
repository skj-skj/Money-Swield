import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';

final _at = DateTime.utc(2026, 10, 4, 8);

ExpenseDraft draft({
  int? editing,
  Set<DraftField>? touched = const {DraftField.title, DraftField.amount},
  DateTime? picked,
  bool blocked = false,
}) => ExpenseDraft(
  editingExpenseId: editing,
  title: 'Lunch "special"\nline 2',
  amountExpression: '50+60*2',
  description: '50 (a) + 60 × 2 (b)\nnotes',
  categoryId: 3,
  eventIds: const {2, 1},
  paymentMethodId: 4,
  currencyCode: 'INR',
  pickedWallClock: picked,
  touched: touched,
  itemizeLine: '50 (a) + 60 × 2 (b)',
  itemizeLabels: const ['a', 'b'],
  itemizeTerms: const ['50', '+60*2'],
  updatedAt: _at,
  suggestionsBlocked: blocked,
);

ExpenseDraft? read(String json, {int? editing}) =>
    ExpenseDraft.fromJson(json, editingExpenseId: editing, updatedAt: _at);

void main() {
  test('round trip', () {
    for (final original in [
      draft(),
      draft(editing: 7),
      draft(touched: const {}),
      draft(touched: DraftField.values.toSet()),
      draft(picked: DateTime(2026, 10, 4, 13, 5)),
      draft(blocked: true),
    ]) {
      expect(
        read(original.toJson(), editing: original.editingExpenseId),
        original,
      );
    }
  });

  test('the picked time is stored as zone-less wall-clock fields', () {
    final json = jsonDecode(
      draft(picked: DateTime(2026, 10, 4, 13, 5)).toJson(),
    ) as Map<String, Object?>;
    expect(json['picked_wall_clock'], '2026-10-04T13:05:00.000');
    expect(json['v'], 1);
    expect(json.containsKey('editing_expense_id'), isFalse, reason: 'column');
    expect(json.containsKey('updated_at'), isFalse, reason: 'column');
  });

  test('a picked time given as UTC keeps its fields', () {
    final json = jsonDecode(
      draft(picked: DateTime.utc(2026, 10, 4, 13, 5)).toJson(),
    ) as Map<String, Object?>;
    expect(json['picked_wall_clock'], '2026-10-04T13:05:00.000');
  });

  test('an unknown key is ignored', () {
    final json = jsonDecode(draft().toJson()) as Map<String, Object?>;
    json['photos'] = ['a.jpg'];
    expect(read(jsonEncode(json)), draft());
  });

  test('a missing key gives that field\'s empty value', () {
    final parsed = read('{"v": 1, "title": "Tea"}')!;
    expect(parsed.title, 'Tea');
    expect(parsed.amountExpression, '');
    expect(parsed.description, '');
    expect(parsed.categoryId, isNull);
    expect(parsed.eventIds, isEmpty);
    expect(parsed.paymentMethodId, isNull);
    expect(parsed.currencyCode, '');
    expect(parsed.pickedWallClock, isNull);
    expect(parsed.itemizeLine, isNull);
    expect(parsed.itemizeLabels, isEmpty);
    expect(parsed.itemizeTerms, isEmpty);
  });

  test('a missing `v` reads as version 1', () {
    expect(read('{"title": "Tea"}')?.title, 'Tea');
  });

  test('a wrong-typed key gives that field\'s empty value', () {
    final parsed = read(
      jsonEncode({
        'v': 1,
        'title': 5,
        'amount': ['50'],
        'description': null,
        'category_id': '3',
        'event_ids': [1, '2', null, 3.5, 4],
        'payment_method_id': 1.5,
        'currency': 0,
        'picked_wall_clock': 'yesterday',
        'itemize_line': 7,
        'itemize_labels': 'a',
      }),
    )!;
    expect(parsed.title, '');
    expect(parsed.amountExpression, '');
    expect(parsed.description, '');
    expect(parsed.categoryId, isNull);
    expect(parsed.eventIds, {1, 4}, reason: 'readable items are kept');
    expect(parsed.paymentMethodId, isNull);
    expect(parsed.currencyCode, '');
    expect(parsed.pickedWallClock, isNull);
    expect(parsed.itemizeLine, isNull);
    expect(parsed.itemizeLabels, isEmpty);
  });

  test('a picked time with a zone reads as untouched', () {
    expect(
      read('{"picked_wall_clock": "2026-10-04T13:05:00Z"}')!.pickedWallClock,
      isNull,
    );
    expect(
      read('{"picked_wall_clock": "2026-10-04T13:05:00+05:30"}')!
          .pickedWallClock,
      isNull,
    );
  });

  test('suggestions_blocked: missing or not true → false', () {
    for (final value in [
      '',
      '"suggestions_blocked": "yes",',
      '"suggestions_blocked": 1,',
    ]) {
      expect(read('{$value "v": 1}')!.suggestionsBlocked, isFalse);
    }
  });

  group('touched', () {
    test('missing → null (the form infers it)', () {
      expect(read('{"title": "Tea"}')!.touched, isNull);
    });

    test('not a list, or a non-string item → null', () {
      expect(read('{"touched": "title"}')!.touched, isNull);
      expect(read('{"touched": ["title", 3]}')!.touched, isNull);
    });

    test('an unknown name (a newer app\'s field) is skipped', () {
      expect(read('{"touched": ["title", "photos"]}')!.touched, {
        DraftField.title,
      });
    });

    test('an empty list means nothing touched', () {
      expect(read('{"touched": []}')!.touched, isEmpty);
    });
  });

  group('no draft', () {
    test('v: 2', () {
      expect(read('{"v": 2, "title": "Tea"}'), isNull);
    });

    test('not JSON', () {
      expect(read('{"title": '), isNull);
      expect(read(''), isNull);
    });

    test('an array or another value', () {
      expect(read('["title"]'), isNull);
      expect(read('"title"'), isNull);
      expect(read('null'), isNull);
      expect(read('5'), isNull);
    });
  });

  test('event ids are written sorted, so the same draft gives the same '
      'JSON', () {
    final json = jsonDecode(draft().toJson()) as Map<String, Object?>;
    expect(json['event_ids'], [1, 2]);
  });
}
