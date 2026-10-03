// A HOME PLACED INSIDE A PULL STAYS WHERE IT WAS PUT.
//
// A home built within 1.5× a planet's field is captured and orbits it. The
// orbit used to be taken at the field's edge, so on the first frame the home
// snapped inward by hundreds of units and looked as if the placement had
// failed; and when the home was the heavier body the planet went round it
// from the wrong side, teleporting across.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CosmicGame game;

  Future<void> boot() async {
    game = CosmicGame(
      world_: CosmicWorld.generate(seed: 1),
      onMeterChanged: () {},
    );
    await game.onLoad();
    game.onGameResize(Vector2(915, 412));
  }

  void tick(int frames) {
    for (var i = 0; i < frames; i++) {
      game.update(1 / 60);
    }
  }

  /// A spot [factor]× the planet's field out from it, in a direction that
  /// is clear of every other planet's pull.
  Offset spotNear(CosmicPlanet p, double factor) {
    for (var k = 0; k < 16; k++) {
      final a = k * pi / 8;
      final at =
          p.position +
          Offset(cos(a), sin(a)) * (p.particleFieldRadius * factor);
      if (game.homeCaptureAt(at) == p) return at;
    }
    fail('no clear spot round ${p.element}');
  }

  testWidgets('a captured home starts where it was placed and keeps that '
      'radius', (tester) async {
    await tester.runAsync(() async {
      await boot();
      // The largest planet, so a small home is the lighter body.
      final planet = game.world_.planets.reduce(
        (a, b) => a.radius > b.radius ? a : b,
      );
      final placed = spotNear(planet, 1.2);
      expect(game.homePlacementBlockerAt(placed), isNull);

      game.teleportTo(placed);
      expect(game.buildHomePlanet(), isNull);
      expect(game.homeOrbitPartner, planet);
      expect(game.homeOrbitsPartner, isTrue);

      final planetAt = planet.position;
      tick(1);
      final home = game.homePlanet!;
      expect(
        (home.position - placed).distance,
        lessThan(5),
        reason: 'no snap on the first frame',
      );
      final radius = (placed - planetAt).distance;
      expect(game.homeOrbitRadius, closeTo(radius, 0.01));

      // It does go round, at the radius it was placed at.
      tick(600);
      expect((home.position - placed).distance, greaterThan(20));
      expect((home.position - planet.position).distance, closeTo(radius, 0.5));

      // Save and restore: same radius, no jump.
      final saved = HomePlanet.deserialise(home.serialise());
      final before = home.position;
      game.homePlanet = null;
      game.restoreHomePlanet(saved);
      tick(1);
      expect(game.homeOrbitRadius, closeTo(radius, 0.5));
      expect((game.homePlanet!.position - before).distance, lessThan(5));
    });
  });

  testWidgets('a home heavier than its planet does not teleport the planet', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await boot();
      final planet = game.world_.planets.reduce(
        (a, b) => a.radius < b.radius ? a : b,
      );
      final placed = spotNear(planet, 1.3);
      game.restoreHomePlanet(
        HomePlanet(position: placed, sizeTierLevel: 4, activeSizeTier: 4),
      );
      expect(game.homePlanet!.visualRadius, greaterThan(planet.radius));
      expect(game.homeOrbitPartner, planet);
      expect(game.homeOrbitsPartner, isFalse);

      final start = planet.position;
      tick(1);
      expect(
        (planet.position - start).distance,
        lessThan(5),
        reason: 'the planet must not jump across the home',
      );
      expect((game.homePlanet!.position - placed).distance, lessThan(0.01));
      final radius = (start - placed).distance;
      tick(600);
      expect((planet.position - start).distance, greaterThan(20));
      expect(
        (planet.position - placed).distance,
        closeTo(radius, 0.5),
        reason: 'it circles the home at the distance it stood at',
      );
    });
  });

  testWidgets('outside every pull nothing is captured', (tester) async {
    await tester.runAsync(() async {
      await boot();
      final planet = game.world_.planets.first;
      final inside = spotNear(planet, 1.2);
      expect(game.homeCaptureAt(inside), planet);
      final tooClose =
          planet.position + Offset(planet.particleFieldRadius * 0.5, 0);
      expect(game.homeCaptureAt(tooClose), isNull);
      expect(game.homePlacementBlockerAt(tooClose), planet);
    });
  });
}
