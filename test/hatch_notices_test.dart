// The after-hatch notices (a breeding milestone, a new discovery) are the
// game's one notice plate: no icon, the place it opens named on the right.

import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a milestone notice is the plain notice plate', (tester) async {
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: factionThemeFor(null),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      EggHatching.showConstellationMilestoneOverlay(
                        context,
                        speciesId: 'LET01',
                        speciesName: 'Firelet',
                        showcase: const PendingMilestoneShowcase(
                          speciesId: 'LET01',
                          milestoneCount: 10,
                          pointsAwarded: 2,
                        ),
                      ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('FIRELET REACHED 10 FUSIONS'), findsOneWidget);
    expect(find.textContaining('+2 CONSTELLATION POINTS'), findsOneWidget);
    expect(find.text('PROGRESS'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);

    // It goes on its own.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('PROGRESS'), findsNothing);
  });
}
