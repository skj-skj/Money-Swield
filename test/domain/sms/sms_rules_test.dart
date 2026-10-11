import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/sms_suggestion.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_draft_rule.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_groups.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_learning.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_title.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_window.dart';
import 'package:my_expense_tracker_app/domain/title_suggestions.dart';

/// phase-9a.md §5.3, §5.4, §5.7 – §5.9.
void main() {
  group('cleanPayee / suggestedTitle', () {
    for (final (payee, expected) in [
      ('GLOBEX TECHNOLOGIES PRIVA', 'Globex Technologies'),
      ('UMBRA MARKETPLACE PRIVATE', 'Umbra Marketplace'),
      ('Example Ceramics Limited', 'Example Ceramics'),
      ('ACME PVT LTD', 'Acme'),
      ('Acme Pvt. Ltd.', 'Acme'),
      ('Sunrise REFRESHMENT', 'Sunrise REFRESHMENT'),
      ('ACME  MARKETPLACE', 'Acme Marketplace'),
      ('PRIVATE', null),
      ('Private Limited', null),
      ('swiggy@ybl', 'swiggy@ybl'),
      ('SWIGGY@YBL', 'SWIGGY@YBL'),
      ('राम स्टोर', 'राम स्टोर'),
      ('CAFÉ BLUE', 'CAFÉ BLUE'), // non-ASCII: kept
      ('7-ELEVEN', '7-eleven'),
      ('12345', '12345'),
      // Cut short by the bank (found on the Oppo): a long name only.
      ('GLOBEX DESIGNS PRIVATE LI', 'Globex Designs'),
      ('Example Clearing Corporation Lt', 'Example Clearing Corporation'),
      ('INITECH TRAVEL PRIVATE LIMI', 'Initech Travel'),
      ('ZEN LI', 'Zen Li'),
      ('', null),
      ('   ', null),
    ]) {
      test('"$payee" → $expected', () {
        expect(cleanPayee(payee), expected);
      });
    }

    test('learned wins over the payee; blank learned is none', () {
      expect(suggestedTitle(learned: 'Groceries', payee: 'ACME'), 'Groceries');
      expect(suggestedTitle(learned: '  ', payee: 'ACME'), 'Acme');
      expect(suggestedTitle(payee: null), isNull);
    });
  });

  group('payeeKeyOf', () {
    test('suffixes, case and spaces don\'t split a payee', () {
      expect(
        payeeKeyOf('ACME MARKETPLACE PRIVATE'),
        payeeKeyOf('Acme  Marketplace Priva'),
      );
      expect(payeeKeyOf('CAFÉ'), payeeKeyOf('café'));
      expect(payeeKeyOf('PRIVATE'), isNull);
      expect(payeeKeyOf(null), isNull);
    });
  });

  group('suggestedCategory', () {
    TitleHistoryRow row(
      String title,
      int category, {
      int recent = 1,
      int at = 1,
    }) => TitleHistoryRow(
      title: title,
      amountMinor: 100,
      currencyCode: 'INR',
      categoryId: category,
      lastAt: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      recent: recent,
    );

    test('learned > title > none', () {
      final history = [row('Acme', 7)];
      expect(
        suggestedCategory(
          learned: (title: 'X', categoryId: 3),
          title: 'Acme',
          history: history,
        ),
        3,
      );
      expect(suggestedCategory(title: 'acme', history: history), 7);
      expect(suggestedCategory(title: 'Other', history: history), isNull);
      expect(suggestedCategory(history: history), isNull);
    });

    test('a title used only longer than 180 days ago gives none; the newest '
        'spelling wins', () {
      expect(
        suggestedCategory(title: 'Acme', history: [row('Acme', 7, recent: 0)]),
        isNull,
      );
      expect(
        suggestedCategory(
          title: 'ACME',
          history: [row('Acme', 7, at: 5), row('acme', 8, at: 9)],
        ),
        8,
      );
    });
  });

  group('scanSince', () {
    const day = Duration.millisecondsPerDay;
    const now = 100 * day;

    test('§5.8\'s table', () {
      expect(scanSince(nowMs: now, cursorMs: null), now - 7 * day);
      expect(scanSince(nowMs: now, cursorMs: now - day), now - day);
      expect(scanSince(nowMs: now, cursorMs: now - 40 * day), now - 30 * day);
      expect(scanSince(nowMs: now, cursorMs: now + 1), now - 7 * day);
      expect(scanSince(nowMs: now, cursorMs: now), now);
    });

    test('30 days exactly and 1 ms older', () {
      expect(scanSince(nowMs: now, cursorMs: now - 30 * day), now - 30 * day);
      expect(
        scanSince(nowMs: now, cursorMs: now - 30 * day - 1),
        now - 30 * day,
      );
    });

    test('a debug look-back of 75: the first scan reads all 75 days', () {
      expect(
        scanSince(nowMs: now, cursorMs: null, lookbackDays: 75),
        now - 75 * day,
      );
      expect(
        scanSince(nowMs: now, cursorMs: now - 60 * day, lookbackDays: 75),
        now - 60 * day,
      );
    });
  });

  group('smsGroups', () {
    var nextId = 100;
    SmsSuggestion s(String on, {int atMs = 0, int offset = 330}) =>
        SmsSuggestion(
          id: nextId--,
          sender: 'VM-ABCBNK-S',
          receivedAt: DateTime.fromMillisecondsSinceEpoch(atMs, isUtc: true),
          utcOffsetMinutes: offset,
          receivedOn: on,
          bodySha256: 'a' * 64,
          amountMinor: 100,
          currencyCode: 'INR',
          paymentMethodKey: 'upi',
          payee: null,
          payeeKey: null,
          reference: null,
          title: null,
          categoryId: null,
          status: SmsStatus.pending,
          expenseId: null,
        );

    test('two months, days across the month end, open frames', () {
      final rows = [
        s('2026-10-01'),
        s('2026-10-01'),
        s('2026-09-30'),
        s('2026-09-29'),
      ];
      final groups = smsGroups(rows, hasMore: true);
      expect(
        [for (final g in groups) g.range.from],
        ['2026-10-01', '2026-09-01'],
      );
      expect([for (final g in groups) g.open], [false, true]);
      expect(groups.first.days.single.items, hasLength(2));
      expect(
        [for (final d in groups.last.days) d.day],
        ['2026-09-30', '2026-09-29'],
      );
      expect(smsGroups(rows, hasMore: false).last.open, isFalse);
      expect(smsGroups(const [], hasMore: false), isEmpty);
    });

    test('a suggestion at 23:30 IST stays on its received_on whatever the '
        'zone the phone is in now', () {
      // 2026-10-09 23:30 IST = 18:00 UTC; in UTC−5 that is 13:00 on the 9th,
      // but 00:30 on the 10th would be wrong either way: the stored day wins.
      final late = s(
        '2026-10-09',
        atMs: DateTime.utc(2026, 10, 9, 18).millisecondsSinceEpoch,
      );
      expect(
        smsGroups([late], hasMore: false).single.days.single.day,
        '2026-10-09',
      );
    });
  });

  group('smsOpenRule', () {
    const link = (id: 1, bodySha256: 'aa');
    ExpenseDraft draft({int? editing, SmsLink? sms}) => ExpenseDraft(
      editingExpenseId: editing,
      title: 'Lunch',
      amountExpression: '5',
      description: '',
      categoryId: null,
      eventIds: const {},
      paymentMethodId: null,
      currencyCode: 'INR',
      pickedWallClock: null,
      touched: const {},
      itemizeLine: null,
      itemizeLabels: const [],
      itemizeTerms: const [],
      updatedAt: DateTime.utc(2026),
      sms: sms,
    );

    test('§5.9\'s table', () {
      expect(smsOpenRule(null, link), SmsOpen.fresh);
      expect(smsOpenRule(draft(sms: link), link), SmsOpen.resume);
      expect(smsOpenRule(draft(), link), SmsOpen.ask);
      expect(
        smsOpenRule(draft(sms: (id: 2, bodySha256: 'bb')), link),
        SmsOpen.ask,
      );
      expect(
        smsOpenRule(draft(sms: (id: 1, bodySha256: 'bb')), link),
        SmsOpen.ask,
        reason: 'same id, another SMS (a restore): not its own draft',
      );
      expect(smsOpenRule(draft(editing: 5), link), SmsOpen.ask);
    });
  });
}
