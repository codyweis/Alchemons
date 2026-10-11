// DUNGEON ABILITIES PLAY BY SURVIVAL'S RULES.
//
// Two gaps found in the 2026-10-10 ability pass, both dungeon-only:
//  - Kin Air's updraft and Kin Water's rain cloud are built to follow the
//    ship. There is no ship down here, so the ward looked for a host it
//    could never find and faded out in 0.4 s.
//  - Mane Light hung a fresh ring on every cast with no ceiling, where
//    survival and open space hang one ward of as many rings as Beauty holds
//    up (ManeLightWard).

import 'dart:io';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/horn_runtime.dart';
import 'package:alchemons/games/cosmic/mane_runtime.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member({
  required String element,
  required String family,
  double stat = 4.25,
}) => CosmicPartyMember(
  instanceId: 'inst_0',
  baseId: 'base_0',
  displayName: '$element $family',
  element: element,
  family: family,
  level: 10,
  statSpeed: stat,
  statIntelligence: stat,
  statStrength: stat,
  statBeauty: stat,
  slotIndex: 0,
  staminaBars: 3,
  staminaMax: 3,
);

PlanetDungeonGame _game(CosmicPartyMember member) {
  final g = PlanetDungeonGame(
    element: 'Air',
    party: [member],
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final at = g.layout.entranceSpawn;
  g.creatures.add(
    DungeonCreature(member: member)
      ..position = at
      ..lastSafe = at,
  );
  g.combatCompanions.add(g.debugCreateCombatCompanion(member, at));
  return g;
}

void main() {
  for (final element in ['Water', 'Air']) {
    test('a Kin $element ward follows its caster and lasts', () {
      final g = _game(_member(element: element, family: 'kin'));
      g.combatCompanions.first.specialCooldown = 0;
      expect(g.activateCombatAbility(), isTrue);
      bool isWard(Projectile p) =>
          p.abilityFamily == 'kin' &&
          p.element == element &&
          p.stationary &&
          p.attachedToSlot == -1;
      expect(g.combatProjectiles.where(isWard), isNotEmpty);

      for (var i = 0; i < 90; i++) {
        g.update(1 / 60);
      }
      expect(
        g.combatProjectiles.where(isWard).where((p) => p.life > 0),
        isNotEmpty,
        reason: 'the ward faded out looking for a ship',
      );
      final ward = g.combatProjectiles.firstWhere(isWard);
      expect(
        (ward.position - g.creatures.first.position).distance,
        lessThan(1.0),
        reason: 'the ward did not follow its caster',
      );
    });
  }

  test('Mane Light keeps one ward of as many rings as Beauty holds', () {
    final member = _member(element: 'Light', family: 'mane');
    final g = _game(member);
    final cap = maneLightRingCount(member.statBeauty);
    for (var cast = 0; cast < cap + 4; cast++) {
      g.combatCompanions.first.specialCooldown = 0;
      g.activateCombatAbility();
      g.update(1 / 60);
    }
    final rings = ManeLightWard.rings(g.combatProjectiles, 0);
    expect(rings.length, lessThanOrEqualTo(cap));
    expect(rings, isNotEmpty);
  });

  test('Horn Dark drags from the shared reach, not a fixed 200', () {
    // Survival and open space drag from hornDarkAuraRadius(Beauty), 221-338;
    // the dungeon dragged from a hard-coded 200.
    final member = _member(element: 'Dark', family: 'horn', stat: 12);
    final g = _game(member);
    final reach = hornDarkAuraRadius(member.statBeauty);
    expect(reach, greaterThan(300));
    final at = g.creatures.first.position;
    CosmicSurvivalEnemy foe(Offset offset) => CosmicSurvivalEnemy(
      position: at + offset,
      hp: 1e9,
      maxHp: 1e9,
      speed: 0,
      damage: 0,
      radius: 10,
      tier: EnemyTier.drone,
      element: 'Fire',
      conduct: EnemyConduct.charge,
      target: CosmicEnemyTarget.orb,
    );
    final near = foe(const Offset(120, 0));
    final far = foe(const Offset(0, 280)); // past 200, inside the reach
    g.combatEnemies.addAll([near, far]);
    g.combatCompanions.first.specialCooldown = 0;
    expect(g.activateCombatAbility(), isTrue);
    final before = (far.position - at).distance;
    for (var i = 0; i < 20; i++) {
      g.update(1 / 60);
    }
    expect(
      (far.position - g.creatures.first.position).distance,
      lessThan(before - 5),
      reason: 'a body inside the shared reach was not dragged',
    );
    final src = File(
      'lib/games/planet_dungeon/planet_dungeon_game.dart',
    ).readAsStringSync();
    expect(src, contains('hornDarkAuraRadius('));
    expect(src, contains('hornDarkCaptureRadius('));
  });
}
