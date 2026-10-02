import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/screens/cosmic/wild_space_encounter_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/grain_assembly.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The ally picked in a space encounter gathers out of grains of itself, as a
// party Alchemon does in the field. It used to step out of a summon tear.
// While its grains are read it is drawn too faintly to see — this checks
// that it still says when it has drawn, and still reads whole.
void main() {
  testWidgets('a veiled ally says it has drawn and reads into grains', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(915, 412) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final catalog = CreatureCatalog();
    await tester.runAsync(catalog.load);
    final wild = catalog.creatures.firstWhere(
      (c) => c.types.contains('Fire') && c.mutationFamily == 'Wing',
    );
    final ally = catalog.creatures.firstWhere(
      (c) => c.types.contains('Lightning') && c.mutationFamily == 'Let',
    );

    final allyKey = GlobalKey();
    var drawn = 0;
    Widget backdrop({
      bool veiled = false,
      GrainAssembly? grains,
      double summon = 1,
    }) => MaterialApp(
      home: WildSpaceBackdrop(
        creature: wild,
        backdrop: const CosmicEncounterBackdrop(),
        partyCreature: ally,
        allyCaptureKey: allyKey,
        allyVeiled: veiled,
        allyGrains: grains,
        allySummon: AlwaysStoppedAnimation(summon),
        onAllyDrawn: () => drawn++,
      ),
    );

    await tester.pumpWidget(backdrop(veiled: true, summon: 0));
    for (var i = 0; i < 20 && drawn == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(drawn, greaterThan(0), reason: 'the ally never said it had drawn');

    // Read as the screen reads it: through the veil, whole.
    final boundary =
        allyKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final grains = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        return SpecimenGrains.fromRgba(
          data!.buffer.asUint8List(),
          image.width,
          image.height,
          pixelRatio: 2,
          tones: 16,
        );
      } finally {
        image.dispose();
      }
    });
    expect(grains!.length, greaterThan(200));

    // Gathering, then whole.
    final assembly = GrainAssembly(grains, accent: Colors.yellow);
    for (final t in const [0.0, 0.3, 0.6, 0.9, 1.0]) {
      await tester.pumpWidget(backdrop(grains: assembly, summon: t));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
