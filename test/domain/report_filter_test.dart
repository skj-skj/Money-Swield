import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/domain/expense_filter.dart';
import 'package:money_swield/domain/report_filter.dart';

void main() {
  const full = ReportFilter(
    base: ExpenseFilter(
      text: 'dinner',
      categoryIds: {4, 1},
      eventIds: {7},
      onlyRecurring: true,
    ),
    paymentMethodIds: {2},
  );

  test('==, isEmpty, withoutText with payment methods', () {
    expect(ReportFilter.none.isEmpty, isTrue);
    expect(const ReportFilter(paymentMethodIds: {1}).isEmpty, isFalse);
    expect(
      const ReportFilter(paymentMethodIds: {1, 2}),
      const ReportFilter(paymentMethodIds: {2, 1}),
    );
    expect(
      const ReportFilter(paymentMethodIds: {1, 2}) ==
          const ReportFilter(paymentMethodIds: {1}),
      isFalse,
    );
    expect(
      const ReportFilter(paymentMethodIds: {1}) ==
          const ReportFilter(paymentMethodIds: {2}),
      isFalse,
    );
    final sql = full.withoutText;
    expect(sql.base.text, '');
    expect(sql.paymentMethodIds, {2});
    expect(sql.base.categoryIds, {1, 4});
    expect(sql.base.onlyRecurring, isTrue);
    expect(full.hashCode, full.withoutText.copyWith(base: full.base).hashCode);
  });

  group('JSON (report_filter)', () {
    test('round trip; none → null', () {
      expect(ReportFilter.fromJson(full.toJson()), full);
      expect(ReportFilter.none.toJson(), isNull);
      expect(ReportFilter.fromJson(null), isNull);
      expect(
        full.toJson(),
        '{"text":"dinner","categories":[1,4],"events":[7],"methods":[2],'
        '"recurring":true}',
      );
    });

    test('missing keys are empty / false; unknown keys ignored', () {
      expect(
        ReportFilter.fromJson('{"methods":[3],"future":{"x":1}}'),
        const ReportFilter(paymentMethodIds: {3}),
      );
      expect(ReportFilter.fromJson('{}'), ReportFilter.none);
    });

    test('malformed or wrong types → null (no filter)', () {
      for (final bad in [
        '',
        'not json',
        '[1,2]',
        '"text"',
        '{"categories":["x"]}',
        '{"categories":[1.5]}',
        '{"categories":1}',
        '{"events":[null]}',
        '{"text":5}',
        '{"recurring":"yes"}',
        '{"methods":{"a":1}}',
        '{"categories":[1e400]}',
      ]) {
        expect(ReportFilter.fromJson(bad), isNull, reason: bad);
      }
    });

    test('an id past 2⁶³ is no filter, not a crash', () {
      // Dart's JSON reads it as a double: not an int id.
      expect(
        ReportFilter.fromJson('{"categories":[99999999999999999999]}'),
        isNull,
      );
    });

    test('a 500-character text is cut to 100 characters, emoji whole', () {
      final long = '🍔' * 500;
      final read = ReportFilter.fromJson(
        ReportFilter(base: ExpenseFilter(text: long)).toJson(),
      )!;
      expect(read.base.text, '🍔' * maxSearchLength);
    });

    test('only whitespace text is kept as typed but is no filter', () {
      const f = ReportFilter(base: ExpenseFilter(text: '   '));
      expect(f.isEmpty, isTrue);
      expect(ReportFilter.fromJson(f.toJson()), f);
    });
  });

  test('withoutMissing drops deleted ids and says which', () {
    final result = full.withoutMissing(
      categories: {1, 9},
      events: {},
      methods: {2},
    );
    expect(result.filter.base.categoryIds, {1});
    expect(result.filter.base.eventIds, isEmpty);
    expect(result.filter.paymentMethodIds, {2});
    expect(result.filter.base.text, 'dinner');
    expect(result.filter.base.onlyRecurring, isTrue);
    expect(result.categories, {4});
    expect(result.events, {7});
    expect(result.methods, isEmpty);
  });
}
