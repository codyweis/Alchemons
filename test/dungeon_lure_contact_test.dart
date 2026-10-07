// A LURE THAT HURTS WHAT IT PROTECTS IS NO LURE.
//
// Taunt beacons (Pip Crystal shards, Horn fire trails, Kin sigils, decoys)
// hijack an enemy's steering, and steering reports an impact on reaching
// whatever it was steering at. Until 2026-10-07 that impact still billed the
// creature the enemy had been chasing, wherever it stood: a wisp diving into
// a shard 250 units away took 59 of its 639 health. Survival's rule is that
// damage needs a body — so a field arrival lands on a creature only if one is
// inside the enemy's reach, and a decoy arrival lands on nobody.

import 'dart:math' show Random;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final m = CosmicPartyMember(
    instanceId: 'inst_0',
    baseId: 'base_0',
    displayName: 'Air wing',
    element: 'Air',
    family: 'wing',
    level: 10,
    statSpeed: 3,
    statIntelligence: 3,
    statStrength: 3,
    statBeauty: 3,
    slotIndex: 0,
    staminaBars: 3,
    staminaMax: 3,
  );
  final g = PlanetDungeonGame(
    element: 'Air',
    party: [m],
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final at = g.layout.entranceSpawn;
  g.creatures.add(
    DungeonCreature(member: m)
      ..position = at
      ..lastSafe = at,
  );
  g.combatCompanions.add(g.debugCreateCombatCompanion(m, at));
  return g;
}

/// One wisp at [at], mid-dive at the party's only creature.
void _diver(PlanetDungeonGame g, Offset at) {
  g.spawnWispWave(element: 'Air', center: at, count: 1, announce: false);
  final e = g.combatEnemies.single;
  e.position = at;
  e.hp = 1e9;
  e.flightSteering = FlightSteeringState(Random(1))
    ..diving = true
    ..diveTimer = 1
    ..targetIndex = 0
    ..retargetTimer = 10;
}

Projectile _beacon(Offset at, {bool decoy = false}) => Projectile(
  position: at,
  angle: 0,
  damage: 0,
  life: 10,
  stationary: true,
  piercing: true,
  tauntRadius: 500,
  tauntStrength: 10,
  decoy: decoy,
  decoyHp: decoy ? 1000 : 0,
);

/// Health the creature loses over [frames].
int _lost(PlanetDungeonGame g, {int frames = 1}) {
  final comp = g.combatCompanions.first;
  final before = comp.currentHp;
  for (var i = 0; i < frames; i++) {
    g.update(1 / 60);
  }
  return before - comp.currentHp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a dive into a distant taunt field costs the creature nothing', () {
    final g = _game();
    final lure = g.creatures.first.position + const Offset(250, 0);
    _diver(g, lure);
    g.combatProjectiles.add(_beacon(lure));
    expect(_lost(g, frames: 30), 0);
  });

  test('a dive into a decoy costs the creature nothing; the decoy pays', () {
    final g = _game();
    final lure = g.creatures.first.position + const Offset(250, 0);
    _diver(g, lure);
    final decoy = _beacon(lure, decoy: true);
    g.combatProjectiles.add(decoy);
    expect(_lost(g, frames: 30), 0);
    expect(decoy.decoyHp, lessThan(1000), reason: 'the decoy soaks the grind');
  });

  test('with no lure, a dive that reaches the creature still lands', () {
    final g = _game();
    _diver(g, g.creatures.first.position);
    expect(_lost(g), greaterThan(0));
  });

  test('a creature standing in its own field is still within reach', () {
    // A field redirects steering; it is not armour. A wisp pulled onto a
    // creature that is standing in the field reaches a body, and bites it.
    final g = _game();
    final here = g.creatures.first.position;
    _diver(g, here);
    g.combatProjectiles.add(_beacon(here));
    expect(_lost(g), greaterThan(0));
  });
}
