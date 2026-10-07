// THE RAID GUARDIAN'S SQUAD HIT. (A dungeon's own guardian fight has a
// lighter one: dungeon_squad_hit_test.dart.)
//
// Dives take one body at a time and the rage aura only the one you play, so
// a raid ground down its front line and never touched the rest. On a steady
// beat the guardian now gathers grains (the telegraph) and sends them out
// through the arena: every living Alchemon takes a share of its own health,
// trimmed by E-DEF, shields first. See docs/plans/raid_threat_plan.md.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/raid_pulse_fx.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot) => CosmicPartyMember(
  instanceId: 'r$slot',
  baseId: 'b$slot',
  displayName: 'Test $slot',
  element: 'Fire',
  family: 'wing',
  level: 10,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: slot,
  staminaBars: 3,
  staminaMax: 3,
);

PlanetDungeonGame _raid({int level = 1, int squad = 5}) {
  final members = [for (var i = 0; i < squad; i++) _member(i)];
  final g = PlanetDungeonGame(
    element: 'Air',
    party: members,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    raid: RaidConfig(level: level),
    onRaidCleared: () async {},
    layoutOverride: buildRaidArenaLayout('Air'),
  );
  g.onGameResize(Vector2(412, 915));
  g.currentRoomId = g.layout.entranceRoomId;
  final spawn = g.layout.entranceSpawn;
  for (var i = 0; i < members.length; i++) {
    final at = spawn + Offset((i - 2) * 50.0, 0);
    g.creatures.add(
      DungeonCreature(member: members[i])
        ..position = at
        ..lastSafe = at,
    );
    g.combatCompanions.add(g.debugCreateCombatCompanion(members[i], at));
  }
  // Play the arrival out: the guardian's combat body exists only once it
  // has landed, and the beat starts from there.
  for (var i = 0; i < 60 * 4; i++) {
    if (g.combatEnemies.any((e) => e.isElite)) break;
    g.update(1 / 60);
  }
  expect(g.combatEnemies.any((e) => e.isElite), isTrue);
  return g;
}

/// Runs the squad hit alone (no dives, no aura) until [hits] have landed.
void _tickToHit(PlanetDungeonGame g, {int hits = 1, int fps = 60}) {
  final target = g.squadHitsLanded + hits;
  for (var i = 0; i < 60 * fps && g.squadHitsLanded < target; i++) {
    g.debugTickSquadHit(1 / fps);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('it is wired into the raid tick, on the tier beat', () {
    final g = _raid();
    final interval = const RaidConfig(level: 1).squadHitInterval;
    var t = 0.0;
    while (t < interval - 0.2) {
      g.update(1 / 60);
      t += 1 / 60;
    }
    expect(g.squadHitsLanded, 0);
    while (t < interval + 0.2) {
      g.update(1 / 60);
      t += 1 / 60;
    }
    expect(g.squadHitsLanded, 1);
  });

  test('the grains gather for the telegraph before it lands', () {
    final g = _raid();
    final interval = const RaidConfig(level: 1).squadHitInterval;
    var t = 0.0;
    while (t < interval - RaidPulseFx.telegraph - 0.1) {
      g.debugTickSquadHit(1 / 60);
      t += 1 / 60;
    }
    expect(g.squadHitGathering, isFalse);
    while (t < interval - 0.1) {
      g.debugTickSquadHit(1 / 60);
      t += 1 / 60;
    }
    expect(g.squadHitGathering, isTrue);
    expect(g.squadHitsLanded, 0);
  });

  test('it lands on every living Alchemon, and skips the fallen', () {
    final g = _raid();
    g.creatures[3].hp = 0;
    g.combatCompanions[3]
      ..currentHp = 0
      ..isDead = true;
    final before = [for (final c in g.combatCompanions) c.currentHp];
    _tickToHit(g);
    for (var i = 0; i < g.combatCompanions.length; i++) {
      final c = g.combatCompanions[i];
      final expected = (c.maxHp *
              const RaidConfig(level: 1).squadHitFraction *
              PlanetDungeonGame.defenseMitigation(c.elemDef))
          .round();
      expect(
        before[i] - c.currentHp,
        i == 3 ? 0 : expected,
        reason: 'slot $i',
      );
    }
  });

  test('every tier hits the same share; the last tier hits more often', () {
    int taken(int level) {
      final g = _raid(level: level);
      final c = g.combatCompanions.first;
      final before = c.currentHp;
      _tickToHit(g);
      return before - c.currentHp;
    }

    int landedIn(int level, double seconds) {
      final g = _raid(level: level);
      for (var i = 0; i < seconds * 60; i++) {
        g.debugTickSquadHit(1 / 60);
      }
      return g.squadHitsLanded;
    }

    expect(taken(3), taken(1));
    expect(landedIn(3, 56), greaterThan(landedIn(1, 56)));
  });

  test('E-DEF trims it', () {
    final g = _raid();
    g.combatCompanions[0].elemDef = 0;
    g.combatCompanions[1].elemDef = 400;
    final before = [for (final c in g.combatCompanions) c.currentHp];
    _tickToHit(g);
    final soft = before[0] - g.combatCompanions[0].currentHp;
    final hard = before[1] - g.combatCompanions[1].currentHp;
    expect(hard, lessThan(soft));
    expect(hard, greaterThan(0));
  });

  test('a shield soaks it first', () {
    final g = _raid();
    final c = g.combatCompanions.first;
    c.shieldHp = 10000;
    final before = c.currentHp;
    _tickToHit(g);
    expect(c.currentHp, before);
    expect(c.shieldHp, lessThan(10000));
  });

  test('the beat is the same at 60 and 120 fps', () {
    int landedIn(int fps, double seconds) {
      final g = _raid();
      for (var i = 0; i < seconds * fps; i++) {
        g.debugTickSquadHit(1 / fps);
      }
      return g.squadHitsLanded;
    }

    expect(landedIn(60, 60), landedIn(120, 60));
    expect(landedIn(60, 60), 7); // 8 s apart at L1: 8, 16 … 56
  });

  test('nothing lands outside a guardian\'s fight', () {
    final m = _member(0);
    final g = PlanetDungeonGame(
      element: 'Air',
      party: [m],
      initialStarMask: 0,
      onStarEarned: (_) {},
      onPlayerDown: () {},
      onChanged: () {},
    );
    g.currentRoomId = g.layout.entranceRoomId;
    for (var i = 0; i < 60 * 20; i++) {
      g.debugTickSquadHit(1 / 60);
    }
    expect(g.squadHitsLanded, 0);
  });
}
