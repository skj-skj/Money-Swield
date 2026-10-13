import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_swield/data/repositories/settings_repository.dart';
import 'package:money_swield/data/repositories/sms_suggestion_repository.dart';
import 'package:money_swield/data/services/sms_scanner.dart';
import 'package:money_swield/domain/sms/sms_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/sms/fixtures/india_sms.dart';
import '../../helpers/fake_sms_service.dart';
import '../../helpers/test_database.dart';

/// `SmsScanner` with a fake inbox and clock, on SQLite 3.22.
void main() {
  late Database db;
  late TestClock clock;
  late FakeSmsService sms;
  late SettingsRepository settings;
  late SmsSuggestionRepository repo;
  late int parseCalls;

  const day = Duration.millisecondsPerDay;
  const bank = 'VM-ABCBNK-S';

  setUp(() async {
    db = await openMigratedDatabase();
    clock = TestClock(DateTime.utc(2026, 10, 11, 9));
    sms = FakeSmsService();
    settings = SettingsRepository(db, deviceCurrency: 'INR');
    repo = SmsSuggestionRepository(db, now: clock.call);
    parseCalls = 0;
    await settings.setSmsEnabled(true);
  });

  int nowMs() => clock.now.millisecondsSinceEpoch;

  SmsScanner scanner({int lookbackDays = 30, int readLimit = 2000}) =>
      SmsScanner(
        service: sms,
        repository: repo,
        settings: settings,
        now: clock.call,
        lookbackDays: lookbackDays,
        readLimit: readLimit,
        offsetMinutesAt: (_) => 330,
        // On this isolate, counting: the real one runs in Isolate.run.
        parseAll: (messages) async {
          parseCalls += messages.length;
          return parseAllNow(messages);
        },
      );

  Future<int> stored() async => (await db.query('sms_suggestions')).length;

  group('nothing read', () {
    test('not built / off / no permission', () async {
      sms.built = false;
      expect((await scanner().scan()).outcome, ScanOutcome.notBuilt);
      sms.built = true;
      await settings.setSmsEnabled(false);
      expect((await scanner().scan()).outcome, ScanOutcome.off);
      await settings.setSmsEnabled(true);
      sms.granted = false;
      expect((await scanner().scan()).outcome, ScanOutcome.noPermission);
      expect(sms.reads, isEmpty);
    });
  });

  group('the window', () {
    test(
      'first scan 7 days; then from the cursor; 40 days away → 30',
      () async {
        final s = scanner();
        await s.scan();
        expect(sms.reads.last.sinceMs, nowMs() - 7 * day);
        final cursor = await repo.cursor();
        expect(cursor, nowMs() - SmsScanner.cursorLag.inMilliseconds);
        clock.advance(const Duration(hours: 2));
        await s.scan();
        expect(sms.reads.last.sinceMs, cursor);
        clock.advance(const Duration(days: 40));
        await s.scan();
        expect(sms.reads.last.sinceMs, nowMs() - 30 * day);
      },
    );

    test('a debug look-back of 75 reads 75 days at once', () async {
      await scanner(lookbackDays: 75).scan();
      expect(sms.reads.single.sinceMs, nowMs() - 75 * day);
    });

    test('the define is used in debug only; a release build ignores it', () {
      expect(lookbackDaysFor(releaseMode: false, define: '75'), 75);
      expect(lookbackDaysFor(releaseMode: true, define: '75'), 30);
      expect(lookbackDaysFor(releaseMode: false, define: ''), 30);
      expect(lookbackDaysFor(releaseMode: false, define: '0'), 30);
      expect(lookbackDaysFor(releaseMode: false, define: 'x'), 30);
      expect(lookbackDaysFor(releaseMode: false, define: ' 9 '), 9);
      final forApp = SmsScanner.forApp(
        service: sms,
        repository: repo,
        settings: settings,
        releaseMode: true,
        lookbackDefine: '75',
      );
      expect(forApp.lookbackDays, 30);
      expect(
        SmsScanner.forApp(
          service: sms,
          repository: repo,
          settings: settings,
          releaseMode: false,
          lookbackDefine: '75',
        ).lookbackDays,
        75,
      );
    });
  });

  group('parsing', () {
    test('candidates stored, non-candidates and unparseable ones move the '
        'cursor and are never retried', () async {
      sms
        ..add(bank, nowMs() - 3 * day, bankSent1)
        ..add(bank, nowMs() - 3 * day + 1, bankAtm)
        ..add('VM-ABCBNK-P', nowMs() - 2 * day, 'Rs 500 off on a purchase')
        ..add(bank, nowMs() - 2 * day + 1, 'Rs 12.345 debited from A/c');
      final s = scanner();
      final result = await s.scan();
      expect(result, (outcome: ScanOutcome.done, added: 1));
      expect(parseCalls, 4);
      clock.advance(const Duration(hours: 1));
      expect((await s.scan()).added, 0);
      expect(parseCalls, 4, reason: 'nothing before the cursor is re-read');
    });

    test(
      'rows already stored are not parsed again (the overlap, a late '
      'SMS); a late-stored SMS before the cursor is read next scan',
      () async {
        sms.add(bank, nowMs() - 5 * 60 * 1000, bankSent1);
        final s = scanner();
        await s.scan();
        expect(parseCalls, 1);
        // Stored by the provider after the scan with an older `date`, inside
        // the 10-minute lag.
        sms.add(bank, nowMs() - 2 * 60 * 1000, bankSent2);
        clock.advance(const Duration(minutes: 1));
        expect((await s.scan()).added, 1);
        expect(parseCalls, 2, reason: 'the stored one was skipped by its key');
        expect(await stored(), 2);
      },
    );

    test('rows the last scan handled inside the lag are not parsed again, '
        'stored or not (a non-candidate, a reference repeated)', () async {
      sms
        ..add(bank, nowMs() - 5 * 60 * 1000, bankSent1)
        ..add(bank, nowMs() - 4 * 60 * 1000, bankAtm)
        ..add(bank, nowMs() - 3 * 60 * 1000, '$bankSent1 ');
      final s = scanner();
      expect((await s.scan()).added, 1);
      expect(parseCalls, 3);
      clock.advance(const Duration(minutes: 1));
      await s.scan();
      expect(parseCalls, 3, reason: 'all three are inside the lag');
      // A new scanner (the app restarted) has no memory: the two not
      // stored are parsed once more, the stored one is skipped by its key.
      await scanner().scan();
      expect(parseCalls, 5);
      expect(await stored(), 1);
    });

    test('2,500 rows → 2,000 handled, the cursor at the 2,000th, the rest '
        'next scan', () async {
      final start = nowMs() - 6 * day;
      for (var i = 0; i < 2500; i++) {
        sms.add(bank, start + i * 1000, 'Rs ${i + 1} debited from A/c XX1');
      }
      final s = scanner();
      expect((await s.scan()).added, 2000);
      expect(await repo.cursor(), start + 1999 * 1000);
      expect((await s.scan()).added, 500);
      expect(await stored(), 2500);
      expect(
        parseCalls,
        2500,
        reason: 'the 2,000th is read again at the cursor but skipped by key',
      );
    });
  });

  group('one at a time, idle, close', () {
    test('two scans at once → one read; idle completes when it ends', () async {
      sms.gate = Completer<void>();
      final s = scanner();
      final a = s.scan();
      final b = s.scan();
      var idle = false;
      unawaited(s.idle.then((_) => idle = true));
      await pumpEventQueue();
      expect(sms.reads, hasLength(1));
      expect(idle, isFalse);
      expect(s.isScanning, isTrue);
      sms.gate!.complete();
      expect(await a, await b);
      await pumpEventQueue();
      expect(idle, isTrue);
      expect(s.isScanning, isFalse);
    });

    test('close() mid-scan → nothing written, later scans closed', () async {
      sms.add(bank, nowMs() - day, bankSent1);
      sms.gate = Completer<void>();
      final s = scanner();
      final running = s.scan();
      await pumpEventQueue();
      s.close();
      sms.gate!.complete();
      expect((await running).outcome, ScanOutcome.closed);
      expect(await stored(), 0);
      expect(await repo.cursor(), isNull);
      expect((await s.scan()).outcome, ScanOutcome.closed);
    });

    test('a read failure: logged, the cursor unchanged, no throw', () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = original);
      sms.readError = Exception('provider gone');
      expect((await scanner().scan()).outcome, ScanOutcome.failed);
      expect(await repo.cursor(), isNull);
      expect(logs.join(), contains('provider gone'));
    });
  });

  test(
    'privacy: no body in the log or in any text column after a scan',
    () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = original);
      final bodies = [bankSent1, bankMandate, creditCardSpend, swiggyUpi];
      for (final (i, body) in bodies.indexed) {
        sms.add(bank, nowMs() - day + i, body);
      }
      // A failing scan too, so its log is checked.
      final s = scanner();
      await s.scan();
      sms.readError = Exception('x');
      await s.scan();
      expect(await stored(), 4);
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
      for (final body in bodies) {
        // Any line of a body longer than a payee is text that leaked.
        for (final line in body.split('\n').where((l) => l.length > 30)) {
          expect(everything.toString(), isNot(contains(line)));
          expect(logs.join(), isNot(contains(line)));
        }
        expect(everything.toString(), isNot(contains(body)));
      }
    },
  );

  test('parseAllNow is the candidate check then the parser', () {
    expect(parseAllNow([(bank, bankAtm), (bank, bankSent1)]), [
      null,
      const IndiaSmsParser().parse(bankSent1),
    ]);
  });
}
