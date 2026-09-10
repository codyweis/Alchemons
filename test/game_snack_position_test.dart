// A notification must sit below the status bar, on any screen.
//
// This was got wrong three times with a styled SnackBar. A floating SnackBar
// is positioned by a bottom margin and grows upward, so putting one at the
// top means subtracting a height you cannot know — and the framework then
// shifts it again on wide layouts. It ended up under the notch on a phone and
// two hundred pixels out on a tablet. The notification is an overlay entry
// now, and these pin the arithmetic that replaced it.

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<Rect> _show(
  WidgetTester tester, {
  required Size surface,
  required double topInset,
  required String message,
  bool withAction = false,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding(top: topInset);
  tester.view.viewPadding = FakeViewPadding(top: topInset);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Provider<FactionTheme>.value(
      value: factionThemeFor(null),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            // The screens that raise these are inside one of these, and a
            // SafeArea zeroes the inset for everything below it. Reading the
            // nearest MediaQuery here reports no status bar at all, which is
            // what put the notification under the notch.
            body: SafeArea(
              child: Center(
                child: ElevatedButton(
                  onPressed: () => showGameSnack(
                    context,
                    message,
                    icon: Icons.star,
                    action: withAction
                        ? SnackBarAction(label: 'VIEW', onPressed: () {})
                        : null,
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  final rect = tester.getRect(find.byType(Dismissible).first);
  // Let the auto-dismiss timer retire before the test ends.
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
  return rect;
}

void main() {
  testWidgets('clears the status bar on a phone', (tester) async {
    final rect = await _show(
      tester,
      surface: const Size(1080, 2400),
      topInset: 100,
      message: 'SHORT',
    );
    expect(rect.top, greaterThanOrEqualTo(100));
    expect(rect.top, 100 + kSnackTopGap);
  });

  testWidgets('clears the status bar on a tablet', (tester) async {
    final rect = await _show(
      tester,
      surface: const Size(1600, 2560),
      topInset: 60,
      message: 'SHORT',
    );
    expect(rect.top, 60 + kSnackTopGap);
  });

  testWidgets('an action does not push it off the top', (tester) async {
    // The achievement notice carries one, and it was the case that clipped.
    final rect = await _show(
      tester,
      surface: const Size(1080, 2400),
      topInset: 100,
      message: '3 ACHIEVEMENT REWARDS READY',
      withAction: true,
    );
    expect(rect.top, 100 + kSnackTopGap);
  });

  testWidgets('a long message stays on screen', (tester) async {
    final rect = await _show(
      tester,
      surface: const Size(1080, 2400),
      topInset: 100,
      message:
          'A MUCH LONGER NOTIFICATION THAT WILL CERTAINLY WRAP ONTO SEVERAL '
          'LINES AND MUST STILL BEGIN BELOW THE STATUS BAR',
    );
    expect(rect.top, 100 + kSnackTopGap);
  });
}
