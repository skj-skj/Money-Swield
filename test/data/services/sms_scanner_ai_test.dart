import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/data/repositories/category_repository.dart';
import 'package:money_swield/data/repositories/data_version.dart';
import 'package:money_swield/data/repositories/expense_repository.dart';
import 'package:money_swield/data/repositories/settings_repository.dart';
import 'package:money_swield/data/repositories/sms_suggestion_repository.dart';
import 'package:money_swield/data/services/on_device_ai_service.dart';
import 'package:money_swield/data/services/sms_scanner.dart';
import 'package:money_swield/domain/models/expense.dart';
import 'package:money_swield/domain/models/money.dart';
import 'package:money_swield/domain/models/sms_suggestion.dart';
import 'package:money_swield/domain/sms/sms_ai_prompt.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/sms/fixtures/india_sms.dart';
import '../../helpers/fake_on_device_ai.dart';
import '../../helpers/fake_sms_service.dart';
import '../../helpers/test_database.dart';

/// The scanner's on-device model path, with a fake model and inbox, on SQLite
/// 3.22.
void main() {
  late Database db;
  late TestClock clock;
  late FakeSmsService sms;
  late FakeOnDeviceAi ai;
  late SettingsRepository settings;
  late SmsSuggestionRepository repo;
  late List<CategoryName> categories;
  late int groceries;

  const day = Duration.millisecondsPerDay;
  const bank = 'VM-ABCBNK-S';

  setUp(() async {
    db = await openMigratedDatabase();
    clock = TestClock(DateTime.utc(2026, 10, 11, 9));
    sms = FakeSmsService();
    ai = FakeOnDeviceAi();
    settings = SettingsRepository(db, deviceCurrency: 'INR');
    repo = SmsSuggestionRepository(db, now: clock.call);
    await settings.setSmsEnabled(true);
    groceries = (await CategoryRepository(
      db,
    ).add(name: 'Groceries', emoji: '🛒')).id;
    categories = [(id: groceries, name: 'Groceries')];
  });

  int nowMs() => clock.now.millisecondsSinceEpoch;

  SmsScanner scanner({int batch = 10}) => SmsScanner(
    service: sms,
    repository: repo,
    settings: settings,
    now: clock.call,
    offsetMinutesAt: (_) => 330,
    ai: ai,
    aiBatchSize: batch,
    // On this isolate: the real one runs in Isolate.run.
    candidatesAll: (messages) async => candidatesNow(messages),
  );

  /// [n] candidate SMS a minute apart from 3 days ago: "Rs.<i+1>.00".
  List<int> addDebits(int n, {int from = 0}) => [
    for (var i = from; i < from + n; i++)
      (() {
        final at = nowMs() - 3 * day + i * 60000;
        sms.add(
          bank,
          at,
          'Rs.${i + 1}.00 debited from A/c XX1234 to SHOP NUMBER $i '
          'Ref ${100000000000 + i}',
        );
        return at;
      })(),
  ];

  Future<List<Map<String, Object?>>> rows() =>
      db.query('sms_suggestions', orderBy: 'received_at');

  /// A scan with the model (as `SmsCubit` asks when it is in and on).
  Future<ScanResult> scan(SmsScanner s, {bool useAi = true}) =>
      s.scan(useAi: useAi, categories: () async => categories);

  group('the model reads', () {
    test('accepted → parsed_by ai, its amount, title (cleaned), category and '
        'payment; the regex\'s payee and reference', () async {
      sms.add(bank, nowMs() - day, bankSent1);
      ai.reply = (_) => AiAnswer(
        FakeOnDeviceAi.answerJson(
          amount: '150',
          title: 'GLOBEX TECHNOLOGIES',
          payee: 'Globex Tech',
        ),
      );
      expect(await scan(scanner()), (outcome: ScanOutcome.done, added: 1));
      final row = (await rows()).single;
      expect(row['parsed_by'], 'ai');
      expect(row['amount_minor'], 15000);
      expect(row['title'], 'Globex Technologies');
      expect(row['category_id'], groceries);
      expect(row['payment_method_key'], 'upi');
      expect(row['payee'], 'GLOBEX TECHNOLOGIES PRIVA');
      expect(row['reference'], '100000000001');
      expect(ai.asked, [bankSent1]);
    });

    test('the model\'s payee when the regex finds none', () async {
      const body = 'Rs 75 debited from A/c XX1234. Ref 123456789012';
      sms.add(bank, nowMs() - day, body);
      ai.reply = (_) =>
          AiAnswer(FakeOnDeviceAi.answerJson(amount: '75', payee: 'Café X'));
      await scan(scanner());
      expect((await rows()).single['payee'], 'Café X');
    });

    test(
      'payment none / invalid → the regex text rule on the whole text',
      () async {
        sms.add(bank, nowMs() - day, bankSent1); // UPI only in its footer
        ai.reply = (_) => AiAnswer(
          FakeOnDeviceAi.answerJson(amount: '150.00', payment: 'neft'),
        );
        await scan(scanner());
        expect((await rows()).single['payment_method_key'], 'upi');
      },
    );

    for (final (what, reply) in <(String, AiReply)>[
      ('refused (failed)', const AiRefused(AiError.failed)),
      ('timeout', const AiRefused(AiError.timeout)),
      ('is_debit false', AiAnswer(FakeOnDeviceAi.answerJson(isDebit: false))),
      ('malformed', const AiAnswer('{"is_debit": tru')),
      (
        'an invented amount',
        AiAnswer(FakeOnDeviceAi.answerJson(amount: '1500')),
      ),
    ]) {
      test('$what → the regex reads that SMS (parsed_by regex)', () async {
        sms.add(bank, nowMs() - day, bankSent1);
        ai.reply = (_) => reply;
        expect(await scan(scanner()), (outcome: ScanOutcome.done, added: 1));
        final row = (await rows()).single;
        expect(row['parsed_by'], 'regex');
        expect(row['amount_minor'], 15000);
        expect(row['title'], 'Globex Technologies');
      });
    }

    test('non-candidates (an OTP, an ATM withdrawal, a promotion) never reach '
        'the model', () async {
      sms
        ..add(bank, nowMs() - day, bankAtm)
        ..add(bank, nowMs() - day + 1, 'OTP 123456 for Rs 500 debit')
        ..add('VM-SHOPIN-P', nowMs() - day + 2, 'Rs 500 off, paid offers')
        ..add(bank, nowMs() - day + 3, bankSent2);
      await scan(scanner());
      expect(ai.asked, [bankSent2]);
    });

    test('two SMS of one payment (same reference and amount) → one row, as '
        'with the regex', () async {
      sms
        ..add(bank, nowMs() - day, bankSent1)
        ..add('JD-ABCBNK-S', nowMs() - day + 5, bankSent1);
      ai.reply = (_) => AiAnswer(FakeOnDeviceAi.answerJson(amount: '150.00'));
      expect((await scan(scanner())).added, 1);
    });

    test('learned title and category win over the model\'s', () async {
      sms.add(bank, nowMs() - 2 * day, bankSent1);
      final s = scanner();
      await scan(s);
      final first = (await rows()).single;
      // Saved from the card as "Rent" in another category.
      final other = (await CategoryRepository(
        db,
      ).add(name: 'Housing', emoji: '🏠')).id;
      await ExpenseRepository(
        db,
        dataVersion: DataVersion(),
        now: clock.call,
      ).add(
        ExpenseInput(
          title: 'Rent',
          description: null,
          amount: const Money(15000, 'INR'),
          amountExpression: null,
          occurredAt: clock.now,
          utcOffsetMinutes: 330,
          categoryId: other,
          paymentMethodId: 1,
          eventIds: const {},
        ),
        fromSms: (
          id: first['id']! as int,
          bodySha256: first['body_sha256']! as String,
        ),
      );
      // A new SMS of the same payee, after the cursor.
      clock.advance(const Duration(hours: 1));
      sms.add(bank, nowMs() - 60000, bankSent1.replaceAll('0001', '0009'));
      await scan(s);
      final second = (await rows()).last;
      expect(second['parsed_by'], 'ai');
      expect(second['title'], 'Rent');
      expect(second['category_id'], other);
    });
  });

  group('writes and stops', () {
    test('written every 10 with the cursor: a kill after 15 keeps 10 and the '
        'cursor at the 10th', () async {
      final at = addDebits(15);
      final hold = Completer<AiReply>();
      ai.reply = (text) => ai.asked.length == 15
          ? hold.future
          : FakeOnDeviceAi.plainAnswer(text);
      unawaited(scan(scanner()));
      await pumpEventQueue(times: 200);
      expect(ai.asked, hasLength(15));
      // The app is killed here: what is on disk.
      expect(await rows(), hasLength(10));
      expect(await repo.cursor(), at[9]);
    });

    test('the next scan after a kill reads from the 10th on, asks the model '
        'only for the rest', () async {
      final at = addDebits(15);
      final hold = Completer<AiReply>();
      ai.reply = (text) => ai.asked.length == 15
          ? hold.future
          : FakeOnDeviceAi.plainAnswer(text);
      unawaited(scan(scanner()));
      await pumpEventQueue(times: 200);
      // A new process: a new scanner, no memory.
      ai
        ..asked.clear()
        ..reply = null;
      final result = await scan(scanner());
      expect(result, (outcome: ScanOutcome.done, added: 5));
      expect(ai.asked, hasLength(5));
      expect(sms.reads.last.sinceMs, at[9]);
      expect(await rows(), hasLength(15));
    });

    for (final error in [AiError.background, AiError.busy]) {
      test('$error at the 4th → 3 stored, the cursor at the 4th, stopped; the '
          'next scan asks for the 4th again', () async {
        final at = addDebits(6);
        ai.reply = (text) => ai.asked.length == 4
            ? AiRefused(error)
            : FakeOnDeviceAi.plainAnswer(text);
        final s = scanner();
        expect(await scan(s), (outcome: ScanOutcome.stopped, added: 3));
        expect(await rows(), hasLength(3));
        expect(await repo.cursor(), at[3]);
        ai
          ..asked.clear()
          ..reply = null;
        expect(await scan(s), (outcome: ScanOutcome.done, added: 3));
        expect(ai.asked.first, contains('Rs.4.00'));
        expect(ai.asked, hasLength(3));
        expect([
          for (final r in await rows()) r['parsed_by'],
        ], everyElement('ai'));
      });
    }

    test('stopped within the last 10 minutes: the cursor stays 10 minutes '
        'behind, so an SMS stored late is still read', () async {
      sms
        ..add(bank, nowMs() - 3 * 60000, bankSent1)
        ..add(bank, nowMs() - 60000, bankSent2);
      ai.reply = (text) => ai.asked.length == 2
          ? const AiRefused(AiError.background)
          : FakeOnDeviceAi.plainAnswer(text);
      final s = scanner();
      expect((await scan(s)).outcome, ScanOutcome.stopped);
      expect(
        await repo.cursor(),
        nowMs() - SmsScanner.cursorLag.inMilliseconds,
      );
      // Stored by the provider after the scan, dated before the stop.
      sms.add(bank, nowMs() - 2 * 60000, bankMandate);
      ai.reply = null;
      await scan(s);
      expect(await rows(), hasLength(3));
      expect(ai.asked.where((sms) => sms == bankSent1), hasLength(1));
    });

    test('stopped at the very first SMS: nothing stored, the cursor not past '
        'it', () async {
      final at = addDebits(2);
      ai.reply = (_) => const AiRefused(AiError.background);
      expect(await scan(scanner()), (outcome: ScanOutcome.stopped, added: 0));
      expect(await repo.cursor(), at[0]);
    });

    test('quota at the 4th → the regex reads the rest, no more prompts, '
        'done', () async {
      addDebits(6);
      ai.reply = (text) => ai.asked.length == 4
          ? const AiRefused(AiError.quota)
          : FakeOnDeviceAi.plainAnswer(text);
      expect(await scan(scanner()), (outcome: ScanOutcome.done, added: 6));
      expect(ai.asked, hasLength(4));
      expect(
        [for (final r in await rows()) r['parsed_by']],
        ['ai', 'ai', 'ai', 'regex', 'regex', 'regex'],
      );
    });

    test('pause() → no prompt after the one running; stopped; the cursor at '
        'the next', () async {
      final at = addDebits(5);
      final hold = Completer<AiReply>();
      ai.reply = (text) =>
          ai.asked.length == 2 ? hold.future : FakeOnDeviceAi.plainAnswer(text);
      final s = scanner();
      final running = scan(s);
      await pumpEventQueue(times: 50);
      s.pause();
      hold.complete(FakeOnDeviceAi.plainAnswer(ai.asked.last));
      expect(await running, (outcome: ScanOutcome.stopped, added: 2));
      expect(ai.asked, hasLength(2));
      expect(await repo.cursor(), at[2]);
    });

    test('pause() with no scan running does nothing to the next one', () async {
      addDebits(3);
      final s = scanner()..pause();
      expect(await scan(s), (outcome: ScanOutcome.done, added: 3));
    });

    test('busy before any answer, 3 scans in a row → the 4th reads with the '
        'regex; the 5th asks the model again', () async {
      addDebits(2);
      ai.reply = (_) => const AiRefused(AiError.busy);
      final s = scanner();
      for (var i = 0; i < 3; i++) {
        expect((await scan(s)).outcome, ScanOutcome.stopped);
      }
      expect(ai.asked, hasLength(3));
      expect(await scan(s), (outcome: ScanOutcome.done, added: 2));
      expect(ai.asked, hasLength(3), reason: 'the 4th never asked');
      clock.advance(const Duration(hours: 1));
      sms.add(bank, nowMs() - 60000, bankSent2);
      ai.reply = null;
      expect((await scan(s)).added, 1);
      expect(ai.asked, hasLength(4));
    });

    test('busy stops count only in a row: another stop between them starts '
        'the count again', () async {
      addDebits(2);
      final s = scanner();
      for (final error in [
        AiError.busy,
        AiError.busy,
        AiError.background,
        AiError.busy,
        AiError.busy,
      ]) {
        ai.reply = (_) => AiRefused(error);
        expect((await scan(s)).outcome, ScanOutcome.stopped);
      }
      expect(ai.asked, hasLength(5), reason: 'never read by the regex');
    });

    test('close() during the pass → nothing more written', () async {
      addDebits(15);
      final hold = Completer<AiReply>();
      ai.reply = (text) => ai.asked.length == 12
          ? hold.future
          : FakeOnDeviceAi.plainAnswer(text);
      final s = scanner();
      final running = scan(s);
      await pumpEventQueue(times: 200);
      expect(await rows(), hasLength(10));
      s.close();
      hold.complete(FakeOnDeviceAi.plainAnswer(ai.asked.last));
      expect((await running).outcome, ScanOutcome.closed);
      expect(await rows(), hasLength(10));
      expect(ai.asked, hasLength(12));
    });

    test('progress: 0 of n, then each, then null when the scan ends', () async {
      addDebits(3);
      final s = scanner();
      final seen = <ScanProgress?>[];
      s.progress.addListener(() => seen.add(s.progress.value));
      await scan(s);
      expect(seen, [
        (done: 0, total: 3),
        (done: 1, total: 3),
        (done: 2, total: 3),
        (done: 3, total: 3),
        null,
      ]);
    });
  });

  group('the model is not asked', () {
    test('without useAi → regex only; neither the model nor the categories '
        'asked', () async {
      sms.add(bank, nowMs() - day, bankSent1);
      var categoriesRead = 0;
      await scanner().scan(
        categories: () async {
          categoriesRead++;
          return categories;
        },
      );
      expect(ai.asked, isEmpty);
      expect(ai.statusCalls, 0);
      expect(categoriesRead, 0);
      expect((await rows()).single['parsed_by'], 'regex');
    });

    test('a prompt over the size limit → the regex reads that SMS', () async {
      sms.add(bank, nowMs() - day, bankSent1);
      categories = [
        for (var i = 0; i < 400; i++) (id: groceries, name: 'Category $i …'),
      ];
      await scan(scanner());
      expect(ai.asked, isEmpty);
      expect((await rows()).single['parsed_by'], 'regex');
    });
  });

  test('a category deleted after the scan began → none, the rows still '
      'written', () async {
    sms.add(bank, nowMs() - day, bankSent1);
    ai.reply = (text) async {
      await db.delete('categories', where: 'id = ?', whereArgs: [groceries]);
      return FakeOnDeviceAi.plainAnswer(text);
    };
    expect(await scan(scanner()), (outcome: ScanOutcome.done, added: 1));
    final row = (await rows()).single;
    expect(row['parsed_by'], 'ai');
    expect(row['category_id'], isNull);
  });

  test(
    'privacy: no body in the log or any column after a model scan',
    () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = original);
      final bodies = [bankSent1, bankMandate, creditCardSpend, swiggyUpi];
      for (final (i, body) in bodies.indexed) {
        sms.add(bank, nowMs() - day + i, body);
      }
      ai.reply = (text) => ai.asked.length == 2
          ? const AiRefused(AiError.failed)
          : AiAnswer(
              FakeOnDeviceAi.answerJson(
                amount: RegExp(r'(?:Rs\.?|INR|₹)\s*([0-9.,]*[0-9])')
                    .firstMatch(text)![1]!,
              ),
            );
      await scan(scanner());
      expect(await rows(), hasLength(4));
      final everything = StringBuffer();
      for (final table in [
        for (final r in await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        ))
          r['name']! as String,
      ]) {
        for (final row in await db.query(table)) {
          everything.writeAll(row.values.whereType<String>(), '\n');
        }
      }
      expect(logs.join(), contains('answered by the on-device model'));
      for (final body in bodies) {
        for (final line in body.split('\n').where((l) => l.length > 30)) {
          expect(everything.toString(), isNot(contains(line)));
          expect(logs.join(), isNot(contains(line)));
        }
      }
    },
  );
}
