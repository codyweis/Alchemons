// A DUNGEON GUARDIAN'S SQUAD HIT.
//
// The raid's squad hit, lighter, in a dungeon's own guardian fight: a share
// of each living Alchemon's health on a steady beat, trimmed by E-DEF, and
// growing with the campaign clock like every other guardian attack. Lighter
// because a dungeon's trio is the one the dungeon asks for, which cannot
// always bring a healer. See docs/plans/raid_threat_plan.md, Phase 7.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot, String element) => CosmicPartyMember(
  instanceId: 'd$slot',
  baseId: 'b$slot',
  displayName: '$element wing',
  element: element,
  family: 'wing',
  level: 10,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: slot,
  staminaBars: 9,
  staminaMax: 9,
);

/// Earth's guardian roused, the trio in its room, the guardian landed.
PlanetDungeonGame _fight({int cleared = 0}) {
  final members = [
    for (final (i, el) in const ['Earth', 'Lightning', 'Crystal'].indexed)
      _member(i, el),
  ];
  final g = PlanetDungeonGame(
    element: 'Earth',
    party: members,
    initialStarMask: 0x3,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    clearedGuardianCount: cleared,
  );
  g.onGameResize(Vector2(412, 915));
  final room = g.layout.rooms.values.firstWhere((r) => r.guardian != null);
  g.currentRoomId = room.id;
  for (var i = 0; i < members.length; i++) {
    final at = room.guardian!.position + Offset((i - 1) * 40.0, 170);
    g.creatures.add(
      DungeonCreature(member: members[i])
        ..position = at
        ..lastSafe = at,
    );
    g.combatCompanions.add(g.debugCreateCombatCompanion(members[i], at));
  }
  g.guardianAwake = true;
  for (var i = 0; i < 60 * 4; i++) {
    if (g.combatEnemies.any((e) => e.isElite)) break;
    g.update(1 / 60);
  }
  expect(g.combatEnemies.any((e) => e.isElite), isTrue);
  return g;
}

/// The squad hit alone (no dives, no aura) until one lands.
void _tickToHit(PlanetDungeonGame g) {
  final target = g.squadHitsLanded + 1;
  for (var i = 0; i < 60 * 20 && g.squadHitsLanded < target; i++) {
    g.debugTickSquadHit(1 / 60);
  }
  expect(g.squadHitsLanded, target);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('it lands on the whole trio, at the dungeon share', () {
    final g = _fight();
    final before = [for (final c in g.combatCompanions) c.currentHp];
    _tickToHit(g);
    for (var i = 0; i < g.combatCompanions.length; i++) {
      final c = g.combatCompanions[i];
      final expected =
          (c.maxHp *
                  PlanetDungeonGame.kDungeonSquadHitFraction *
                  PlanetDungeonGame.defenseMitigation(c.elemDef))
              .round();
      expect(before[i] - c.currentHp, expected, reason: 'slot $i');
    }
  });

  test('it is on the dungeon beat, wired into the real tick', () {
    final g = _fight();
    final landed = g.squadHitsLanded;
    for (
      var i = 0;
      i < (PlanetDungeonGame.kDungeonSquadHitInterval + 0.3) * 60;
      i++
    ) {
      for (final c in g.creatures) {
        c.hp = c.maxHp;
      }
      g.update(1 / 60);
    }
    expect(g.squadHitsLanded, landed + 1);
  });

  test('it grows with the campaign clock, like its other attacks', () {
    int taken(int cleared) {
      final g = _fight(cleared: cleared);
      final c = g.combatCompanions.first;
      final before = c.currentHp;
      _tickToHit(g);
      return before - c.currentHp;
    }

    expect(taken(16), greaterThan(taken(0) * 2));
  });

  test('nothing lands once the party leaves the guardian\'s room', () {
    final g = _fight();
    g.currentRoomId = g.layout.entranceRoomId;
    for (var i = 0; i < 60 * 20; i++) {
      g.debugTickSquadHit(1 / 60);
    }
    expect(g.squadHitsLanded, 0);
  });
}
