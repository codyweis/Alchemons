// DEFENCE TAKES THE EDGE OFF A DUNGEON HIT.
//
// Dungeon hits are a fraction of the victim's pool, and until 2026-10-07 that
// fraction ignored P-DEF and E-DEF entirely: the combat audit measured the
// same 59 off a body with 0 defence and with 999. It also found a guardian's
// contact hit pinned at its one-fifth ceiling from the second dungeon on, so
// the campaign's advertised damage curve never reached a body.

import 'dart:math' show Random;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:flame/game.dart' show Vector2;
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

/// A raid on [element] with one Alchemon whose E-DEF is [elemDef], the
/// guardian landed. Its combat body is held invincible, so dives, contact
/// and the squad hit never reach it: only what writes the creature's own
/// health (the attacks under test) does. A raid runs no campaign clock, so
/// what lands is the authored figure times the trim.
PlanetDungeonGame _raidOf(String element, int elemDef) {
  final m = _member();
  final g = PlanetDungeonGame(
    element: element,
    party: [m],
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    raid: const RaidConfig(level: 1),
    onRaidCleared: () async {},
    layoutOverride: buildRaidArenaLayout(element),
  );
  g.onGameResize(Vector2(412, 915));
  g.currentRoomId = g.layout.entranceRoomId;
  final at = g.layout.entranceSpawn;
  g.creatures.add(
    DungeonCreature(member: m)
      ..position = at
      ..lastSafe = at,
  );
  g.combatCompanions.add(
    g.debugCreateCombatCompanion(m, at)..elemDef = elemDef,
  );
  for (var i = 0; i < 60 * 4 && _boss(g) == null; i++) {
    g.update(1 / 60);
  }
  expect(_boss(g), isNotNull);
  return g;
}

dynamic _boss(PlanetDungeonGame g) =>
    g.combatEnemies.where((e) => e.isElite).firstOrNull;

/// Health a second the creature loses over [frames] frames in which [stand]
/// put it in the way of the attack (frames where it returns false are run
/// but not counted), at [fps].
double _lossPerSecond(
  PlanetDungeonGame g,
  bool Function(DungeonCreature c) stand, {
  int frames = 60,
  int fps = 60,
}) {
  final c = g.creatures.single;
  var lost = 0.0;
  var counted = 0;
  for (var f = 0; f < fps * 60 && counted < frames; f++) {
    g.combatCompanions.single.invincibleTimer = 999;
    c.hp = c.maxHp;
    final counts = stand(c);
    final before = c.hp;
    g.update(1 / fps);
    if (!counts) continue;
    lost += before - c.hp;
    counted++;
  }
  expect(counted, frames, reason: 'never stood in it long enough');
  return lost / counted * fps;
}

/// The guardian's rage aura: 60 px off it while it is shut.
double _auraLoss(int elemDef, {int fps = 60}) {
  final g = _raidOf('Earth', elemDef);
  return _lossPerSecond(fps: fps, g, (c) {
    final boss = _boss(g);
    final at = (boss.position as Offset) + const Offset(0, 60);
    c
      ..position = at
      ..lastSafe = at;
    return !g.guardianVulnerable;
  });
}

/// Simurgh's pillars: standing in one that is burning, well clear of the
/// guardian's aura.
double _pillarLoss(int elemDef, {int fps = 60}) {
  final g = _raidOf('Fire', elemDef);
  final room = g.currentRoom;
  final spots = g.simurghTelegraphSpots(room);
  final park = room.bounds.bottomLeft + const Offset(60, -60);
  return _lossPerSecond(fps: fps, g, (c) {
    final boss = _boss(g).position as Offset;
    for (final e in g.simurghPillars.entries) {
      if (e.value < 0.66 || e.value > 0.95) continue;
      final at = spots[g.riteBrazierAt(e.key)];
      if ((at - boss).distance < 160) continue;
      c
        ..position = at
        ..lastSafe = at;
      return true;
    }
    c
      ..position = park
      ..lastSafe = park;
    return false;
  });
}

/// Solarin's light: bare glass it reaches, with its swing and bolts held.
double _burnLoss(int elemDef, {int fps = 60}) {
  final g = _raidOf('Light', elemDef);
  g.archive
    ..swingNext = 999
    ..boltNext = 999;
  final def = g.currentRoom.hall!.def!;
  // The body played is named Light on the floor (its element is not one of
  // the three names); find glass its light reaches.
  final s = g.archive.state(def.id);
  Offset? lit;
  for (var y = 0; y < def.rows && lit == null; y++) {
    for (var x = 3; x < def.cols && lit == null; x++) {
      if (def.at(x, y) != '~') continue;
      if (shadowSolarinBurns(def, s.moved('Light', sq(x, y)), 'Light')) {
        lit = shadowCentre(x, y);
      }
    }
  }
  expect(lit, isNotNull);
  return _lossPerSecond(fps: fps, g, (c) {
    c
      ..position = lit!
      ..lastSafe = lit;
    return true;
  }, frames: 30);
}

/// One of Solarin's bolts, at the vent island (stone, so its light does not
/// burn there, and nothing stands between it and Solarin).
double _boltLoss(int elemDef) {
  final g = _raidOf('Light', elemDef);
  final c = g.creatures.single;
  final vent = shadowCentre(12, 2);
  g.archive
    ..swingNext = 999
    ..boltNext = 0;
  var worst = 0.0;
  for (var f = 0; f < 180; f++) {
    g.combatCompanions.single.invincibleTimer = 999;
    c
      ..position = vent
      ..lastSafe = vent
      ..hp = c.maxHp;
    if (f > 0) g.archive.boltNext = 999;
    g.update(1 / 60);
    final lost = c.maxHp - c.hp;
    if (lost > worst) worst = lost;
  }
  return worst;
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

  // A guardian's own attacks that take a flat share of the 100-point pool
  // (2026-10-07, combat follow-ups Phase 2). A fresh level-1 body (E-DEF at
  // the reference, 35) takes the authored figure; more E-DEF takes less;
  // nothing takes less than 60% of it.
  group("a guardian's own attacks are trimmed by E-DEF", () {
    for (final (name, loss, authored)
        in <(String, double Function(int), double)>[
          ('the rage aura', _auraLoss, 28.0),
          ("Simurgh's pillars", _pillarLoss, 5.5),
          ("Solarin's light", _burnLoss, kSolarinBurnDps),
          ("Solarin's bolts", _boltLoss, kSolarinBoltDamage),
        ]) {
      test(name, () {
        final fresh = loss(PlanetDungeonGame.kDefenseReference.round());
        final mid = loss(150);
        final armoured = loss(999);
        expect(fresh, closeTo(authored, authored * 0.02));
        expect(mid, lessThan(fresh));
        expect(armoured, lessThan(mid));
        expect(armoured, closeTo(authored * 0.6, authored * 0.02));
      });
    }

    test('the same a second at 60 and 120 fps', () {
      for (final (name, loss) in <(String, double Function(int, {int fps}))>[
        ('the rage aura', _auraLoss),
        ("Simurgh's pillars", _pillarLoss),
        ("Solarin's light", _burnLoss),
      ]) {
        final at60 = loss(150);
        final at120 = loss(150, fps: 120);
        expect(at120, closeTo(at60, at60 * 0.02), reason: name);
      }
    });
  });
}
