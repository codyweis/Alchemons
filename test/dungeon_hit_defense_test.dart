// DEFENCE TAKES THE EDGE OFF A DUNGEON HIT.
//
// Dungeon hits are a fraction of the victim's pool, and until 2026-10-07 that
// fraction ignored P-DEF and E-DEF entirely: the combat audit measured the
// same 59 off a body with 0 defence and with 999. It also found a guardian's
// contact hit pinned at its one-fifth ceiling from the second dungeon on, so
// the campaign's advertised damage curve never reached a body.

import 'dart:math' show Random;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member() => CosmicPartyMember(
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

PlanetDungeonGame _game({int cleared = 0, int? physDef}) {
  final m = _member();
  final g = PlanetDungeonGame(
    element: 'Air',
    party: [m],
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    clearedGuardianCount: cleared,
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final at = g.layout.entranceSpawn;
  g.creatures.add(
    DungeonCreature(member: m)
      ..position = at
      ..lastSafe = at,
  );
  final comp = g.debugCreateCombatCompanion(m, at);
  if (physDef != null) comp.physDef = physDef;
  g.combatCompanions.add(comp);
  return g;
}

/// One wisp dive that reaches the creature. Returns the health it took.
int _wispDive(PlanetDungeonGame g) {
  final c = g.creatures.first;
  g.spawnWispWave(
    element: 'Air',
    center: c.position,
    count: 1,
    announce: false,
  );
  final e = g.combatEnemies.single;
  e.position = c.position;
  e.hp = 1e9;
  e.flightSteering = FlightSteeringState(Random(1))
    ..diving = true
    ..diveTimer = 1
    ..targetIndex = 0
    ..retargetTimer = 10;
  final comp = g.combatCompanions.first;
  final before = comp.currentHp;
  g.update(1 / 60);
  return before - comp.currentHp;
}

/// The guardian's first contact hit, as a fraction of the victim's pool.
/// It is held on the creature mid-dive until a frame lands one (it does not
/// steer on the frame it lands, nor while perched in a lull).
double _guardianHit(int cleared) {
  final g = _game(cleared: cleared, physDef: 0);
  g.debugSpawnGuardian();
  final comp = g.combatCompanions.first;
  final c = g.creatures.first;
  for (var f = 0; f < 60 * 30; f++) {
    comp
      ..currentHp = comp.maxHp
      ..shieldHp = 0
      ..invincibleTimer = 0;
    c.hp = c.maxHp;
    final boss = g.combatEnemies.where((e) => e.isElite).firstOrNull;
    if (boss != null) {
      boss
        ..position = c.position
        ..attackCooldown = 0;
      boss.flightSteering = FlightSteeringState(Random(1))
        ..diving = true
        ..diveTimer = 1
        ..targetIndex = 0
        ..retargetTimer = 10;
    }
    g.update(1 / 60);
    if (boss != null && comp.currentHp < comp.maxHp) {
      return (comp.maxHp - comp.currentHp) / comp.maxHp;
    }
  }
  fail('the guardian never landed a hit');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the mitigation curve', () {
    test('a fresh level-1 body takes the authored fraction', () {
      expect(
        PlanetDungeonGame.defenseMitigation(
          PlanetDungeonGame.kDefenseReference.round(),
        ),
        closeTo(1.0, 0.001),
      );
    });

    test('it only ever reduces: no defence is not a penalty', () {
      expect(PlanetDungeonGame.defenseMitigation(0), 1.0);
    });

    test('a mid level-10 team takes about a fifth less', () {
      // physDef ≈ 84 (Pip) … 137 (Horn) at level 10, stat 3.
      expect(PlanetDungeonGame.defenseMitigation(110), closeTo(0.81, 0.02));
    });

    test('nothing takes less than 60% of the hit', () {
      expect(PlanetDungeonGame.defenseMitigation(999), 0.6);
    });
  });

  test('defence trims a wisp dive (the audit repro, now inverted)', () {
    final bare = _wispDive(_game(physDef: 0));
    final armoured = _wispDive(_game(physDef: 999));
    expect(bare, greaterThan(0));
    expect(armoured, lessThan(bare));
    expect(armoured / bare, closeTo(0.6, 0.03));
  });

  test("a guardian's contact hit climbs with the campaign", () {
    final first = _guardianHit(0);
    final eighth = _guardianHit(8);
    expect(first, closeTo(0.19, 0.02), reason: 'unchanged on a fresh save');
    expect(
      eighth,
      greaterThan(first + 0.05),
      reason: 'it used to sit at the 0.20 ceiling from the second dungeon on',
    );
    // 0.30 contact ceiling, plus whatever the rage aura ticks that frame.
    expect(eighth, lessThan(0.35), reason: 'never a one-shot');
  });
}
