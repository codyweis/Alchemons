// The ambient crowd around a ship that sits still in open space.
//
// Stalkers spawn around the ship and hold a set distance from it, and were
// only ever despawned for being far from the ship — so a parked ship
// collected them without limit (3 on screen after a minute, 30–60 after
// eight). They are now capped at two groups and lose interest after a while.
//
// PARKED_CROWD_TRACE=1 prints the crowd by behaviour every 30 s.

import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

const _screenW = 412.0;
const _screenH = 915.0;

Future<CosmicGame> _parked() async {
  final game = CosmicGame(
    world_: CosmicWorld.generate(seed: 37),
    onMeterChanged: () {},
  );
  game.ship = ShipComponent(pos: Offset.zero);
  game.onGameResize(Vector2(_screenW, _screenH));
  await game.onLoad();

  // Deep space, away from home (where everything spawns as a drifter).
  final world = game.world_;
  Offset spot = Offset.zero;
  var best = -1.0;
  for (var gx = 1; gx < 20; gx++) {
    for (var gy = 1; gy < 20; gy++) {
      final p = Offset(
        world.worldSize.width * gx / 20,
        world.worldSize.height * gy / 20,
      );
      var nearest = double.infinity;
      for (final planet in world.planets) {
        nearest = min(nearest, (planet.position - p).distance);
      }
      if (nearest > best && !game.isHomeRecoveryArea(p)) {
        best = nearest;
        spot = p;
      }
    }
  }
  game.teleportTo(spot);
  game.enemies.clear();
  game.activeBoss = null;
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a parked ship does not collect a crowd of stalkers', () async {
    final game = await _parked();
    final trace = Platform.environment['PARKED_CROWD_TRACE'] != null;
    const dt = 1 / 60;
    final viewR = sqrt(
          pow(_screenW / game.cameraZoom, 2) +
              pow(_screenH / game.cameraZoom, 2),
        ) /
        2;

    final stalkingSince = <CosmicEnemy, double>{};
    var longestStalk = 0.0;
    var mostStalkers = 0;
    var lateOnScreen = 0;
    var lateSamples = 0;

    for (var s = 1; s <= 480; s++) {
      for (var f = 0; f < 60; f++) {
        // Full health throughout: a stalker strikes a wounded ship, which is
        // not what is measured here.
        game.shipHealth = CosmicGame.shipMaxHealth;
        game.activeBoss = null;
        game.update(dt);
      }
      final now = s.toDouble();
      var stalkers = 0;
      var onScreen = 0;
      final byBehaviour = <String, int>{};
      for (final e in game.enemies) {
        if (e.dead) continue;
        if (e.behavior == EnemyBehavior.stalking) {
          stalkers++;
          stalkingSince.putIfAbsent(e, () => now);
        } else if (stalkingSince.containsKey(e)) {
          longestStalk = max(longestStalk, now - stalkingSince.remove(e)!);
        }
        if ((e.position - game.ship.pos).distance < viewR) {
          onScreen++;
          byBehaviour[e.behavior.name] =
              (byBehaviour[e.behavior.name] ?? 0) + 1;
        }
      }
      for (final e in stalkingSince.keys) {
        longestStalk = max(longestStalk, now - stalkingSince[e]!);
      }
      stalkingSince.removeWhere((e, _) => !game.enemies.contains(e));
      mostStalkers = max(mostStalkers, stalkers);
      if (s > 240) {
        lateOnScreen += onScreen;
        lateSamples++;
      }
      if (trace && s % 30 == 0) {
        // ignore: avoid_print
        print('t=${s}s onScreen=$onScreen stalkers=$stalkers $byBehaviour');
      }
    }

    // Two groups, a wisp flock at most five.
    expect(mostStalkers, lessThanOrEqualTo(10));
    // Patience is 35–60 s; a little slack for the sampling.
    expect(longestStalk, lessThanOrEqualTo(63));
    // Before the fix the second four minutes averaged 30–55 on screen.
    expect(lateOnScreen / lateSamples, lessThan(18));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
