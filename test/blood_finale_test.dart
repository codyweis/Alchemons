import 'dart:typed_data';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/story/blood_finale.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small square of grains in one colour: a species, for the census.
SpecimenGrains _square(Color colour, {double side = 40}) {
  final xs = <double>[], ys = <double>[];
  for (var y = -side / 2; y < side / 2; y += 2) {
    for (var x = -side / 2; x < side / 2; x += 2) {
      xs.add(x);
      ys.add(y);
    }
  }
  return SpecimenGrains.points(
    Float32List.fromList(xs),
    Float32List.fromList(ys),
    Uint8List(xs.length),
    [colour],
    2,
  );
}

void main() {
  testWidgets(
    'the finale: each line waits for a tap, the census passes, it ends',
    (tester) async {
      tester.view.physicalSize = const Size(900, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});

      final offering = CosmicPartyMember(
        instanceId: 'offering',
        baseId: 'HOR03',
        displayName: 'Earthhorn',
        element: 'Earth',
        family: 'horn',
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: 0,
        staminaBars: 3,
        staminaMax: 3,
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('home'))),
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<bool>(
              builder: (_) => BloodFinalePage(
                offering: offering,
                census: [
                  CensusEntry(_square(const Color(0xFF55AA55)), 'Plant'),
                  CensusEntry(_square(const Color(0xFF5577DD)), 'Water'),
                  CensusEntry(_square(const Color(0xFFDD6633)), 'Fire'),
                ],
                offeringGrains: _square(const Color(0xFF997755), side: 120),
                portrait: (size) => const SizedBox(),
              ),
            ),
          );
      // A frame at a time: the finale steps at most 1/20 s a frame.
      Future<void> run(double seconds) async {
        for (var t = 0.0; t < seconds; t += 0.05) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      Future<void> tap() => tester.tapAt(const Offset(450, 210));

      Future<void> read(String line) async {
        expect(find.text(line), findsOneWidget);
        // Waits however long it is left.
        await run(6);
        expect(find.text(line), findsOneWidget);
        await tap();
      }

      // It gathers out of the ring's light; then its line.
      await run(3.5);
      await read('Every collection has a favorite.');
      // Sacrificed: it drips away into a pool of blood; a new one rises.
      await run(10);
      await read('Alchemy is power.');
      await run(1);
      await read('Favorites can always become stronger.');
      // It drips away, sent below; the census passes with the credits; the
      // vial it was sent to comes last.
      await run(14);
      expect(find.text('Cody Weisenberger'), findsOneWidget);
      // The credits play out before the vial comes, however small the
      // census.
      await run(32);
      await read('The census is finished. The collector is not.');
      await run(0.6);
      expect(find.text('Thank you for playing.'), findsOneWidget);
      expect(find.text('RETURN'), findsOneWidget);
      await run(1.2);
      await tap();
      await run(2);
      expect(find.byType(BloodFinalePage), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
