import 'dart:math';

import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/components/survival_attacks.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/enemies/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// PIP FAMILY - RICOCHET MECHANIC
/// Tier 0: Locked
/// Tier 1: Unlocks ricochet
/// Tier 2: More bounces & damage
/// Tier 3+: Hyper-ricochet (more bounces, faster, harder)
class PipRicochetMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final rawRank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final int tier = rawRank.clamp(0, 3);

    final bool isSuper = tier >= 3;

    // Tier-based tuning
    //  T1: 3 bounces, normal speed
    //  T2: 4 bounces, faster
    //  T3+: 5+ bounces, very fast
    final int baseBounces = 2 + tier * 3; // 1→3, 2→6, 3→9
    final int bounces = isSuper ? baseBounces + 5 : baseBounces;

    final double speed;
    switch (tier) {
      case 1:
        speed = 2.5;
        break;
      case 2:
        speed = 3.5;
        break;
      default: // tier 3+
        speed = 5.0;
        break;
    }

    final double dmgMult;
    switch (tier) {
      case 1:
        dmgMult = 1.2;
        break;
      case 2:
        dmgMult = 1.4;
        break;
      default: // tier 3+
        dmgMult = 1.7;
        break;
    }

    _chainRecursive(
      game: game,
      source: attacker,
      currentTarget: target,
      element: element,
      bouncesLeft: bounces,
      dmgMult: dmgMult,
      hitHistory: [],
      tier: tier,
      speed: speed,
      hitIndex: 0,
    );
  }

  static void _triggerRicochetFinisher(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    String element,
    Vector2 position,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.5 * getAbilityPowerMultiplier(attacker))
            .toInt();

    switch (element) {
      case 'Fire':
        // DETONATION - All burning enemies explode
        _fireDetonation(game, attacker, position, damage);
        break;
      case 'Lava':
        // ERUPTION - Massive lava burst at final position
        _lavaEruption(game, attacker, position, damage);
        break;
      case 'Blood':
        // HEMORRHAGE - Massive team heal based on enemies hit
        _bloodHemorrhage(game, attacker, position, damage);
        break;
      case 'Water':
        // TIDAL SURGE - Wave pushes all enemies away from orb
        _waterTidalSurge(game, attacker, position, damage);
        break;
      case 'Ice':
        // FLASH FREEZE - All nearby enemies frozen solid
        _iceFlashFreeze(game, attacker, position, damage);
        break;
      case 'Steam':
        // PRESSURE BURST - Explosion of scalding steam
        _steamPressureBurst(game, attacker, position, damage);
        break;
      case 'Plant':
        // BLOOM - All thorn patches explode with growth
        _plantBloom(game, attacker, position, damage);
        break;
      case 'Poison':
        // PANDEMIC - Poison spreads to all nearby enemies
        _poisonPandemic(game, attacker, position, damage);
        break;
      case 'Earth':
        // TREMOR - Shockwave knocks down all nearby enemies
        _earthTremor(game, attacker, position, damage);
        break;
      case 'Mud':
        // SINKHOLE - Enemies pulled to center and stuck
        _mudSinkhole(game, attacker, position, damage);
        break;
      case 'Crystal':
        // SHATTER - Massive shard explosion
        _crystalShatter(game, attacker, position, damage);
        break;
      case 'Air':
        // CYCLONE - Brief tornado at final position
        _airCyclone(game, attacker, position, damage);
        break;
      case 'Dust':
        // SANDBLAST - Blinding burst that scatters enemies
        _dustSandblast(game, attacker, position, damage);
        break;
      case 'Lightning':
        // THUNDERCLAP - Chain lightning to ALL nearby enemies
        _lightningThunderclap(game, attacker, position, damage);
        break;
      case 'Spirit':
        // HAUNT - Summons temporary ghost that attacks
        _spiritHaunt(game, attacker, position, damage);
        break;
      case 'Dark':
        // EXECUTE - Instant kill on low HP enemies nearby
        _darkExecute(game, attacker, position, damage);
        break;
      case 'Light':
        // BLESSING - Big heal to all allies
        _lightBlessing(game, attacker, position, damage);
        break;
      default:
        ImpactVisuals.playExplosion(game, position, element, 100);
    }
  }

  static void _chainRecursive({
    required SurvivalHoardGame game,
    required HoardGuardian source,
    required HoardEnemy currentTarget,
    required String element,
    required int bouncesLeft,
    required double dmgMult,
    required List<HoardEnemy> hitHistory,
    required int tier,
    required double speed,
    required int hitIndex,
  }) {
    if (bouncesLeft <= 0 || currentTarget.isDead) return;

    final dmg = (calcDmg(source, currentTarget) * dmgMult).toInt();
    final color = SurvivalAttackManager.getElementColor(element);

    final Vector2 startPos = (hitHistory.isEmpty)
        ? source.position
        : hitHistory.last.position;

    game.spawnAlchemyProjectile(
      start: startPos,
      target: currentTarget,
      damage: dmg,
      color: color,
      shape: ProjectileShape.bolt,
      speed: speed,
      isEnemy: false,
      onHit: () {
        currentTarget.takeDamage(dmg);
        ImpactVisuals.play(game, currentTarget.position, element, scale: 0.8);
        hitHistory.add(currentTarget);

        // Elemental augment per hit (tier-aware)
        _applyElementalRicochetAugmentOnHit(
          game: game,
          attacker: source,
          element: element,
          tier: tier,
          hitTarget: currentTarget,
          hitIndex: hitIndex,
        );

        // ✨ RANK 3 FINISHER - triggers on last bounce
        if (bouncesLeft == 1 && tier >= 3) {
          _triggerRicochetFinisher(
            game,
            source,
            element,
            currentTarget.position,
          );
        }

        // Find next target
        final nextTarget = _findNearestExcluding(
          game,
          currentTarget.position,
          400, // range
          hitHistory,
        );

        if (nextTarget != null) {
          Future.delayed(const Duration(milliseconds: 50), () {
            _chainRecursive(
              game: game,
              source: source,
              currentTarget: nextTarget,
              element: element,
              bouncesLeft: bouncesLeft - 1,
              dmgMult: dmgMult * 0.9,
              hitHistory: hitHistory,
              tier: tier,
              speed: speed,
              hitIndex: hitIndex + 1,
            );
          });
        }
      },
    );
  }

  static void _fireDetonation(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // All enemies with Burn status explode
    final allEnemies = game.getEnemiesInRange(position, 500);
    for (final e in allEnemies) {
      final hasBurn = e.unit.statusEffects.values.any((s) => s.type == 'Burn');
      if (hasBurn) {
        e.takeDamage((damage * 0.8).toInt());
        ImpactVisuals.playExplosion(game, e.position, 'Fire', 60);

        // Spread fire to nearby
        final nearby = game.getEnemiesInRange(e.position, 80);
        for (final n in nearby) {
          n.unit.applyStatusEffect(
            SurvivalStatusEffect(
              type: 'Burn',
              damagePerTick: (attacker.unit.statIntelligence * 1.0)
                  .toInt()
                  .clamp(3, 50),
              ticksRemaining: 4,
              tickInterval: 0.5,
            ),
          );
        }
      }
    }
    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  static void _lavaEruption(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Big lava pool at final position
    final poolRadius = 120.0;

    final pool = CircleComponent(
      radius: poolRadius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.orange.shade800.withValues(alpha: 0.5),
    );

    // Initial burst damage
    final victims = game.getEnemiesInRange(position, poolRadius);
    for (final v in victims) {
      v.takeDamage(damage);
      final dir = (v.position - position).normalized();
      v.add(MoveEffect.by(dir * 80, EffectController(duration: 0.2)));
    }

    // Lingering damage
    pool.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final poolVictims = game.getEnemiesInRange(position, poolRadius);
          for (final v in poolVictims) {
            v.takeDamage((damage * 0.2).toInt());
          }
        },
      ),
    );

    pool.add(RemoveEffect(delay: 4.0));
    game.world.add(pool);
    ImpactVisuals.playExplosion(game, position, 'Lava', poolRadius);
    SurvivalAttackManager.triggerScreenShake(game, 8.0);
  }

  static void _bloodHemorrhage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Damage nearby enemies and heal team massively
    final victims = game.getEnemiesInRange(position, 200);
    int totalDrain = 0;

    for (final v in victims) {
      v.takeDamage((damage * 0.6).toInt());
      totalDrain += (damage * 0.6).toInt();
    }

    // Big team heal
    final healPerAlly = (totalDrain * 0.5 / max(1, game.guardians.length))
        .toInt();
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healPerAlly);
        ImpactVisuals.playHeal(game, g.position, scale: 0.8);
      }
    }

    // Orb heal
    game.orb.heal((totalDrain * 0.3).toInt());
    ImpactVisuals.playHeal(game, game.orb.position, scale: 1.0);
  }

  static void _waterTidalSurge(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Wave pushes all enemies away from orb
    final victims = game.getEnemiesInRange(game.orb.position, 400);
    for (final v in victims) {
      v.takeDamage((damage * 0.5).toInt());
      final dir = (v.position - game.orb.position).normalized();
      v.add(
        MoveEffect.by(
          dir * 150,
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
    }

    // Heal orb
    game.orb.heal((attacker.unit.statIntelligence * 5).toInt().clamp(20, 150));
    ImpactVisuals.playExplosion(game, game.orb.position, 'Water', 400);
    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  static void _iceFlashFreeze(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Freeze all nearby enemies
    final victims = game.getEnemiesInRange(position, 180);
    for (final v in victims) {
      v.takeDamage((damage * 0.4).toInt());
      // Full freeze for 1.5 seconds
      v.add(MoveEffect.by(Vector2.zero(), EffectController(duration: 1.5)));
      ImpactVisuals.play(game, v.position, 'Ice', scale: 0.8);
    }

    ImpactVisuals.playExplosion(game, position, 'Ice', 180);
    SurvivalAttackManager.triggerScreenShake(game, 4.0);
  }

  static void _steamPressureBurst(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    final rng = Random();
    final victims = game.getEnemiesInRange(position, 150);

    for (final v in victims) {
      v.takeDamage((damage * 0.6).toInt());

      // Heavy burn
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Burn',
          damagePerTick: (attacker.unit.statIntelligence * 1.5).toInt().clamp(
            5,
            80,
          ),
          ticksRemaining: 5,
          tickInterval: 0.5,
        ),
      );

      // Scatter in random directions
      final scatter = Vector2(
        (rng.nextDouble() - 0.5) * 120,
        (rng.nextDouble() - 0.5) * 120,
      );
      v.add(MoveEffect.by(scatter, EffectController(duration: 0.25)));
    }

    ImpactVisuals.playExplosion(game, position, 'Steam', 150);
    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  static void _plantBloom(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Create a healing garden + damage zone
    final gardenRadius = 140.0;

    final garden = CircleComponent(
      radius: gardenRadius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green.withValues(alpha: 0.35),
    );

    garden.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          // Damage enemies
          final victims = game.getEnemiesInRange(position, gardenRadius);
          for (final v in victims) {
            v.takeDamage((damage * 0.15).toInt());
            // Push back
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -15;
            v.position += pushBack;
          }

          // Heal allies
          final allies = game.getGuardiansInRange(
            center: position,
            range: gardenRadius,
          );
          for (final g in allies) {
            g.unit.heal(
              (attacker.unit.statIntelligence * 0.8).toInt().clamp(3, 40),
            );
          }
        },
      ),
    );

    garden.add(RemoveEffect(delay: 4.0));
    game.world.add(garden);
    ImpactVisuals.playExplosion(game, position, 'Plant', gardenRadius);
  }

  static void _poisonPandemic(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    final victims = game.getEnemiesInRange(position, 300);

    for (final v in victims) {
      // Check for existing poison - if present, DETONATE it
      final existingPoison = v.unit.statusEffects['Poison'];
      if (existingPoison != null && existingPoison.ticksRemaining > 0) {
        // Burst damage based on remaining poison
        final burstDmg =
            existingPoison.damagePerTick * existingPoison.ticksRemaining;
        v.takeDamage(burstDmg);
        ImpactVisuals.playExplosion(game, v.position, 'Poison', 60);

        // Clear the old poison
        v.unit.statusEffects.remove('Poison');
      }

      // Apply fresh HEAVY poison
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick: (attacker.unit.statIntelligence * 1.5).toInt().clamp(
            5,
            80,
          ),
          ticksRemaining: 12,
          tickInterval: 0.35,
        ),
      );

      ImpactVisuals.play(game, v.position, 'Poison', scale: 0.8);
    }

    ImpactVisuals.playExplosion(game, position, 'Poison', 300);
    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  static void _earthTremor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Shockwave that knocks down enemies
    final victims = game.getEnemiesInRange(position, 200);
    for (final v in victims) {
      v.takeDamage((damage * 0.7).toInt());
      final dir = (v.position - position).normalized();
      v.add(
        MoveEffect.by(
          dir * 100,
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
      // Brief stun
      v.add(MoveEffect.by(Vector2.zero(), EffectController(duration: 0.5)));
    }

    // Shield all allies
    final shieldAmount = (attacker.unit.maxHp * 0.1).toInt().clamp(20, 200);
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.shieldHp = (g.unit.shieldHp ?? 0) + shieldAmount;
      }
    }

    ImpactVisuals.playExplosion(game, position, 'Earth', 200);
    SurvivalAttackManager.triggerScreenShake(game, 7.0);
  }

  static void _mudSinkhole(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Pull enemies to center and trap them
    final victims = game.getEnemiesInRange(position, 180);

    for (final v in victims) {
      // Pull to center
      final toCenter = position - v.position;
      v.add(
        MoveEffect.by(
          toCenter * 0.7,
          EffectController(duration: 0.3, curve: Curves.easeIn),
        ),
      );

      v.takeDamage((damage * 0.5).toInt());

      // Apply heavy Mudded debuff
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Mudded',
          damagePerTick: 15,
          ticksRemaining: 12,
          tickInterval: 0.2,
        ),
      );
    }

    // Create sticky zone
    final sinkhole = CircleComponent(
      radius: 100,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.brown.shade800.withValues(alpha: 0.5),
    );

    sinkhole.add(
      TimerComponent(
        period: 0.15,
        repeat: true,
        onTick: () {
          final trapped = game.getEnemiesInRange(position, 100);
          for (final v in trapped) {
            final toCenter = (position - v.position).normalized() * 8;
            v.position += toCenter;
          }
        },
      ),
    );

    sinkhole.add(RemoveEffect(delay: 3.5));
    game.world.add(sinkhole);
    ImpactVisuals.playExplosion(game, position, 'Mud', 180);
  }

  static void _crystalShatter(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Massive shard explosion in all directions
    final enemies = game.getEnemiesInRange(position, 350);

    for (int i = 0; i < min(16, enemies.length + 8); i++) {
      final angle = (i / 16.0) * pi * 2;
      final direction = Vector2(cos(angle), sin(angle));

      Future.delayed(Duration(milliseconds: i * 25), () {
        // Find enemy in this direction
        HoardEnemy? target;
        for (final e in enemies) {
          final toEnemy = (e.position - position).normalized();
          if (toEnemy.dot(direction) > 0.7) {
            target = e;
            break;
          }
        }

        if (target == null || target.isDead) return;

        game.spawnAlchemyProjectile(
          start: position,
          target: target,
          damage: (damage * 0.5).toInt(),
          color: Colors.tealAccent,
          shape: ProjectileShape.shard,
          speed: 4.0,
          isEnemy: false,
          onHit: () {
            if (target == null || target.isDead) return;
            target.takeDamage((damage * 0.5).toInt());
            ImpactVisuals.play(game, target.position, 'Crystal', scale: 0.6);
          },
        );
      });
    }

    ImpactVisuals.playExplosion(game, position, 'Crystal', 120);
    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  static void _airCyclone(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Brief tornado that pushes enemies outward
    final tornado = CircleComponent(
      radius: 80,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.cyan.withValues(alpha: 0.3),
    );

    tornado.add(RotateEffect.by(6.28 * 3, EffectController(duration: 2.0)));

    tornado.add(
      ScaleEffect.to(Vector2.all(2.5), EffectController(duration: 2.0)),
    );

    tornado.add(
      TimerComponent(
        period: 0.2,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(position, 200);
          for (final v in victims) {
            v.takeDamage((damage * 0.1).toInt());
            final dir = (v.position - position).normalized();
            v.position += dir * 25;
          }
        },
      ),
    );

    tornado.add(RemoveEffect(delay: 2.0));
    game.world.add(tornado);
    SurvivalAttackManager.triggerScreenShake(game, 4.0);
  }

  static void _dustSandblast(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    final rng = Random();
    final victims = game.getEnemiesInRange(position, 200);

    for (final v in victims) {
      v.takeDamage((damage * 0.5).toInt());

      // Massive scatter
      final scatter = Vector2(
        (rng.nextDouble() - 0.5) * 200,
        (rng.nextDouble() - 0.5) * 200,
      );
      v.add(MoveEffect.by(scatter, EffectController(duration: 0.3)));
    }

    ImpactVisuals.playExplosion(game, position, 'Dust', 200);
    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  static void _lightningThunderclap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Chain to ALL nearby enemies
    final victims = game.getEnemiesInRange(position, 300);

    for (int i = 0; i < victims.length; i++) {
      final v = victims[i];
      Future.delayed(Duration(milliseconds: i * 30), () {
        if (v.isDead) return;

        game.spawnAlchemyProjectile(
          start: position,
          target: v,
          damage: (damage * 0.6).toInt(),
          color: Colors.yellow,
          shape: ProjectileShape.bolt,
          speed: 6.0,
          isEnemy: false,
          onHit: () {
            v.takeDamage((damage * 0.6).toInt());
            // Stun
            v.add(
              MoveEffect.by(Vector2.zero(), EffectController(duration: 0.3)),
            );
            ImpactVisuals.play(game, v.position, 'Lightning', scale: 0.8);
          },
        );
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  static void _spiritHaunt(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Summon a ghost that attacks for a few seconds
    final ghost = CircleComponent(
      radius: 20,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.purple.shade200.withValues(alpha: 0.7),
    );

    ghost.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final target = game.getNearestEnemy(ghost.position, 200);
          if (target == null) return;

          // Move toward target
          final dir = (target.position - ghost.position).normalized();
          ghost.position += dir * 30;

          // Attack if close
          if (ghost.position.distanceTo(target.position) < 50) {
            target.takeDamage((damage * 0.25).toInt());
            attacker.unit.heal((damage * 0.08).toInt());
            ImpactVisuals.play(game, target.position, 'Spirit', scale: 0.5);
          }
        },
      ),
    );

    ghost.add(
      SequenceEffect([
        OpacityEffect.to(0.8, EffectController(duration: 3.5)),
        OpacityEffect.fadeOut(EffectController(duration: 0.5)),
        RemoveEffect(),
      ]),
    );

    game.world.add(ghost);
  }

  static void _darkExecute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Execute low HP enemies, damage others
    final victims = game.getEnemiesInRange(position, 180);

    for (final v in victims) {
      if (!v.isBoss && v.unit.hpPercent < 0.30) {
        // Execute
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.2);

        // Heal attacker per execute
        attacker.unit.heal((attacker.unit.maxHp * 0.05).toInt());
      } else {
        // Normal damage
        v.takeDamage((damage * 0.7).toInt());
      }
    }

    ImpactVisuals.playExplosion(game, position, 'Dark', 180);
    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  static void _lightBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
    int damage,
  ) {
    // Big heal to all allies + orb
    final healAmount = (attacker.unit.statIntelligence * 6).toInt().clamp(
      30,
      250,
    );

    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healAmount);
        ImpactVisuals.playHeal(game, g.position, scale: 1.0);
      }
    }

    game.orb.heal((healAmount * 0.8).toInt());
    ImpactVisuals.playHeal(game, game.orb.position, scale: 1.2);

    // Also damage nearby enemies (holy burst)
    final victims = game.getEnemiesInRange(position, 150);
    for (final v in victims) {
      v.takeDamage((damage * 0.4).toInt());
    }

    ImpactVisuals.playExplosion(game, position, 'Light', 150);
  }

  static HoardEnemy? _findNearestExcluding(
    SurvivalHoardGame game,
    Vector2 pos,
    double range,
    List<HoardEnemy> exclude,
  ) {
    final candidates = game
        .getEnemiesInRange(pos, range)
        .where((e) => !exclude.contains(e))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => a.position
          .distanceToSquared(pos)
          .compareTo(b.position.distanceToSquared(pos)),
    );
    return candidates.first;
  }

  // ─────────────────────────────
  //  ELEMENTAL AUGMENTS PER HIT
  // ─────────────────────────────

  static void _applyElementalRicochetAugmentOnHit({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int tier,
    required HoardEnemy hitTarget,
    required int hitIndex,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD → aggressive, splashy, lifesteal-ish
      case 'Fire':
        _fireRicochet(game, attacker, tier, hitTarget);
        break;
      case 'Lava':
        _lavaRicochet(game, attacker, tier, hitTarget);
        break;
      case 'Blood':
        _bloodRicochet(game, attacker, tier, hitTarget);
        break;

      // 💧 WATER / ICE / STEAM → sustain & control
      case 'Water':
        _waterRicochet(game, attacker, tier, hitTarget);
        break;
      case 'Ice':
        _iceRicochet(game, attacker, tier, hitTarget);
        break;
      case 'Steam':
        _steamRicochet(game, attacker, tier, hitTarget);
        break;

      // 🌿 PLANT / POISON → DoT & hazards
      case 'Plant':
        _plantRicochet(game, attacker, tier, hitTarget, hitIndex);
        break;
      case 'Poison':
        _poisonRicochet(game, attacker, tier, hitTarget);
        break;

      // 🌍 EARTH / MUD / CRYSTAL → knockback & shard splits
      case 'Earth':
        _earthRicochet(game, attacker, tier, hitTarget);
        break;
      case 'Mud':
        _mudRicochet(game, attacker, tier, hitTarget);
        break;
      case 'Crystal':
        _crystalRicochet(game, attacker, tier, hitTarget);
        break;

      // 🌬️ AIR / DUST → disruption, wave shaping
      case 'Air':
        _airRicochet(game, attacker, tier, hitTarget);
        break;
      case 'Dust':
        _dustRicochet(game, attacker, tier, hitTarget);
        break;

      // ⚡ LIGHTNING
      case 'Lightning':
        _lightningRicochet(game, attacker, tier, hitTarget);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritRicochet(game, attacker, tier, hitTarget);
        break;
      case 'Dark':
        _darkRicochet(game, attacker, tier, hitTarget);
        break;
      case 'Light':
        _lightRicochet(game, attacker, tier, hitTarget);
        break;
      default:
        break;
    }
  }

  // ─────────────────────────────
  //  ELEMENT-SPECIFIC HELPERS
  // ─────────────────────────────

  // FIRE – small splash around each hit
  static void _fireRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final radius = 60.0 + tier * 6;
    final dmg = (calcDmg(attacker, target) * (0.4 + 0.1 * tier)).toInt().clamp(
      3,
      120,
    );
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      if (e == target) continue;
      e.takeDamage(dmg);
      ImpactVisuals.play(game, e.position, 'Fire', scale: 0.5);
    }
  }

  // LAVA – mini ground crack that damages over a short time
  static void _lavaRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final radius = 50.0 + tier * 5;
    final duration = 2.5 + tier * 0.3;
    final dps = (attacker.unit.statIntelligence * (1.0 + 0.2 * tier))
        .toInt()
        .clamp(2, 80);

    final zone = CircleComponent(
      radius: radius,
      position: target.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor('Lava').withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dps);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // BLOOD – lifesteal per hit (team vamp)
  static void _bloodRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final stealBase = (calcDmg(attacker, target) * (0.2 + 0.05 * tier))
        .toInt()
        .clamp(2, 120);

    final stealForOrb = (stealBase * 0.3).toInt();
    final stealForTeam = (stealBase * 0.7).toInt();

    game.orb.heal(stealForOrb);
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal((stealForTeam / game.guardians.length).round());
      }
    }
    ImpactVisuals.play(game, target.position, 'Blood', scale: 0.8);
  }

  // WATER – small orb heal & push enemies slightly away from orb
  static void _waterRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final heal = (attacker.unit.statIntelligence * (1.5 + 0.2 * tier))
        .toInt()
        .clamp(3, 80);
    game.orb.heal(heal);

    final radius = 70.0 + tier * 5;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final dir = (v.position - game.orb.position).normalized();
      v.position += dir * (20 + tier * 4);
    }
    ImpactVisuals.play(game, target.position, 'Water', scale: 0.7);
  }

  // ICE – heavy slow by nudging them back toward their previous spot
  static void _iceRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final radius = 70.0 + tier * 5;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final pushBack =
          (v.targetOrb.position - v.position).normalized() *
          -6 *
          (1 + 0.3 * tier);
      v.position += pushBack;
      ImpactVisuals.play(game, v.position, 'Ice', scale: 0.4);
    }
  }

  // STEAM – fog: mild slow + tiny orb regen if multiple hit
  static void _steamRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final radius = 70.0 + tier * 6;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final pushBack =
          (v.targetOrb.position - v.position).normalized() *
          -4 *
          (1 + 0.2 * tier);
      v.position += pushBack;
    }
    if (victims.length >= 2) {
      game.orb.heal(2 + tier); // small sustain
    }
  }

  // PLANT – drops tiny thorn patches on early bounces
  static void _plantRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int hitIndex,
  ) {
    // only create a few patches, e.g., first 2–3 hits
    if (hitIndex > 2) return;

    final radius = 55.0 + tier * 5;
    final duration = 3.0 + tier * 0.4;
    final dps = (attacker.unit.statIntelligence * (1.2 + 0.2 * tier))
        .toInt()
        .clamp(2, 70);

    final zone = CircleComponent(
      radius: radius,
      position: target.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor(
          'Plant',
        ).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dps);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // POISON – poison DoT on hit target

  static void _poisonRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    // Lower base scaling + lower cap.
    final poisonDmg = (attacker.unit.statIntelligence * (0.55 + 0.15 * rank))
        .toInt()
        .clamp(1, 9);

    // Fewer ticks overall so it can’t stack into absurd damage
    // (R1: 3, R2: 4, R3: 4).
    final ticks = 3 + (rank > 1 ? 1 : 0);

    target.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Poison',
        damagePerTick: poisonDmg,
        ticksRemaining: ticks,
        tickInterval: 0.5,
      ),
    );

    // Purely visual feedback
    ImpactVisuals.play(game, target.position, 'Poison', scale: 0.5);
  }

  // EARTH – knock enemies slightly back & small “armor” heal on the guardian
  static void _earthRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final radius = 65.0 + tier * 5;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final dir = (v.position - target.position).normalized();
      v.position += dir * (25 + tier * 4);
    }

    final shield = (attacker.unit.maxHp * (0.02 + 0.01 * tier)).toInt();
    attacker.unit.heal(shield);
    ImpactVisuals.play(game, attacker.position, 'Earth', scale: 0.7);
  }

  // MUD – sticky slow zone on hit
  static void _mudRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final radius = 60.0 + tier * 5;
    final duration = 3.5 + tier * 0.4;

    final zone = CircleComponent(
      radius: radius,
      position: target.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor('Mud').withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -8;
            v.position += pushBack;
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // CRYSTAL – mini split shot to another nearby enemy
  static void _crystalRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final nearby = game
        .getEnemiesInRange(target.position, 200)
        .where((e) => e != target);
    final candidates = nearby.toList();
    if (candidates.isEmpty) return;

    final other = candidates[Random().nextInt(candidates.length)];
    final dmg = (calcDmg(attacker, other) * (0.8 + 0.1 * tier)).toInt().clamp(
      3,
      120,
    );

    game.spawnAlchemyProjectile(
      start: target.position,
      target: other,
      damage: dmg,
      color: SurvivalAttackManager.getElementColor('Crystal'),
      shape: ProjectileShape.shard,
      speed: 2.4,
      isEnemy: false,
      onHit: () {
        other.takeDamage(dmg);
        ImpactVisuals.play(game, other.position, 'Crystal', scale: 0.6);
      },
    );
  }

  // AIR – pushes enemies along the chain direction (wave shaping)
  static void _airRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final radius = 75.0 + tier * 5;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final dir = (v.position - game.orb.position).normalized();
      v.add(
        MoveEffect.by(
          dir * (40 + tier * 6),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
    }
    ImpactVisuals.play(game, target.position, 'Air', scale: 0.8);
  }

  // DUST – jitter/confuse hit pack
  static void _dustRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final radius = 70.0 + tier * 5;
    final rng = Random();
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final offset = Vector2(
        (rng.nextDouble() - 0.5) * (10 + tier * 2),
        (rng.nextDouble() - 0.5) * (10 + tier * 2),
      );
      v.position += offset;
    }
  }

  // LIGHTNING – extra micro-chains from hit target
  static void _lightningRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final rng = Random();
    final nearby = game
        .getEnemiesInRange(target.position, 220)
        .where((e) => e != target);
    final candidates = nearby.toList();
    if (candidates.isEmpty) return;

    final chains = min(1 + tier, candidates.length);
    for (int i = 0; i < chains; i++) {
      final next = candidates[rng.nextInt(candidates.length)];
      final dmg = (calcDmg(attacker, next) * (0.7 + 0.1 * tier)).toInt().clamp(
        3,
        120,
      );

      game.spawnAlchemyProjectile(
        start: target.position,
        target: next,
        damage: dmg,
        color: SurvivalAttackManager.getElementColor('Lightning'),
        shape: ProjectileShape.bolt,
        speed: 3.0,
        isEnemy: false,
        onHit: () {
          next.takeDamage(dmg);
          ImpactVisuals.play(game, next.position, 'Lightning', scale: 0.7);
        },
      );
    }
  }

  // SPIRIT – ghost mark: small delayed blast around the hit target
  static void _spiritRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final delayMs = 500 - (tier * 80).clamp(0, 250);
    final radius = 60.0 + tier * 6;
    final dmg = (calcDmg(attacker, target) * (0.6 + 0.1 * tier)).toInt().clamp(
      3,
      100,
    );

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (target.isDead) return;
      final victims = game.getEnemiesInRange(target.position, radius);
      for (final v in victims) {
        v.takeDamage(dmg);
        ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.6);
      }
    });
  }

  // DARK – chip + tiny lifesteal to attacker
  static void _darkRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final extra = (calcDmg(attacker, target) * (0.4 + 0.1 * tier))
        .toInt()
        .clamp(3, 120);
    target.takeDamage(extra);
    final heal = (extra * (0.3 + 0.05 * tier)).toInt();
    attacker.unit.heal(heal);
    ImpactVisuals.play(game, target.position, 'Dark', scale: 0.7);
  }

  // LIGHT – small team sustain on hit
  static void _lightRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
  ) {
    final healEach = (attacker.unit.statIntelligence * (1.0 + 0.2 * tier))
        .toInt()
        .clamp(2, 60);

    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healEach);
        ImpactVisuals.play(game, g.position, 'Light', scale: 0.4);
      }
    }
  }
}
