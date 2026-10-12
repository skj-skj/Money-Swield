import 'package:flutter_test/flutter_test.dart';
import 'package:my_expense_tracker_app/app/app_dependencies.dart';
import 'package:my_expense_tracker_app/data/repositories/expense_draft_repository.dart';
import 'package:my_expense_tracker_app/data/repositories/sms_suggestion_repository.dart';
import 'package:my_expense_tracker_app/domain/models/expense_draft.dart';
import 'package:my_expense_tracker_app/domain/models/sms_suggestion.dart';
import 'package:my_expense_tracker_app/domain/repeat_input.dart';
import 'package:my_expense_tracker_app/ui/features/expenses/view_models/expense_form_cubit.dart';

import '../../../../helpers/fake_timers.dart';
import '../../../../helpers/test_database.dart';

/// The Add form filled from an SMS suggestion.
void main() {
  late AppDependencies deps;
  late TestClock clock;
  late FakeTimers timers;
  late ExpenseDraftRepository drafts;

  setUp(() async {
    clock = TestClock(DateTime.utc(2026, 10, 11, 9));
    deps = await openTestDependencies(clock: clock);
    timers = FakeTimers();
    drafts = ExpenseDraftRepository(deps.database, timer: timers.call);
  });

  /// A stored pending suggestion: ₹150.00 to ACME via UPI, received
  /// 2026-10-09 08:35 UTC.
  Future<SmsSuggestion> suggestion({
    String? payee = 'ACME MARKETPLACE PRIVATE',
    String method = 'upi',
    int amount = 15000,
    String sha = 'a',
  }) async {
    await deps.smsSuggestions.insertScanned([
      NewSmsSuggestion(
        sender: 'VM-ABCBNK-S',
        receivedAtMs: DateTime.utc(2026, 10, 9, 8, 35).millisecondsSinceEpoch,
        utcOffsetMinutes: 330,
        bodySha256: sha * 64,
        amountMinor: amount,
        paymentMethodKey: method,
        payee: payee,
      ),
    ], cursorMs: 1);
    return (await deps.smsSuggestions.pendingPage()).firstWhere(
      (s) => s.bodySha256 == sha * 64,
    );
  }

  Future<ExpenseFormCubit> openForm({
    SmsSuggestion? sms,
    ExpenseDraft? draft,
    String defaultCurrency = 'INR',
  }) async {
    final cubit = ExpenseFormCubit(
      expenses: deps.expenses,
      categories: deps.categories,
      events: deps.events,
      paymentMethods: deps.paymentMethods,
      drafts: drafts,
      l10n: l10nFor('en'),
      defaultCurrency: defaultCurrency,
      defaultPaymentMethodId: 1,
      openingDraft: draft,
      sms: sms,
      smsSuggestions: deps.smsSuggestions,
      now: clock.call,
    );
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  ExpenseFields fields(ExpenseFormCubit cubit) =>
      (cubit.value as ExpenseFormReady).fields;

  Future<int> methodId(String key) async => (await deps.paymentMethods.all())
      .firstWhere((m) => m.builtinKey == key)
      .id;

  test('fills title, amount in INR, the SMS time in this zone, the payment '
      'method, the category; no draft until a change', () async {
    final sms = await suggestion();
    await deps.database.update(
      'sms_suggestions',
      {'category_id': 3},
      where: 'id = ?',
      whereArgs: [sms.id],
    );
    final cubit = await openForm(
      sms: (await deps.smsSuggestions.byId(sms.id))!,
    );
    final f = fields(cubit);
    expect(f.title, 'Acme Marketplace');
    expect(f.expression, '150.00');
    expect(f.currencyCode, 'INR');
    final local = DateTime.utc(2026, 10, 9, 8, 35).toLocal();
    expect(
      f.wallClock,
      DateTime.utc(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
      ),
    );
    expect(f.paymentMethodId, await methodId('upi'));
    expect(f.categoryId, 3);
    expect(cubit.smsLink, sms.link);
    expect(cubit.smsSource?.sender, 'VM-ABCBNK-S');
    expect(cubit.ownsDraft, isFalse);
    expect(await drafts.read(), isNull);
    expect(cubit.isDirty, isTrue, reason: 'Clear brings back a plain form');
  });

  test('INR with 2 digits on a JPY or KWD default currency', () async {
    final sms = await suggestion();
    for (final currency in ['JPY', 'KWD']) {
      final cubit = await openForm(sms: sms, defaultCurrency: currency);
      expect(fields(cubit).currencyCode, 'INR');
      expect(fields(cubit).expression, '150.00');
    }
  });

  test('a change makes a draft with the link; Save marks it, from that '
      'draft too', () async {
    final sms = await suggestion();
    final cubit = await openForm(sms: sms);
    cubit.categorySelected(2);
    await drafts.flush();
    final draft = await drafts.read();
    expect(draft!.sms, sms.link);
    // Resumed from the FAB later:
    final resumed = await openForm(draft: draft);
    expect(resumed.smsLink, sms.link);
    expect(resumed.smsSource?.id, sms.id);
    final saved = await resumed.save();
    expect(saved, isNotNull);
    final row = (await deps.smsSuggestions.byId(sms.id))!;
    expect(row.status, SmsStatus.added);
    expect(row.expenseId, saved!.id);
    expect(saved.occurredAt, sms.receivedAt);
    expect(saved.amount.amountMinor, 15000);
  });

  test('a second Save of an added SMS: SmsAlreadyAdded, nothing saved, the '
      'form and its draft stay', () async {
    final sms = await suggestion();
    final first = await openForm(sms: sms);
    first.categorySelected(1);
    await first.save();
    final second = await openForm(sms: sms);
    second.categorySelected(2);
    await expectLater(second.save(), throwsA(isA<SmsAlreadyAdded>()));
    expect(second.value, isA<ExpenseFormReady>());
    expect((second.value as ExpenseFormReady).saving, isFalse);
    await drafts.flush();
    expect((await drafts.read())?.sms, sms.link);
    expect(
      (await deps.database.query('expenses')).length,
      1,
      reason: 'no second expense',
    );
  });

  test('Clear: a plain Add form, the link gone; Undo brings it back', () async {
    final sms = await suggestion();
    final cubit = await openForm(sms: sms);
    await cubit.clear();
    expect(cubit.smsLink, isNull);
    expect(cubit.smsSource, isNull);
    expect(fields(cubit).title, '');
    cubit.undoReset();
    expect(cubit.smsLink, sms.link);
    expect(fields(cubit).title, 'Acme Marketplace');
  });

  test('a payment method key whose built-in row was deleted → the default; '
      'a category gone → none; no title → empty', () async {
    final sms = await suggestion(method: 'credit_card', payee: null);
    await deps.database.delete(
      'payment_methods',
      where: "builtin_key = 'credit_card'",
    );
    final withCategory = (await deps.smsSuggestions.byId(sms.id))!;
    final cubit = await openForm(
      sms: SmsSuggestion(
        id: withCategory.id,
        sender: withCategory.sender,
        receivedAt: withCategory.receivedAt,
        utcOffsetMinutes: withCategory.utcOffsetMinutes,
        receivedOn: withCategory.receivedOn,
        bodySha256: withCategory.bodySha256,
        amountMinor: withCategory.amountMinor,
        currencyCode: withCategory.currencyCode,
        paymentMethodKey: withCategory.paymentMethodKey,
        payee: null,
        payeeKey: null,
        reference: null,
        title: null,
        categoryId: 999,
        status: SmsStatus.pending,
        expenseId: null,
      ),
    );
    expect(fields(cubit).paymentMethodId, 1);
    expect(fields(cubit).categoryId, isNull);
    expect(fields(cubit).title, '');
  });

  test('a renamed built-in method is still matched by its key', () async {
    final sms = await suggestion(method: 'debit_card');
    await deps.database.update('payment_methods', {
      'name': 'Bank card',
    }, where: "builtin_key = 'debit_card'");
    final cubit = await openForm(sms: sms);
    expect(fields(cubit).paymentMethodId, await methodId('debit_card'));
  });

  test('a title of 100 characters is kept', () async {
    final sms = await suggestion(payee: 'a' * 100);
    final cubit = await openForm(sms: sms);
    expect(fields(cubit).title, 'a' * 100);
    cubit.categorySelected(1);
    expect(await cubit.save(), isNotNull);
  });

  test('Repeats on → addRepeating marks the SMS', () async {
    final sms = await suggestion();
    final cubit = await openForm(sms: sms);
    cubit
      ..categorySelected(1)
      ..repeatToggled(true);
    expect(fields(cubit).repeat, RepeatChoice.defaults);
    final saved = await cubit.save();
    expect(saved?.recurringExpenseId, isNotNull);
    expect((await deps.smsSuggestions.byId(sms.id))!.status, SmsStatus.added);
  });

  test('a resumed SMS draft whose row is gone: no banner, the Save still '
      'works and marks nothing', () async {
    final sms = await suggestion();
    final cubit = await openForm(sms: sms);
    cubit.categorySelected(2);
    await drafts.flush();
    final draft = (await drafts.read())!;
    await deps.database.delete('sms_suggestions');
    final resumed = await openForm(draft: draft);
    expect(resumed.smsSource, isNull);
    expect(await resumed.save(), isNotNull);
  });

  test('a resumed draft whose id now names another SMS (a restore): no '
      'banner, and that other SMS is never marked', () async {
    final sms = await suggestion();
    final cubit = await openForm(sms: sms);
    cubit.categorySelected(2);
    await drafts.flush();
    final draft = (await drafts.read())!;
    await deps.database.update(
      'sms_suggestions',
      {'body_sha256': 'b' * 64},
      where: 'id = ?',
      whereArgs: [sms.id],
    );
    final resumed = await openForm(draft: draft);
    expect(resumed.smsSource, isNull);
    await resumed.save();
    expect((await deps.smsSuggestions.byId(sms.id))!.status, SmsStatus.pending);
  });
}
