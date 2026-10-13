import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/l10n/app_localizations.dart';
import 'package:money_swield/ui/core/widgets/currency_picker_sheet.dart';

void main() {
  Future<List<String>> pumpList(
    WidgetTester tester, {
    required String selected,
    void Function(String)? onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CurrencySearchList(
            selected: selected,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return visibleCodes(tester);
  }

  testWidgets(
    'the selected currency is shown first, so it is visible without scrolling',
    (tester) async {
      final codes = await pumpList(tester, selected: 'INR');
      expect(codes.first, 'INR');
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Indian Rupee'))
            .selected,
        isTrue,
      );
      expect(
        codes.where((c) => c == 'INR'),
        hasLength(1),
        reason: 'not listed twice',
      );
    },
  );

  testWidgets('while searching, results keep their search order', (
    tester,
  ) async {
    await pumpList(tester, selected: 'INR');
    await tester.enterText(find.byType(TextField), 'dollar');
    await tester.pumpAndSettle();
    expect(visibleCodes(tester), isNot(contains('INR')));
    expect(visibleCodes(tester).first, 'AUD');
  });

  testWidgets('a selected code outside the catalog does not break the list', (
    tester,
  ) async {
    final codes = await pumpList(tester, selected: 'XYZ');
    expect(codes.first, 'AED');
  });

  testWidgets('tapping a row reports its code', (tester) async {
    String? picked;
    await pumpList(
      tester,
      selected: 'INR',
      onSelected: (code) => picked = code,
    );
    await tester.tap(find.text('UAE Dirham'));
    expect(picked, 'AED');
  });
  group('recentSection', () {
    List<String> codes(String selected, List<String> recent) => [
      for (final c in recentSection(selected, recent)) c.code,
    ];

    test('is the selected currency, then up to 5 recent ones', () {
      expect(codes('INR', ['USD', 'EUR']), ['INR', 'USD', 'EUR']);
      expect(codes('INR', ['USD', 'EUR', 'GBP', 'JPY', 'AED', 'CAD', 'AUD']), [
        'INR',
        'USD',
        'EUR',
        'GBP',
        'JPY',
        'AED',
      ]);
    });

    test('has no duplicates and no unknown codes', () {
      expect(codes('INR', ['INR', 'XYZ', 'USD', 'USD']), ['INR', 'USD']);
    });

    test('is empty when nothing but the selected one would be in it', () {
      expect(codes('INR', []), isEmpty);
      expect(codes('INR', ['INR']), isEmpty);
    });
  });

  testWidgets('with recent currencies: Recent, then the full list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CurrencySearchList(
            selected: 'INR',
            recent: const ['USD', 'INR'],
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('All currencies'), findsOneWidget);
    final codes = visibleCodes(tester);
    expect(codes.take(3), ['INR', 'USD', 'AED'], reason: 'full list from A');

    await tester.enterText(find.byType(TextField), 'dollar');
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsNothing, reason: 'search is plain');
  });

  testWidgets('without recent currencies it looks like before: no headers', (
    tester,
  ) async {
    await pumpList(tester, selected: 'INR');
    expect(find.text('Recent'), findsNothing);
    expect(find.text('All currencies'), findsNothing);
  });
}

/// Codes of the currency rows currently built, top to bottom.
List<String> visibleCodes(WidgetTester tester) => [
  for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
    (tile.key! as ValueKey<String>).value,
];
