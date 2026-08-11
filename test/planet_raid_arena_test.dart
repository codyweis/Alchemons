// Headless tests for the raid arena: generated single-room layout, the
// empowered guardian, phase adds, and the onRaidCleared win path.
//
// Mirrors the harness in planet_dungeon_combat_test.dart: onLoad is skipped
// and the party is wired manually.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member({
  required int slot,
  String element = 'Air',
  String family = 'wing',
}) {
  return CosmicPartyMember(
    instanceId: 'inst_$slot',
    baseId: 'base_$slot',
    displayName: 'Test $slot',
    element: element,
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
}

CosmicSurvivalCompanion _companion(CosmicPartyMember member, Offset position) {
  final stats = deriveCosmicSurvivalCompanionStats(member: member);
  return CosmicSurvivalCompanion(
    member: member,
    slotIndex: member.slotIndex,
    position: position,
    anchor: position,
    maxHp: stats.maxHp,
    currentHp: stats.maxHp,
    physAtk: stats.physAtk,
    elemAtk: stats.elemAtk,
    physDef: stats.physDef,
    elemDef: stats.elemDef,
    cooldownReduction: stats.cooldownReduction,
    critChance: stats.critChance,
    attackRange: stats.attackRange,
    specialAbilityRange: stats.specialAbilityRange,
    tethered: false,
    invincibleTimer: 0,
  );
}

PlanetDungeonGame _buildRaid({
  RaidConfig config = const RaidConfig(),
  void Function()? onCleared,
  void Function(int)? onStar,
}) {
  final party = [for (var i = 0; i < 2; i++) _member(slot: i)];
  final game = PlanetDungeonGame(
    element: 'Air',
    party: party,
    initialStarMask: 0,
    onStarEarned: onStar ?? (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    raid: config,
    onRaidCleared: onCleared,
    layoutOverride: buildRaidArenaLayout('Air'),
  );
  game.currentRoomId = game.layout.entranceRoomId;
  final spawn = game.layout.entranceSpawn;
  for (var i = 0; i < party.length; i++) {
    final c = DungeonCreature(member: party[i])
      ..position = spawn + Offset(i * 60.0, 0)
      ..lastSafe = spawn + Offset(i * 60.0, 0);
    game.creatures.add(c);
    game.combatCompanions.add(_companion(party[i], c.position));
  }
  return game;
}

PlanetDungeonGame _buildNormalDungeon() {
  final party = [for (var i = 0; i < 2; i++) _member(slot: i)];
  final game = PlanetDungeonGame(
    element: 'Air',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  return game;
}

void _step(PlanetDungeonGame game, double seconds, {double dt = 1 / 60}) {
  var t = 0.0;
  while (t < seconds) {
    game.update(dt);
    t += dt;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('raid arena layout', () {
    test('every configured raid element generates a clean one-room arena', () {
      for (final element in kRaidGuardianIds.keys) {
        final layout = buildRaidArenaLayout(element);
        expect(layout.rooms.length, 1, reason: element);
        final room = layout.entranceRoom;
        expect(room.doors, isEmpty, reason: element);
        expect(room.clouds, isEmpty, reason: element);
        expect(room.anchors, isEmpty, reason: element);
        expect(room.conduits, isEmpty, reason: element);
        expect(room.gustShrines, isEmpty, reason: element);
        expect(room.stormRods, isEmpty, reason: element);
        expect(room.stormOrbit, isNull, reason: element);
        expect(room.summit, isNull, reason: element);
        expect(room.guardian, isNotNull, reason: element);
        expect(room.guardian!.encounter!.canCalm, isFalse, reason: element);
        expect(room.guardian!.encounter!.canDefeat, isTrue, reason: element);
        expect(
          room.bounds.contains(layout.entranceSpawn),
          isTrue,
          reason: element,
        );
        expect(
          room.bounds.contains(room.guardian!.position),
          isTrue,
          reason: element,
        );
      }
    });
  });

  group('raid guardian', () {
    test('spawns awake immediately with multiplied hp and damage', () {
      final baseline = _buildRaid(
        config: const RaidConfig(hpMul: 1.0, dmgMul: 1.0),
      );
      final raid = _buildRaid(
        config: const RaidConfig(hpMul: 3.0, dmgMul: 1.5),
      );
      expect(raid.guardianAwake, isTrue);
      _step(baseline, 0.5);
      _step(raid, 0.5);
      final base = baseline.combatEnemies.singleWhere((e) => e.isElite);
      final boosted = raid.combatEnemies.singleWhere((e) => e.isElite);
      expect(boosted.maxHp, closeTo(base.maxHp * 3.0, 0.001));
      expect(boosted.damage, closeTo(base.damage * 1.5, 0.001));

      // The normal dungeon's guardian still waits for the altar puzzle.
      final normal = _buildNormalDungeon();
      expect(normal.guardianAwake, isFalse);
    });

    test('phase adds spawn as guardian hp crosses each threshold', () {
      final raid = _buildRaid(
        config: const RaidConfig(addPhaseThresholds: [0.7, 0.35]),
      );
      _step(raid, 0.5);
      final guardian = raid.combatEnemies.singleWhere((e) => e.isElite);
      final baseCount = raid.combatEnemies.length;

      guardian.hp = guardian.maxHp * 0.65; // below first threshold
      _step(raid, 0.2);
      final afterFirst = raid.combatEnemies.length;
      expect(afterFirst, greaterThan(baseCount));

      guardian.hp = guardian.maxHp * 0.30; // below second threshold
      _step(raid, 0.2);
      expect(raid.combatEnemies.length, greaterThan(afterFirst));
    });

    test('killing the guardian fires onRaidCleared, never onStarEarned', () {
      var cleared = 0;
      var stars = 0;
      final raid = _buildRaid(
        onCleared: () => cleared++,
        onStar: (_) => stars++,
      );
      _step(raid, 0.5);
      final guardian = raid.combatEnemies.singleWhere((e) => e.isElite);

      guardian.hp = 0;
      guardian.isDead = true;
      _step(raid, 0.5);

      expect(cleared, 1);
      expect(stars, 0);
      // And it only fires once even as the loop keeps running.
      _step(raid, 1.0);
      expect(cleared, 1);
    });
  });
}
