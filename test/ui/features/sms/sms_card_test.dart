import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/domain/models/sms_suggestion.dart';
import 'package:my_expense_tracker_app/l10n/app_localizations.dart';
import 'package:my_expense_tracker_app/ui/features/sms/views/sms_card.dart';

/// The SMS card; both bugs were found on the Oppo.
void main() {
  SmsSuggestion sms({int amount = 12345600, String? payee}) => SmsSuggestion(
    id: 1,
    sender: 'VM-ABCBNK-S',
    receivedAt: DateTime.utc(2026, 9, 22, 15, 5),
    utcOffsetMinutes: 330,
    receivedOn: '2026-09-22',
    bodySha256: 'a' * 64,
    amountMinor: amount,
    currencyCode: 'INR',
    paymentMethodKey: 'debit_card',
    payee: payee,
    payeeKey: null,
    reference: null,
    title: null,
    categoryId: null,
    status: SmsStatus.pending,
    expenseId: null,
  );

  Future<void> pumpCard(WidgetTester tester, SmsSuggestion row) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'IN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            // One column of the two at 360 dp.
            child: SizedBox(
              width: 148,
              child: SmsCard(
                sms: row,
                method: null,
                onTap: () {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a large amount stays on one line (it wrapped "0" onto a '
      'second line)', (tester) async {
    await pumpCard(tester, sms(amount: 99999999999999));
    final amount = find.textContaining('999.99');
    expect(amount, findsOneWidget);
    final style = tester.widget<Text>(amount).style!;
    expect(
      tester.getSize(amount).height,
      lessThan(style.fontSize! * 2),
      reason: 'one line',
    );
    expect(tester.takeException(), isNull);
  });

  test('TalkBack label: only the parts there are, no empty payee', () {
    expect(
      smsCardLabel(amount: '₹5', payee: null, method: 'UPI', time: '9 am'),
      '₹5, UPI, 9 am',
    );
    expect(
      smsCardLabel(amount: '₹5', payee: 'Acme', method: 'UPI', time: '9 am'),
      '₹5, Acme, UPI, 9 am',
    );
  });

  testWidgets('the time is the clock where it was scanned, so it matches '
      'the day header whatever the zone of the phone is now', (tester) async {
    // 15:05 UTC at +05:30 → 8:35 pm, in any test zone.
    await pumpCard(tester, sms());
    expect(find.textContaining('8:35'), findsOneWidget);
  });
}
