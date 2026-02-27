import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/components/survival_attacks.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/enemies/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// MANE FAMILY - BARRAGE MECHANIC (CREATIVE RANK 3 PATTERNS)
///
/// Rank 0: Base barrage (no elemental rider, just cone of projectiles)
/// Rank 1: Unlocks elemental rider effects
/// Rank 2: More projectiles, damage, and stronger riders
/// Rank 3: UNIQUE ELEMENTAL ULTIMATE PATTERNS!
class ManeBarrageMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final rawRank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final int rank = rawRank < 0 ? 0 : (rawRank > 3 ? 3 : rawRank);

    final color = SurvivalAttackManager.getElementColor(element);

    // ✨ RANK 3: UNIQUE ELEMENTAL PATTERNS!
    if (rank >= 3) {
      _executeRank3Ultimate(game, attacker, target, element, color);
      return;
    }

    // Ranks 0-2: Standard barrage behavior
    _executeStandardBarrage(game, attacker, target, element, rank, color);
  }

  /// Standard barrage for Rank 0-2
  static void _executeStandardBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
    int rank,
    Color color,
  ) {
    final bool hasElemental = rank >= 1;
    final bool isEmpowered = rank >= 2;

    const int baseProjectiles = 15;
    const int projectilesPerRank = 4;
    final int projectiles = baseProjectiles + projectilesPerRank * rank;

    final double dmgMult = 0.9 + 0.2 * rank;
    final double beautyMult = getAbilityPowerMultiplier(attacker);
    final int damage = (calcDmg(attacker, null) * dmgMult * beautyMult)
        .toInt()
        .clamp(1, 999999)
        .toInt();

    final double spreadAngleDeg = 40.0 + rank * 5.0;
    final double spreadRad = spreadAngleDeg * pi / 180.0;

    HoardEnemy? primaryTarget =
        target ??
        game.pickTargetForGuardian(attacker) ??
        game.getNearestEnemy(attacker.position, 700);

    if (primaryTarget == null) return;

    final baseDir = (primaryTarget.position - attacker.position).normalized();
    final candidates = game
        .getEnemiesInRange(attacker.position, attacker.unit.attackRange)
        .where((e) => !e.isDead)
        .toList();

    HoardEnemy? pickEnemyInCone(double angleOffset) {
      if (candidates.isEmpty) return primaryTarget;

      final rotCos = cos(angleOffset);
      final rotSin = sin(angleOffset);
      final coneDir = Vector2(
        baseDir.x * rotCos - baseDir.y * rotSin,
        baseDir.x * rotSin + baseDir.y * rotCos,
      );

      final double cosHalf = cos(spreadRad * 0.5);
      HoardEnemy? best;
      double bestDot = cosHalf;

      for (final e in candidates) {
        final v = (e.position - attacker.position);
        final len = v.length;
        if (len < 1) continue;
        final dir = v / len;
        final dot = dir.dot(coneDir);
        if (dot > bestDot) {
          bestDot = dot;
          best = e;
        }
      }
      return best ?? primaryTarget;
    }

    for (int i = 0; i < projectiles; i++) {
      final speedMult = 1.0 - (attacker.unit.statSpeed * 0.04).clamp(0.0, 0.4);
      final baseDelay = isEmpowered ? 32 : 40;
      final int delayMs = (i * baseDelay * speedMult).toInt();

      Future.delayed(Duration(milliseconds: delayMs), () {
        if (attacker.isDead) return;

        final double t = projectiles == 1 ? 0.5 : i / (projectiles - 1);
        final double angleOffset = (t - 0.5) * spreadRad;

        final targetEnemy = pickEnemyInCone(angleOffset);
        if (targetEnemy == null || targetEnemy.isDead) return;

        game.spawnAlchemyProjectile(
          start: attacker.position,
          target: targetEnemy,
          damage: damage,
          color: color,
          shape: ProjectileShape.bolt,
          speed: 3.5 + rank * 0.3,
          isEnemy: false,
          onHit: () {
            if (targetEnemy.isDead) return;
            targetEnemy.takeDamage(damage);
            ImpactVisuals.play(game, targetEnemy.position, element, scale: 0.5);

            if (hasElemental) {
              _applyElementalBarrage(
                game: game,
                attacker: attacker,
                element: element,
                rank: rank,
                victim: targetEnemy,
                damage: damage,
                projectileIndex: i,
              );
            }
          },
        );
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, isEmpowered ? 4.0 : 3.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RANK 3 ULTIMATE PATTERNS - ELEMENT-SPECIFIC CREATIVITY!
  // ═══════════════════════════════════════════════════════════════════════════

  static void _executeRank3Ultimate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
    Color color,
  ) {
    switch (element) {
      case 'Fire':
        _fireInferno(game, attacker, target, color);
        break;
      case 'Lava':
        _lavaVolcano(game, attacker, target, color);
        break;
      case 'Water':
        _waterTsunami(game, attacker, target, color);
        break;
      case 'Ice':
        _iceBlizzard(game, attacker, target, color);
        break;
      case 'Lightning':
        _lightningStorm(game, attacker, target, color);
        break;
      case 'Air':
        _airTornado(game, attacker, target, color);
        break;
      case 'Earth':
        _earthQuake(game, attacker, target, color);
        break;
      case 'Plant':
        _plantOvergrowth(game, attacker, target, color);
        break;
      case 'Poison':
        _poisonMiasma(game, attacker, target, color);
        break;
      case 'Crystal':
        _crystalPrism(game, attacker, target, color);
        break;
      case 'Dark':
        _darkVortex(game, attacker, target, color);
        break;
      case 'Light':
        _lightNova(game, attacker, target, color);
        break;
      case 'Spirit':
        _spiritWhirlwind(game, attacker, target, color);
        break;
      // ✨ NEW ADDITIONS
      case 'Blood':
        _bloodExsanguination(game, attacker, target, color);
        break;
      case 'Steam':
        _steamGeyserBarrage(game, attacker, target, color);
        break;
      case 'Mud':
        _mudQuagmireBarrage(game, attacker, target, color);
        break;
      case 'Dust':
        _dustDesertBarrage(game, attacker, target, color);
        break;
      default:
        _massiveBarrage(game, attacker, target, element, color);
    }
  }

  /// 🩸 BLOOD - Exsanguination (massive drain that heals team and orb)
  static void _bloodExsanguination(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.6 * getAbilityPowerMultiplier(attacker))
            .toInt();

    final origin = attacker.position.clone();
    final enemies = game.getEnemiesInRange(origin, 500).take(20).toList();

    int totalDrained = 0;

    // Fire draining bolts at up to 20 enemies
    for (int i = 0; i < enemies.length; i++) {
      final e = enemies[i];

      Future.delayed(Duration(milliseconds: i * 40), () {
        if (attacker.isDead || e.isDead) return;

        game.spawnAlchemyProjectile(
          start: origin,
          target: e,
          damage: damage,
          color: color,
          shape: ProjectileShape.shard,
          speed: 4.5,
          isEnemy: false,
          onHit: () {
            if (e.isDead) return;

            e.takeDamage(damage);
            totalDrained += damage;

            // Lifesteal to attacker
            final selfHeal = (damage * 0.35).toInt();
            attacker.unit.heal(selfHeal);

            // Blood tendril visual back to attacker
            ImpactVisuals.play(game, e.position, 'Blood', scale: 0.7);
            ImpactVisuals.playHeal(game, attacker.position, scale: 0.4);
          },
        );
      });
    }

    // After all bolts fired, heal team and orb based on total drained
    Future.delayed(Duration(milliseconds: enemies.length * 40 + 300), () {
      if (attacker.isDead) return;

      // Heal all guardians
      final teamHeal = (totalDrained * 0.15 / max(1, game.guardians.length))
          .toInt();
      for (final g in game.guardians) {
        if (!g.isDead) {
          g.unit.heal(teamHeal);
          ImpactVisuals.playHeal(game, g.position, scale: 0.6);
        }
      }

      // Heal orb significantly
      final orbHeal = (totalDrained * 0.25).toInt();
      game.orb.heal(orbHeal);
      ImpactVisuals.playHeal(game, game.orb.position, scale: 1.0);
    });

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  /// 🌫️ STEAM - Geyser Barrage (erupting scalding jets)
  static void _steamGeyserBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.5 * getAbilityPowerMultiplier(attacker))
            .toInt();

    final origin = attacker.position.clone();
    final primaryTarget = target ?? game.pickTargetForGuardian(attacker);
    if (primaryTarget == null) return;

    final baseDir = (primaryTarget.position - origin).normalized();
    final rng = Random();

    // 5 geyser eruption points in a cone
    for (int g = 0; g < 5; g++) {
      final coneOffset = (g - 2) * 0.25; // -0.5 to +0.5 radians spread
      final rotCos = cos(coneOffset);
      final rotSin = sin(coneOffset);
      final geyserDir = Vector2(
        baseDir.x * rotCos - baseDir.y * rotSin,
        baseDir.x * rotSin + baseDir.y * rotCos,
      );

      final geyserDist = 150.0 + g * 60.0;
      final geyserPos = origin + geyserDir * geyserDist;

      Future.delayed(Duration(milliseconds: g * 120), () {
        if (attacker.isDead) return;

        // Create geyser visual
        final geyser = CircleComponent(
          radius: 60,
          position: geyserPos,
          anchor: Anchor.center,
          paint: Paint()..color = Colors.white.withOpacity(0.4),
        );

        // Eruption bursts
        int burstCount = 0;
        geyser.add(
          TimerComponent(
            period: 0.3,
            repeat: true,
            onTick: () {
              burstCount++;
              if (burstCount > 8) return;

              final victims = game.getEnemiesInRange(geyserPos, 70);
              for (final v in victims) {
                // Scald damage
                v.takeDamage((damage * 0.4).toInt());

                // Apply burn
                v.unit.applyStatusEffect(
                  SurvivalStatusEffect(
                    type: 'Burn',
                    damagePerTick: (attacker.unit.statIntelligence * 1.2)
                        .toInt()
                        .clamp(3, 60),
                    ticksRemaining: 3,
                    tickInterval: 0.5,
                  ),
                );

                // Disorientation - random scatter
                final jitter = Vector2(
                  (rng.nextDouble() - 0.5) * 50,
                  (rng.nextDouble() - 0.5) * 50,
                );
                v.position += jitter;
              }

              ImpactVisuals.play(game, geyserPos, 'Steam', scale: 0.8);
            },
          ),
        );

        geyser.add(RemoveEffect(delay: 2.5));
        game.world.add(geyser);
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 7.0);
  }

  /// 🟤 MUD - Quagmire Barrage (sticky bog that traps enemies)
  static void _mudQuagmireBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.4 * getAbilityPowerMultiplier(attacker))
            .toInt();

    final origin = attacker.position.clone();
    final primaryTarget = target ?? game.pickTargetForGuardian(attacker);
    if (primaryTarget == null) return;

    final baseDir = (primaryTarget.position - origin).normalized();

    // Fire 24 mud globs that create sticky patches
    for (int i = 0; i < 24; i++) {
      final t = i / 23.0;
      final spreadAngle = (t - 0.5) * 0.8; // ~45 degree cone
      final rotCos = cos(spreadAngle);
      final rotSin = sin(spreadAngle);
      final dir = Vector2(
        baseDir.x * rotCos - baseDir.y * rotSin,
        baseDir.x * rotSin + baseDir.y * rotCos,
      );

      final targetDist = 200.0 + (i % 3) * 100.0; // Staggered distances
      final impactPos = origin + dir * targetDist;

      Future.delayed(Duration(milliseconds: i * 35), () {
        if (attacker.isDead) return;

        // Find enemy near impact point
        final nearbyEnemies = game.getEnemiesInRange(impactPos, 80);
        final targetEnemy = nearbyEnemies.isNotEmpty
            ? nearbyEnemies.first
            : null;

        if (targetEnemy != null) {
          game.spawnAlchemyProjectile(
            start: origin,
            target: targetEnemy,
            damage: damage,
            color: color,
            shape: ProjectileShape.bolt,
            speed: 3.0, // Slow, heavy mud
            isEnemy: false,
            onHit: () {
              if (targetEnemy.isDead) return;

              targetEnemy.takeDamage(damage);

              // Create mud patch at impact
              _createMudPatch(game, attacker, targetEnemy.position.clone());
            },
          );
        } else {
          // No enemy, just create mud patch at target location
          _createMudPatch(game, attacker, impactPos);
        }
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  /// Helper: Creates a persistent mud patch that slows enemies
  static void _createMudPatch(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 position,
  ) {
    final patchRadius = 50.0 + attacker.unit.statIntelligence * 8;
    final slowStrength = 8.0 + attacker.unit.statIntelligence * 1.5;

    final mudPatch = CircleComponent(
      radius: patchRadius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.brown.shade700.withOpacity(0.35),
    );

    mudPatch.add(
      TimerComponent(
        period: 0.15,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(position, patchRadius);
          for (final v in victims) {
            // Constant drag back toward orb direction (stuck in mud)
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    mudPatch.add(
      SequenceEffect([
        OpacityEffect.to(0.35, EffectController(duration: 2.5)),
        OpacityEffect.fadeOut(EffectController(duration: 0.5)),
        RemoveEffect(),
      ]),
    );

    game.world.add(mudPatch);
  }

  /// 🏜️ DUST - Desert Barrage (blinding sandstorm cone)
  static void _dustDesertBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.3 * getAbilityPowerMultiplier(attacker))
            .toInt();

    final origin = attacker.position.clone();
    final primaryTarget = target ?? game.pickTargetForGuardian(attacker);
    if (primaryTarget == null) return;

    final baseDir = (primaryTarget.position - origin).normalized();
    final rng = Random();

    // Create a sandstorm cone zone
    final stormLength = 400.0;
    final stormWidth = 200.0;
    final stormCenter = origin + baseDir * (stormLength * 0.5);

    // Visual sandstorm area
    final sandstorm = CircleComponent(
      radius: stormWidth,
      position: stormCenter,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.amber.shade300.withOpacity(0.3),
    );

    // Swirling effect
    sandstorm.add(
      RotateEffect.by(6.28, EffectController(duration: 1.5, infinite: true)),
    );

    int tickCount = 0;
    sandstorm.add(
      TimerComponent(
        period: 0.2,
        repeat: true,
        onTick: () {
          tickCount++;
          if (tickCount > 20) return; // 4 seconds of storm

          // Get all enemies in the cone area
          final victims = game.getEnemiesInRange(stormCenter, stormWidth);

          for (final v in victims) {
            // Verify they're actually in the cone direction
            final toEnemy = (v.position - origin).normalized();
            final dot = toEnemy.dot(baseDir);
            if (dot < 0.5) continue; // Not in cone

            // Damage
            v.takeDamage((damage * 0.15).toInt());

            // Heavy disorientation - random movement
            final jitter = Vector2(
              (rng.nextDouble() - 0.5) * 60,
              (rng.nextDouble() - 0.5) * 60,
            );
            v.position += jitter;

            // Occasional bigger stumble
            if (rng.nextDouble() < 0.2) {
              final bigJitter = Vector2(
                (rng.nextDouble() - 0.5) * 100,
                (rng.nextDouble() - 0.5) * 100,
              );
              v.add(
                MoveEffect.by(
                  bigJitter,
                  EffectController(duration: 0.2, curve: Curves.easeOut),
                ),
              );
            }
          }

          // Visual dust puffs
          final puffPos =
              stormCenter +
              Vector2(
                (rng.nextDouble() - 0.5) * stormWidth,
                (rng.nextDouble() - 0.5) * stormWidth,
              );
          ImpactVisuals.play(game, puffPos, 'Dust', scale: 0.6);
        },
      ),
    );

    sandstorm.add(
      SequenceEffect([
        OpacityEffect.to(0.4, EffectController(duration: 3.5)),
        OpacityEffect.fadeOut(EffectController(duration: 0.5)),
        RemoveEffect(),
      ]),
    );

    game.world.add(sandstorm);

    // Also fire some projectiles for immediate impact
    for (int i = 0; i < 16; i++) {
      final spreadAngle = (i / 15.0 - 0.5) * 0.6;
      final rotCos = cos(spreadAngle);
      final rotSin = sin(spreadAngle);
      final dir = Vector2(
        baseDir.x * rotCos - baseDir.y * rotSin,
        baseDir.x * rotSin + baseDir.y * rotCos,
      );

      Future.delayed(Duration(milliseconds: i * 30), () {
        if (attacker.isDead) return;

        final enemies = game.getEnemiesInRange(origin, 500);
        HoardEnemy? best;
        double bestDot = 0.7;

        for (final e in enemies) {
          final toEnemy = (e.position - origin).normalized();
          final d = toEnemy.dot(dir);
          if (d > bestDot) {
            bestDot = d;
            best = e;
          }
        }

        if (best == null || best.isDead) return;

        game.spawnAlchemyProjectile(
          start: origin,
          target: best,
          damage: damage,
          color: color,
          shape: ProjectileShape.bolt,
          speed: 3.5,
          isEnemy: false,
          onHit: () {
            if (best == null || best.isDead) return;
            best.takeDamage(damage);
            ImpactVisuals.play(game, best.position, 'Dust', scale: 0.5);
          },
        );
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  /// 🔥 FIRE - Spiraling Inferno (360° rotating barrage)
  static void _fireInferno(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.8 * getAbilityPowerMultiplier(attacker))
            .toInt();

    final center = attacker.position.clone();

    // 3 waves of spiraling fire
    for (int wave = 0; wave < 3; wave++) {
      Future.delayed(Duration(milliseconds: wave * 400), () {
        if (attacker.isDead) return;

        // 16 projectiles in a circle
        for (int i = 0; i < 16; i++) {
          final angle =
              (i / 16.0) * pi * 2 + (wave * pi / 4); // Offset each wave
          final direction = Vector2(cos(angle), sin(angle));
          final endPos = center + direction * 600;

          Future.delayed(Duration(milliseconds: i * 30), () {
            if (attacker.isDead) return;

            // Find enemy along this ray
            final enemies = game.getEnemiesInRange(center, 600);
            HoardEnemy? best;
            double bestDist = 999999;

            for (final e in enemies) {
              final toEnemy = (e.position - center).normalized();
              final dot = toEnemy.dot(direction);
              if (dot > 0.8) {
                // Within narrow cone
                final dist = e.position.distanceTo(center);
                if (dist < bestDist) {
                  bestDist = dist;
                  best = e;
                }
              }
            }

            if (best == null || best.isDead) return;

            game.spawnAlchemyProjectile(
              start: center,
              target: best,
              damage: damage,
              color: color,
              shape: ProjectileShape.shard,
              speed: 4.0,
              isEnemy: false,
              onHit: () {
                if (best == null || best.isDead) return;
                best.takeDamage(damage);
                // Ignite nearby enemies
                final nearby = game.getEnemiesInRange(best.position, 80);
                for (final n in nearby) {
                  n.unit.applyStatusEffect(
                    SurvivalStatusEffect(
                      type: 'Burn',
                      damagePerTick: (damage * 0.15).toInt(),
                      ticksRemaining: 4,
                      tickInterval: 0.5,
                    ),
                  );
                }
                ImpactVisuals.play(game, best.position, 'Fire', scale: 0.8);
              },
            );
          });
        }
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 8.0);
  }

  /// 🌋 LAVA - Volcano (erupting cone of heavy knockback shards)
  static void _lavaVolcano(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.7 * getAbilityPowerMultiplier(attacker))
            .toInt();

    final origin = attacker.position.clone();
    final primaryTarget = target ?? game.pickTargetForGuardian(attacker);
    if (primaryTarget == null) return;

    final baseDir = (primaryTarget.position - origin).normalized();
    final double coneAngle = 60 * pi / 180.0;
    final rng = Random();

    // 20 eruptions in a wide cone
    for (int i = 0; i < 20; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (attacker.isDead) return;

        final t = i / 19.0;
        final offset = (t - 0.5) * coneAngle;
        final rotCos = cos(offset);
        final rotSin = sin(offset);
        final dir = Vector2(
          baseDir.x * rotCos - baseDir.y * rotSin,
          baseDir.x * rotSin + baseDir.y * rotCos,
        );

        // Pick an enemy roughly along this direction
        final enemies = game.getEnemiesInRange(origin, 600);
        HoardEnemy? best;
        double bestDot = 0.8;
        for (final e in enemies) {
          final toEnemy = (e.position - origin);
          final len = toEnemy.length;
          if (len < 10) continue;
          final d = toEnemy / len;
          final dot = d.dot(dir);
          if (dot > bestDot) {
            bestDot = dot;
            best = e;
          }
        }

        if (best == null || best.isDead) return;

        game.spawnAlchemyProjectile(
          start: origin,
          target: best,
          damage: damage,
          color: color,
          shape: ProjectileShape.shard,
          speed: 4.0,
          isEnemy: false,
          onHit: () {
            if (best == null || best.isDead) return;
            best.takeDamage(damage);

            // Heavy knockback
            final knockDir =
                (best.position - origin).normalized() *
                (120 + rng.nextInt(40)).toDouble();
            best.add(
              MoveEffect.by(
                knockDir,
                EffectController(duration: 0.2, curve: Curves.easeOut),
              ),
            );

            // Small lava pool at hit
            final pool = CircleComponent(
              radius: 70,
              position: best.position.clone(),
              anchor: Anchor.center,
              paint: Paint()..color = Colors.orange.shade800.withOpacity(0.4),
            );
            pool.add(
              TimerComponent(
                period: 0.4,
                repeat: true,
                onTick: () {
                  final victims = game.getEnemiesInRange(pool.position, 70);
                  for (final v in victims) {
                    v.takeDamage((damage * 0.25).toInt());
                  }
                },
              ),
            );
            pool.add(RemoveEffect(delay: 2.0));
            game.world.add(pool);

            ImpactVisuals.play(game, best.position, 'Lava', scale: 0.9);
          },
        );
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 9.0);
  }

  /// 🌊 WATER - Tsunami Wave (sweeping horizontal barrage)
  static void _waterTsunami(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.6 * getAbilityPowerMultiplier(attacker))
            .toInt();

    // Determine wave direction (perpendicular to orb)
    final toOrb = (game.orb.position - attacker.position).normalized();
    final waveDir = Vector2(-toOrb.y, toOrb.x); // Perpendicular

    // 30 projectiles in a line moving forward
    for (int i = 0; i < 30; i++) {
      final lateralOffset = (i - 15) * 40.0; // Spread along the wave
      final startPos = attacker.position + waveDir * lateralOffset;

      Future.delayed(Duration(milliseconds: i * 20), () {
        if (attacker.isDead) return;

        final endPos = startPos + toOrb * 800;

        // Find enemies along this path
        final enemies = game.getEnemiesInRange(startPos, 800);
        HoardEnemy? best;

        for (final e in enemies) {
          final toEnemy = (e.position - startPos);
          final projected = toOrb.dot(toEnemy);
          if (projected > 0 && projected < 800) {
            // Check if close to the line
            final pointOnLine = startPos + toOrb * projected;
            if (pointOnLine.distanceTo(e.position) < 50) {
              best = e;
              break;
            }
          }
        }

        if (best == null || best.isDead) return;

        game.spawnAlchemyProjectile(
          start: startPos,
          target: best,
          damage: damage,
          color: color,
          shape: ProjectileShape.blade,
          speed: 3.0,
          isEnemy: false,
          onHit: () {
            if (best == null || best.isDead) return;
            best.takeDamage(damage);
            // Knockback away from orb
            final pushDir = (best.position - game.orb.position).normalized();
            best.add(
              MoveEffect.by(pushDir * 80, EffectController(duration: 0.2)),
            );
            ImpactVisuals.play(game, best.position, 'Water', scale: 0.7);
          },
        );
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 7.0);
  }

  /// ⚡ LIGHTNING - Chain Storm (projectiles that chain forever-ish)
  static void _lightningStorm(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.4 * getAbilityPowerMultiplier(attacker))
            .toInt();

    // Fire 8 initial bolts
    final enemies = game
        .getEnemiesInRange(attacker.position, 600)
        .take(8)
        .toList();

    for (int i = 0; i < enemies.length; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (attacker.isDead) return;
        _fireChainLightning(
          game,
          attacker.position,
          enemies[i],
          damage,
          color,
          5,
        ); // Chain up to 5 times
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  static void _fireChainLightning(
    SurvivalHoardGame game,
    Vector2 from,
    HoardEnemy target,
    int damage,
    Color color,
    int remainingChains,
  ) {
    if (target.isDead || remainingChains <= 0) return;

    game.spawnAlchemyProjectile(
      start: from,
      target: target,
      damage: damage,
      color: color,
      shape: ProjectileShape.bolt,
      speed: 6.0,
      isEnemy: false,
      onHit: () {
        if (target.isDead) return;
        target.takeDamage(damage);
        ImpactVisuals.play(game, target.position, 'Lightning', scale: 0.6);

        // Chain to next enemy
        final nearby = game
            .getEnemiesInRange(target.position, 250)
            .where((e) => e != target && !e.isDead)
            .toList();
        if (nearby.isNotEmpty) {
          final next = nearby[Random().nextInt(nearby.length)];
          Future.delayed(const Duration(milliseconds: 100), () {
            _fireChainLightning(
              game,
              target.position,
              next,
              (damage * 0.9).toInt(),
              color,
              remainingChains - 1,
            );
          });
        }
      },
    );
  }

  /// ❄️ ICE - Frozen Barrage (slow projectiles, huge AoE freeze on impact)
  static void _iceBlizzard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.5 * getAbilityPowerMultiplier(attacker))
            .toInt();

    // 24 slow-moving icicles that explode on impact
    for (int i = 0; i < 24; i++) {
      final angle = (i / 24.0) * pi * 2;
      final direction = Vector2(cos(angle), sin(angle));

      Future.delayed(Duration(milliseconds: i * 50), () {
        if (attacker.isDead) return;

        final endPos = attacker.position + direction * 500;
        final enemies = game.getEnemiesInRange(attacker.position, 500);

        HoardEnemy? best;
        double bestDot = 0.9;
        for (final e in enemies) {
          final toEnemy = (e.position - attacker.position).normalized();
          final dot = toEnemy.dot(direction);
          if (dot > bestDot) {
            bestDot = dot;
            best = e;
          }
        }

        if (best == null || best.isDead) return;

        game.spawnAlchemyProjectile(
          start: attacker.position,
          target: best,
          damage: damage,
          color: color,
          shape: ProjectileShape.blade,
          speed: 1.5, // VERY slow
          isEnemy: false,
          onHit: () {
            final impactPos = best!.position.clone();
            // Freeze all enemies in large radius
            final frozen = game.getEnemiesInRange(impactPos, 120);
            for (final f in frozen) {
              f.takeDamage((damage * 0.8).toInt());
              // Push away from orb (frozen push)
              final pushDir = (f.position - game.orb.position).normalized();
              f.position += pushDir * 40;
            }
            ImpactVisuals.playExplosion(game, impactPos, 'Ice', 120);
          },
        );
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 7.0);
  }

  /// 🌪️ AIR - Tornado (spiraling vortex that sucks enemies in)
  static void _airTornado(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.3 * getAbilityPowerMultiplier(attacker))
            .toInt();
    final centerPos = attacker.position.clone();

    // Create visible tornado
    final tornado = CircleComponent(
      radius: 30,
      position: centerPos,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    tornado.add(
      ScaleEffect.to(
        Vector2.all(8.0),
        EffectController(duration: 2.5, curve: Curves.easeOut),
      ),
    );
    tornado.add(OpacityEffect.fadeOut(EffectController(duration: 2.5)));
    tornado.add(RemoveEffect(delay: 2.51));
    game.world.add(tornado);

    // Pull enemies toward center and damage them
    const duration = 2.5;
    const pullInterval = 0.1;
    final int tickCount = (duration / pullInterval).floor();

    for (int tick = 0; tick < tickCount; tick++) {
      Future.delayed(
        Duration(milliseconds: (tick * pullInterval * 1000).toInt()),
        () {
          if (attacker.isDead) return;

          final victims = game.getEnemiesInRange(centerPos, 250);
          for (final v in victims) {
            // Pull toward center
            final toCenter = (centerPos - v.position);
            final dist = toCenter.length;
            if (dist > 20) {
              final pullStrength = min(dist * 0.15, 30.0);
              v.position += toCenter.normalized() * pullStrength;
            }

            // Damage
            if (tick % 3 == 0) {
              v.takeDamage((damage * 0.3).toInt());
              ImpactVisuals.play(game, v.position, 'Air', scale: 0.5);
            }
          }
        },
      );
    }

    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  /// 🌍 EARTH - Earthquake (expanding shockwaves)
  static void _earthQuake(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int baseDamage =
        (calcDmg(attacker, null) * 1.9 * getAbilityPowerMultiplier(attacker))
            .toInt();
    final center = attacker.position.clone();

    for (int wave = 0; wave < 4; wave++) {
      final radius = 150.0 + wave * 70.0;
      Future.delayed(Duration(milliseconds: wave * 250), () {
        if (attacker.isDead) return;

        final victims = game.getEnemiesInRange(center, radius);
        for (final v in victims) {
          final dist = v.position.distanceTo(center);
          final falloff = 1.0 - (dist / radius) * 0.5;
          final int dmg = max(1, (baseDamage * falloff).toInt());
          v.takeDamage(dmg);

          final dir = (v.position - center).normalized();
          v.add(
            MoveEffect.by(
              dir * 60.0,
              EffectController(duration: 0.2, curve: Curves.easeOut),
            ),
          );
        }

        ImpactVisuals.playExplosion(game, center, 'Earth', radius);
        SurvivalAttackManager.triggerScreenShake(game, 4.0 + wave.toDouble());
      });
    }
  }

  /// 💎 CRYSTAL - Prismatic Refraction (fires in one direction, splits into rainbow)
  static void _crystalPrism(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.6 * getAbilityPowerMultiplier(attacker))
            .toInt();

    final primaryTarget = target ?? game.pickTargetForGuardian(attacker);
    if (primaryTarget == null) return;

    // Fire main crystal beam
    game.spawnAlchemyProjectile(
      start: attacker.position,
      target: primaryTarget,
      damage: damage,
      color: color,
      shape: ProjectileShape.shard,
      speed: 4.5,
      isEnemy: false,
      onHit: () {
        if (primaryTarget.isDead) return;
        primaryTarget.takeDamage(damage);

        // SPLIT into 12 shards in all directions
        for (int i = 0; i < 12; i++) {
          final angle = (i / 12.0) * pi * 2;
          final direction = Vector2(cos(angle), sin(angle));

          Future.delayed(Duration(milliseconds: i * 40), () {
            final enemies = game.getEnemiesInRange(primaryTarget.position, 400);
            HoardEnemy? best;
            double bestDot = 0.85;

            for (final e in enemies) {
              if (e == primaryTarget) continue;
              final toEnemy = (e.position - primaryTarget.position)
                  .normalized();
              final dot = toEnemy.dot(direction);
              if (dot > bestDot) {
                bestDot = dot;
                best = e;
              }
            }

            if (best == null || best.isDead) return;

            game.spawnAlchemyProjectile(
              start: primaryTarget.position,
              target: best,
              damage: (damage * 0.7).toInt(),
              color: Colors.primaries[i % Colors.primaries.length],
              shape: ProjectileShape.shard,
              speed: 4.0,
              isEnemy: false,
              onHit: () {
                if (best == null || best.isDead) return;
                best.takeDamage((damage * 0.7).toInt());
                ImpactVisuals.play(game, best.position, 'Crystal', scale: 0.6);
              },
            );
          });
        }

        ImpactVisuals.playExplosion(
          game,
          primaryTarget.position,
          'Crystal',
          150,
        );
      },
    );

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  /// 🌿 PLANT - Overgrowth (ring of thorn gardens)
  static void _plantOvergrowth(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final center = attacker.position.clone();
    final int thornDps = (attacker.unit.statIntelligence * 1.4)
        .toInt()
        .clamp(5, 120)
        .toInt();
    const double ringRadius = 220.0;
    const int patches = 6;
    const double gardenRadius = 120.0;

    for (int i = 0; i < patches; i++) {
      final angle = (i / patches) * pi * 2;
      final pos = center + Vector2(cos(angle), sin(angle)) * ringRadius;

      Future.delayed(Duration(milliseconds: i * 120), () {
        final garden = CircleComponent(
          radius: gardenRadius,
          position: pos,
          anchor: Anchor.center,
          paint: Paint()..color = Colors.green.withOpacity(0.3),
        );

        garden.add(
          TimerComponent(
            period: 0.45,
            repeat: true,
            onTick: () {
              final victims = game.getEnemiesInRange(pos, gardenRadius);
              for (final v in victims) {
                v.takeDamage(thornDps);
                final pushBack =
                    (v.targetOrb.position - v.position).normalized() * -10.0;
                v.position += pushBack;
              }

              final allies = game.getGuardiansInRange(
                center: pos,
                range: gardenRadius,
              );
              final int heal = (thornDps * 0.5).toInt();
              for (final g in allies) {
                g.unit.heal(heal);
                ImpactVisuals.playHeal(game, g.position, scale: 0.5);
              }
            },
          ),
        );

        garden.add(RemoveEffect(delay: 4.5));
        game.world.add(garden);
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  /// ☠️ POISON - Miasma (huge lingering poison cloud)
  static void _poisonMiasma(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final center = (target?.position ?? attacker.position).clone();

    final basePoisonDmg = (attacker.unit.statIntelligence * 1.0).toInt().clamp(
      4,
      80,
    );

    const double radius = 50.0;
    // scale duration with intelligence
    final double duration = (6.0 + attacker.unit.statIntelligence * 0.1).clamp(
      6.0,
      12.0,
    );

    final cloud = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = color.withOpacity(0.4),
    );

    int tickCount = 0;

    cloud.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          tickCount++;

          // Ramping damage - poison gets stronger the longer you stay
          final rampMult =
              1.0 + (tickCount * 0.1).clamp(0.0, 1.5); // Up to 2.5x
          final currentDmg = (basePoisonDmg * rampMult).toInt();

          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            // Apply stacking poison
            v.unit.applyStatusEffect(
              SurvivalStatusEffect(
                type: 'Poison',
                damagePerTick: currentDmg,
                ticksRemaining: 8,
                tickInterval: 0.4,
              ),
            );

            // Visual feedback
            if (tickCount % 2 == 0) {
              ImpactVisuals.play(game, v.position, 'Poison', scale: 0.5);
            }
          }
        },
      ),
    );

    // Pulsing visual
    cloud.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.1),
          EffectController(duration: 0.8, curve: Curves.easeInOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.8, curve: Curves.easeInOut),
        ),
      ], infinite: true),
    );

    cloud.add(RemoveEffect(delay: duration));
    game.world.add(cloud);
    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  /// 🌑 DARK - Void Vortex (sucks in projectiles and enemies, then explodes)
  static void _darkVortex(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 2.0 * getAbilityPowerMultiplier(attacker))
            .toInt();
    final vortexPos = attacker.position + Vector2(0, -150);

    // Visual vortex
    final vortex = CircleComponent(
      radius: 40,
      position: vortexPos,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.fill,
    );
    vortex.add(
      ScaleEffect.by(
        Vector2.all(2.0),
        EffectController(duration: 1.5, curve: Curves.easeIn),
      ),
    );
    vortex.add(RemoveEffect(delay: 1.5));
    game.world.add(vortex);

    // Pull phase (1.5 seconds)
    for (int i = 0; i < 15; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (attacker.isDead) return;

        final victims = game.getEnemiesInRange(vortexPos, 350);
        for (final v in victims) {
          final toVortex = (vortexPos - v.position);
          final dist = toVortex.length;
          if (dist > 10) {
            v.position += toVortex.normalized() * min(dist * 0.2, 25.0);
          }
        }
      });
    }

    // Explosion
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (attacker.isDead) return;

      final victims = game.getEnemiesInRange(vortexPos, 200);
      for (final v in victims) {
        v.takeDamage(damage);
        // Execute low HP enemies
        if (!v.isBoss && v.unit.hpPercent < 0.25) {
          v.takeDamage(99999);
        }
      }
      ImpactVisuals.playExplosion(game, vortexPos, 'Dark', 200);
      SurvivalAttackManager.triggerScreenShake(game, 10.0);
    });
  }

  /// ☀️ LIGHT - Nova (big damage + team heal)
  static void _lightNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.7 * getAbilityPowerMultiplier(attacker))
            .toInt();
    final center = attacker.position.clone();

    final nova = CircleComponent(
      radius: 40,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = color.withOpacity(0.4),
    );
    nova.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(5.0), EffectController(duration: 0.6)),
        OpacityEffect.fadeOut(EffectController(duration: 0.3)),
        RemoveEffect(),
      ]),
    );
    game.world.add(nova);

    // Single big pulse
    final victims = game.getEnemiesInRange(center, 260);
    for (final v in victims) {
      v.takeDamage(damage);
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.9);
    }

    // Heal team + orb
    final int healAmount = (attacker.unit.statIntelligence * 4.0)
        .toInt()
        .clamp(20, 300)
        .toInt();
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healAmount);
        ImpactVisuals.playHeal(game, g.position, scale: 0.7);
      }
    }
    game.orb.heal((healAmount * 0.6).toInt());

    SurvivalAttackManager.triggerScreenShake(game, 7.0);
  }

  /// 🌗 SPIRIT - Whirlwind (spirit bolts that mark then explode)
  static void _spiritWhirlwind(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    Color color,
  ) {
    final int markDamage =
        (calcDmg(attacker, null) * 1.4 * getAbilityPowerMultiplier(attacker))
            .toInt();
    final origin = attacker.position.clone();

    final enemies = game.getEnemiesInRange(origin, 600).take(10).toList();
    for (int i = 0; i < enemies.length; i++) {
      final e = enemies[i];
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (attacker.isDead || e.isDead) return;

        game.spawnAlchemyProjectile(
          start: origin,
          target: e,
          damage: markDamage,
          color: color,
          shape: ProjectileShape.shard,
          speed: 4.0,
          isEnemy: false,
          onHit: () {
            if (e.isDead) return;
            e.takeDamage(markDamage);
            ImpactVisuals.play(game, e.position, 'Spirit', scale: 0.8);

            // Delayed mini explosion around each marked enemy
            Future.delayed(const Duration(milliseconds: 500), () {
              if (e.isDead) return;
              final victims = game.getEnemiesInRange(e.position, 80);
              for (final v in victims) {
                v.takeDamage((markDamage * 0.6).toInt());
                ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.5);
              }
            });
          },
        );
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  /// Fallback massive barrage
  static void _massiveBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
    Color color,
  ) {
    final int damage =
        (calcDmg(attacker, null) * 1.5 * getAbilityPowerMultiplier(attacker))
            .toInt();

    for (int i = 0; i < 40; i++) {
      Future.delayed(Duration(milliseconds: i * 25), () {
        if (attacker.isDead) return;

        final nearestEnemy = game.pickTargetForGuardian(attacker);
        if (nearestEnemy == null || nearestEnemy.isDead) return;

        game.spawnAlchemyProjectile(
          start: attacker.position,
          target: nearestEnemy,
          damage: damage,
          color: color,
          shape: ProjectileShape.bolt,
          speed: 4.0,
          isEnemy: false,
          onHit: () {
            if (!nearestEnemy.isDead) {
              nearestEnemy.takeDamage(damage);
              ImpactVisuals.play(
                game,
                nearestEnemy.position,
                element,
                scale: 0.6,
              );
            }
          },
        );
      });
    }

    SurvivalAttackManager.triggerScreenShake(game, 7.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ELEMENTAL RIDERS FOR RANK 1–2
  // ═══════════════════════════════════════════════════════════════════════════

  static void _applyElementalBarrage({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank, // 1–3 here
    required HoardEnemy victim,
    required int damage,
    required int projectileIndex,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireBarrage(game, attacker, rank, victim);
        break;
      case 'Lava':
        _lavaBarrage(game, attacker, rank, victim);
        break;
      case 'Blood':
        _bloodBarrage(game, attacker, rank, victim, damage);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterBarrage(game, attacker, rank, victim);
        break;
      case 'Ice':
        _iceBarrage(game, attacker, rank, victim);
        break;
      case 'Steam':
        _steamBarrage(game, attacker, rank, victim);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantBarrage(game, attacker, rank, victim);
        break;
      case 'Poison':
        _poisonBarrage(game, attacker, rank, victim);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthBarrage(game, attacker, rank, victim);
        break;
      case 'Mud':
        _mudBarrage(game, attacker, rank, victim);
        break;
      case 'Crystal':
        _crystalBarrage(game, attacker, rank, victim, damage, projectileIndex);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airBarrage(game, attacker, rank, victim);
        break;
      case 'Dust':
        _dustBarrage(game, attacker, rank, victim);
        break;
      case 'Lightning':
        _lightningBarrage(game, attacker, rank, victim, damage);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritBarrage(game, attacker, rank, victim);
        break;
      case 'Dark':
        _darkBarrage(game, attacker, rank, victim);
        break;
      case 'Light':
        _lightBarrage(game, attacker, rank, victim);
        break;

      default:
        break;
    }
  }

  //
  //  FIRE / LAVA / BLOOD
  //

  /// Fire Barrage - Burns stack on each hit
  static void _fireBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final int burnDmg = (attacker.unit.statIntelligence * (1.0 + 0.3 * rank))
        .toInt()
        .clamp(3, 120)
        .toInt();

    victim.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Burn',
        damagePerTick: burnDmg,
        ticksRemaining: 2 + rank,
        tickInterval: 0.5,
      ),
    );
  }

  /// Lava Barrage - Knockback on each hit
  static void _lavaBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    // Lava shot ignites and leaves a burning lava pool at impact — distinct from
    // Earth's raw knockback.
    victim.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Burn',
        damagePerTick: (attacker.unit.statIntelligence * (0.6 + 0.15 * rank))
            .toInt()
            .clamp(2, 50),
        ticksRemaining: 4 + rank,
        tickInterval: 0.4,
      ),
    );
    // Leave a small lava pool at the impact point
    final color = SurvivalAttackManager.getElementColor('Lava');
    final poolPos = victim.position.clone();
    final poolRadius = 30.0 + rank * 5;
    final pool = CircleComponent(
      radius: poolRadius,
      position: poolPos,
      anchor: Anchor.center,
      paint: Paint()..color = color.withOpacity(0.4),
    );
    final poolTick = max(
      1,
      (attacker.unit.statIntelligence * (0.3 + 0.08 * rank)).toInt(),
    );
    pool.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          for (final v in game.getEnemiesInRange(poolPos, poolRadius)) {
            v.takeDamage(poolTick);
          }
        },
      ),
    );
    pool.add(RemoveEffect(delay: 2.0 + rank * 0.5));
    game.world.add(pool);
  }

  //
  //  WATER / ICE / STEAM
  //

  /// Water Barrage - Push enemies away from orb + small guardian heal per shot
  static void _waterBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    // Push away from orb
    final dir = (victim.position - game.orb.position).normalized();
    victim.add(
      MoveEffect.by(
        dir * (10.0 + 4.0 * rank),
        EffectController(duration: 0.12),
      ),
    );
    // Each water shot carries healing energy to nearby guardians
    final int healAmt = (attacker.unit.statIntelligence * (0.3 + 0.06 * rank))
        .toInt()
        .clamp(1, 20);
    for (final g in game.getGuardiansInRange(
      center: victim.position,
      range: 120,
    )) {
      g.unit.heal(healAmt);
    }
  }

  /// Ice Barrage - Stacking micro-slow / pushback
  static void _iceBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final pushBack =
        (victim.targetOrb.position - victim.position).normalized() *
        -(6.0 + rank * 2.0);
    victim.position += pushBack;
  }

  //
  //  PLANT / POISON
  //

  /// Plant Barrage - Bleed DoT
  static void _plantBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final int bleedDmg = (attacker.unit.statIntelligence * (0.8 + 0.2 * rank))
        .toInt()
        .clamp(2, 80)
        .toInt();

    victim.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Thorns',
        damagePerTick: bleedDmg,
        ticksRemaining: 3 + rank,
        tickInterval: 0.4,
      ),
    );
  }

  /// Poison Barrage - Poison application
  /// Poison Barrage - Stacking venom that spreads
  static void _poisonBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    // Lower per-tick than fire, but MORE ticks and STACKS
    final poisonDmg = (attacker.unit.statIntelligence * (0.7 + 0.15 * rank))
        .toInt()
        .clamp(2, 60);

    // Long duration - poison lingers
    final ticks = 8 + rank * 2; // 10, 12, 14 ticks at R1, R2, R3

    victim.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Poison',
        damagePerTick: poisonDmg,
        ticksRemaining: ticks,
        tickInterval: 0.4, // Fast ticks = more total damage
      ),
    );

    // Rank 2+: Poison spreads to one nearby enemy (weaker)
    if (rank >= 2) {
      final nearby = game
          .getEnemiesInRange(victim.position, 100)
          .where((e) => e != victim && !e.isDead)
          .take(1);

      for (final n in nearby) {
        n.unit.applyStatusEffect(
          SurvivalStatusEffect(
            type: 'Poison',
            damagePerTick: (poisonDmg * 0.5).toInt(),
            ticksRemaining: (ticks * 0.6).toInt(),
            tickInterval: 0.5,
          ),
        );
      }
    }
  }
  //
  //  EARTH / MUD / CRYSTAL
  //

  /// Earth Barrage - Heavy knockback
  static void _earthBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final dir = (victim.position - attacker.position).normalized();
    victim.add(
      MoveEffect.by(
        dir * (22.0 + 5.0 * rank),
        EffectController(duration: 0.12),
      ),
    );
  }

  /// Mud Barrage - Sticky slowdown that stacks and lingers
  static void _mudBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    // Small immediate pushback (mud is sticky, not slippery like ice)
    final pushBack =
        (victim.targetOrb.position - victim.position).normalized() *
        -(4.0 + rank * 1.0);
    victim.position += pushBack;

    // Apply "Mudded" status - long duration slow
    final slowStrength =
        (2.0 + rank * 0.8 + attacker.unit.statIntelligence * 0.6).toInt().clamp(
          2,
          15,
        );

    victim.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Mudded',
        damagePerTick: slowStrength, // Repurposed as slow strength
        ticksRemaining: 6 + rank * 2, // Much longer than ice
        tickInterval: 0.2, // Very frequent ticks = consistent slow
      ),
    );
  }

  /// Steam Barrage - Scald damage + disorientation
  static void _steamBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final rng = Random();

    // Disorientation jitter
    final jitter = Vector2(
      (rng.nextDouble() - 0.5) * (12 + rank * 5),
      (rng.nextDouble() - 0.5) * (12 + rank * 5),
    );
    victim.position += jitter;

    // Apply scald burn (weaker than fire but still there)
    final scaldDmg = (attacker.unit.statIntelligence * (0.6 + 0.15 * rank))
        .toInt()
        .clamp(2, 50);

    victim.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Burn',
        damagePerTick: scaldDmg,
        ticksRemaining: 2 + rank,
        tickInterval: 0.5,
      ),
    );
  }

  /// Blood Barrage - Strong lifesteal
  static void _bloodBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
    int damage,
  ) {
    // Stronger lifesteal scaling
    final int heal = (damage * (0.25 + 0.08 * rank)).toInt(); // 33% at rank 3
    attacker.unit.heal(heal);
    ImpactVisuals.playHeal(game, attacker.position, scale: 0.4);

    // Rank 2+: Small orb heal too
    if (rank >= 2) {
      game.orb.heal((heal * 0.15).toInt());
    }
  }

  /// Dust Barrage - Heavier disorientation with damage
  static void _dustBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final rng = Random();

    // Strong random displacement
    final offset = Vector2(
      (rng.nextDouble() - 0.5) * (20 + rank * 8),
      (rng.nextDouble() - 0.5) * (20 + rank * 8),
    );
    victim.position += offset;

    // Rank 2+: Also deal minor damage (sand in wounds)
    if (rank >= 2) {
      final abrasionDmg = (attacker.unit.statIntelligence * 0.4).toInt().clamp(
        1,
        30,
      );
      victim.takeDamage(abrasionDmg);
    }
  }

  /// Crystal Barrage - Shard split on every 3rd projectile
  static void _crystalBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
    int damage,
    int projectileIndex,
  ) {
    // Only split once every 3rd bolt to keep visuals readable
    if ((projectileIndex + 1) % 3 != 0) return;

    final int shardDmg = (damage * (0.5 + 0.08 * rank)).toInt();
    final nearby = game
        .getEnemiesInRange(victim.position, 170)
        .where((e) => e != victim && !e.isDead)
        .take(rank >= 3 ? 3 : 2); // rank 3 can chain to 3 nearby

    for (final n in nearby) {
      game.spawnAlchemyProjectile(
        start: victim.position,
        target: n,
        damage: shardDmg,
        color: Colors.tealAccent,
        shape: ProjectileShape.shard,
        speed: 3.2,
        isEnemy: false,
        onHit: () {
          if (n.isDead) return;
          n.takeDamage(shardDmg);
          ImpactVisuals.play(game, n.position, 'Crystal', scale: 0.5);
        },
      );
    }
  }

  //
  //  AIR / DUST / LIGHTNING
  //

  /// Air Barrage - Strong knockback
  static void _airBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    // Air flings enemies in a chaotic spiral — random ±90° deviation from the
    // orb-outward direction, creating wind-scatter rather than orderly push.
    final baseDir = (victim.position - game.orb.position).normalized();
    final angle = (Random().nextDouble() - 0.5) * pi; // ±90°
    final spiralDir = Vector2(
      baseDir.x * cos(angle) - baseDir.y * sin(angle),
      baseDir.x * sin(angle) + baseDir.y * cos(angle),
    );
    victim.add(
      MoveEffect.by(
        spiralDir * (28.0 + 7.0 * rank),
        EffectController(duration: 0.15, curve: Curves.easeOut),
      ),
    );
  }

  /// Lightning Barrage - Chain to 1–2 nearby
  static void _lightningBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
    int damage,
  ) {
    final nearby = game
        .getEnemiesInRange(victim.position, 180)
        .where((e) => e != victim && !e.isDead)
        .take(rank >= 3 ? 2 : 1); // rank 3 can hit 2 nearby

    for (final n in nearby) {
      final int chainDmg = (damage * (0.55 + 0.1 * rank)).toInt();
      game.spawnAlchemyProjectile(
        start: victim.position,
        target: n,
        damage: chainDmg,
        color: Colors.yellow,
        shape: ProjectileShape.bolt,
        speed: 4.2,
        isEnemy: false,
        onHit: () {
          if (n.isDead) return;
          n.takeDamage(chainDmg);
          ImpactVisuals.play(game, n.position, 'Lightning', scale: 0.6);
        },
      );
    }
  }

  //
  //  SPIRIT / DARK / LIGHT
  //

  /// Spirit Barrage - Small drain
  static void _spiritBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final int drain = (attacker.unit.statIntelligence * (0.6 + 0.16 * rank))
        .toInt()
        .clamp(2, 60)
        .toInt();
    victim.takeDamage(drain);
    attacker.unit.heal((drain * (0.3 + 0.05 * rank)).toInt());
  }

  /// Dark Barrage - Damage amp on low HP
  static void _darkBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    if (victim.unit.hpPercent < 0.5) {
      final int bonusDmg = (calcDmg(attacker, victim) * (0.35 + 0.09 * rank))
          .toInt()
          .clamp(3, 100)
          .toInt();
      victim.takeDamage(bonusDmg);
    }
  }

  /// Light Barrage - Heal on hit
  static void _lightBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final int heal = (attacker.unit.statIntelligence * (1.0 + 0.24 * rank))
        .toInt()
        .clamp(4, 100)
        .toInt();
    attacker.unit.heal(heal);
    ImpactVisuals.playHeal(game, attacker.position, scale: 0.45);
  }
}
