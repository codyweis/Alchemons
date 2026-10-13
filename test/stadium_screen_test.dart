import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/trials_records.dart';
import 'package:alchemons/screens/stadium/cup_shelf.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CosmicPartyMember _member(String name, String element, String family) =>
    CosmicPartyMember(
      instanceId: 'test:$name',
      baseId: '',
      displayName: name,
      element: element,
      family: family,
      level: 1,
      statSpeed: 3.4,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      slotIndex: 0,
      staminaBars: 4,
      staminaMax: 4,
    );

void main() {
  for (final size in const [Size(844, 390), Size(916, 265)]) {
    testWidgets(
      'a whole race plays out and pays at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final cup = kRaceCups[0];
        final me = _member('Ember', 'Fire', 'mane');
        final racers = raceField(cup, 0, racerFromMember(me, null));
        final bodies = [
          for (final r in racers)
            RaceBody(
              r.isPlayer
                  ? me
                  : _member(
                      r.entrant.name,
                      r.entrant.element,
                      r.entrant.family,
                    ),
            ),
        ];
        int? paidFor;
        double? timed;
        RaceOutcome? outcome;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  outcome = await Navigator.of(context).push<RaceOutcome>(
                    MaterialPageRoute(
                      builder: (_) => RaceScreen(
                        cup: cup,
                        race: 0,
                        racers: racers,
                        bodies: bodies,
                        onFinished: (finish) async {
                          paidFor = finish.place;
                          timed = finish.mark;
                          return TrialsPayout(
                            gold: finish.place == 1 ? 1 : 0,
                          );
                        },
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Through the count, then boost three times along the way. The stage
        // steps at most a tenth of a second a frame, so frames come that often.
        Future<void> run(double seconds) async {
          for (var f = 0; f < seconds * 10 && paidFor == null; f++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await run(6);
        for (var b = 0; b < 3; b++) {
          await tester.tap(find.text('BOOST'));
          await run(4);
        }
        await run(90);
        expect(paidFor, isNotNull);
        // The race reports its time for the record.
        expect(timed, greaterThan(0));
        // The podium, then the results.
        for (var f = 0; f < 60; f++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('YOUR RUN'), findsOneWidget);
        expect(find.text('3 of 4 boosts spent.'), findsOneWidget);

        await tester.tap(find.text('LEAVE'));
        await tester.pumpAndSettle();
        expect(outcome?.place, paidFor);
      },
    );
  }

  testWidgets('the Trials show the cups, the race and the party', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: StadiumScreen(party: [_member('Ember', 'Fire', 'mane')]),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('THE TRIALS'), findsOneWidget);
    expect(find.text('OPEN TRACK'), findsOneWidget);
    expect(find.text('COPPER CUP · RACE 1 OF 3 · THE ARENA'), findsOneWidget);
    // Rain and Ember wait on Open.
    expect(find.text('LOCKED'), findsNWidgets(2));
    expect(find.text('Ember'), findsOneWidget);
    expect(find.text('RACE'), findsOneWidget);

    // The Gold cup can be looked at, not raced.
    await tester.tapAt(
      tester.getTopLeft(find.byType(CupShelf)) +
          Offset(tester.getSize(find.byType(CupShelf)).width * .88, 60),
    );
    // The light passes to it; its races come up as it does.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('LONG TRACK'), findsOneWidget);
    expect(find.text('GOLD CUP · RACE 1 OF 3 · HILLS'), findsOneWidget);
    expect(find.text('RACE'), findsNothing);
    // Its three races and the button.
    expect(find.text('LOCKED'), findsNWidgets(4));
  });

  testWidgets('a won race opens the next, and the shelf opens on it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      RaceProgress.prefsKey: '{"copper":3,"silver":1}',
    });
    // The folded Fold's cover screen, upright.
    tester.view.physicalSize = const Size(475, 751);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: StadiumScreen(party: [_member('Ember', 'Fire', 'mane')]),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('HILL TRACK'), findsOneWidget);
    expect(find.text('SILVER CUP · RACE 2 OF 3 · HILLS'), findsOneWidget);
    expect(find.text('WON'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
  });
}
