import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/horn_runtime.dart';
import 'package:alchemons/games/cosmic/mane_runtime.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_horn.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mane.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// The survival bugs the 2026-10-20 family audit found, each driven through
/// the real game.
///
/// Two kinds. The first group are crashes and exploits: a Light Mane that
/// threw on a full projectile pool, a Crystal Mane that executed any boss, a
/// Light Wing whose beam split on every kill, a Bodyguard whose share vanished
/// into hit invulnerability, a Steam haste that never came back down, a Fire
/// phoenix that missed half the ways an orb can die, and a Mud weight that
/// thought drones outweighed brutes. The second group are kits that did
/// nothing at all to a boss, on the waves where a boss is the whole fight.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseIds = {
    'Horn': 'HRN01',
    'Mane': 'MAN01',
    'Wing': 'WNG01',
    'Kin': 'KIN01',
  };

  CosmicPartyMember member(String family, String element, {int slot = 0}) =>
      CosmicPartyMember(
        instanceId: '${family.toLowerCase()}-$slot',
        baseId: baseIds[family] ?? 'HRN01',
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

  SurvivalFamilyMasterySnapshot equip(
    CreatureFamily family,
    String pathId, {
    int throughTier = 4,
  }) {
    final path = FamilyMasteryCatalog.pathFor(family, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: '${family.name}-0',
        family: family,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  /// A cleared arena: the party is out, the opening wave is dead, the ship is
  /// parked far away with its guns held, and nothing holds the orb's shield.
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
    for (var i = 1; i < party.length; i++) {
      game.applyPowerUp(kAllPowerUps.firstWhere((d) => d.id == 'pack_leader'));
    }
    game.startGame();
    for (var i = 0; i < party.length; i++) {
      game.summonCompanion(i);
    }
    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    for (final e in game.enemies) {
      e.isDead = true;
    }
    game.orb.shieldHp = 0;
    game.ship.position = game.orb.position + const Offset(0, 900);
    game.ship.fireTimer = -1e9;
    return game;
  }

  CosmicSurvivalEnemy body(
    CosmicSurvivalGame game,
    Offset at, {
    double hp = 1e6,
    EnemyTrait? trait,
  }) {
    final e = CosmicSurvivalEnemy(
      position: at,
      hp: hp,
      maxHp: hp,
      speed: 0,
      damage: 0,
      radius: 11,
      tier: EnemyTier.drone,
      element: 'Ice',
      target: CosmicEnemyTarget.orb,
      conduct: EnemyConduct.stalk,
      trait: trait,
    );
    game.enemies.add(e);
    return e;
  }

  /// A boss standing still with its shield down, so what it loses is exactly
  /// what the kit under test dealt it.
  SurvivalBoss boss(CosmicSurvivalGame game, Offset at, {bool spawning = false}) {
    final b = game.spawner.createBossForWave(5, at)!;
    b
      ..position = at
      ..spawnIntroTimer = spawning ? 2.0 : 0
      ..spawnFromPosition = spawning ? at : null
      ..spawnTargetPosition = spawning ? at : null
      ..chillTimer = 1e9
      ..chillMultiplier = 0
      ..shieldUp = false
      ..shieldTimer = 1e9;
    game.activeBoss = b;
    return b;
  }

  /// Frames with the party's own attacks held, so only the effect under test
  /// touches anything, and anything the spawner sends in is put down at once.
  void run(
    CosmicSurvivalGame game,
    int frames, {
    Set<CosmicSurvivalEnemy> keep = const {},
    SurvivalBoss? still,
    bool holdBasics = true,
  }) {
    for (var f = 0; f < frames; f++) {
      for (final comp in game.activeCompanions.values) {
        comp.specialCooldown = 99999;
        if (holdBasics) comp.basicCooldown = 99999;
      }
      for (final e in game.enemies) {
        if (!keep.contains(e)) e.isDead = true;
      }
      if (still != null) {
        still
          ..shieldUp = false
          ..shieldTimer = 1e9;
      }
      game.update(1 / 60);
    }
  }

  group('crashes and exploits', () {
    test(
      'a Light Mane with Endless Circuit casts into a full pool without throwing',
      () async {
        // The ward's new ring was refused at the 220 cap, so there was no ring
        // to send to the rim, and the capstone fell through to the ordinary
        // projectile path with an empty list and asked it for its first shot.
        final game = await arena(
          [member('Mane', 'Light')],
          snapshot: equip(CreatureFamily.mane, ManeNodes.limitlessPath),
        );
        final comp = game.activeCompanions[0]!;
        final target = body(game, comp.position + const Offset(90, 0));
        while (game.companionProjectiles.length < 220) {
          game.companionProjectiles.add(
            Projectile(
              position: game.orb.position + const Offset(-900, 0),
              angle: 0,
              life: 9999,
              damage: 0,
              stationary: true,
            ),
          );
        }
        comp.specialCooldown = 0;
        comp.basicCooldown = 99999;
        for (var f = 0; f < 30; f++) {
          target
            ..isDead = false
            ..position = comp.position + const Offset(90, 0);
          game.update(1 / 60);
        }
        expect(game.isGameOver, isFalse);
      },
    );

    group('Crystal Mane on a boss', () {
      Projectile crystalShot(Offset at, double damage) => Projectile(
        position: at,
        angle: 0,
        element: 'Crystal',
        damage: damage,
        life: 2,
        speedMultiplier: 0.1,
        piercing: true,
        abilityFamily: 'mane',
        sourceSlotIndex: 0,
      );

      test('explodes for heavy damage, never an execute', () async {
        final game = await arena([member('Mane', 'Crystal')]);
        final b = boss(game, game.orb.position + const Offset(320, 0));
        b.shieldUp = true;
        b.shieldHealth = SurvivalBoss.shieldMaxHealth;
        final shot = b.maxHp * 0.05;
        final bystander = body(game, b.position + Offset(b.radius + 60, 0));
        game.companionProjectiles.add(crystalShot(b.position, shot));
        game.update(1 / 60);

        expect(b.isDead, isFalse, reason: 'the shot executed the boss');
        final lost = b.maxHp - b.hp;
        // Heavier than the shot itself, after the family's boss multiplier.
        expect(lost, greaterThan(shot));
        expect(lost, lessThan(b.maxHp * 0.5));
        expect(b.shieldUp, isFalse, reason: 'the burst still breaks a shield');
        expect(
          bystander.hp,
          lessThan(bystander.maxHp),
          reason: 'the blast reaches what stands round the boss',
        );
      });

      test('passes through a boss that is still flying in', () async {
        final game = await arena([member('Mane', 'Crystal')]);
        final b = boss(
          game,
          game.orb.position + const Offset(320, 0),
          spawning: true,
        );
        game.companionProjectiles.add(crystalShot(b.position, b.maxHp * 0.05));
        game.update(1 / 60);
        expect(b.hp, b.maxHp);
      });
    });

    group('Light Wing refraction', () {
      const lightBeam = WingBeamEffect(
        element: 'Light',
        targetPolicy: WingBeamTargetPolicy.nearestEnemy,
        duration: 4,
        tickInterval: 0.1,
        damagePerTick: 40,
        range: 520,
      );

      int beamsOf(CosmicSurvivalGame game, int slot) =>
          game.debugWingBeams.where((b) => b.slot == slot).length;

      test('a beam refracts once, however many it kills', () async {
        final game = await arena([member('Wing', 'Light')]);
        final comp = game.activeCompanions[0]!;
        final origin = comp.position;
        final prey = {
          for (var i = 0; i < 24; i++)
            body(
              game,
              origin + Offset(110.0 + (i % 6) * 18, -40.0 + (i ~/ 6) * 26),
              hp: 1,
            ),
        };
        final anchor = body(game, origin + const Offset(260, 0));
        game.debugCastWingBeam(0, lightBeam);
        var peak = 0;
        for (var f = 0; f < 120; f++) {
          comp.position = origin;
          run(game, 1, keep: {...prey, anchor});
          peak = max(peak, beamsOf(game, 0));
        }
        expect(prey.where((e) => e.isDead).length, greaterThan(3));
        expect(
          peak,
          lessThanOrEqualTo(1 + 3),
          reason: 'one cast held $peak beams',
        );
      });

      test('the split beams hunt other bodies, not the parent\'s', () async {
        final game = await arena([member('Wing', 'Light')]);
        final comp = game.activeCompanions[0]!;
        final origin = comp.position;
        final prey = body(game, origin + const Offset(110, 0), hp: 1);
        final a = body(game, origin + const Offset(150, 40));
        final b = body(game, origin + const Offset(170, -60));
        final d = body(game, origin + const Offset(200, 90));
        final keep = {prey, a, b, d};
        game.debugCastWingBeam(0, lightBeam);
        for (var f = 0; f < 20; f++) {
          comp.position = origin;
          run(game, 1, keep: keep);
        }
        expect(prey.isDead, isTrue);
        final beams = game.debugWingBeams.where((x) => x.slot == 0).toList()
          ..sort((x, y) => y.damagePerTick.compareTo(x.damagePerTick));
        expect(beams.length, greaterThan(1), reason: 'the kill never split');
        final parentEnd = beams.first.end!;
        final childEnds = [for (final c in beams.skip(1)) c.end!];
        for (final end in childEnds) {
          expect(
            (end - parentEnd).distance,
            greaterThan(20),
            reason: 'a split beam is sitting on the parent\'s target',
          );
        }
        expect(
          (childEnds.first - childEnds.last).distance,
          greaterThan(20),
          reason: 'the split beams share one target',
        );
      });

      test('a full beam pool gives up the caster\'s own beams', () async {
        // Fifteen of one Wing's beams must not push another Wing's beam off
        // the field: the cap takes the caster's oldest instead.
        final game = await arena([
          member('Wing', 'Light'),
          member('Wing', 'Mud', slot: 1),
        ]);
        final target = body(
          game,
          game.activeCompanions[0]!.position + const Offset(150, 0),
        );
        game.debugCastWingBeam(
          1,
          const WingBeamEffect(
            element: 'Mud',
            targetPolicy: WingBeamTargetPolicy.nearestEnemy,
            duration: 8,
            tickInterval: 0.25,
            damagePerTick: 1,
            range: 900,
          ),
        );
        for (var i = 0; i < WingBeamRules.beamCap + 1; i++) {
          game.debugCastWingBeam(
            0,
            const WingBeamEffect(
              element: 'Light',
              targetPolicy: WingBeamTargetPolicy.nearestEnemy,
              duration: 4,
              tickInterval: 0.25,
              damagePerTick: 1,
              range: 900,
            ),
          );
          run(game, 1, keep: {target});
        }
        expect(beamsOf(game, 1), 1, reason: 'the other Wing lost its beam');
        expect(
          game.debugWingBeams.length,
          lessThanOrEqualTo(WingBeamRules.beamCap),
        );
      });
    });

    group('Bodyguard', () {
      test('the share lands on the Horn through its hit invulnerability', () async {
        final game = await arena(
          [member('Horn', 'Fire')],
          snapshot: equip(
            CreatureFamily.horn,
            HornNodes.bastionPath,
            throughTier: 2,
          ),
        );
        final comp = game.activeCompanions[0]!;
        comp.position = game.orb.position + const Offset(40, 0);
        // As if a body had struck it a moment ago.
        comp.invincibleTimer = 0.45;
        final hornBefore = comp.currentHp;
        final orbBefore = game.orb.currentHp;
        game.debugDamageOrb(400);
        final orbLoss = orbBefore - game.orb.currentHp;
        final incoming = orbLoss / (1 - HornTuning.bodyguardShare);
        expect(
          (hornBefore - comp.currentHp).toDouble(),
          closeTo(
            incoming *
                HornTuning.bodyguardShare *
                (1 - HornTuning.bodyguardMitigation),
            1.5,
          ),
          reason: 'the diverted share vanished',
        );
        expect(comp.invincibleTimer, closeTo(0.45, 1e-9));
      });

      test('a diverted chip does not hand the Horn invulnerability', () async {
        final game = await arena(
          [member('Horn', 'Fire')],
          snapshot: equip(
            CreatureFamily.horn,
            HornNodes.bastionPath,
            throughTier: 2,
          ),
        );
        final comp = game.activeCompanions[0]!;
        comp.position = game.orb.position + const Offset(40, 0);
        comp.invincibleTimer = 0;
        game.debugDamageOrb(400);
        expect(comp.invincibleTimer, 0);
      });
    });

    test('Steam haste follows the boiler back down', () async {
      final game = await arena([member('Kin', 'Steam')]);
      final comp = game.activeCompanions[0]!;
      comp.kinSteamBoilerTimer = 10;
      comp.kinSteamBoilerStacks = 10;
      run(game, 2);
      final hasted = comp.effectiveBasicCooldown;
      comp.kinSteamBoilerStacks = 0;
      comp.kinSteamStackCarry = 0;
      run(game, 2);
      final calm = comp.effectiveBasicCooldown;
      expect(
        calm,
        greaterThan(hasted * 1.5),
        reason: 'peak haste stuck after the stacks were gone',
      );
    });

    test('the phoenix catches an orb killed after the Kin has ticked', () async {
      // A boss round is resolved after the Kin's own tick in the frame, so
      // this death used to reach the game-over check unseen.
      final game = await arena([member('Kin', 'Fire')]);
      final comp = game.activeCompanions[0]!;
      comp.position = game.orb.position + const Offset(320, 0);
      game.orb.currentHp = 5;
      game.bossProjectiles.add(
        SurvivalBossProjectile(
          position: game.orb.position,
          angle: 0,
          element: 'Fire',
          damage: 1e6,
          speed: 0,
        ),
      );
      game.update(1 / 60);
      expect(game.isGameOver, isFalse);
      expect(comp.kinFireOrbitalFlameActive, isTrue);
      expect(game.orb.currentHp, greaterThan(0));
    });

    test('a Crystal world values a brute above a drone', () async {
      final game = await arena([member('Kin', 'Water')]);
      final bySize = [...EnemyTier.values]
        ..sort((x, y) => tierBaseHp(x).compareTo(tierBaseHp(y)));
      for (var i = 1; i < bySize.length; i++) {
        expect(
          game.debugMysticCrystalValue(bySize[i]),
          greaterThan(game.debugMysticCrystalValue(bySize[i - 1])),
          reason: '${bySize[i]} is not worth more than ${bySize[i - 1]}',
        );
      }
    });

    test(
      'a Bastion whose broken shield kills splitters in contact keeps going',
      () async {
        // Contact damage is taken inside a walk of the enemy list; Last Stand
        // ruptures in that walk, and a splitter it kills adds its shards.
        final game = await arena(
          [member('Horn', 'Fire')],
          snapshot: equip(CreatureFamily.horn, HornNodes.bastionPath),
        );
        final comp = game.activeCompanions[0]!;
        comp
          ..specialCooldown = 99999
          ..basicCooldown = 99999
          ..invincibleTimer = 0;
        game.hornMasteryFor(0)!.guardShield = 1;
        final at = comp.position;
        final splitters = [
          for (var i = 0; i < 6; i++)
            body(game, at + Offset(i * 2.0, 0), hp: 1, trait: EnemyTrait.splitter),
        ];
        game.update(1 / 60);
        expect(splitters.every((e) => e.isDead), isTrue);
      },
    );
  });

  group('kits that reach bosses', () {
    group('Horn', () {
      test('the ram hits a boss it ploughs through, once', () async {
        final game = await arena([member('Horn', 'Plant')]);
        final b = boss(game, game.orb.position + const Offset(300, 0));
        final comp = game.activeCompanions[0]!;
        final reach = b.radius + 120;
        comp
          ..position = b.position - Offset(reach, 0)
          ..chargeTarget = b.position + Offset(reach, 0)
          ..chargeTimer = 2.0
          ..chargeHitIds = <int>{}
          ..chargeDamage = 300
          ..chargeSweepRadius = 20
          ..chargeFinalSweepRadius = 20
          ..chargeSpeedMultiplier = 1.0;
        run(game, 150, still: b);
        final rammed = b.maxHp - b.hp;
        expect(rammed, greaterThan(0), reason: 'the ram went through the boss');
        final before = b.hp;
        game.damageBoss(
          300,
          attackElement: 'Plant',
          sourceSlotIndex: 0,
          target: b,
        );
        expect(rammed, closeTo(before - b.hp, 1e-6), reason: 'not once');
      });

      test('the slam at the end of the ram hits a boss beside it', () async {
        final game = await arena([member('Horn', 'Plant')]);
        final b = boss(game, game.orb.position + const Offset(300, 0));
        final comp = game.activeCompanions[0]!;
        final at = b.position - Offset(b.radius + 30, 0);
        comp
          ..position = at
          ..chargeTarget = at
          ..chargeTimer = 0.05
          ..chargeHitIds = <int>{}
          ..chargeDamage = 300
          ..chargeSweepRadius = 10
          ..chargeFinalSweepRadius = 60
          ..chargeSpeedMultiplier = 1.0;
        run(game, 20, still: b);
        expect(b.hp, lessThan(b.maxHp));
      });

      for (final (name, element, effect) in [
        ('a Fire patch', 'Fire', AbilityEffectKind.burn),
        ('a Steam geyser', 'Steam', AbilityEffectKind.geyser),
        ('an Earth quake', 'Earth', AbilityEffectKind.zoneDamage),
        ('a Dark void', 'Dark', AbilityEffectKind.blackHole),
        ('a Lightning chain zone', 'Lightning', AbilityEffectKind.chain),
      ]) {
        test('$name ticks a boss standing in it', () async {
          final game = await arena([member('Horn', 'Plant')]);
          final b = boss(game, game.orb.position + const Offset(300, 0));
          game.companionProjectiles.add(
            element == 'Fire'
                ? hornFireTrailSegment(
                    position: b.position,
                    abilityAtk: 200,
                    sourceSlot: 0,
                  )
                : Projectile(
                    position: b.position,
                    angle: 0,
                    element: element,
                    damage: 0,
                    life: 6,
                    speedMultiplier: 0,
                    stationary: true,
                    piercing: true,
                    abilityFamily: 'horn',
                    sourceSlotIndex: 0,
                    tickEffect: effect,
                    effectPower: 60,
                    effectRadius: 120,
                    effectDuration: 6,
                  ),
          );
          run(game, 60, still: b);
          expect(b.hp, lessThan(b.maxHp), reason: '$name left the boss alone');
        });
      }

      test('the Poison aura ticks a boss beside the Horn', () async {
        final game = await arena([member('Horn', 'Poison')]);
        final b = boss(game, game.orb.position + const Offset(300, 0));
        final comp = game.activeCompanions[0]!;
        for (var f = 0; f < 90; f++) {
          comp.position = b.position - Offset(b.radius + 20, 0);
          run(game, 1, still: b);
        }
        expect(b.hp, lessThan(b.maxHp));
      });
    });

    group('Mane', () {
      Projectile seed(Offset at) => Projectile(
        position: at,
        angle: 0,
        element: 'Earth',
        damage: 200,
        abilityFamily: 'mane',
        sourceSlotIndex: 0,
        effectPower: 60,
        effectRadius: 44,
        effectDuration: 1,
        turretDamage: 60,
      );

      for (final (name, build) in <(String, Projectile Function(Offset))>[
        ('a Lava blob', (at) => ManeRuntime.lavaBlob(seed(at), at)),
        (
          'a Lightning field',
          (at) => ManeRuntime.lightningShockField(seed(at), at),
        ),
        ('an Earth quake', (at) => ManeRuntime.earthQuakePulse(seed(at), Random(1))),
        ('a Steam puff', (at) => ManeRuntime.steamPuff(seed(at))),
      ]) {
        test('$name ticks a boss standing in it', () async {
          final game = await arena([member('Mane', 'Fire')]);
          final b = boss(game, game.orb.position + const Offset(300, 0));
          game.companionProjectiles.add(build(b.position));
          run(game, 45, still: b);
          expect(b.hp, lessThan(b.maxHp), reason: '$name left the boss alone');
        });
      }
    });

    group('Kin', () {
      test('the charged laser burns a boss on its line', () async {
        final game = await arena([member('Kin', 'Water')]);
        final comp = game.activeCompanions[0]!;
        final b = boss(game, comp.position + const Offset(150, 0));
        comp.basicCooldown = 0;
        run(game, 60 * 3, still: b, holdBasics: false);
        expect(b.hp, lessThan(b.maxHp));
      });

      test('the charge starts on a boss at the edge of its body', () async {
        final game = await arena([member('Kin', 'Water')]);
        final comp = game.activeCompanions[0]!;
        final b = boss(game, comp.position + Offset(comp.attackRange + 50, 0));
        comp.basicCooldown = 0;
        comp.kinAutoChargeTimer = 0;
        run(game, 1, still: b, holdBasics: false);
        expect(
          comp.kinAutoChargeTimer,
          greaterThan(0),
          reason: 'a Kin locked on a boss neither lasered nor cast',
        );
      });

      test('the Lava splash reaches a boss pressing the orb', () async {
        final game = await arena([member('Kin', 'Lava')]);
        final comp = game.activeCompanions[0]!;
        final b = boss(game, game.orb.position + const Offset(120, 0));
        comp.kinLavaPlateTimer = 10;
        game.debugDamageOrb(60);
        run(game, 1, still: b);
        expect(b.hp, lessThan(b.maxHp));
      });

      test('the reborn Fire Kin\'s flame burns a boss', () async {
        final game = await arena([member('Kin', 'Fire')]);
        final comp = game.activeCompanions[0]!;
        final b = boss(game, game.orb.position + const Offset(300, 0));
        comp
          ..kinFireOrbitalFlameActive = true
          ..kinFireFlameRadius = 200
          ..kinFireFlameInterval = 0.2
          ..kinFireFlameTimer = 0;
        for (var f = 0; f < 30; f++) {
          comp.position = b.position - Offset(b.radius + 40, 0);
          run(game, 1, still: b);
        }
        expect(b.hp, lessThan(b.maxHp));
      });
    });
  });
}
