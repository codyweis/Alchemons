import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The star chart's TRAVEL: a flight, not a hop. The ship may only be carried
// across while space is fully dark round it, and it must arrive in the
// planet's idle orbit flying along it, so the orbit takes over without a
// turn or a jump.
void main() {
  late CosmicGame game;

  Offset wrapped(Offset a, Offset b) {
    final w = game.world_.worldSize.width, h = game.world_.worldSize.height;
    var dx = a.dx - b.dx, dy = a.dy - b.dy;
    if (dx > w / 2) dx -= w;
    if (dx < -w / 2) dx += w;
    if (dy > h / 2) dy -= h;
    if (dy < -h / 2) dy += h;
    return Offset(dx, dy);
  }

  setUp(() async {
    game = CosmicGame(
      world_: CosmicWorld.generate(seed: 1),
      onMeterChanged: () {},
    );
    await game.onLoad();
    game.onGameResize(Vector2(390, 844));
    for (final p in game.world_.planets) {
      p.discovered = true;
    }
  });

  test('flies to a planet and into its orbit, jumping only in the dark', () {
    final planet = game.world_.planets[2];
    game.teleportTo(
      Offset(
        (planet.position.dx + 9000) % game.world_.worldSize.width,
        (planet.position.dy + 5000) % game.world_.worldSize.height,
      ),
    );
    game.ship.angle = 0.6;
    game.update(1 / 60);
    game.travelTo(planet.position, orbitRadius: planet.radius * 2.0);
    expect(game.isTravelling, isTrue);

    var last = game.ship.pos;
    var jumps = 0;
    for (var i = 0; i < 60 * 4 && game.isTravelling; i++) {
      game.update(1 / 60);
      final step = wrapped(game.ship.pos, last).distance;
      last = game.ship.pos;
      if (step > 200) {
        jumps++;
        expect(game.travelVeil, 1.0, reason: 'a jump must happen in the dark');
      } else {
        // Flying: never faster than the flight's top speed.
        expect(step, lessThan(2400 / 60 + 1));
      }
    }
    expect(game.isTravelling, isFalse);
    expect(jumps, 1);

    // In the orbit, at its radius, flying along it.
    final toCentre = wrapped(planet.position, game.ship.pos);
    expect(toCentre.distance, closeTo(planet.radius * 2.0, 1));
    final dir = toCentre / toCentre.distance;
    final tangent = atan2(dir.dx, -dir.dy);
    final dh = atan2(
      sin(game.ship.angle - tangent),
      cos(game.ship.angle - tangent),
    );
    expect(dh.abs(), lessThan(1e-6));

    // The idle orbit takes over gently from there.
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
      final step = wrapped(game.ship.pos, last).distance;
      last = game.ship.pos;
      expect(step, lessThan(6));
    }
  });
}
