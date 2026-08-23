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
      // The guardian ARRIVES (it falls in) before its body exists.
      _step(baseline, 2.2);
      _step(raid, 2.2);
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
      _step(raid, 2.2); // past the arrival
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
      _step(raid, 2.2); // past the arrival
      final guardian = raid.combatEnemies.singleWhere((e) => e.isElite);

      guardian.hp = 0;
      guardian.isDead = true;
      _step(raid, 6.0); // through the death sequence

      expect(cleared, 1);
      expect(stars, 0);
      // And it only fires once even as the loop keeps running.
      _step(raid, 1.0);
      expect(cleared, 1);
    });
  });

  group('the guardian death sequence', () {
    // The reward screen used to appear over a still-standing body, which gave
    // the longest fight in the game no ending.
    PlanetDungeonGame killedRaid({void Function()? onCleared}) {
      final raid = _buildRaid(onCleared: onCleared);
      _step(raid, 2.2);
      final guardian = raid.combatEnemies.singleWhere((e) => e.isElite);
      guardian.hp = 0;
      guardian.isDead = true;
      _step(raid, 0.2);
      return raid;
    }

    test('rewards are withheld until the sequence finishes', () {
      var cleared = 0;
      final raid = killedRaid(onCleared: () => cleared++);
      expect(raid.isRaidDeathPlaying, isTrue);
      expect(cleared, 0, reason: 'the reward screen must wait for the death');

      _step(raid, 1.5);
      expect(cleared, 0, reason: 'still mid-collapse');

      _step(raid, 4.0);
      expect(cleared, 1);
      expect(raid.isRaidDeathPlaying, isFalse);
    });

    test('the arena goes quiet so nothing shoots during the cinematic', () {
      final raid = _buildRaid();
      _step(raid, 2.2);
      final guardian = raid.combatEnemies.singleWhere((e) => e.isElite);
      // Force a phase so there are adds alive at the moment of death.
      guardian.hp = guardian.maxHp * 0.05;
      _step(raid, 0.2);
      expect(raid.combatEnemies.length, greaterThan(1));

      guardian.hp = 0;
      guardian.isDead = true;
      _step(raid, 0.3);
      expect(
        raid.combatEnemies.where((e) => !e.isDead), 
        isEmpty,
        reason: 'surviving adds are consumed by the collapse',
      );
    });

    test('the player cannot act during the sequence', () {
      final raid = killedRaid();
      expect(raid.canAct, isFalse);
    });

    test('hits on the guardian throw damage numbers', () {
      final raid = _buildRaid();
      // Companions auto-attack; a few seconds of the fight must produce
      // visible feedback that the guardian is taking damage.
      _step(raid, 6.0);
      expect(
        raid.damageNumbers.isEmpty,
        isFalse,
        reason: 'a raid boss fight with no damage feedback is unreadable',
      );
      expect(raid.damageNumbers.length, lessThanOrEqualTo(40));
    });

    test('damage numbers are cleared when the guardian falls', () {
      final raid = killedRaid();
      expect(raid.damageNumbers.isEmpty, isTrue);
    });
  });

  group('raid squad and difficulty', () {
    test('a raid squad is five, against a dungeon party of three', () {
      expect(RaidConfig.squadSize, 5);
    });

    test('the guardian is scaled for the bigger squad, not just buffed', () {
      // Five Alchemons is roughly +67% DPS and +67% bodies over three. HP
      // rises with the party so the fight still takes about as long, and
      // damage rises further so the extra bodies are not just slack.
      const cfg = RaidConfig();
      expect(cfg.hpMul, 5.0);
      expect(cfg.dmgMul, 2.2);
      // HP must scale at least as fast as the party, or raids got easier.
      expect(cfg.hpMul / 3.0, greaterThanOrEqualTo(RaidConfig.squadSize / 3));
      // And damage must outpace HP, or it is only a longer fight.
      expect(cfg.dmgMul / 1.5, greaterThan(1.0));
    });

    test('a five-strong squad all reaches the arena', () {
      final party = [for (var i = 0; i < RaidConfig.squadSize; i++) _member(slot: i)];
      final game = PlanetDungeonGame(
        element: 'Air',
        party: party,
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () {},
        onChanged: () {},
        raid: const RaidConfig(),
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
      _step(game, 2.2);

      // Nothing in the dungeon may assume a party of three.
      expect(game.creatures.length, 5);
      expect(game.combatCompanions.length, 5);
      expect(game.creatures.where((c) => c.alive).length, 5);
    });

    test('the guardian scales with cleared planets on top of the raid mul', () {
      PlanetDungeonGame raidWith(int cleared) => PlanetDungeonGame(
        element: 'Air',
        party: [_member(slot: 0)],
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () {},
        onChanged: () {},
        raid: const RaidConfig(),
        clearedGuardianCount: cleared,
        layoutOverride: buildRaidArenaLayout('Air'),
      );
      expect(raidWith(5).progressHpMul, greaterThan(raidWith(0).progressHpMul));
      expect(raidWith(0).progressHpMul, 1.0);
    });
  });

  group('the raid fight timer', () {
    PlanetDungeonGame timed({void Function()? onExpired}) {
      final party = [for (var i = 0; i < 2; i++) _member(slot: i)];
      final game = PlanetDungeonGame(
        element: 'Air',
        party: party,
        initialStarMask: 0,
        onStarEarned: (_) {},
        onPlayerDown: () {},
        onChanged: () {},
        raid: const RaidConfig(),
        onRaidExpired: onExpired,
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

    test('ten minutes, counting down', () {
      expect(kRaidFightLimit, const Duration(minutes: 10));
      final g = timed();
      _step(g, 2.0);
      final left = g.raidTimeRemaining!;
      expect(left.inSeconds, lessThanOrEqualTo(600));
      expect(left.inSeconds, greaterThan(560));
    });

    test('a normal dungeon has no fight clock', () {
      expect(_buildNormalDungeon().raidTimeRemaining, isNull);
    });

    test('running it out loses the attempt', () {
      var expired = 0;
      final g = timed(onExpired: () => expired++);
      _step(g, kRaidFightLimit.inSeconds + 2.0, dt: 1 / 6);
      expect(expired, 1);
      expect(g.raidTimeRemaining, Duration.zero);
    });

    test('it fires once, not every frame after', () {
      var expired = 0;
      final g = timed(onExpired: () => expired++);
      _step(g, kRaidFightLimit.inSeconds + 30.0, dt: 1 / 6);
      expect(expired, 1);
    });

    test('felling the guardian stops the clock', () {
      var expired = 0;
      final g = timed(onExpired: () => expired++);
      _step(g, 2.2);
      final guardian = g.combatEnemies.singleWhere((e) => e.isElite);
      guardian.hp = 0;
      guardian.isDead = true;
      _step(g, 1.0);
      final atDeath = g.raidTimeRemaining!;

      // Far past the limit — a slow death sequence must never lose you a
      // fight you already won.
      _step(g, kRaidFightLimit.inSeconds + 10.0, dt: 1 / 6);
      expect(expired, 0);
      expect(g.raidTimeRemaining, atDeath);
    });
  });
}
