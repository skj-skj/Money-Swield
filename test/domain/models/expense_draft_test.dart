import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/sms_suggestion.dart';
import 'package:my_expense_tracker_app/domain/photos.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';

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

  group('photos', () {
    final a = 'a' * 64;
    final b = 'b' * 64;
    const uuid = '0f8fad5b-d9cb-469f-a165-70867728950e';
    final saved = SavedPhoto(
      id: 12,
      relativePath: 'photos/$a.jpg',
      sha256: a,
      byteSize: 412345,
    );
    final staged = StagedPhoto(
      stagingName: '$uuid.jpg',
      sha256: b,
      byteSize: 522871,
    );

    ExpenseDraft withPhotos(List<FormPhoto> photos) => ExpenseDraft(
      editingExpenseId: 7,
      title: 'Lunch',
      amountExpression: '50',
      description: '',
      categoryId: 1,
      eventIds: const {},
      paymentMethodId: 1,
      currencyCode: 'INR',
      pickedWallClock: null,
      touched: const {},
      itemizeLine: null,
      itemizeLabels: const [],
      itemizeTerms: const [],
      updatedAt: _at,
      photos: photos,
    );

    test('round trip keeps saved and staged photos in order', () {
      final original = withPhotos([staged, saved]);
      final back = read(original.toJson(), editing: 7)!;
      expect(back, original);
      expect(back.photos, [staged, saved]);
      final json = jsonDecode(original.toJson()) as Map<String, Object?>;
      expect(json['photos'], [
        {'staged': '$uuid.jpg', 'sha256': b, 'bytes': 522871},
        {'photo_id': 12, 'path': 'photos/$a.jpg', 'sha256': a, 'bytes': 412345},
      ]);
      expect(json['v'], 1, reason: 'v stays 1');
    });

    test('an older draft (no photos key) and a wrong type read as none', () {
      expect(read('{"title": "Tea"}')!.photos, isEmpty);
      expect(read('{"photos": "x"}')!.photos, isEmpty);
      expect(read('{"photos": {"a": 1}}')!.photos, isEmpty);
      expect(read('{"photos": null}')!.photos, isEmpty);
    });

    test('a bad item is skipped, the rest kept', () {
      Map<String, Object?> good() => {
        'staged': '$uuid.jpg',
        'sha256': b,
        'bytes': 5,
      };
      final bad = <Object?>[
        5,
        'photos/$a.jpg',
        null,
        {'staged': '$uuid.jpg', 'sha256': b}, // no bytes
        {'staged': '$uuid.jpg', 'sha256': b, 'bytes': '5'},
        {'staged': '$uuid.jpg', 'sha256': b, 'bytes': 0},
        {'staged': '$uuid.jpg', 'sha256': 'B' * 64, 'bytes': 5},
        {'staged': '$uuid.jpg', 'sha256': 'b' * 63, 'bytes': 5},
        {'staged': '../$uuid.jpg', 'sha256': b, 'bytes': 5},
        {'staged': 7, 'sha256': b, 'bytes': 5},
        {'photo_id': '12', 'path': 'photos/$a.jpg', 'sha256': a, 'bytes': 5},
        {
          'photo_id': 12,
          'path': '../databases/expense_tracker.db',
          'sha256': a,
          'bytes': 5,
        },
        {'photo_id': 12, 'path': 'photos/$b.jpg', 'sha256': a, 'bytes': 5},
        {'photo_id': 12, 'sha256': a, 'bytes': 5},
      ];
      final json = jsonEncode({
        'photos': [good(), ...bad, good()],
      });
      expect(read(json)!.photos, hasLength(2));
    });

    test("the photos are part of the draft's equality", () {
      expect(withPhotos([saved]), isNot(withPhotos([])));
      expect(withPhotos([saved, staged]), isNot(withPhotos([staged, saved])));
    });
  });

  group('repeat', () {
    ExpenseDraft withRepeat(RepeatChoice? repeat) => ExpenseDraft(
      editingExpenseId: null,
      title: 'Netflix',
      amountExpression: '649',
      description: '',
      categoryId: 3,
      eventIds: const {},
      paymentMethodId: 4,
      currencyCode: 'INR',
      pickedWallClock: null,
      touched: const {DraftField.title},
      itemizeLine: null,
      itemizeLabels: const [],
      itemizeTerms: const [],
      updatedAt: _at,
      repeat: repeat,
    );

    /// The JSON of [withRepeat] with `repeat` replaced by [value].
    String jsonWith(Object? value) {
      final json =
          jsonDecode(withRepeat(null).toJson()) as Map<String, Object?>;
      return jsonEncode({...json, 'repeat': value});
    }

    RepeatChoice? readRepeat(Object? value) => read(jsonWith(value))!.repeat;

    test('round trip of both end kinds, and off', () {
      for (final repeat in [
        null,
        const RepeatChoice(),
        const RepeatChoice(
          frequency: Frequency.weekly,
          intervalText: '2',
          end: RepeatEnd.onDate,
          endOn: '2027-04-09',
        ),
        // The date is kept while Never is chosen.
        const RepeatChoice(endOn: '2027-04-09'),
        // After N payments, the date kept too.
        const RepeatChoice(
          end: RepeatEnd.afterCount,
          countText: '12',
          endOn: '2027-04-09',
        ),
        // The count is kept while another end is chosen.
        const RepeatChoice(countText: '5'),
      ]) {
        final original = withRepeat(repeat);
        expect(read(original.toJson()), original, reason: '$repeat');
        expect(read(original.toJson())!.repeat, repeat);
      }
    });

    test('the stored shape', () {
      final json = jsonDecode(
        withRepeat(
          const RepeatChoice(
            intervalText: '1',
            end: RepeatEnd.onDate,
            endOn: '2027-04-09',
          ),
        ).toJson(),
      ) as Map<String, Object?>;
      expect(json['repeat'], {
        'frequency': 'monthly',
        'interval': '1',
        'end': 'on',
        'on': '2027-04-09',
        'count': '',
      });
      expect(json['v'], 1);
      final after = jsonDecode(
        withRepeat(
          const RepeatChoice(end: RepeatEnd.afterCount, countText: '12'),
        ).toJson(),
      ) as Map<String, Object?>;
      expect((after['repeat']! as Map)['end'], 'after');
      expect((after['repeat']! as Map)['count'], '12');
      expect(
        (jsonDecode(withRepeat(null).toJson()) as Map).containsKey('repeat'),
        isFalse,
      );
    });

    test('half-typed intervals come back as typed', () {
      for (final text in ['', '0', '100', '007']) {
        final original = withRepeat(RepeatChoice(intervalText: text));
        expect(read(original.toJson())!.repeat!.intervalText, text);
      }
    });

    test('half-typed counts come back as typed; anything not up to 3 digits '
        'is empty', () {
      for (final text in ['', '0', '1', '2', '999', '000']) {
        final original = withRepeat(
          RepeatChoice(end: RepeatEnd.afterCount, countText: text),
        );
        expect(read(original.toJson())!.repeat!.countText, text);
      }
      for (final bad in ['1000', 'abc', '1.5', 12, null, '-3', ' 12']) {
        final repeat = readRepeat({
          'frequency': 'weekly',
          'interval': '1',
          'end': 'after',
          'count': bad,
        })!;
        expect(repeat.countText, '', reason: '$bad');
        expect(repeat.end, RepeatEnd.afterCount, reason: '$bad');
      }
    });

    test('an older draft (no count) reads unchanged', () {
      expect(
        readRepeat({
          'frequency': 'weekly',
          'interval': '2',
          'end': 'on',
          'on': '2027-01-01',
        }),
        const RepeatChoice(
          frequency: Frequency.weekly,
          intervalText: '2',
          end: RepeatEnd.onDate,
          endOn: '2027-01-01',
        ),
      );
    });

    test('a draft from before Repeats has Repeats off', () {
      expect(read(jsonWith(null))!.repeat, isNull);
      final json = jsonDecode(withRepeat(null).toJson()) as Map<String, Object?>
        ..remove('repeat');
      expect(read(jsonEncode(json))!.repeat, isNull);
    });

    test('a repeat that is not an object is off; the rest of the draft is '
        'kept', () {
      for (final bad in [
        'monthly',
        1,
        true,
        ['monthly'],
      ]) {
        final draft = read(jsonWith(bad))!;
        expect(draft.repeat, isNull, reason: '$bad');
        expect(draft.title, 'Netflix');
      }
    });

    test('a bad field drops to its default, the others are kept', () {
      expect(
        readRepeat({
          'frequency': 'fortnightly',
          'interval': '3',
          'end': 'on',
          'on': '2027-01-01',
        }),
        const RepeatChoice(
          intervalText: '3',
          end: RepeatEnd.onDate,
          endOn: '2027-01-01',
        ),
      );
      // A number, too long, not digits: back to '1'.
      for (final interval in [5, '1000', '1a', ' 2', null]) {
        expect(
          readRepeat({'frequency': 'yearly', 'interval': interval})!,
          const RepeatChoice(frequency: Frequency.yearly),
          reason: '$interval',
        );
      }
      // Not a real YYYY-MM-DD date: no date.
      for (final on in ['31-12-2026', '2026-02-30', 20261231, '']) {
        expect(
          readRepeat({'end': 'on', 'on': on}),
          const RepeatChoice(end: RepeatEnd.onDate),
          reason: '$on',
        );
      }
    });

    test('"after N payments" reads back; a count that '
        'isn\'t text is empty, the date kept; an unknown end is never', () {
      expect(
        readRepeat({'end': 'after', 'on': '2027-01-01', 'count': 12}),
        const RepeatChoice(end: RepeatEnd.afterCount, endOn: '2027-01-01'),
      );
      expect(
        readRepeat({'end': 'afterwards', 'count': '12'}),
        const RepeatChoice(countText: '12'),
      );
    });

    test('equality sees the repeat', () {
      expect(
        withRepeat(const RepeatChoice()),
        isNot(withRepeat(const RepeatChoice(intervalText: '2'))),
      );
      expect(withRepeat(const RepeatChoice()), isNot(withRepeat(null)));
    });
  });

  group('sms', () {
    final sha = 'c' * 64;
    ExpenseDraft withSms(SmsLink? sms) => draft().copyForTest(sms);

    test('round trip; equality sees the link', () {
      final linked = withSms((id: 4, bodySha256: sha));
      expect(read(linked.toJson()), linked);
      expect(read(linked.toJson())!.sms, (id: 4, bodySha256: sha));
      expect(linked, isNot(withSms(null)));
      expect((jsonDecode(linked.toJson()) as Map<String, Object?>)['sms'], {
        'id': 4,
        'sha256': sha,
      });
    });

    test('an older draft has no key: no link; a damaged one is no link, '
        'the rest of the draft kept', () {
      expect(read(draft().toJson())!.sms, isNull);
      for (final bad in [
        {'id': '4', 'sha256': sha},
        {'id': 4, 'sha256': 'not a hash'},
        {'id': 4},
        'x',
        [4, sha],
      ]) {
        final json = jsonDecode(draft().toJson()) as Map<String, Object?>;
        json['sms'] = bad;
        final readBack = read(jsonEncode(json))!;
        expect(readBack.sms, isNull, reason: '$bad');
        expect(readBack.title, draft().title);
      }
    });
  });
}

extension on ExpenseDraft {
  ExpenseDraft copyForTest(SmsLink? sms) => ExpenseDraft(
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
    sms: sms,
  );
}
