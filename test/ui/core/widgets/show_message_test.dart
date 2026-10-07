import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_expense_tracker_app/ui/core/widgets/show_message.dart';

void main() {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: messengerKey,
      home: const Scaffold(body: SizedBox.expand()),
    ),
  );

  testWidgets('shows the message for 4 seconds, without a close button', (
    tester,
  ) async {
    await pump(tester);
    showMessage(messengerKey.currentState, 'Saved');
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    await tester.pump(shortMessageDuration);
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('a new message replaces the one showing at once, instead of '
      'waiting behind it', (tester) async {
    await pump(tester);
    showMessage(messengerKey.currentState, 'First');
    await tester.pumpAndSettle();
    showMessage(messengerKey.currentState, 'Second');
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('long: 10 seconds and a close button', (tester) async {
    await pump(tester);
    showMessage(messengerKey.currentState, 'Read me', long: true);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.pump(shortMessageDuration);
    await tester.pumpAndSettle();
    expect(find.text('Read me'), findsOneWidget, reason: 'still showing');
    await tester.pump(longMessageDuration - shortMessageDuration);
    await tester.pumpAndSettle();
    expect(find.text('Read me'), findsNothing);
  });

  testWidgets('with Undo: the action works, and the snackbar still goes '
      'away on its own', (tester) async {
    await pump(tester);
    var undone = 0;
    showMessage(
      messengerKey.currentState,
      'Moved to bin',
      action: SnackBarAction(label: 'Undo', onPressed: () => undone++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);

    showMessage(
      messengerKey.currentState,
      'Moved again',
      action: SnackBarAction(label: 'Undo', onPressed: () => undone++),
    );
    await tester.pumpAndSettle();
    await tester.pump(shortMessageDuration);
    await tester.pumpAndSettle();
    expect(find.text('Moved again'), findsNothing, reason: 'not persistent');
    expect(undone, 1);
  });

  testWidgets('no messenger (the screen is gone): nothing happens', (
    tester,
  ) async {
    await pump(tester);
    showMessage(null, 'Lost');
    await tester.pumpAndSettle();
    expect(find.text('Lost'), findsNothing);
  });
}
