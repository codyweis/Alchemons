import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_horn.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_kin.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mask.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mystic.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_pip.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_runtime.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_wing.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 2026-10-21 sweep of every survival Family Mastery path: the nodes
/// whose text promised more than the game did, driven through the real
/// game. The per-path shares this sweep measured are in
/// docs/audits/survival_families_2026-10-20.md ("Mastery sweep").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member(String family, String element, int slot) =>
      CosmicPartyMember(
        instanceId: '$family-$slot',
        baseId: switch (family) {
          'Horn' => 'HOR01',
          'Wing' => 'WNG01',
          'Kin' => 'KIN01',
          'Mask' => 'MSK01',
          'Mystic' => 'MYS01',
          'Mane' => 'MAN01',
          'Pip' => 'PIP01',
          _ => 'LET01',
        },
        displayName: '$family $element',
        family: family,
        element: element,
        level: 10,
        slotIndex: slot,
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

  /// [pathId] bought through [throughTier] for the party member in slot 0.
  SurvivalFamilyMasterySnapshot equip(
    CosmicPartyMember m,
    String pathId, {
    int throughTier = 4,
  }) {
    final family = creatureFamilyFromStorage(m.family)!;
    final path = FamilyMasteryCatalog.pathFor(family, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      m.slotIndex: EquippedFamilyMastery(
        instanceId: m.instanceId,
        family: family,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  Future<CosmicSurvivalGame> arena(
    List<CosmicPartyMember> party, {
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: party,
      onGameOver: () {},
      masterySnapshot: snapshot,
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    // One more on the field for each Pack Leader, as a run grants them.
    for (var i = 1; i < party.length; i++) {
      game.applyPowerUp(kAllPowerUps.firstWhere((d) => d.id == 'pack_leader'));
    }
    game.startGame();
    for (var i = 0; i < party.length; i++) {
      game.summonCompanion(i);
    }
    game.clearCompanionTether();
    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    return game;
  }

  SurvivalBoss boss(Offset at, {double hp = 1e9}) => SurvivalBoss(
    template: kBossTemplates.first,
    type: BossType.gunner,
    level: 3,
    position: at,
    hp: hp,
    maxHp: hp,
    speed: 0,
    baseSpeed: 0,
    radius: 30,
    color: const Color(0xFFFFFFFF),
  );

  CosmicSurvivalEnemy dummy(
    CosmicSurvivalGame game,
    Offset at, {
    double hp = 1e9,
  }) {
    final template = game.enemies.first;
    return CosmicSurvivalEnemy(
      position: at,
      hp: hp,
      maxHp: hp,
      speed: 0,
      damage: 0,
      radius: 14,
      tier: template.tier,
      element: template.element,
      conduct: template.conduct,
      target: template.target,
    );
  }

  /// Clears the field to one stationary body at [at], so a test decides
  /// what its companions shoot.
  CosmicSurvivalEnemy onlyBody(CosmicSurvivalGame game, Offset at) {
    final body = dummy(game, at);
    for (final e in game.enemies) {
      e.isDead = true;
    }
    game.enemies.add(body);
    game.debugRebuildEnemyGrid();
    return body;
  }

  /// What [boss] lost to one hit through the game's real boss intake.
  double bossTook(
    CosmicSurvivalGame game,
    SurvivalBoss target,
    double damage, {
    required int slot,
    bool autoAttack = false,
  }) {
    final before = target.hp;
    game.damageBoss(
      damage,
      sourceSlotIndex: slot,
      target: target,
      autoAttack: autoAttack,
    );
    return before - target.hp;
  }

  group('Paths that reached bodies and not bosses', () {
    test('Ironhead puts a Horn\'s bulk into its auto-attacks on a boss',
        () async {
      final horn = member('Horn', 'Fire', 0);
      Future<double> hit(SurvivalFamilyMasterySnapshot? snap) async {
        final game = await arena([horn], snapshot: snap);
        final b = boss(game.orb.position + const Offset(200, 0));
        return bossTook(game, b, 40, slot: 0, autoAttack: true);
      }

      final plain = await hit(null);
      final bulwark = await hit(
        equip(horn, HornNodes.bulwarkPath, throughTier: 1),
      );
      expect(plain, greaterThan(0));
      expect(bulwark, greaterThan(plain * 1.2),
          reason: 'the weight never reached the boss');
    });

    test('Longshot pays a Wing for a far boss as for a far body', () async {
      final wing = member('Wing', 'Dark', 0);
      Future<double> hit(SurvivalFamilyMasterySnapshot? snap) async {
        final game = await arena([wing], snapshot: snap);
        final comp = game.activeCompanions[0]!;
        // Well past 60% of its range, with nothing closer.
        final b = boss(comp.position + Offset(comp.attackRange * 0.95, 0));
        for (final e in game.enemies) {
          e.isDead = true;
        }
        game.debugRebuildEnemyGrid();
        return bossTook(game, b, 40, slot: 0, autoAttack: true);
      }

      final plain = await hit(null);
      final longshot = await hit(
        equip(wing, WingNodes.longshotPath, throughTier: 1),
      );
      expect(longshot / plain, closeTo(1 + WingTuning.rangefinderBonus, 0.01));
    });

    test('Weight of Heaven lands on a boss', () async {
      final mystic = member('Mystic', 'Lightning', 0);
      Future<double> hit(int tier) async {
        final game = await arena(
          [mystic],
          snapshot: equip(mystic, MysticNodes.quickeningPath, throughTier: tier),
        );
        expect(await _lightWorld(game), isTrue);
        final b = boss(game.orb.position + const Offset(200, 0));
        return bossTook(game, b, 40, slot: 0);
      }

      final without = await hit(2);
      final weighted = await hit(3);
      expect(weighted / without, closeTo(MysticTuning.weightOfHeaven, 0.01));
    });

    test('Home Ground lifts what an ally deals from inside the world, '
        'its special and on a boss included', () async {
      final mystic = member('Mystic', 'Lightning', 0);
      final mane = member('Mane', 'Fire', 1);
      Future<(double, double)> hits(int tier) async {
        final game = await arena(
          [mystic, mane],
          snapshot: equip(mystic, MysticNodes.firmamentPath, throughTier: tier),
        );
        expect(await _lightWorld(game), isTrue);
        game.activeCompanions[1]!.position =
            game.activeCompanions[0]!.position + const Offset(40, 0);
        final b = boss(game.orb.position + const Offset(300, 0));
        final onBoss = bossTook(game, b, 40, slot: 1);
        final body = dummy(game, game.orb.position + const Offset(-300, 0));
        game.enemies.add(body);
        final before = body.hp;
        game.debugAbilityDamage(body, 40, sourceSlotIndex: 1);
        return (onBoss, before - body.hp);
      }

      final (bossWithout, bodyWithout) = await hits(1);
      final (bossWith, bodyWith) = await hits(2);
      final lift = 1 + MysticTuning.homeGroundPower;
      expect(bossWith / bossWithout, closeTo(lift, 0.01));
      expect(bodyWith / bodyWithout, closeTo(lift, 0.01));
    });
  });

  group('Nodes that did less than their text', () {
    test('Weight Behind It: a Horn whose special strikes nothing carries the '
        'weight on its attacks instead', () async {
      Future<(double, double)> hits(String element) async {
        final horn = member('Horn', element, 0);
        Future<double> at(int tier) async {
          final game = await arena(
            [horn],
            snapshot: equip(horn, HornNodes.bulwarkPath, throughTier: tier),
          );
          final b = boss(game.orb.position + const Offset(200, 0));
          return bossTook(game, b, 40, slot: 0, autoAttack: true);
        }

        return (await at(1), await at(2));
      }

      // Air's special is a wind that pushes and never strikes.
      final (airIronhead, airWeighted) = await hits('Air');
      expect(airWeighted, greaterThan(airIronhead * 1.15));
      // A charging Horn's weight goes into its charge, not its attacks.
      final (fireIronhead, fireWeighted) = await hits('Fire');
      expect(fireWeighted, closeTo(fireIronhead, 0.01));
    });

    test('Pin Cushion: the special\'s darts read the Pins too', () async {
      final pip = member('Pip', 'Fire', 0);
      final game = await arena(
        [pip],
        snapshot: equip(pip, 'pip.assault', throughTier: 2),
      );
      for (var i = 0; i < 600 && game.pipMasteryFor(0) == null; i++) {
        game.update(1 / 60);
      }
      final state = game.pipMasteryFor(0)!;
      final pinned = boss(game.orb.position + const Offset(200, 0));
      final bare = boss(game.orb.position + const Offset(-200, 0));
      for (var i = 0; i < 5; i++) {
        state.addPin(identityHashCode(pinned), game.mastery.clock);
      }
      int specialCast() => game.mastery.beginCast(
        slotIndex: 0,
        family: CreatureFamily.pip,
        element: 'Fire',
        kind: MasteryCastKind.special,
        projectileCount: 1,
      );
      double took(SurvivalBoss b) {
        final before = b.hp;
        game.damageBoss(40, sourceSlotIndex: 0, target: b,
            masteryCastId: specialCast());
        return before - b.hp;
      }

      expect(
        took(pinned) / took(bare),
        closeTo(1 + 5 * PipTuning.pinDamagePerStack, 0.01),
      );
    });

    test('Three Fronts pays every one of the three bodies', () async {
      final pip = member('Pip', 'Fire', 0);
      final game = await arena(
        [pip],
        snapshot: equip(pip, 'pip.control', throughTier: 2),
      );
      for (var i = 0; i < 600 && game.pipMasteryFor(0) == null; i++) {
        game.update(1 / 60);
      }
      final bodies = [
        for (var i = 0; i < 3; i++)
          boss(game.orb.position + Offset(150.0 + i * 120, 0)),
      ];
      final volley = game.mastery.beginCast(
        slotIndex: 0,
        family: CreatureFamily.pip,
        element: 'Fire',
        kind: MasteryCastKind.basic,
        projectileCount: 3,
      );
      for (final b in bodies) {
        game.damageBoss(40, sourceSlotIndex: 0, target: b,
            masteryCastId: volley, autoAttack: true);
      }
      final took = [for (final b in bodies) b.maxHp - b.hp];
      // Each took its dart and the 20% on top, the first two as well.
      expect(took[0], closeTo(took[2], 0.01));
      expect(took[0], greaterThan(took[2] / 1.21));
    });

    test('Sighted: the Let\'s special lands harder on what it Sighted',
        () async {
      final let = member('Let', 'Fire', 0);
      final game = await arena(
        [let],
        snapshot: equip(let, 'let.ground_zero', throughTier: 1),
      );
      final sighted = boss(game.orb.position + const Offset(200, 0))
        ..applyLetSight(
          slotIndex: 0,
          duration: 6,
          calledShot: false,
          fireForEffect: false,
        );
      final bare = boss(game.orb.position + const Offset(-200, 0));
      final a = bossTook(game, sighted, 40, slot: 0);
      final b = bossTook(game, bare, 40, slot: 0);
      expect(a / b, closeTo(1.20, 0.01));
    });

    test('Longshot: the special\'s hits far out are paid too', () async {
      final wing = member('Wing', 'Dark', 0);
      Future<double> hit(SurvivalFamilyMasterySnapshot? snap) async {
        final game = await arena([wing], snapshot: snap);
        final comp = game.activeCompanions[0]!;
        for (final e in game.enemies) {
          e.isDead = true;
        }
        game.debugRebuildEnemyGrid();
        final b = boss(comp.position + Offset(comp.attackRange * 0.95, 0));
        return bossTook(game, b, 40, slot: 0);
      }

      final plain = await hit(null);
      final longshot = await hit(
        equip(wing, WingNodes.longshotPath, throughTier: 1),
      );
      expect(longshot / plain, closeTo(1 + WingTuning.rangefinderBonus, 0.01));
    });
  });

  group('Burn Through', () {
    /// The most dwell a Wing's beam builds on one body it holds.
    Future<double> peakDwell(int tier) async {
      final wing = member('Wing', 'Dark', 0);
      final game = await arena(
        [wing],
        snapshot: equip(wing, WingNodes.burnThroughPath, throughTier: tier),
      );
      final comp = game.activeCompanions[0]!;
      // Out from the orb: a body that reaches it is spent on it.
      final body = onlyBody(game, game.orb.position + const Offset(380, 0));
      comp.position = game.orb.position + const Offset(200, 0);
      comp.specialCooldown = 0;
      var peak = 0.0;
      for (var i = 0; i < 60 * 6; i++) {
        _keepOnly(game, body);
        game.update(1 / 60);
        if (body.wingBeamDwell > peak) peak = body.wingBeamDwell;
      }
      return peak;
    }

    test('Bore holds its ramp between the beam\'s ticks', () async {
      // The beam ticks every 0.12-0.28 s, and the ramp used to fall away on
      // every frame between two ticks, so before No Reprieve it never got
      // past one tick's worth: Bore and Deeper bought almost nothing.
      expect(await peakDwell(1), greaterThan(1.0));
    });

    test('a beam held on a boss builds the same ramp', () async {
      final wing = member('Wing', 'Dark', 0);
      final game = await arena(
        [wing],
        snapshot: equip(wing, WingNodes.burnThroughPath, throughTier: 2),
      );
      final comp = game.activeCompanions[0]!;
      // The boss stands on the line to the only body, so the beam held on
      // the body runs through it.
      final body = onlyBody(game, game.orb.position + const Offset(460, 0));
      final b = boss(game.orb.position + const Offset(330, 0));
      game.activeBoss = b;
      comp.position = game.orb.position + const Offset(200, 0);
      comp.specialCooldown = 0;
      var peak = 0.0;
      for (var i = 0; i < 60 * 5; i++) {
        _keepOnly(game, body);
        game.update(1 / 60);
        if (b.wingBeamDwell > peak) peak = b.wingBeamDwell;
      }
      expect(peak, greaterThan(0.5), reason: 'the boss never took the ramp');
    });
  });

  group('Benediction', () {
    test('Deep Reserves strengthens the heals and shields a Kin hands out',
        () async {
      final kin = member('Kin', 'Water', 0);
      Future<(int, int)> support(int tier) async {
        final game = await arena(
          [kin],
          snapshot: equip(kin, KinNodes.benedictionPath, throughTier: tier),
        );
        final comp = game.activeCompanions[0]!;
        comp.currentHp = 1;
        comp.shieldHp = 0;
        game.debugApplySpecialSupport(
          0,
          const CosmicSpecialResult(shieldHp: 100, selfHeal: 100),
        );
        return (comp.shieldHp, comp.currentHp - 1);
      }

      final (shieldBefore, healBefore) = await support(1);
      final (shieldAfter, healAfter) = await support(2);
      expect(shieldAfter, (shieldBefore * KinTuning.deepReservesPower).round());
      expect(healAfter, (healBefore * KinTuning.deepReservesPower).round());
    });

    test('Communion reaches the ship', () async {
      final kin = member('Kin', 'Water', 0);
      Future<double> shipMended(int tier) async {
        final game = await arena(
          [kin],
          snapshot: equip(kin, KinNodes.benedictionPath, throughTier: tier),
        );
        game.ship.currentHp = game.ship.maxHp * 0.2;
        final before = game.ship.currentHp;
        game.debugApplySpecialSupport(
          0,
          const CosmicSpecialResult(blessingTimer: 4, blessingHealPerTick: 200),
        );
        for (var i = 0; i < 60 * 3; i++) {
          game.ship.position = game.orb.position + const Offset(0, -400);
          game.update(1 / 60);
        }
        return game.ship.currentHp - before;
      }

      final without = await shipMended(3);
      final communion = await shipMended(4);
      expect(communion, greaterThan(without + 5));
    });
  });

  test('Communion: a shared blessing mends its ally, not the orb again',
      () async {
    final kin = member('Kin', 'Water', 0);
    final party = [kin, member('Mane', 'Fire', 1), member('Pip', 'Fire', 2)];
    Future<double> orbMended(int tier) async {
      final game = await arena(
        party,
        snapshot: equip(kin, KinNodes.benedictionPath, throughTier: tier),
      );
      for (final comp in game.activeCompanions.values) {
        comp.specialCooldown = 99999;
        comp.currentHp = comp.maxHp ~/ 2;
      }
      game.orb.currentHp = game.orb.maxHp * 0.3;
      final before = game.orb.currentHp;
      game.debugApplySpecialSupport(
        0,
        const CosmicSpecialResult(blessingTimer: 4, blessingHealPerTick: 40),
      );
      for (var i = 0; i < 60 * 2; i++) {
        for (final comp in game.activeCompanions.values) {
          comp.specialCooldown = 99999;
        }
        for (final e in game.enemies) {
          e.isDead = true;
        }
        game.update(1 / 60);
      }
      return game.orb.currentHp - before;
    }

    final caster = await orbMended(3);
    final shared = await orbMended(4);
    expect(caster, greaterThan(0));
    // Two allies share it. Every copy used to echo into the orb as well,
    // which is three times the caster's own.
    expect(shared, lessThan(caster * 1.3));
  });

  group('Rearm', () {
    /// The life a Mask trap comes back with after it is spent: the life of
    /// the first new fixture seen once the placed one has gone.
    Future<double> rearmedLife(int tier) async {
      final mask = member('Mask', 'Lightning', 0);
      final game = await arena(
        [mask],
        snapshot: equip(mask, MaskNodes.rearmPath, throughTier: tier),
      );
      final comp = game.activeCompanions[0]!;
      comp.specialCooldown = 0;
      bool isTrap(Projectile p) =>
          p.abilityFamily == 'mask' && p.stationary && p.life > 0;
      for (var i = 0; i < 60 * 8; i++) {
        game.update(1 / 60);
        if (game.companionProjectiles.any(isTrap)) break;
      }
      final placed = game.companionProjectiles.where(isTrap).toList();
      expect(placed, isNotEmpty, reason: 'the Mask never placed a trap');
      for (final p in placed) {
        p.life = 0.001;
      }
      for (var i = 0; i < 60 * 4; i++) {
        comp.specialCooldown = 99999;
        game.update(1 / 60);
        for (final p in game.companionProjectiles) {
          if (isTrap(p) && !placed.any((q) => identical(p, q))) return p.life;
        }
      }
      return 0;
    }

    test('Hair Trigger: a trap comes back with the life it was placed with',
        () async {
      // Lightning's trap is placed for 12 s. Spring Again alone brings it
      // back for 6 s; Hair Trigger says re-arming no longer shortens it.
      expect(await rearmedLife(1), lessThan(6.5));
      expect(await rearmedLife(2), greaterThan(9));
    });
  });
}

/// Clears every body but [body] the spawner has added since, so a beam's
/// nearest target stays the one a test put down.
void _keepOnly(CosmicSurvivalGame game, CosmicSurvivalEnemy body) {
  for (final e in game.enemies) {
    if (!identical(e, body)) e.isDead = true;
  }
}

/// Runs until the Mystic in slot 0 has lit its world.
Future<bool> _lightWorld(CosmicSurvivalGame game, {int seconds = 40}) async {
  final comp = game.activeCompanions[0]!;
  for (var i = 0; i < 60 * seconds; i++) {
    if (game.debugMysticWorldLit(0)) return true;
    if (comp.specialCooldown > 0) comp.specialCooldown = 0;
    game.update(1 / 60);
  }
  return game.debugMysticWorldLit(0);
}
