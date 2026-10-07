// Every planet's raid has to be a fight the squad can win. The arena is
// generated, so a planet's own dungeon rule (a pillar the guardian needs
// standing, a shell floor, a door the entry rite looks for) finds nothing
// there. A hook that forgets to skip raids then holds the lull shut, floors
// the guardian's health or throws on the ability button.
//
// The squad's health is refilled every frame, so only the guardian's rules
// decide the outcome. The planet's own element is in the squad, so its
// dungeon verbs are pressed in the arena too.
//
// Where a guardian fights by its planet's rule (Frowyrm's pillar, Bogdrya's
// anchor, Ashdjinn's cut, Wraithord's chime, Magmara's ring, Prismalith's
// floor, Botanica's rings, Blightfang's brews, Raikuma's spike, Solarin's
// shadow), the squad answers it the way a player would:
// while the guardian is shut, the key Alchemon goes to the thing and presses.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'guardian_rule_harness.dart';

CosmicPartyMember _member(int slot, String element, String family) =>
    CosmicPartyMember(
      instanceId: 'r$slot',
      baseId: 'b$slot',
      displayName: '$element $family',
      element: element,
      family: family,
      level: 10,
      statSpeed: 4.5,
      statIntelligence: 4.5,
      statStrength: 4.5,
      statBeauty: 4.5,
      slotIndex: slot,
      staminaBars: 9,
      staminaMax: 9,
    );

/// Slot 1 is the key Alchemon: the planet's own element, or the Blood Pip
/// that rings Wraithord's chime. Botanica's rings take three hands (Water,
/// Spirit and Crystal stand in one together).
({bool cleared, int lulls, double seconds}) _fight(String element) {
  final plant = element == 'Plant';
  final poison = element == 'Poison';
  final members = [
    _member(0, element, 'horn'),
    _member(1, switch (element) {
      'Spirit' => 'Blood',
      'Plant' => 'Water',
      _ => element,
    }, 'pip'),
    _member(2, plant ? 'Spirit' : (poison ? 'Plant' : 'Fire'), 'wing'),
    _member(3, 'Water', 'kin'),
    _member(4, plant ? 'Crystal' : 'Earth', 'let'),
  ];
  final game = PlanetDungeonGame(
    element: element,
    party: members,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    raid: const RaidConfig(level: 1),
    onRaidCleared: () async {},
    onRaidCreatureDown: (_) {},
    onRaidWiped: () {},
    layoutOverride: buildRaidArenaLayout(element),
  );
  game.onGameResize(Vector2(412, 915));
  game.currentRoomId = game.layout.entranceRoomId;
  final spawn = game.layout.entranceSpawn;
  for (var i = 0; i < members.length; i++) {
    final at = spawn + Offset((i - 2) * 50.0, 0);
    game.creatures.add(
      DungeonCreature(member: members[i])
        ..position = at
        ..lastSafe = at,
    );
    game.combatCompanions.add(game.debugCreateCombatCompanion(members[i], at));
  }
  final star = game.currentRoom.guardian!.starIndex;
  const dt = 1 / 60;
  var t = 0.0;
  var lulls = 0;
  var wasOpen = false;
  while (t < 120) {
    for (final c in game.combatCompanions) {
      c.currentHp = c.maxHp;
    }
    for (final c in game.creatures) {
      c.hp = c.maxHp;
    }
    final answer = guardianAnswerAt(game);
    if (poison && !game.guardianVulnerable) {
      blightfangStep(game, 1, 2);
    } else if (answer != null &&
        (!game.guardianVulnerable || element == 'Light')) {
      // (Solarin is struck from the very shadow that opens it.)
      if (game.activeIndex != 1) game.setActive(1);
      game.creatures[1]
        ..position = answer
        ..lastSafe = answer;
      if (plant) {
        for (final (i, off) in const [
          (2, Offset(18, 0)),
          (4, Offset(-18, 0)),
        ]) {
          game.creatures[i]
            ..position = answer + off
            ..lastSafe = answer + off;
        }
      }
      game.activateAbility();
    } else {
      // Hand the fight round the squad, so every family presses its button.
      if (t % 3 < dt) game.cycleActive();
      final boss = game.combatEnemies.where((e) => e.isElite).firstOrNull;
      final a = game.active;
      if (a != null && boss != null) {
        final stand = boss.position + const Offset(0, 90);
        a
          ..position = stand
          ..lastSafe = stand;
      }
      if (game.autoAttackReady) game.activateAutoAttack();
      if (game.abilityReady) game.activateCombatAbility();
      game.activateAbility();
    }
    game.update(dt);
    t += dt;
    if (game.guardianVulnerable && !wasOpen) lulls++;
    wasOpen = game.guardianVulnerable;
    if (game.hasStar(star)) return (cleared: true, lulls: lulls, seconds: t);
  }
  return (cleared: false, lulls: lulls, seconds: t);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final element in kRaidGuardianIds.keys) {
    test('$element raid: the lull keeps opening and the guardian falls', () {
      final r = _fight(element);
      expect(
        r.lulls,
        greaterThanOrEqualTo(3),
        reason: '$element opened its lull ${r.lulls} times',
      );
      expect(
        r.cleared,
        isTrue,
        reason: '$element guardian still standing after ${r.seconds}s',
      );
    });
  }
}
