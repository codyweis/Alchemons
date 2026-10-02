// A Mystic's special is its world, which only Survival runs. In a planet
// dungeon, as in open space, a Mystic still fights in the party — with its
// auto attack — and its special button says there is nothing to cast.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot, String family) => CosmicPartyMember(
  instanceId: 'inst_$slot',
  baseId: 'base_$slot',
  displayName: '$family $slot',
  element: 'Water',
  family: family,
  level: 10,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: slot,
  staminaBars: 3,
  staminaMax: 3,
);

PlanetDungeonGame _game(String leadFamily) {
  final party = [_member(0, leadFamily), _member(1, 'Wing')];
  final game = PlanetDungeonGame(
    element: 'Air',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  final spawn = game.layout.entranceSpawn;
  for (var i = 0; i < party.length; i++) {
    final c = DungeonCreature(member: party[i])
      ..position = spawn + Offset(i * 60.0, 0)
      ..lastSafe = spawn + Offset(i * 60.0, 0);
    game.creatures.add(c);
    final stats = deriveAlchemonCombatStats(member: party[i]);
    game.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: party[i],
        slotIndex: i,
        position: c.position,
        anchor: c.position,
        maxHp: stats.maxHp,
        currentHp: stats.maxHp,
        physAtk: stats.physAtk,
        elemAtk: stats.elemAtk,
        abilityAtk: stats.abilityAtk,
        physDef: stats.physDef,
        elemDef: stats.elemDef,
        cooldownReduction: stats.cooldownReduction,
        specialCooldownReduction: stats.specialCooldownReduction,
        attackRange: stats.attackRange,
        specialAbilityRange: stats.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      )..specialCooldown = 0,
    );
  }
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only Survival runs a Mystic special', () {
    expect(castsSpecialOutsideSurvival('Mystic'), isFalse);
    for (final family in ['Horn', 'Wing', 'Let', 'Pip', 'Mane', 'Mask', 'Kin']) {
      expect(castsSpecialOutsideSurvival(family), isTrue, reason: family);
    }
  });

  test('a Mystic in a dungeon has no special to cast', () {
    final game = _game('Mystic');
    expect(game.activeCombat!.member.family, 'Mystic');
    expect(game.abilityIsAbsent, isTrue);
    expect(game.abilityReady, isFalse);
    final before = game.combatProjectiles.length;
    expect(game.activateCombatAbility(), isFalse);
    expect(game.combatProjectiles.length, before);
    expect(game.abilityDeniedPulse, greaterThan(0));
  });

  test('anyone else still casts', () {
    final game = _game('Pip');
    expect(game.abilityIsAbsent, isFalse);
    expect(game.abilityReady, isTrue);
  });
}
