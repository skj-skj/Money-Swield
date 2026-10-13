import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/data/services/database/sql_helpers.dart';

void main() {
  group('sqlPlaceholders', () {
    test('one ? per value, comma separated', () {
      expect(sqlPlaceholders(1), '?');
      expect(sqlPlaceholders(3), '?, ?, ?');
      expect(
        '?'.allMatches(sqlPlaceholders(maxBoundValues)),
        hasLength(maxBoundValues),
      );
    });

    test('refuses an empty list (IN () is a syntax error) and one over '
        'the limit', () {
      expect(() => sqlPlaceholders(0), throwsRangeError);
      expect(() => sqlPlaceholders(maxBoundValues + 1), throwsRangeError);
    });

    test('the limit leaves room under SQLite 3.22 999 variables', () {
      expect(maxBoundValues * 2, lessThan(999 + 2));
      expect(maxBoundValues, lessThan(999));
    });
  });

  group('inChunks', () {
    test('no values: nothing is queried', () async {
      var calls = 0;
      final result = await inChunks<int, int>([], (chunk) async {
        calls++;
        return chunk;
      });
      expect(result, isEmpty);
      expect(calls, 0);
    });

    test('slices of at most the limit, in order, results joined', () async {
      final values = [for (var i = 0; i < 2 * maxBoundValues + 1; i++) i];
      final sizes = <int>[];
      final result = await inChunks<int, String>(values, (chunk) async {
        sizes.add(chunk.length);
        return [for (final v in chunk) 'v$v'];
      });
      expect(sizes, [maxBoundValues, maxBoundValues, 1]);
      expect(result, [for (final v in values) 'v$v']);
    });

    test('exactly the limit: one query', () async {
      var calls = 0;
      await inChunks<int, int>(
        List.filled(maxBoundValues, 7),
        (chunk) async => [calls++],
      );
      expect(calls, 1);
    });

    test('a failing slice fails the whole call', () async {
      final values = [for (var i = 0; i < maxBoundValues + 1; i++) i];
      await expectLater(
        inChunks<int, int>(values, (chunk) async {
          if (chunk.length == 1) throw StateError('disk');
          return chunk;
        }),
        throwsStateError,
      );
    });
  });

  group('utcFromEpochMs', () {
    test('is UTC and the same instant', () {
      final at = DateTime.utc(2026, 10, 5, 23, 30, 15, 250);
      final read = utcFromEpochMs(at.millisecondsSinceEpoch);
      expect(read.isUtc, isTrue);
      expect(read, at);
      expect((read.day, read.hour), (5, 23), reason: 'not the local day');
    });
  });
}
