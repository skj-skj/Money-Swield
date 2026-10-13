import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:money_swield/ui/core/widgets/sheet_messenger.dart';
import 'package:money_swield/ui/core/widgets/show_message.dart';

/// Snackbars inside a bottom sheet, where the screen's own would be
/// covered by the sheet.
void main() {
  final messenger = GlobalKey<SheetMessengerState>();
  final message = find.byKey(const ValueKey('sheetMessage'));

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SheetMessenger(
                  key: messenger,
                  child: const SizedBox(height: 300, child: Text('content')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows over the sheet, at its bottom, with the snackbar '
      'colours; gone after the usual time', (tester) async {
    await pumpSheet(tester);
    messenger.currentState!.show('3 photos saved');
    await tester.pumpAndSettle();
    expect(find.text('3 photos saved'), findsOneWidget);
    final sheet = tester.getRect(find.byType(BottomSheet));
    final rect = tester.getRect(message);
    expect(sheet.contains(rect.center), isTrue, reason: 'on the sheet');
    expect(rect.center.dy, greaterThan(sheet.center.dy), reason: 'bottom');
    final context = tester.element(message);
    expect(
      tester.widget<Text>(message).style?.color,
      Theme.of(context).colorScheme.onInverseSurface,
    );
    await tester.pump(shortMessageDuration);
    await tester.pumpAndSettle();
    expect(message, findsNothing);
  });

  testWidgets('a new message replaces the one showing and gets its own '
      'time', (tester) async {
    await pumpSheet(tester);
    messenger.currentState!.show('first');
    await tester.pump(const Duration(seconds: 3));
    messenger.currentState!.show('second');
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('second'), findsOneWidget, reason: 'its own 4 s');
    await tester.pump(shortMessageDuration);
  });

  testWidgets('a tap on it reaches what is under it', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SheetMessenger(
          key: messenger,
          child: SizedBox.expand(
            child: GestureDetector(
              onTap: () => tapped++,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );
    messenger.currentState!.show('Saved');
    await tester.pumpAndSettle();
    await tester.tap(message, warnIfMissed: false);
    expect(tapped, 1);
    await tester.pump(shortMessageDuration);
  });

  testWidgets('TalkBack reads it out (a live region)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSheet(tester);
    messenger.currentState!.show('Saved');
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Saved')),
      isSemantics(isLiveRegion: true),
    );
    await tester.pump(shortMessageDuration);
    semantics.dispose();
  });
}
