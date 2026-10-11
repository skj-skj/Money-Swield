import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/services/sms_scanner.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/sms_suggestion.dart';
import 'package:my_expense_tracker_app/domain/sms/sms_draft_rule.dart';
import 'package:my_expense_tracker_app/ui/features/sms/view_models/sms_cubit.dart';
import 'package:my_expense_tracker_app/ui/features/sms/view_models/sms_list_cubit.dart';

import '../../../../domain/sms/fixtures/india_sms.dart';
import '../../../../helpers/fake_sms_service.dart';
import '../../../../helpers/test_database.dart';

/// `SmsCubit` and `SmsListCubit` (phase-9a.md §7.1, §7.2, §12 "Cubits").
void main() {
  late AppDependencies deps;
  late TestClock clock;
  late FakeSmsService sms;
  late SmsScanner scanner;

  const day = Duration.millisecondsPerDay;
  const bank = 'VM-ABCBNK-S';

  setUp(() async {
    clock = TestClock(DateTime.utc(2026, 10, 11, 9));
    deps = await openTestDependencies(clock: clock);
    sms = FakeSmsService();
    scanner = SmsScanner(
      service: sms,
      repository: deps.smsSuggestions,
      settings: deps.settings,
      now: clock.call,
      offsetMinutesAt: (_) => 330,
      parseAll: (messages) async => parseAllNow(messages),
    );
  });

  int nowMs() => clock.now.millisecondsSinceEpoch;

  SmsCubit smsCubit() {
    final cubit = SmsCubit(
      service: sms,
      scanner: scanner,
      repository: deps.smsSuggestions,
      settings: deps.settings,
      now: clock.call,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('SmsCubit', () {
    test('start → scan → count; availability on', () async {
      await deps.settings.setSmsEnabled(true);
      sms.add(bank, nowMs() - day, bankSent1);
      final cubit = smsCubit();
      await cubit.start();
      expect(cubit.value.availability, SmsAvailability.on);
      expect(cubit.value.pendingCount, 1);
      expect(cubit.value.scanVersion, 1);
      expect(cubit.value.lastScanAt, clock.now);
      expect(cubit.value.scanning, isFalse);
    });

    test('resumed within 60 s → no scan; after → scan', () async {
      await deps.settings.setSmsEnabled(true);
      final cubit = smsCubit();
      await cubit.start();
      expect(sms.reads, hasLength(1));
      clock.advance(const Duration(seconds: 59));
      await cubit.resumed();
      expect(sms.reads, hasLength(1));
      clock.advance(const Duration(seconds: 2));
      await cubit.resumed();
      expect(sms.reads, hasLength(2));
    });

    test('off / not built / permission taken away', () async {
      final cubit = smsCubit();
      await cubit.start();
      expect(cubit.value.availability, SmsAvailability.off);
      sms.built = false;
      await cubit.resumed();
      expect(cubit.value.availability, SmsAvailability.notBuilt);
      expect(cubit.value.isBuilt, isFalse);
      sms.built = true;
      await deps.settings.setSmsEnabled(true);
      sms.granted = false;
      await cubit.resumed();
      expect(cubit.value.availability, SmsAvailability.needsPermission);
      expect(sms.reads, isEmpty);
    });

    test('enable: granted → on and a scan; refused → off; can\'t ask → '
        'the settings page, and on once allowed there', () async {
      sms.granted = false;
      final cubit = smsCubit();
      await cubit.start();

      sms.grantOnRequest = false;
      expect(await cubit.enable(), SmsEnableResult.refused);
      expect(await deps.settings.smsEnabled(), isFalse);
      expect(cubit.value.availability, SmsAvailability.off);

      // Refused twice: Android won't show its dialog any more.
      expect(await cubit.enable(), SmsEnableResult.refused);
      expect(cubit.value.canAsk, isFalse, reason: 'the banner offers settings');
      expect(await cubit.enable(), SmsEnableResult.openedSettings);
      expect(sms.settingsOpened, 1);
      expect(await deps.settings.smsEnabled(), isFalse);
      // Allowed on the settings page, back in the app:
      sms.granted = true;
      await cubit.resumed();
      expect(await deps.settings.smsEnabled(), isTrue);
      expect(cubit.value.availability, SmsAvailability.on);
      expect(sms.reads, hasLength(1));
    });

    test('enable granted at once', () async {
      sms.granted = false;
      final cubit = smsCubit();
      expect(await cubit.enable(), SmsEnableResult.enabled);
      expect(await deps.settings.smsEnabled(), isTrue);
      expect(sms.reads, hasLength(1));
    });

    test('disable keeps the stored suggestions', () async {
      await deps.settings.setSmsEnabled(true);
      sms.add(bank, nowMs() - day, bankSent1);
      final cubit = smsCubit();
      await cubit.start();
      await cubit.disable();
      expect(cubit.value.availability, SmsAvailability.off);
      expect(await deps.smsSuggestions.pendingCount(), 1);
    });

    test('runningScan during a scan waits for it', () async {
      await deps.settings.setSmsEnabled(true);
      sms.gate = Completer<void>();
      final cubit = smsCubit();
      expect(cubit.runningScan(), isNull);
      final started = cubit.start();
      await pumpEventQueue();
      final running = cubit.runningScan();
      expect(running, isNotNull);
      var done = false;
      unawaited(running!.then((_) => done = true));
      await pumpEventQueue();
      expect(done, isFalse);
      sms.gate!.complete();
      await started;
      await pumpEventQueue();
      expect(done, isTrue);
      expect(cubit.runningScan(), isNull);
    });
  });

  group('SmsListCubit', () {
    late SmsListCubit list;

    setUp(() async {
      list = SmsListCubit(
        repository: deps.smsSuggestions,
        drafts: deps.drafts,
        paymentMethods: deps.paymentMethods,
        pageSize: 2,
      );
      addTearDown(list.close);
      await deps.smsSuggestions.insertScanned([
        for (var i = 0; i < 5; i++)
          NewSmsSuggestion(
            sender: bank,
            receivedAtMs: nowMs() - i * day,
            utcOffsetMinutes: 330,
            bodySha256: '$i' * 64,
            amountMinor: 100 + i,
            paymentMethodKey: 'upi',
          ),
      ], cursorMs: 1);
    });

    List<int> amounts() => [
      for (final r in (list.value as SmsListLoaded).rows) r.amountMinor,
    ];

    test('pages, groups, the methods by key', () async {
      await list.load();
      expect(amounts(), [100, 101]);
      await list.loadMore();
      await list.loadMore();
      expect(amounts(), [100, 101, 102, 103, 104]);
      final loaded = list.value as SmsListLoaded;
      expect(loaded.hasMore, isFalse);
      expect(loaded.months.expand((m) => m.days), hasLength(5));
      expect(loaded.methods.keys, containsAll(['upi', 'credit_card']));
    });

    test('dismiss + undo; two dismisses then Undo of the first → nothing, '
        'of the second → it comes back in its place', () async {
      await list.load();
      final rows = (list.value as SmsListLoaded).rows;
      expect(await list.dismiss(rows[0].id), isTrue);
      expect(amounts(), [101]);
      expect(await list.dismiss(rows[1].id), isTrue);
      await list.undo(rows[0].id);
      expect(await deps.smsSuggestions.pendingCount(), 3);
      await list.undo(rows[1].id);
      expect(await deps.smsSuggestions.pendingCount(), 4);
      expect(amounts().first, 101);
    });

    test('dismiss of an added one: false and the list reloads', () async {
      await list.load();
      final row = (list.value as SmsListLoaded).rows.first;
      await deps.database.update(
        'sms_suggestions',
        {'status': 'added'},
        where: 'id = ?',
        whereArgs: [row.id],
      );
      expect(await list.dismiss(row.id), isFalse);
      expect(amounts(), [101, 102]);
    });

    test('openRule for each slot; dismissDraft clears it', () async {
      await list.load();
      final row = (list.value as SmsListLoaded).rows.first;
      expect(smsOpenRule(await list.pendingDraft(), row.link), SmsOpen.fresh);
      deps.drafts.update(
        ExpenseDraft(
          editingExpenseId: null,
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
          updatedAt: clock.now,
        ),
      );
      await deps.drafts.flush();
      expect(smsOpenRule(await list.pendingDraft(), row.link), SmsOpen.ask);
      await list.dismissDraft();
      expect(await list.pendingDraft(), isNull);
    });
  });
}
