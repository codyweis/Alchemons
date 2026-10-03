import 'package:alchemons/screens/onboarding/first_launch_account_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The first-launch prompt in the bracket frame: the welcome question's two
/// answers, and the sign-in form's cancel leading back to the question. The
/// restore itself needs the account services and is not exercised here.
void main() {
  Future<List<bool>> pumpFlow(WidgetTester tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    results.add(await runFirstLaunchAccountRestore(context)),
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets("I'M NEW returns false", (tester) async {
    final results = await pumpFlow(tester);
    expect(find.text('WELCOME, ALCHEMIST'), findsOneWidget);
    expect(find.text('I HAVE AN ACCOUNT'), findsOneWidget);

    await tester.tap(find.text("I'M NEW"));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(find.text('WELCOME, ALCHEMIST'), findsNothing);
  });

  testWidgets('cancelling sign-in returns to the welcome prompt', (
    tester,
  ) async {
    final results = await pumpFlow(tester);

    await tester.tap(find.text('I HAVE AN ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('WELCOME, ALCHEMIST'), findsOneWidget);
    expect(results, isEmpty);

    await tester.tap(find.text("I'M NEW"));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });
}
