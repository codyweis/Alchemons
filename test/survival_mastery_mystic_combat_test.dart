import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mystic.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mystic's two paths, driven through the real game.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember mystic(String element) => CosmicPartyMember(
    instanceId: 'mystic-0',
    baseId: 'MYS01',
    displayName: 'Mystic $element',
    family: 'Mystic',
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: 4.25,
    statIntelligence: 4.25,
    statStrength: 4.25,
    statBeauty: 4.25,
    statSpeedPotential: 50,
    statIntelligencePotential: 50,
    statStrengthPotential: 50,
    statBeautyPotential: 50,
    staminaBars: 3,
    staminaMax: 3,
  );

  SurvivalFamilyMasterySnapshot equip(String pathId, {int throughTier = 4}) {
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.mystic, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'mystic-0',
        family: CreatureFamily.mystic,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  Future<CosmicSurvivalGame> arena({
    String element = 'Lightning',
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: [mystic(element)],
      onGameOver: () {},
      masterySnapshot: snapshot,
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    return game;
  }

  /// Runs until the world is actually lit. Mystic has the longest cooldown
  /// in the game, so the cast has to be held open rather than nudged once.
  Future<bool> lightWorld(CosmicSurvivalGame game, {int seconds = 40}) async {
    final comp = game.activeCompanions[0]!;
    for (var i = 0; i < 60 * seconds; i++) {
      if (game.debugMysticWorldLit(0)) return true;
      if (comp.specialCooldown > 0) comp.specialCooldown = 0;
      game.update(1 / 60);
    }
    return game.debugMysticWorldLit(0);
  }

  /// Runs until the world is lit, then counts how much damage it deals.
  Future<double> worldOutput({
    SurvivalFamilyMasterySnapshot? snapshot,
    int seconds = 30,
  }) async {
    final game = await arena(snapshot: snapshot);
    await lightWorld(game);
    var dealt = 0.0;
    var before = {for (final e in game.enemies) e: e.hp};
    for (var i = 0; i < 60 * seconds; i++) {
      game.update(1 / 60);
      for (final e in game.enemies) {
        final was = before[e];
        if (was != null && e.hp < was) dealt += was - e.hp;
      }
      before = {for (final e in game.enemies) e: e.hp};
    }
    return dealt;
  }

  CosmicSurvivalEnemy body(
    Offset at, {
    EnemyTier tier = EnemyTier.drone,
    double hp = 1e9,
  }) => CosmicSurvivalEnemy(
    position: at,
    hp: hp,
    maxHp: hp,
    speed: 0,
    damage: 4,
    radius: 14,
    tier: tier,
    element: 'Ice',
    target: CosmicEnemyTarget.orb,
    conduct: EnemyConduct.stalk,
  );

  group('Quickening drives the world', () {
    test('the world is lit and the path does not break it', () async {
      final plain = await worldOutput();
      final quick = await worldOutput(
        snapshot: equip(MysticNodes.quickeningPath, throughTier: 4),
      );
      expect(plain, greaterThan(0), reason: 'the world never did anything');
      expect(quick, greaterThan(0));
    });

    test('First Light makes the world act on ignition', () async {
      // The clock-driven worlds normally spend their first full interval
      // doing nothing at all.
      final game = await arena(
        snapshot: equip(MysticNodes.quickeningPath, throughTier: 2),
      );
      expect(await lightWorld(game), isTrue);
    });

    /// What a Lightning world's lone target lost on each frame a strike
    /// landed, across a few strikes, in order. With [deaths], a body far from
    /// the bolts dies on the frame after each one lands (and on the frame
    /// after that), whoever killed it.
    Future<List<(int, double)>> strikes(int tier, {bool deaths = false}) async {
      final game = await arena(
        snapshot: equip(MysticNodes.quickeningPath, throughTier: tier),
      );
      expect(await lightWorld(game), isTrue);
      final comp = game.activeCompanions[0]!;
      // One body, far from the ship and out of everyone's way: every bolt
      // lands on it, and nothing else hurts it.
      final target = body(game.orb.position + const Offset(-260, -120));
      final hits = <(int, double)>[];
      var dieAt = <int>{};
      for (var i = 0; i < 60 * 8; i++) {
        for (final e in game.enemies) {
          if (!identical(e, target)) e.isDead = true;
        }
        if (!game.enemies.contains(target)) game.enemies.add(target);
        if (dieAt.remove(i)) {
          // Nowhere near the bolt, and not the world's doing.
          final dying = body(game.orb.position + const Offset(300, 260));
          game.enemies.add(dying);
          game.debugKillEnemy(dying);
        }
        comp.basicCooldown = 99;
        game.ship.position = game.orb.position + const Offset(300, 300);
        game.orb.currentHp = game.orb.maxHp;
        final hp = target.hp;
        game.update(1 / 60);
        if (target.hp < hp - 1) {
          hits.add((i, hp - target.hp));
          if (deaths) dieAt = {...dieAt, i + 1, i + 2};
        }
      }
      expect(hits, isNotEmpty, reason: 'no bolt ever landed');
      return hits;
    }

    test('Quickening: after each act, the next death makes the world act '
        'again at once, at half strength', () async {
      // No deaths, no repeats: whole bolts, on the clock.
      final quiet = await strikes(1);
      expect(quiet.length, greaterThan(1));
      final gap = quiet[1].$1 - quiet[0].$1;
      expect(gap, greaterThan(30), reason: 'setup: bolts come on a clock');
      for (final (_, damage) in quiet) {
        expect(damage, closeTo(quiet.first.$2, quiet.first.$2 * 0.2));
      }

      final hits = await strikes(1, deaths: true);
      final (frame, damage) = hits.first;
      // The death on the next frame brings the bolt down again on the same
      // spot, at half; the death after it brings nothing, because the world
      // has not acted again in between.
      final again = hits.where((h) => h.$1 > frame).toList();
      expect(again, isNotEmpty);
      expect(again.first.$1 - frame, lessThanOrEqualTo(3));
      expect(
        again.first.$2 / damage,
        closeTo(MysticTuning.quickenStrength, 0.05),
      );
      expect(
        again.length < 2 || again[1].$1 - frame > 10,
        isTrue,
        reason: 'one repeat per act, however many die',
      );
    });

    test('Aftershock: each bolt falls again half a second later, at 40%',
        () async {
      final hits = await strikes(3);
      // Each strike is followed, 30 frames on, by one at 40% of it.
      final (frame, damage) = hits.first;
      final echo = hits.firstWhere(
        (h) => h.$1 > frame,
        orElse: () => fail('no aftershock'),
      );
      expect(echo.$1 - frame, closeTo(30, 2));
      expect(echo.$2 / damage, closeTo(MysticTuning.aftershockStrength, 0.05));
    });

    test('Relentless Sky: each bolt falls twice in a row, then the '
        'aftershock', () async {
      final hits = await strikes(4);
      final (frame, damage) = hits.first;
      final after = hits.where((h) => h.$1 > frame).take(2).toList();
      expect(after, hasLength(2));
      expect(after[0].$1 - frame, closeTo(15, 2));
      expect(after[0].$2 / damage, closeTo(1.0, 0.05));
      expect(after[1].$1 - frame, closeTo(30, 2));
      expect(after[1].$2 / damage, closeTo(MysticTuning.aftershockStrength, 0.05));
    });

    /// Lights [element]'s world with the path through [throughTier] and
    /// gives it what it needs to act, until [done] says something it did has
    /// been done again. With [deaths], a body far from everything dies every
    /// few frames, whoever killed it.
    Future<MysticMasteryState?> repeats(
      String element, {
      int throughTier = 4,
      bool deaths = false,
      bool Function(MysticMasteryState state)? done,
    }) async {
      done ??= (s) => s.replays > 0;
      final game = await arena(
        element: element,
        snapshot: equip(MysticNodes.quickeningPath, throughTier: throughTier),
      );
      expect(await lightWorld(game), isTrue, reason: element);
      final comp = game.activeCompanions[0]!;
      final orb = game.orb.position;
      for (var i = 0; i < 60 * 30; i++) {
        final state = game.mysticMasteryFor(0);
        if (state != null && done(state)) break;
        if (deaths && i % 7 == 0) {
          final dying = body(orb + const Offset(-330, 280), hp: 1);
          game.enemies.add(dying);
          game.debugKillEnemy(dying);
        }
        game.orb.currentHp = game.orb.maxHp;
        final live = game.enemies.where((e) => !e.isDead).toList();
        switch (element) {
          case 'Poison':
            // The ship lays the world as it flies.
            final a = i / 40;
            game.ship.position = orb + Offset(cos(a), sin(a)) * 180;
          case 'Light':
            if (i % 60 == 0) game.debugRushMysticDawn(0);
          case 'Blood' || 'Mud':
            if (live.isNotEmpty && i % 10 == 0) {
              game.debugAutoAttackDamage(live.first, 3, sourceSlotIndex: 1);
            }
          case 'Dust':
            if (live.isNotEmpty && i % 10 == 0) game.debugRollHaze(live.first);
          case 'Dark':
            final maw = game.mysticMawPosition(0);
            if (maw != null && i % 30 == 0) game.enemies.add(body(maw));
          case 'Lava':
            final crack = game.mysticFissurePointNear(0);
            if (crack != null && i % 60 == 0) {
              game.enemies.add(body(crack, tier: EnemyTier.brute));
            }
          case 'Crystal':
            // Bodies die under the ship, and the ship takes what they drop.
            if (i % 5 == 0) {
              final dying = body(game.ship.position, hp: 1);
              game.enemies.add(dying);
              game.debugKillEnemy(dying);
            }
          case 'Spirit':
            if (i % 20 == 0) {
              final dying = body(orb + const Offset(120, 0), hp: 1);
              game.enemies.add(dying);
              game.debugKillEnemy(dying);
            }
        }
        comp.specialCooldown = double.infinity;
        game.update(1 / 60);
      }
      return game.mysticMasteryFor(0);
    }

    const allWorlds = [
      'Fire',
      'Spirit',
      'Blood',
      'Dark',
      'Plant',
      'Lightning',
      'Poison',
      'Mud',
      'Earth',
      'Ice',
      'Crystal',
      'Light',
      'Dust',
      'Steam',
      'Lava',
      'Water',
      'Air',
    ];

    test('every world repeats its act, Ice included', () async {
      expect(allWorlds, hasLength(17));
      final silent = <String>[];
      for (final element in allWorlds) {
        if (((await repeats(element))?.replays ?? 0) == 0) silent.add(element);
      }
      expect(silent, isEmpty, reason: 'these worlds never acted again');
    });

    test('Quickening reaches all seventeen worlds: a death after an act makes '
        'each of them act again', () async {
      final silent = <String>[];
      for (final element in allWorlds) {
        // First Light too, so a world on a long clock (Earth's quake is half
        // a minute) has acted by the time the deaths come. Neither node
        // repeats anything by itself.
        final state = await repeats(
          element,
          throughTier: 2,
          deaths: true,
          done: (s) => s.quickenings > 0,
        );
        if ((state?.quickenings ?? 0) == 0) silent.add(element);
        // Quickening alone queues no Aftershock or Relentless Sky.
        expect(state?.replays ?? 0, 0, reason: element);
      }
      expect(silent, isEmpty, reason: 'deaths never made these act again');
    });

  });

  group('the Ice world acts only for Quickening', () {
    /// Runs a lit Ice world for [seconds] with a crowd standing in it,
    /// returning the slowest any body was held to on each frame.
    Future<(CosmicSurvivalGame, List<double>)> blizzard({
      SurvivalFamilyMasterySnapshot? snapshot,
      int seconds = 14,
    }) async {
      final game = await arena(element: 'Ice', snapshot: snapshot);
      final comp = game.activeCompanions[0]!;
      final crowd = [
        for (var i = 0; i < 6; i++)
          body(game.orb.position + Offset(-300.0 + 40 * i, -260)),
      ];
      void step() {
        // The wave's own bodies go quietly: a death would quicken the world.
        for (final e in game.enemies) {
          if (!crowd.contains(e)) e.isDead = true;
        }
        for (final e in crowd) {
          if (!game.enemies.contains(e)) game.enemies.add(e);
        }
        game.orb.currentHp = game.orb.maxHp;
        game.update(1 / 60);
      }

      for (var i = 0; i < 60 * 40 && !game.debugMysticWorldLit(0); i++) {
        if (comp.specialCooldown > 0) comp.specialCooldown = 0;
        step();
      }
      expect(game.debugMysticWorldLit(0), isTrue);
      final held = <double>[];
      for (var i = 0; i < 60 * seconds; i++) {
        comp.specialCooldown = double.infinity;
        step();
        held.add(crowd.map((e) => e.blizzardMultiplier).reduce(min));
      }
      return (game, held);
    }

    test('without the path the blizzard is as it was: a steady slow, no '
        'clock and no freeze', () async {
      final (plain, held) = await blizzard();
      expect(plain.mysticClockLeft(0), isNull);
      expect(plain.mysticWorldBeat(0), isNull);
      // The same factor every frame, and never a freeze.
      expect(held.toSet(), hasLength(1));
      expect(held.first, lessThan(1.0));
      expect(held.first, greaterThan(MysticTuning.iceFreezeSpeed));
      // The other path leaves it alone too.
      final (_, firm) = await blizzard(
        snapshot: equip(MysticNodes.firmamentPath),
      );
      expect(firm.toSet(), {held.first});
    });

    /// Frames each freeze held everything, freeze by freeze.
    List<int> freezes(List<double> held) {
      final runs = <int>[];
      var run = 0;
      for (final f in held) {
        if (f <= MysticTuning.iceFreezeSpeed) {
          run++;
        } else if (run > 0) {
          runs.add(run);
          run = 0;
        }
      }
      if (run > 0) runs.add(run);
      return runs;
    }

    test('with Quickening the blizzard freezes everything on a beat', () async {
      final (game, held) = await blizzard(
        snapshot: equip(MysticNodes.quickeningPath, throughTier: 1),
      );
      final beat = game.mysticWorldBeat(0);
      expect(beat, isNotNull);
      final runs = freezes(held);
      expect(runs, isNotEmpty, reason: 'the blizzard never froze');
      // Once a beat, each for its share of the beat.
      expect(runs.length, (14 / beat!).floor());
      for (final run in runs.take(2)) {
        expect(run / 60, closeTo(beat * MysticTuning.iceActHoldShare, 0.05));
      }
      expect(game.mysticStrikeCount(0), runs.length);
    });

    test('First Light freezes on ignition; Aftershock and Relentless Sky '
        'hold each freeze longer', () async {
      final (game, held) = await blizzard(
        snapshot: equip(MysticNodes.quickeningPath, throughTier: 2),
        seconds: 1,
      );
      expect(
        held.first,
        lessThanOrEqualTo(MysticTuning.iceFreezeSpeed),
        reason: 'First Light: frozen from the first frame',
      );
      expect(game.mysticStrikeCount(0), 1);

      Future<int> firstFreeze(int tier) async {
        final (_, held) = await blizzard(
          snapshot: equip(MysticNodes.quickeningPath, throughTier: tier),
          seconds: 3,
        );
        return freezes(held).first;
      }

      final one = await firstFreeze(2);
      expect(
        await firstFreeze(3),
        closeTo(one * (1 + MysticTuning.aftershockStrength), 3),
      );
      expect(
        await firstFreeze(4),
        closeTo(
          one *
              (1 +
                  MysticTuning.aftershockStrength +
                  MysticTuning.relentlessStrength),
          3,
        ),
      );
    });
  });

  group('Firmament shelters the team', () {
    test('an ally in the world takes less and the world mends them', () async {
      final game = await arena(
        snapshot: equip(MysticNodes.firmamentPath, throughTier: 3),
      );
      expect(await lightWorld(game), isTrue);
      final comp = game.activeCompanions[0]!;

      // Hurt the ship, stand it in the world, and let Tended work.
      game.ship.currentHp = game.ship.maxHp * 0.3;
      final before = game.ship.currentHp;
      for (var i = 0; i < 60 * 10; i++) {
        game.ship.position = comp.position;
        game.update(1 / 60);
      }
      expect(
        game.mysticMasteryFor(0)?.healedInside ?? 0,
        greaterThanOrEqualTo(0),
      );
      expect(game.ship.currentHp, greaterThan(before));
    });

    test('an unequipped Mystic shelters nobody', () async {
      final game = await arena();
      await lightWorld(game);
      expect(game.mysticMasteryFor(0), isNull);
    });
  });
}
