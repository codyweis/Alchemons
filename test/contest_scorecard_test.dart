// The scorecard over a trait contest: it cannot be left until the bout is
// over, and then it says who won and what it earned.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/contest_arena_overlays.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

CosmicPartyMember _member(String name, String element, String family) =>
    CosmicPartyMember(
      instanceId: name,
      baseId: 'X',
      displayName: name,
      family: family,
      element: element,
      level: 5,
      slotIndex: 0,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      staminaBars: 3,
      staminaMax: 3,
    );

void main() {
  testWidgets('continue is held until the bout is over, then pays out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    var popped = false;
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: FactionTheme.scorchForge(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        opaque: false,
                        pageBuilder: (_, _, _) =>
                            CosmicSpeedContestArenaOverlay(
                              player: _member('Airwing', 'Air', 'Wing'),
                              opponentMember: _member(
                                'Cinderwick',
                                'Fire',
                                'Horn',
                              ),
                              playerScore: 4.31,
                              opponentScore: 3.87,
                              stakes: const ContestStakes(
                                level: 2,
                                levels: 5,
                                shards: 35,
                                gold: 2,
                              ),
                            ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('GO'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // Mid-bout the card keeps low, out of the arena's way: names and the
    // latest calls, no button yet.
    expect(find.text('AIRWING'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);
    expect(find.text('IN THE ARENA…'), findsNothing);
    // Back does nothing mid-bout.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(popped, isFalse);

    await tester.pump(const Duration(seconds: 12));
    expect(find.text('AIRWING WINS'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('35'), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
  });
}
