// Two notices raised in the same frame (closing a new discovery does this)
// left the first in the overlay: it was inserted but not built yet, and the
// old dismissal skipped anything not mounted. Swiping it away then removed
// the second instead, and the swiped Dismissible stayed in the tree.

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('two notices in one frame: only the second stays, and it swipes '
      'away cleanly', (tester) async {
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: factionThemeFor(null),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showGameSnack(context, 'first');
                    showGameSnack(context, 'second');
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('FIRST'), findsNothing);
    expect(find.text('SECOND'), findsOneWidget);

    await tester.drag(find.text('SECOND'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('SECOND'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
