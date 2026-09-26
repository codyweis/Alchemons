// The dungeon's hit buzz: one hit is felt once, and a swap is not a hit.
//
// It used to buzz every 0.45s forever after a single hit (the felt level went
// stale above the creature's health), which read on device as a constant,
// unexplained vibration — most noticeably after Air's glide dropped a
// creature into a fall.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot, String element, String family) =>
    CosmicPartyMember(
      instanceId: 'inst_$slot',
      baseId: 'base_$slot',
      displayName: '$element $family',
      element: element,
      family: family,
      level: 10,
      statSpeed: 3,
      statIntelligence: 5,
      statStrength: 3,
      statBeauty: 3,
      slotIndex: slot,
      staminaBars: 3,
      staminaMax: 3,
    );

PlanetDungeonGame _air(List<DungeonHaptic> felt) {
  final party = [
    _member(0, 'Air', 'wing'),
    _member(1, 'Lightning', 'horn'),
    _member(2, 'Fire', 'mask'),
  ];
  final game = PlanetDungeonGame(
    element: 'Air',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    final stats = deriveCosmicSurvivalCompanionStats(member: m);
    game.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: m,
        slotIndex: m.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: stats.maxHp,
        currentHp: stats.maxHp,
        physAtk: stats.physAtk,
        elemAtk: stats.elemAtk,
        abilityAtk: stats.elemAtk,
        physDef: stats.physDef,
        elemDef: stats.elemDef,
        cooldownReduction: stats.cooldownReduction,
        critChance: stats.critChance,
        attackRange: stats.attackRange,
        specialAbilityRange: stats.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  game.onHaptic = felt.add;
  return game;
}

void _run(PlanetDungeonGame g, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    g.update(1 / 60);
  }
}

int _hits(List<DungeonHaptic> felt) =>
    felt.where((k) => k == DungeonHaptic.hit).length;

void main() {
  test('one hit is felt once, not every 0.45s until healed', () {
    final felt = <DungeonHaptic>[];
    final g = _air(felt);
    _run(g, 0.2);
    g.active!.hp -= 20;
    _run(g, 3);
    expect(_hits(felt), 1);
  });

  test('swapping to a hurt creature is not felt as a hit', () {
    final felt = <DungeonHaptic>[];
    final g = _air(felt);
    g.creatures[1].hp -= 30;
    _run(g, 0.2);
    g.setActive(1);
    _run(g, 3);
    expect(_hits(felt), 0);
  });
}
