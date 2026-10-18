// A tap in space on a Works building finds it: each home building by its
// berth round home, an extractor by its rig, and nothing in open space.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/works.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a tap finds the Works building under it', (tester) async {
    late CosmicGame game;
    await tester.runAsync(() async {
      game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await game.onLoad();
      game.onGameResize(Vector2(915, 412));
      for (final p in game.world_.planets) {
        p.discovered = true;
      }
      final fire = game.world_.planets.firstWhere((p) => p.element == 'Fire');
      game.restoreHomePlanet(
        HomePlanet(
          position: fire.position + const Offset(1900, 700),
          activeColor: 'Water',
          sizeTierLevel: 2,
          activeSizeTier: 2,
        ),
      );
      game.works = WorksState(
        extractors: {'Fire': ExtractorState(element: 'Fire', updatedMs: 0)},
        bay: ScavengerBayState(tier: 1, berth: 0),
        press: SilverPressState(tier: 1, berth: 1),
        refinery: RefineryState(tier: 1, berth: 2),
        armory: ArmoryState(tier: 1, berth: 3),
      );
      game.teleportTo(game.homePlanet!.position);
    });

    Offset screenOf(Offset world) {
      final z = game.cameraZoom;
      return Offset((world.dx - game.camX) * z, (world.dy - game.camY) * z);
    }

    for (final (b, berth) in [
      (WorksBuilding.scavengerBay, 0),
      (WorksBuilding.silverPress, 1),
      (WorksBuilding.refinery, 2),
      (WorksBuilding.armory, 3),
    ]) {
      expect(
        game.worksHitAt(screenOf(game.berthPos(berth)!)),
        (b, null),
        reason: b.name,
      );
    }

    // Open space between home and its ring holds nothing to open.
    final home = game.homePlanet!.position;
    expect(
      game.worksHitAt(screenOf(home + const Offset(0, -40))),
      isNull,
    );

    // The rig stands up from its foot: a tap there finds the extractor.
    game.teleportTo(game.extractorRigPos('Fire')!);
    expect(
      game.worksHitAt(screenOf(game.extractorRigPos('Fire')!)),
      (WorksBuilding.extractor, 'Fire'),
    );
  });
}
