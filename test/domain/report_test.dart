import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/expense_filter.dart';
import 'package:my_expense_tracker_app/domain/report.dart';
import 'package:my_expense_tracker_app/domain/report_document.dart';
import 'package:my_expense_tracker_app/domain/report_filter.dart';
import 'package:my_expense_tracker_app/domain/report_range.dart';

/// phase-8.md §5.2 and §12 "Domain: buildReport".
const eventThenCategory = ReportGrouping(
  GroupDimension.event,
  then: GroupDimension.category,
);

void main() {
  const oct = ReportRange(ReportPeriod.month, '2026-10-01', '2026-10-31');
  const all = ReportRange.allTime();
  const maxInt = 9223372036854775807;
  var nextId = 1;

  ReportRow row({
    int? id,
    String title = 'Lunch',
    String? description,
    int amount = 100,
    String currency = 'INR',
    String day = '2026-10-05',
    int at = 0,
    int offset = 330,
    int category = 1,
    int method = 1,
    Set<int> events = const {},
    bool recurring = false,
  }) => ReportRow(
    id: id ?? nextId++,
    title: title,
    description: description,
    amountMinor: amount,
    currencyCode: currency,
    occurredAtMs: at,
    utcOffsetMinutes: offset,
    day: day,
    categoryId: category,
    paymentMethodId: method,
    eventIds: events,
    recurring: recurring,
  );

  Report build(
    List<ReportRow> rows, {
    ReportRange range = oct,
    ReportFilter filter = ReportFilter.none,
    ReportGrouping grouping = ReportGrouping.byCategory,
    String defaultCurrency = 'INR',
  }) => buildReport(
    rows,
    range: range,
    filter: filter,
    grouping: grouping,
    defaultCurrency: defaultCurrency,
  );

  List<GroupKey> keys(Report r, String currency) => [
    for (final g in r.groupsIn(currency)) g.key,
  ];

  BigInt amountOf(ReportGroup g, String c) => g.byCurrency[c]!.amount;

  setUp(() => nextId = 1);

  group('basics', () {
    test('empty → no currencies, no groups, span null', () {
      final r = build([]);
      expect(r.isEmpty, isTrue);
      expect(r.currencies, isEmpty);
      expect(r.groupsIn('INR'), isEmpty);
      expect(r.span, isNull);
      expect(r.totals, isEmpty);
      expect(r.overlapIn('INR'), 0);
    });

    test('one row', () {
      final r = build([row(amount: 250)]);
      expect(r.totals, {'INR': GroupTotal(BigInt.from(250), 1)});
      expect(r.span, (first: '2026-10-05', last: '2026-10-05'));
      expect(keys(r, 'INR'), [const CategoryKey(1)]);
    });

    test('3 categories × 2 currencies, default first', () {
      final r = build([
        row(category: 1, amount: 100),
        row(category: 2, amount: 300),
        row(category: 3, amount: 200),
        row(category: 1, currency: 'USD', amount: 5),
        row(category: 3, currency: 'USD', amount: 9),
      ], defaultCurrency: 'USD');
      expect(r.currencies, ['USD', 'INR']);
      expect(r.totals['INR'], GroupTotal(BigInt.from(600), 3));
      expect(r.totals['USD'], GroupTotal(BigInt.from(14), 2));
      expect(keys(r, 'INR'), [
        const CategoryKey(2),
        const CategoryKey(3),
        const CategoryKey(1),
      ]);
      // Category 2 has no USD: not in USD's list.
      expect(keys(r, 'USD'), [const CategoryKey(3), const CategoryKey(1)]);
    });

    test('0- and 3-digit currencies stay apart', () {
      final r = build([
        row(currency: 'JPY', amount: 500),
        row(currency: 'KWD', amount: 1234),
        row(currency: 'JPY', amount: 1),
      ], defaultCurrency: 'INR');
      expect(r.currencies, ['JPY', 'KWD']);
      expect(r.totals['JPY']!.amount, BigInt.from(501));
      expect(r.totals['KWD']!.amount, BigInt.from(1234));
    });

    test('three rows of 2⁶³ − 1 add up exactly', () {
      final r = build([for (var i = 0; i < 3; i++) row(amount: maxInt)]);
      expect(r.totals['INR']!.amount, BigInt.from(maxInt) * BigInt.from(3));
      expect(
        r.groupsIn('INR').single.byCurrency['INR']!.amount,
        BigInt.from(maxInt) * BigInt.from(3),
      );
    });

    test('unknown category / method / event ids still group: totals whole', () {
      // The screen names them "?" (§6.1); the domain never drops them.
      final r = build(
        [
          row(category: 999, method: 888, events: {777}, amount: 70),
          row(amount: 30),
        ],
        grouping: const ReportGrouping(
          GroupDimension.paymentMethod,
          then: GroupDimension.event,
        ),
      );
      expect(r.totals['INR']!.amount, BigInt.from(100));
      expect(keys(r, 'INR'), [
        const PaymentMethodKey(888),
        const PaymentMethodKey(1),
      ]);
      final unknown = r.groupsIn('INR').first;
      expect(unknown.childrenIn('INR').single.key, const EventKey(777));
    });
  });

  group('range', () {
    test('a future-dated row inside counts, outside not', () {
      final r = build([
        row(day: '2026-10-31', amount: 1),
        row(day: '2026-11-01', amount: 10),
        row(day: '2026-09-30', amount: 100),
      ]);
      expect(r.totals['INR']!.amount, BigInt.one);
    });

    test('All time keeps every row; span is first and last day', () {
      final r = build([
        row(day: '1900-01-01'),
        row(day: '2200-01-01'),
        row(day: '2026-10-05'),
      ], range: all);
      expect(r.rows.length, 3);
      expect(r.span, (first: '1900-01-01', last: '2200-01-01'));
    });

    test('rows ascending by date, moment, id whatever the input order', () {
      final r = build([
        row(id: 5, day: '2026-10-05', at: 10),
        row(id: 3, day: '2026-10-05', at: 10),
        row(id: 9, day: '2026-10-04', at: 99),
        row(id: 1, day: '2026-10-05', at: 5),
      ]);
      expect([for (final x in r.rows) x.id], [9, 1, 3, 5]);
      expect(
        [for (final x in r.groupsIn('INR').single.rows) x.id],
        [9, 1, 3, 5],
      );
    });
  });

  group('text', () {
    ReportFilter text(String t) => ReportFilter(base: ExpenseFilter(text: t));

    test('folds Unicode; every word needed; %, _ literal', () {
      final rows = [
        row(title: 'CAFÉ latte'),
        row(title: 'Café', description: 'with team'),
        row(title: '100% juice'),
        row(title: 'a_b'),
        row(title: 'ab'),
      ];
      expect(build(rows, filter: text('café')).rows.length, 2);
      expect(build(rows, filter: text('café team')).rows.length, 1);
      expect(build(rows, filter: text('%')).rows.single.title, '100% juice');
      expect(build(rows, filter: text('_')).rows.single.title, 'a_b');
    });

    test('Hindi in a description; emoji; words never across the two', () {
      final rows = [
        row(title: 'Lunch', description: 'घर का खाना'),
        row(title: '🍔 Burger'),
        row(title: 'lun', description: 'ch'),
      ];
      expect(build(rows, filter: text('खाना')).rows.single.title, 'Lunch');
      expect(build(rows, filter: text('🍔')).rows.single.title, '🍔 Burger');
      expect(build(rows, filter: text('lunch')).rows.single.title, 'Lunch');
    });

    test('only the first 100 characters of the search count', () {
      final rows = [row(title: 'a' * 100)];
      expect(build(rows, filter: text('${'a' * 100}zzz')).rows.length, 1);
    });

    test('a 100-character title and a 1,000-character description', () {
      final title = 'T' * 99 + 'x';
      final description = 'd' * 999 + 'y';
      final r = build([
        row(title: title, description: description),
      ], filter: text('xy'));
      expect(r.rows, isEmpty, reason: 'title and description are apart');
      expect(
        build([
          row(title: title, description: description),
        ], filter: text('y')).rows.length,
        1,
      );
    });
  });

  group('filters applied again in Dart', () {
    test('payment methods alone and with categories', () {
      final rows = [
        row(category: 1, method: 1),
        row(category: 2, method: 1),
        row(category: 1, method: 2),
      ];
      expect(
        build(
          rows,
          filter: const ReportFilter(paymentMethodIds: {1}),
        ).rows.length,
        2,
      );
      expect(
        build(
          rows,
          filter: const ReportFilter(
            base: ExpenseFilter(categoryIds: {1}),
            paymentMethodIds: {1},
          ),
        ).rows.single.categoryId,
        1,
      );
    });

    test('Only recurring + events → only payments; payment 0 included', () {
      final rows = [
        row(events: {7}, recurring: true, amount: 0),
        row(events: {7}),
        row(recurring: true),
      ];
      final r = build(
        rows,
        filter: const ReportFilter(
          base: ExpenseFilter(eventIds: {7}, onlyRecurring: true),
        ),
      );
      expect(r.rows.length, 1);
      expect(r.totals['INR'], GroupTotal(BigInt.zero, 1));
    });
  });

  group('events', () {
    // Wedding (1) ₹100, Birthday (2) ₹50, one ₹30 row in both.
    final rows = [
      for (final r in [
        (events: {1}, amount: 70),
        (events: {2}, amount: 20),
        (events: {1, 2}, amount: 30),
        (events: <int>{}, amount: 5),
        (events: {1, 3}, amount: 0),
      ])
        (r.events, r.amount),
    ];

    List<ReportRow> make() => [
      for (final (events, amount) in rows)
        row(events: events, amount: amount, category: events.length + 1),
    ];

    test('chosen events: a row in both is in both groups, total once', () {
      final r = build(
        make(),
        filter: const ReportFilter(base: ExpenseFilter(eventIds: {1, 2})),
        grouping: eventThenCategory,
      );
      expect(r.totals['INR']!.amount, BigInt.from(120));
      expect(keys(r, 'INR'), [const EventKey(1), const EventKey(2)]);
      expect(amountOf(r.groupsIn('INR')[0], 'INR'), BigInt.from(100));
      expect(amountOf(r.groupsIn('INR')[1], 'INR'), BigInt.from(50));
      expect(r.overlapIn('INR'), 1);
      expect(r.overlapIn('USD'), 0);
      // The not-chosen Party (3) is ignored: that row is only in Wedding.
      expect(r.groupsIn('INR')[0].byCurrency['INR']!.count, 3);
    });

    test('no events chosen: each event, plus No event, last on a tie', () {
      final r = build(
        make(),
        grouping: const ReportGrouping(GroupDimension.event),
      );
      expect(keys(r, 'INR'), [
        const EventKey(1),
        const EventKey(2),
        const NoEventKey(),
        const EventKey(3),
      ]);
      // Two rows are in two events: {1,2} and {1,3}.
      expect(r.overlapIn('INR'), 2);
      final tie = build([
        row(events: {}, amount: 5),
        row(events: {9}, amount: 5),
      ], grouping: const ReportGrouping(GroupDimension.event));
      expect(keys(tie, 'INR'), [const EventKey(9), const NoEventKey()]);
    });

    test('event at the second level, with overlap', () {
      final r = build(
        make(),
        grouping: const ReportGrouping(
          GroupDimension.category,
          then: GroupDimension.event,
        ),
      );
      // Category 3 holds the two-event rows ({1,2} ₹30 and {1,3} ₹0).
      final cat3 = r
          .groupsIn('INR')
          .firstWhere((g) => g.key == const CategoryKey(3));
      expect(amountOf(cat3, 'INR'), BigInt.from(30));
      expect(
        [for (final c in cat3.childrenIn('INR')) c.key],
        [const EventKey(1), const EventKey(2), const EventKey(3)],
      );
      expect(r.overlapIn('INR'), 2);
    });

    test('category filter + events → only those categories inside', () {
      final r = build(
        make(),
        filter: const ReportFilter(
          base: ExpenseFilter(eventIds: {1}, categoryIds: {2}),
        ),
        grouping: eventThenCategory,
      );
      final wedding = r.groupsIn('INR').single;
      expect(wedding.key, const EventKey(1));
      expect(
        [for (final c in wedding.childrenIn('INR')) c.key],
        [const CategoryKey(2)],
      );
    });

    test('an archived event is a normal group (ids only here)', () {
      final r = build([
        row(events: {42}),
      ], grouping: const ReportGrouping(GroupDimension.event));
      expect(keys(r, 'INR'), [const EventKey(42)]);
    });

    test('without an Event level there is no overlap', () {
      expect(build(make()).overlapIn('INR'), 0);
    });
  });

  test('every grouping with every second dimension builds', () {
    final rows = [
      row(category: 1, method: 2, events: {5}, title: 'A'),
      row(category: 2, method: 1, events: {}, title: 'b'),
      row(category: 1, method: 1, events: {5, 6}, title: 'a', amount: 7),
    ];
    for (final first in GroupDimension.values) {
      for (final then in [null, ...GroupDimension.values]) {
        if (then == first) continue;
        final r = build(rows, grouping: ReportGrouping(first, then: then));
        expect(r.totals['INR']!.amount, BigInt.from(207), reason: '$first');
        for (final g in r.groupsIn('INR')) {
          // A group's children add up to it unless Event splits a row.
          if (then != null && then != GroupDimension.event) {
            var sum = BigInt.zero;
            for (final c in g.childrenIn('INR')) {
              sum += c.byCurrency['INR']!.amount;
            }
            expect(sum, amountOf(g, 'INR'), reason: '$first > $then');
          }
          expect(g.childrenIn('INR').isEmpty, then == null);
        }
      }
    }
  });

  test('a USD-only group is absent from the INR list; ties by id', () {
    final r = build([
      row(category: 5, currency: 'USD'),
      row(category: 3),
      row(category: 2),
    ]);
    expect(keys(r, 'INR'), [const CategoryKey(2), const CategoryKey(3)]);
    expect(keys(r, 'USD'), [const CategoryKey(5)]);
  });

  group('time zones', () {
    test('rows keep their occurred_on; Time is each clock', () {
      // 23:30 in +05:30 on 5 Oct = 18:00 UTC; 00:30 in −05:00 on 6 Oct =
      // 05:30 UTC: both keep their own dates whatever the phone's zone.
      final ist = DateTime.utc(2026, 10, 5, 18).millisecondsSinceEpoch;
      final est = DateTime.utc(2026, 10, 6, 5, 30).millisecondsSinceEpoch;
      final r = build([
        row(day: '2026-10-05', at: ist, offset: 330),
        row(day: '2026-10-06', at: est, offset: -300),
      ]);
      expect([for (final x in r.rows) x.day], ['2026-10-05', '2026-10-06']);
      expect(clockTimeOf(ist, 330), '23:30');
      expect(clockTimeOf(est, -300), '00:30');
      expect(clockTimeOf(0, -1), '23:59');
      expect(clockTimeOf(0, 14 * 60), '14:00');
    });
  });

  group('sharePermille', () {
    BigInt b(int x) => BigInt.from(x);

    test('§5.2 table', () {
      expect(sharePermille(b(1), b(3)), 333);
      expect(sharePermille(b(2), b(3)), 667);
      expect(sharePermille(b(1), b(2000)), 1);
      expect(sharePermille(b(1), b(3000)), 0);
      expect(sharePermille(b(7), b(7)), 1000);
      expect(sharePermille(BigInt.zero, BigInt.zero), isNull);
      final big = BigInt.from(maxInt);
      expect(sharePermille(big * b(3), big * b(6)), 500);
    });

    test('half up at 0.5 permille exactly', () {
      expect(sharePermille(b(1), b(2000)), 1);
      expect(sharePermille(b(3), b(2000)), 2); // 1.5 → 2
      expect(sharePermille(b(1999), b(2000)), 1000); // 999.5 → 1000
    });
  });
}
