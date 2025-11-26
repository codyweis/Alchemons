import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/components/survival_attacks.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// LET FAMILY - METEOR MECHANIC
/// Launches a devastating meteor that crashes down on enemies
/// Rank 1+: Elemental augment based on type
/// Rank 5 (MAX): Apocalyptic meteor with massive AoE and effects
class LetMeteorMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final color = SurvivalAttackManager.getElementColor(element);

    // Base meteor parameters scale with rank
    final baseRadius = 100.0 + rank * 15;
    final baseDmg = (calcDmg(attacker, target) * (1.5 + 0.25 * rank)).toInt();

    // Rank 5: Apocalyptic Meteor
    final isApocalyptic = rank >= 5;
    final radius = isApocalyptic ? baseRadius * 1.8 : baseRadius;
    final damage = isApocalyptic ? (baseDmg * 1.5).toInt() : baseDmg;

    // Visual: Meteor falling from sky
    final impactPos = target.position.clone();
    final startPos = impactPos + Vector2(0, -400);

    final meteor = CircleComponent(
      radius: isApocalyptic ? 35 : 25,
      position: startPos,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Trail effect
    meteor.add(
      TimerComponent(
        period: 0.03,
        repeat: true,
        onTick: () {
          game.world.add(
            CircleComponent(
              radius: isApocalyptic ? 18 : 12,
              position: meteor.position.clone(),
              anchor: Anchor.center,
              paint: Paint()..color = color.withOpacity(0.4),
            )..add(
              SequenceEffect([
                ScaleEffect.to(
                  Vector2.all(0.3),
                  EffectController(duration: 0.3),
                ),
                RemoveEffect(),
              ]),
            ),
          );
        },
      ),
    );

    meteor.add(
      MoveEffect.to(
        impactPos,
        EffectController(duration: 0.4, curve: Curves.easeIn),
        onComplete: () {
          meteor.removeFromParent();

          // Screen shake
          SurvivalAttackManager.triggerScreenShake(
            game,
            isApocalyptic ? 12.0 : 6.0,
          );

          // Impact damage
          final victims = game.getEnemiesInRange(impactPos, radius);
          for (final v in victims) {
            final dist = v.position.distanceTo(impactPos);
            final falloff = 1.0 - (dist / radius) * 0.4;
            v.takeDamage((damage * falloff).toInt());
          }

          // Explosion visual
          ImpactVisuals.playExplosion(game, impactPos, element, radius);

          // Apply elemental effect
          if (rank >= 1) {
            _applyElementalMeteor(
              game: game,
              attacker: attacker,
              element: element,
              rank: rank,
              center: impactPos,
              radius: radius,
              enemiesHit: victims,
            );
          }
        },
      ),
    );

    game.world.add(meteor);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ELEMENT ROUTER
  // ═══════════════════════════════════════════════════════════════════════════

  static void _applyElementalMeteor({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 center,
    required double radius,
    required List<HoardEnemy> enemiesHit,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireMeteor(game, attacker, rank, center, radius);
        break;
      case 'Lava':
        _lavaMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Blood':
        _bloodMeteor(game, attacker, rank, center, enemiesHit);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Ice':
        _iceMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Steam':
        _steamMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantMeteor(game, attacker, rank, center, radius);
        break;
      case 'Poison':
        _poisonMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Mud':
        _mudMeteor(game, attacker, rank, center, radius);
        break;
      case 'Crystal':
        _crystalMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Dust':
        _dustMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Lightning':
        _lightningMeteor(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritMeteor(game, attacker, rank, center, enemiesHit);
        break;
      case 'Dark':
        _darkMeteor(game, attacker, rank, center, enemiesHit);
        break;
      case 'Light':
        _lightMeteor(game, attacker, rank, center, radius);
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FIRE / LAVA / BLOOD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fire Meteor - Leaves burning crater that damages over time
  static void _fireMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final burnRadius = radius * 0.8;
    final duration = 3.0 + 0.5 * rank;
    final dps = (attacker.unit.statIntelligence * (2.0 + 0.3 * rank))
        .toInt()
        .clamp(5, 200);

    final fireZone = CircleComponent(
      radius: burnRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.deepOrange.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    fireZone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, burnRadius);
          for (final v in victims) {
            v.takeDamage(dps);
            ImpactVisuals.play(game, v.position, 'Fire', scale: 0.4);
          }
        },
      ),
    );

    fireZone.add(RemoveEffect(delay: duration));
    game.world.add(fireZone);

    // Rank 5: Heal from burning enemies
    if (rank >= 5) {
      final heal = (dps * 0.3).toInt();
      attacker.unit.heal(heal);
    }
  }

  /// Lava Meteor - Massive damage with knockback and molten pool
  static void _lavaMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Knockback all hit enemies
    for (final v in victims) {
      final dir = (v.position - center).normalized();
      v.add(
        MoveEffect.by(
          dir * (80.0 + 15.0 * rank),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
    }

    // Leave molten pool
    final poolRadius = radius * 0.6;
    final duration = 2.5 + 0.3 * rank;
    final poolDps = (attacker.unit.statIntelligence * (1.5 + 0.2 * rank))
        .toInt()
        .clamp(3, 150);

    final lavaPool = CircleComponent(
      radius: poolRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.orange.shade800.withOpacity(0.4),
    );

    lavaPool.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final poolVictims = game.getEnemiesInRange(center, poolRadius);
          for (final v in poolVictims) {
            v.takeDamage(poolDps);
          }
        },
      ),
    );

    lavaPool.add(RemoveEffect(delay: duration));
    game.world.add(lavaPool);
  }

  /// Blood Meteor - Heavy lifesteal from all enemies hit
  static void _bloodMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final drainPerEnemy = (calcDmg(attacker, null) * (0.3 + 0.08 * rank))
        .toInt()
        .clamp(5, 200);

    int totalDrain = 0;
    for (final v in victims) {
      v.takeDamage(drainPerEnemy);
      totalDrain += drainPerEnemy;
      ImpactVisuals.play(game, v.position, 'Blood', scale: 0.8);
    }

    // Heal attacker and orb
    final selfHeal = (totalDrain * (0.4 + 0.1 * rank)).toInt();
    final orbHeal = (totalDrain * (0.2 + 0.05 * rank)).toInt();
    attacker.unit.heal(selfHeal);
    game.orb.heal(orbHeal);

    ImpactVisuals.playHeal(game, attacker.position);

    // Rank 5: Also heal nearby guardians
    if (rank >= 5) {
      final nearbyGuardians = game.getGuardiansInRange(
        center: center,
        range: 200,
      );
      for (final g in nearbyGuardians) {
        g.unit.heal((selfHeal * 0.3).toInt());
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  WATER / ICE / STEAM
  // ═══════════════════════════════════════════════════════════════════════════

  /// Water Meteor - Tidal wave that pushes enemies back and heals allies
  static void _waterMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Push enemies away from orb
    for (final v in victims) {
      final pushDir = (v.position - game.orb.position).normalized();
      v.add(
        MoveEffect.by(
          pushDir * (60.0 + 12.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }

    // Heal allies in range
    final healAmount = (attacker.unit.statIntelligence * (2.0 + 0.4 * rank))
        .toInt()
        .clamp(5, 150);
    final nearbyGuardians = game.getGuardiansInRange(
      center: center,
      range: radius,
    );
    for (final g in nearbyGuardians) {
      g.unit.heal(healAmount);
      ImpactVisuals.playHeal(game, g.position, scale: 0.6);
    }

    // Heal orb if in range
    if (game.orb.position.distanceTo(center) <= radius) {
      game.orb.heal(healAmount);
    }
  }

  /// Ice Meteor - Freezing impact that heavily slows and creates ice field
  static void _iceMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Create ice field
    final iceRadius = radius * 0.9;
    final duration = 4.0 + 0.5 * rank;
    final slowStrength = 15.0 + 3.0 * rank;

    final iceField = CircleComponent(
      radius: iceRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.cyanAccent.withOpacity(0.25),
    );

    iceField.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final iceVictims = game.getEnemiesInRange(center, iceRadius);
          for (final v in iceVictims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    iceField.add(RemoveEffect(delay: duration));
    game.world.add(iceField);

    // Rank 5: Freeze enemies in place briefly (stun)
    if (rank >= 5) {
      for (final v in victims) {
        v.add(MoveEffect.by(Vector2.zero(), EffectController(duration: 1.5)));
      }
    }
  }

  /// Steam Meteor - Scalding burst that damages and confuses enemies
  static void _steamMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();
    final scaldDmg = (calcDmg(attacker, null) * (0.4 + 0.1 * rank))
        .toInt()
        .clamp(3, 120);

    for (final v in victims) {
      // Damage
      v.takeDamage(scaldDmg);

      // Confusion: random movement
      final randomDir = Vector2(
        rng.nextDouble() * 2 - 1,
        rng.nextDouble() * 2 - 1,
      ).normalized();
      v.add(
        MoveEffect.by(
          randomDir * (30.0 + 8.0 * rank),
          EffectController(duration: 0.3),
        ),
      );

      ImpactVisuals.play(game, v.position, 'Steam', scale: 0.6);
    }

    // Steam cloud visual
    final cloud = CircleComponent(
      radius: radius * 0.7,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.blueGrey.shade300.withOpacity(0.3),
    );
    cloud.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 1.0)),
        OpacityEffect.fadeOut(EffectController(duration: 0.5)),
        RemoveEffect(),
      ]),
    );
    game.world.add(cloud);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PLANT / POISON
  // ═══════════════════════════════════════════════════════════════════════════

  /// Plant Meteor - Seeds a thorny garden that damages and ensnares
  static void _plantMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final gardenRadius = radius * 0.85;
    final duration = 4.0 + 0.6 * rank;
    final thornDps = (attacker.unit.statIntelligence * (1.2 + 0.2 * rank))
        .toInt()
        .clamp(2, 100);
    final slowStrength = 8.0 + 2.0 * rank;

    final garden = CircleComponent(
      radius: gardenRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green.withOpacity(0.3),
    );

    garden.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, gardenRadius);
          for (final v in victims) {
            v.takeDamage(thornDps);
            // Slow effect
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    garden.add(RemoveEffect(delay: duration));
    game.world.add(garden);

    // Rank 5: Garden also heals guardians inside
    if (rank >= 5) {
      garden.add(
        TimerComponent(
          period: 1.0,
          repeat: true,
          onTick: () {
            final allies = game.getGuardiansInRange(
              center: center,
              range: gardenRadius,
            );
            for (final g in allies) {
              g.unit.heal((thornDps * 0.5).toInt());
            }
          },
        ),
      );
    }
  }

  /// Poison Meteor - Toxic explosion that applies stacking poison
  static void _poisonMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final poisonDmg = (attacker.unit.statIntelligence * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(2, 80);
    final poisonTicks = 6 + rank;

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick: poisonDmg,
          ticksRemaining: poisonTicks,
          tickInterval: 0.5,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Poison', scale: 0.7);
    }

    // Poison cloud lingers
    final cloudDuration = 2.0 + 0.3 * rank;
    final cloud = CircleComponent(
      radius: radius * 0.6,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.purple.withOpacity(0.25),
    );

    cloud.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          final newVictims = game.getEnemiesInRange(center, radius * 0.6);
          for (final v in newVictims) {
            v.unit.applyStatusEffect(
              SurvivalStatusEffect(
                type: 'Poison',
                damagePerTick: (poisonDmg * 0.5).toInt(),
                ticksRemaining: 3,
                tickInterval: 0.5,
              ),
            );
          }
        },
      ),
    );

    cloud.add(RemoveEffect(delay: cloudDuration));
    game.world.add(cloud);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EARTH / MUD / CRYSTAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Earth Meteor - Devastating impact with shrapnel and shield
  static void _earthMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Shrapnel damage to nearby enemies
    final shrapnelRadius = radius * 1.3;
    final shrapnelDmg = (calcDmg(attacker, null) * (0.5 + 0.1 * rank))
        .toInt()
        .clamp(3, 150);

    final shrapnelVictims = game.getEnemiesInRange(center, shrapnelRadius);
    for (final v in shrapnelVictims) {
      if (!victims.contains(v)) {
        v.takeDamage(shrapnelDmg);
        ImpactVisuals.play(game, v.position, 'Earth', scale: 0.5);
      }
    }

    // Grant shield to attacker
    final shieldAmount = (attacker.unit.maxHp * (0.1 + 0.03 * rank))
        .toInt()
        .clamp(20, 400);
    attacker.unit.shieldHp = (attacker.unit.shieldHp ?? 0) + shieldAmount;

    // Rank 5: Also grant shield to nearby guardians
    if (rank >= 5) {
      final allies = game.getGuardiansInRange(
        center: attacker.position,
        range: 200,
      );
      for (final g in allies) {
        g.unit.shieldHp = (g.unit.shieldHp ?? 0) + (shieldAmount * 0.4).toInt();
      }
    }
  }

  /// Mud Meteor - Creates sticky mud that heavily slows
  static void _mudMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final mudRadius = radius * 1.0;
    final duration = 5.0 + 0.5 * rank;
    final slowStrength = 20.0 + 4.0 * rank;

    final mudPool = CircleComponent(
      radius: mudRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.brown.shade600.withOpacity(0.4),
    );

    mudPool.add(
      TimerComponent(
        period: 0.25,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, mudRadius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    mudPool.add(RemoveEffect(delay: duration));
    game.world.add(mudPool);
  }

  /// Crystal Meteor - Shatters into homing crystal shards
  static void _crystalMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final shardCount = 4 + rank;
    final shardDmg = (calcDmg(attacker, null) * (0.4 + 0.08 * rank))
        .toInt()
        .clamp(3, 120);

    final rng = Random();
    final allEnemies = game.getEnemiesInRange(center, radius * 2);

    for (int i = 0; i < shardCount; i++) {
      if (allEnemies.isEmpty) break;
      final target = allEnemies[rng.nextInt(allEnemies.length)];

      Future.delayed(Duration(milliseconds: i * 80), () {
        if (target.isDead) return;

        game.spawnAlchemyProjectile(
          start: center,
          target: target,
          damage: shardDmg,
          color: Colors.tealAccent,
          shape: ProjectileShape.shard,
          speed: 2.5,
          isEnemy: false,
          onHit: () {
            target.takeDamage(shardDmg);
            ImpactVisuals.play(game, target.position, 'Crystal', scale: 0.6);
          },
        );
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  AIR / DUST / LIGHTNING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Air Meteor - Powerful shockwave that blasts enemies away
  static void _airMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Massive knockback
    for (final v in victims) {
      final dir = (v.position - center).normalized();
      final knockbackDist = 120.0 + 25.0 * rank;

      v.add(
        MoveEffect.by(
          dir * knockbackDist,
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }

    SurvivalAttackManager.triggerScreenShake(game, 4.0 + rank);

    // Rank 5: Second shockwave
    if (rank >= 5) {
      Future.delayed(const Duration(milliseconds: 300), () {
        final secondWaveVictims = game.getEnemiesInRange(center, radius * 1.3);
        for (final v in secondWaveVictims) {
          final dir = (v.position - center).normalized();
          v.add(
            MoveEffect.by(
              dir * 80.0,
              EffectController(duration: 0.2, curve: Curves.easeOut),
            ),
          );
        }
        ImpactVisuals.playExplosion(game, center, 'Air', radius * 1.3);
      });
    }
  }

  /// Dust Meteor - Blinding sandstorm that confuses and damages
  static void _dustMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();
    final duration = 3.0 + 0.4 * rank;
    final tickDmg = (attacker.unit.statIntelligence * (0.6 + 0.1 * rank))
        .toInt()
        .clamp(1, 60);

    final sandstorm = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.amber.shade300.withOpacity(0.35),
    );

    sandstorm.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final stormVictims = game.getEnemiesInRange(center, radius);
          for (final v in stormVictims) {
            v.takeDamage(tickDmg);
            // Confusion: jitter movement
            final jitter = Vector2(
              (rng.nextDouble() - 0.5) * (20 + 4 * rank),
              (rng.nextDouble() - 0.5) * (20 + 4 * rank),
            );
            v.position += jitter;
          }
        },
      ),
    );

    sandstorm.add(RemoveEffect(delay: duration));
    game.world.add(sandstorm);
  }

  /// Lightning Meteor - Thunderbolt strike with chain lightning
  static void _lightningMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final chainCount = 2 + rank;
    final chainDmg = (calcDmg(attacker, null) * (0.5 + 0.1 * rank))
        .toInt()
        .clamp(4, 150);

    final rng = Random();

    for (final src in victims) {
      final nearby = game
          .getEnemiesInRange(src.position, 250)
          .where((e) => e != src && !victims.contains(e))
          .toList();

      final chains = min(chainCount, nearby.length);
      for (int i = 0; i < chains; i++) {
        if (nearby.isEmpty) break;
        final target = nearby[rng.nextInt(nearby.length)];

        Future.delayed(Duration(milliseconds: i * 60), () {
          if (target.isDead) return;

          game.spawnAlchemyProjectile(
            start: src.position,
            target: target,
            damage: chainDmg,
            color: Colors.yellow,
            shape: ProjectileShape.bolt,
            speed: 4.0,
            isEnemy: false,
            onHit: () {
              target.takeDamage(chainDmg);
              ImpactVisuals.play(
                game,
                target.position,
                'Lightning',
                scale: 0.8,
              );
            },
          );
        });
      }
    }

    SurvivalAttackManager.triggerScreenShake(game, 3.0 + rank * 0.5);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SPIRIT / DARK / LIGHT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Spirit Meteor - Marks enemies for delayed spirit explosions
  static void _spiritMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final markDmg = (calcDmg(attacker, null) * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(5, 250);
    final explosionRadius = 60.0 + 8.0 * rank;

    for (final e in victims) {
      // Mark visual
      ImpactVisuals.play(game, e.position, 'Spirit', scale: 0.8);

      // Delayed explosion
      Future.delayed(const Duration(milliseconds: 800), () {
        if (e.isDead) return;
        final explosionVictims = game.getEnemiesInRange(
          e.position,
          explosionRadius,
        );
        for (final v in explosionVictims) {
          v.takeDamage(markDmg);
          ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.5);
        }
      });
    }
  }

  /// Dark Meteor - Execute low HP enemies, bonus damage to weakened
  static void _darkMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final executeThreshold = 0.15 + 0.05 * rank;
    final bonusDmg = (calcDmg(attacker, null) * (0.8 + 0.2 * rank))
        .toInt()
        .clamp(5, 400);

    for (final v in victims) {
      if (!v.isBoss && v.unit.hpPercent < executeThreshold) {
        // Execute!
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.4);
      } else {
        // Bonus damage to weakened enemies
        final extraDmg = v.unit.hpPercent < 0.5
            ? (bonusDmg * 1.5).toInt()
            : bonusDmg;
        v.takeDamage(extraDmg);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 0.8);
      }
    }

    // Rank 5: Lifesteal from executes
    if (rank >= 5) {
      final executed = victims.where((v) => v.isDead).length;
      attacker.unit.heal(executed * 50);
    }
  }

  /// Light Meteor - Holy explosion that damages enemies and heals team
  static void _lightMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    // Damage enemies
    final lightDmg = (calcDmg(attacker, null) * (1.2 + 0.2 * rank))
        .toInt()
        .clamp(10, 500);
    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      v.takeDamage(lightDmg);
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.9);
    }

    // Heal all guardians
    final healAmount = (attacker.unit.statIntelligence * (3.0 + 0.5 * rank))
        .toInt()
        .clamp(10, 200);
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healAmount);
        ImpactVisuals.playHeal(game, g.position, scale: 0.6);
      }
    }

    // Heal orb
    game.orb.heal((healAmount * 0.5).toInt());

    // Rank 5: Purify debuffs (clear negative status effects)
    if (rank >= 5) {
      for (final g in game.guardians) {
        g.unit.statusEffects.clear();
      }
    }
  }
}
