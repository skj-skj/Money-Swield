import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/l10n/app_localizations.dart';
import 'package:money_swield/ui/features/expenses/views/itemize_sheet.dart';

void main() {
  Future<Future<List<String>?>> open(
    WidgetTester tester, {
    List<String> terms = const ['50', '+60*2', '-10'],
    List<String> labels = const [],
  }) async {
    late Future<List<String>?> result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => result = showItemizeSheet(
                context,
                terms: terms,
                labels: labels,
                decimalSeparator: '.',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  // Found on the Oppo: the term was a prefixText, which Material shows only
  // while the field has focus or text, so rows 2 and 3 didn't say which
  // item they were.
  testWidgets('one row per item, labelled with it, focused or not', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Describe the items'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('50'), findsOneWidget);
    expect(find.text('60 × 2'), findsOneWidget);
    expect(find.text('−10'), findsOneWidget);
    // No placeholder: the same text on every row read oddly (owner).
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.decoration!.hintText, isNull);
    }
  });

  testWidgets('Done needs one label and returns one per term, trimmed', (
    tester,
  ) async {
    final result = await open(tester);
    FilledButton done() => tester.widget(find.byType(FilledButton));
    expect(done().onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('itemLabel-1')),
      ' onion ',
    );
    await tester.pump();
    expect(done().onPressed, isNotNull);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(await result, ['', 'onion', '']);
  });

  testWidgets('labels are one line and at most 40 characters', (tester) async {
    await open(tester);
    final field = find.byKey(const ValueKey('itemLabel-0'));
    await tester.enterText(field, 'a\nb');
    expect(tester.widget<TextField>(field).controller!.text, 'ab');
    await tester.enterText(field, 'x' * 50);
    expect(tester.widget<TextField>(field).controller!.text, 'x' * 40);
  });

  testWidgets('opens with the given labels', (tester) async {
    await open(tester, terms: ['1', '+2'], labels: ['a', 'b']);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });
}
