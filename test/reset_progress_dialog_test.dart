import 'package:alchemons/widgets/reset_progress_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final amount in <int?>[null, 0, 1000]) {
    testWidgets(
      'reset confirmation for $amount is explicit and cancellable at large text size',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? choice = 'not-answered';
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    choice = await showDialog<String>(
                      context: context,
                      builder: (_) =>
                          ResetProgressDialog(purchasedGold: amount),
                    );
                  },
                  child: const Text('Open reset'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open reset'));
        await tester.pumpAndSettle();
        expect(
          find.text('Are you sure you want to reset your progress?'),
          findsOneWidget,
        );
        if (amount == null) {
          expect(find.text('Sign In'), findsOneWidget);
          expect(
            find.textContaining('sign in to the account that bought it'),
            findsOneWidget,
          );
        } else {
          expect(
            find.textContaining('$amount purchased gold will be restored'),
            findsOneWidget,
          );
          expect(find.text('Sign In'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(choice, isNull);
      },
    );
  }
  testWidgets('only the destructive button confirms reset', (tester) async {
    String? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                choice = await showDialog<String>(
                  context: context,
                  builder: (_) =>
                      const ResetProgressDialog(purchasedGold: 1000),
                );
              },
              child: const Text('Open reset'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset Progress'));
    await tester.pumpAndSettle();
    expect(choice, 'reset');
  });
}
