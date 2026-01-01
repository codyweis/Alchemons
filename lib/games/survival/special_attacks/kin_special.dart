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

/// KIN FAMILY - BLESSING MECHANIC
/// Support ability that buffs allies and heals the team
/// Rank 1: Unlocks the elemental blessing
/// Rank 2: Stronger numbers & larger radius
/// Rank 3 (MAX): Divine blessing with powerful team-wide effects
class KinBlessingMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final rawRank = game.getSpecialAbilityRank(attacker.unit.id, element);

    // Clamp to 1–3 for the new 3-upgrade system (old saves with 4/5 behave as 3).
    final rank = rawRank.clamp(1, 3);
    final color = SurvivalAttackManager.getElementColor(element);

    // Base blessing parameters (scale modestly with rank)
    final baseRadius = 200.0 + rank * 25;
    final baseHeal = (attacker.unit.statIntelligence * (3.0 + 0.5 * rank))
        .toInt()
        .clamp(10, 200);

    // Rank 3: Divine blessing
    final isDivine = rank >= 3;
    final radius = isDivine ? baseRadius * 1.4 : baseRadius;
    final healAmount = isDivine ? (baseHeal * 1.5).toInt() : baseHeal;

    // Visual: Expanding blessing ring
    final ring = CircleComponent(
      radius: 20,
      position: attacker.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDivine ? 8 : 5,
    );

    ring.add(
      ScaleEffect.to(
        Vector2.all(radius / 20),
        EffectController(duration: 0.4, curve: Curves.easeOut),
      ),
    );
    ring.add(OpacityEffect.fadeOut(EffectController(duration: 0.5)));
    ring.add(RemoveEffect(delay: 0.51));

    game.world.add(ring);

    // Heal allies in range
    final allies = game.getGuardiansInRange(
      center: attacker.position,
      range: radius,
    );
    for (final g in allies) {
      g.unit.heal(healAmount);
      ImpactVisuals.playHeal(game, g.position, scale: 0.7);
    }

    // Heal orb if in range
    if (game.orb.position.distanceTo(attacker.position) <= radius) {
      game.orb.heal((healAmount * 0.5).toInt());
      ImpactVisuals.playHeal(game, game.orb.position, scale: 0.8);
    }

    // Apply elemental blessing
    _applyElementalBlessing(
      game: game,
      attacker: attacker,
      element: element,
      rank: rank,
      center: attacker.position,
      radius: radius,
      allies: allies,
      baseHeal: healAmount,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ELEMENT ROUTER
  // ═══════════════════════════════════════════════════════════════════════════

  static void _applyElementalBlessing({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 center,
    required double radius,
    required List<HoardGuardian> allies,
    required int baseHeal,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireBlessing(game, attacker, rank, center, radius, allies);
        break;
      case 'Lava':
        _lavaBlessing(game, attacker, rank, center, radius, allies);
        break;
      case 'Blood':
        _bloodBlessing(game, attacker, rank, center, radius, allies, baseHeal);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterBlessing(game, attacker, rank, center, radius, allies, baseHeal);
        break;
      case 'Ice':
        _iceBlessing(game, attacker, rank, center, radius);
        break;
      case 'Steam':
        _steamBlessing(game, attacker, rank, center, radius, allies);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantBlessing(game, attacker, rank, center, radius, allies, baseHeal);
        break;
      case 'Poison':
        _poisonBlessing(game, attacker, rank, center, radius);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthBlessing(game, attacker, rank, center, radius, allies);
        break;
      case 'Mud':
        _mudBlessing(game, attacker, rank, center, radius);
        break;
      case 'Crystal':
        _crystalBlessing(game, attacker, rank, center, radius, allies);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airBlessing(game, attacker, rank, center, radius);
        break;
      case 'Dust':
        _dustBlessing(game, attacker, rank, center, radius);
        break;
      case 'Lightning':
        _lightningBlessing(game, attacker, rank, center, radius, allies);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritBlessing(game, attacker, rank, center, radius, allies);
        break;
      case 'Dark':
        _darkBlessing(game, attacker, rank, center, radius);
        break;
      case 'Light':
        _lightBlessing(game, attacker, rank, center, allies, baseHeal);
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FIRE / LAVA / BLOOD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fire Blessing - Grants allies burning aura
  static void _fireBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
  ) {
    final auraDps = (attacker.unit.statIntelligence * (1.5 + 0.3 * rank))
        .toInt()
        .clamp(3, 100);
    final auraDuration = 5.0 + rank;
    final auraRadius = 60.0 + 10.0 * rank;
    final isDivine = rank >= 3;

    for (final g in allies) {
      // Burning aura around each ally
      final aura = CircleComponent(
        radius: auraRadius,
        position: Vector2.zero(),
        anchor: Anchor.center,
        paint: Paint()..color = Colors.deepOrange.withOpacity(0.15),
      );

      aura.add(
        TimerComponent(
          period: 0.5,
          repeat: true,
          onTick: () {
            final victims = game.getEnemiesInRange(g.position, auraRadius);
            for (final v in victims) {
              v.takeDamage(auraDps);
            }

            // Rank 3: occasional mini explosion around this ally
            if (isDivine &&
                victims.isNotEmpty &&
                Random().nextDouble() < 0.15) {
              final explosionDmg = (auraDps * 2).toInt();
              final boomVictims = game.getEnemiesInRange(
                g.position,
                auraRadius,
              );
              for (final v in boomVictims) {
                v.takeDamage(explosionDmg);
              }
              ImpactVisuals.playExplosion(game, g.position, 'Fire', auraRadius);
            }
          },
        ),
      );

      aura.add(RemoveEffect(delay: auraDuration));
      g.add(aura);
    }
  }

  /// Lava Blessing - Grants allies damage and knockback on attacks
  static void _lavaBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
  ) {
    // Damage all nearby enemies
    final blessingDmg = (calcDmg(attacker, null) * (0.6 + 0.12 * rank)).toInt();
    final victims = game.getEnemiesInRange(center, radius);

    for (final v in victims) {
      v.takeDamage(blessingDmg);
      final dir = (v.position - center).normalized();
      v.add(
        MoveEffect.by(
          dir * (30.0 + 8.0 * rank),
          EffectController(duration: 0.15),
        ),
      );
      ImpactVisuals.play(game, v.position, 'Lava', scale: 0.5);
    }
  }

  /// Blood Blessing - Heavy heal over time with lifesteal
  static void _bloodBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
    int baseHeal,
  ) {
    final hotAmount = (baseHeal * (0.3 + 0.06 * rank)).toInt();
    final hotDuration = 4.0 + 0.5 * rank;
    final isDivine = rank >= 3;

    // Heal over time on allies
    for (final g in allies) {
      final hot = TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          g.unit.heal(hotAmount);
        },
      );
      hot.add(RemoveEffect(delay: hotDuration));
      g.add(hot);
    }

    // Extra orb heal (same as before)
    game.orb.heal((baseHeal * 0.4).toInt());

    if (!isDivine) return;

    // Rank 3: BLOOD WELL around orb - drains enemies, heals allies
    final wellRadius = radius * 0.6;
    final wellDuration = 5.0;
    final drainPerTick = (attacker.unit.statIntelligence * 0.8).toInt().clamp(
      4,
      80,
    );
    final healFactor = 0.4;

    final bloodWell = CircleComponent(
      radius: wellRadius,
      position: game.orb.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.red.withOpacity(0.25),
    );

    bloodWell.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          int totalDrained = 0;

          final victims = game.getEnemiesInRange(game.orb.position, wellRadius);
          for (final v in victims) {
            v.takeDamage(drainPerTick);
            totalDrained += drainPerTick;
            ImpactVisuals.play(game, v.position, 'Blood', scale: 0.5);
          }

          if (totalDrained <= 0) return;

          final nearbyAllies = game.getGuardiansInRange(
            center: game.orb.position,
            range: wellRadius,
          );
          final perAlly =
              (totalDrained * healFactor / max(1, nearbyAllies.length)).toInt();

          for (final g in nearbyAllies) {
            g.unit.heal(perAlly);
          }

          // Small orb heal too
          game.orb.heal((totalDrained * 0.2).toInt());
        },
      ),
    );

    bloodWell.add(RemoveEffect(delay: wellDuration));
    game.world.add(bloodWell);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  WATER / ICE / STEAM
  // ═══════════════════════════════════════════════════════════════════════════

  /// Water Blessing - Massive heal and cleanse
  static void _waterBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
    int baseHeal,
  ) {
    // Extra heal
    for (final g in allies) {
      g.unit.heal((baseHeal * 0.3).toInt());
      // Cleanse negative effects
      g.unit.statusEffects.clear();
    }

    // Big orb heal
    game.orb.heal((baseHeal * 0.6).toInt());
    ImpactVisuals.playHeal(game, game.orb.position, scale: 1.0);

    // Push nearby enemies
    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      final dir = (v.position - game.orb.position).normalized();
      v.position += dir * (20.0 + 5.0 * rank);
    }
  }

  /// Ice Blessing - Creates protective ice zone around orb
  static void _iceBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final iceRadius = 120.0 + 20.0 * rank;
    final iceDuration = 5.0 + 0.6 * rank;
    final slowStrength = 20.0 + 4.0 * rank;

    final iceZone = CircleComponent(
      radius: iceRadius,
      position: game.orb.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.cyanAccent.withOpacity(0.2),
    );

    iceZone.add(
      TimerComponent(
        period: 0.25,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(game.orb.position, iceRadius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    iceZone.add(RemoveEffect(delay: iceDuration));
    game.world.add(iceZone);
  }

  /// Steam Blessing - Creates healing steam field with damage
  /// Rank 1: Steam field that damages enemies and heals allies
  /// Rank 2: Stronger effects with brief evasion
  /// Rank 3: THERMAL SANCTUARY - Large steam zone with powerful regen
  static void _steamBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
  ) {
    final isDivine = rank >= 3;

    // Steam field parameters
    final steamRadius = isDivine ? radius * 0.7 : radius * 0.5;
    final steamDuration = 5.0 + rank * 0.8; // 5.8s, 6.6s, 7.4s
    final damagePerTick = (attacker.unit.statIntelligence * (0.8 + 0.2 * rank))
        .toInt()
        .clamp(3, 70);
    final healPerTick = (attacker.unit.statIntelligence * (0.6 + 0.15 * rank))
        .toInt()
        .clamp(2, 50);

    // Visual: Steam cloud
    final steamCloud = CircleComponent(
      radius: steamRadius,
      position: game.orb.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.blueGrey.shade200.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );

    // Inner steam wisps
    final steamWisp = CircleComponent(
      radius: steamRadius * 0.5,
      position: Vector2(steamRadius, steamRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );
    steamCloud.add(steamWisp);

    // Wisp floats upward effect (scale/opacity pulse)
    steamWisp.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.3),
          EffectController(duration: 0.8, curve: Curves.easeOut),
        ),
        ScaleEffect.to(
          Vector2.all(0.8),
          EffectController(duration: 0.8, curve: Curves.easeIn),
        ),
      ], infinite: true),
    );

    // Main steam tick - damages enemies, heals allies
    steamCloud.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          // Damage enemies
          final victims = game.getEnemiesInRange(
            game.orb.position,
            steamRadius,
          );
          for (final v in victims) {
            v.takeDamage(damagePerTick);

            // Rank 2+: Confusion effect
            if (rank >= 2) {
              final rng = Random();
              final jitter = Vector2(
                (rng.nextDouble() - 0.5) * 10,
                (rng.nextDouble() - 0.5) * 10,
              );
              v.position += jitter;
            }
          }

          // Heal allies in steam
          final steamAllies = game.getGuardiansInRange(
            center: game.orb.position,
            range: steamRadius,
          );
          for (final g in steamAllies) {
            g.unit.heal(healPerTick);
          }

          // Heal orb
          game.orb.heal((healPerTick * 0.3).toInt());

          // Rank 3: Also cleanse one debuff per tick
          if (isDivine) {
            for (final g in steamAllies) {
              if (g.unit.statusEffects.isNotEmpty) {
                // Remove the first status effect by key
                final firstKey = g.unit.statusEffects.keys.first;
                g.unit.statusEffects.remove(firstKey);
              }
            }
          }
        },
      ),
    );

    // Steam puff visual
    steamCloud.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          ImpactVisuals.play(game, game.orb.position, 'Steam', scale: 0.5);
        },
      ),
    );

    // Expanding/fading effect
    steamCloud.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.1),
          EffectController(duration: steamDuration * 0.7),
        ),
        OpacityEffect.fadeOut(EffectController(duration: steamDuration * 0.3)),
        RemoveEffect(),
      ]),
    );

    game.world.add(steamCloud);

    // Initial burst damage
    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      final burstDmg = (attacker.unit.statIntelligence * (1.2 + 0.25 * rank))
          .toInt()
          .clamp(3, 80);
      v.takeDamage(burstDmg);
      ImpactVisuals.play(game, v.position, 'Steam', scale: 0.5);
    }

    // Initial ally heal
    for (final g in allies) {
      g.unit.heal((healPerTick * 2).toInt());
      ImpactVisuals.playHeal(game, g.position, scale: 0.5);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PLANT / POISON
  // ═══════════════════════════════════════════════════════════════════════════

  /// Plant Blessing - Regeneration and garden around orb
  static void _plantBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
    int baseHeal,
  ) {
    final regenAmount = (baseHeal * (0.15 + 0.03 * rank)).toInt();
    final gardenDuration = 6.0 + 0.8 * rank;
    final gardenRadius = 100.0 + 15.0 * rank;
    final thornDps = (attacker.unit.statIntelligence * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(2, 60);

    // Healing garden around orb
    final garden = CircleComponent(
      radius: gardenRadius,
      position: game.orb.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green.withOpacity(0.2),
    );

    garden.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          // Heal allies in garden
          final gardenAllies = game.getGuardiansInRange(
            center: game.orb.position,
            range: gardenRadius,
          );
          for (final g in gardenAllies) {
            g.unit.heal(regenAmount);
          }

          // Damage enemies in garden
          final victims = game.getEnemiesInRange(
            game.orb.position,
            gardenRadius,
          );
          for (final v in victims) {
            v.takeDamage(thornDps);
          }

          // Heal orb
          game.orb.heal((regenAmount * 0.3).toInt());
        },
      ),
    );

    garden.add(RemoveEffect(delay: gardenDuration));
    game.world.add(garden);
  }

  /// Poison Blessing - Toxic aura that damages nearby enemies
  static void _poisonBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final poisonDmg = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 80);

    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick: poisonDmg,
          ticksRemaining: 8 + rank,
          tickInterval: 0.4,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Poison', scale: 0.6);
    }

    // Rank 3: lingering toxic garden around the orb
    if (rank < 3) return;

    final gardenRadius = radius * 0.7;
    final gardenDuration = 7.0;
    final cloud = CircleComponent(
      radius: gardenRadius,
      position: game.orb.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green.withOpacity(0.28),
    );

    cloud.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final cloudVictims = game.getEnemiesInRange(
            game.orb.position,
            gardenRadius,
          );
          for (final v in cloudVictims) {
            v.unit.applyStatusEffect(
              SurvivalStatusEffect(
                type: 'Poison',
                damagePerTick: (poisonDmg * 0.6).toInt(),
                ticksRemaining: 3,
                tickInterval: 0.4,
              ),
            );
          }
        },
      ),
    );

    cloud.add(RemoveEffect(delay: gardenDuration));
    game.world.add(cloud);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EARTH / MUD / CRYSTAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Earth Blessing - Grants shields to all allies
  static void _earthBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
  ) {
    final shieldAmount = (attacker.unit.maxHp * (0.15 + 0.04 * rank))
        .toInt()
        .clamp(30, 400);

    for (final g in allies) {
      g.unit.shieldHp = (g.unit.shieldHp ?? 0) + shieldAmount;
    }

    // Also shield orb (damage reduction visual)
    ImpactVisuals.play(game, game.orb.position, 'Earth', scale: 1.2);
  }

  /// Mud Blessing - Creates slowing field around orb
  static void _mudBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final mudRadius = 140.0 + 20.0 * rank;
    final mudDuration = 6.0 + 0.6 * rank;
    final slowStrength = 25.0 + 5.0 * rank;

    final mudField = CircleComponent(
      radius: mudRadius,
      position: game.orb.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.brown.shade600.withOpacity(0.3),
    );

    mudField.add(
      TimerComponent(
        period: 0.2,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(game.orb.position, mudRadius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    mudField.add(RemoveEffect(delay: mudDuration));
    game.world.add(mudField);
  }

  /// Crystal Blessing - Grants allies crystal shards that auto-attack
  static void _crystalBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
  ) {
    final shardDmg = (attacker.unit.statIntelligence * (1.5 + 0.3 * rank))
        .toInt()
        .clamp(5, 100);
    final shardDuration = 5.0 + 0.5 * rank;

    for (final g in allies) {
      // Auto-targeting shard timer
      final shardTimer = TimerComponent(
        period: 0.8,
        repeat: true,
        onTick: () {
          final target = game.pickTargetForGuardian(g);
          if (target != null && target.position.distanceTo(g.position) < 300) {
            game.spawnAlchemyProjectile(
              start: g.position,
              target: target,
              damage: shardDmg,
              color: Colors.tealAccent,
              shape: ProjectileShape.shard,
              speed: 3.0,
              isEnemy: false,
              onHit: () {
                target.takeDamage(shardDmg);
                ImpactVisuals.play(
                  game,
                  target.position,
                  'Crystal',
                  scale: 0.4,
                );
              },
            );
          }
        },
      );

      shardTimer.add(RemoveEffect(delay: shardDuration));
      g.add(shardTimer);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  AIR / DUST / LIGHTNING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Air Blessing - Creates protective wind barrier around orb
  /// Rank 1: Wind barrier that pushes enemies away from orb
  /// Rank 2: Stronger push with damage
  /// Rank 3: HURRICANE WARD - Massive barrier that shreds and repels enemies
  static void _airBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final isDivine = rank >= 3;

    // Wind barrier parameters
    final barrierRadius = isDivine ? 180.0 + 25.0 * rank : 140.0 + 20.0 * rank;
    final barrierDuration = 5.0 + rank * 1.0; // 6s, 7s, 8s
    final pushStrength = 35.0 + rank * 12.0;
    final damagePerTick = rank >= 2
        ? (attacker.unit.statIntelligence * (0.5 + 0.15 * rank)).toInt().clamp(
            3,
            60,
          )
        : 0;

    // Visual: Swirling wind barrier around orb
    final barrier = CircleComponent(
      radius: barrierRadius,
      position: game.orb.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.cyan.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    // Inner wind ring
    final windRing = CircleComponent(
      radius: barrierRadius * 0.7,
      position: Vector2(barrierRadius, barrierRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    barrier.add(windRing);

    // Outer wind ring
    final outerRing = CircleComponent(
      radius: barrierRadius * 0.9,
      position: Vector2(barrierRadius, barrierRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.cyan.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    barrier.add(outerRing);

    // Rotate rings for wind effect
    windRing.add(
      RotateEffect.by(6.28, EffectController(duration: 1.5, infinite: true)),
    );
    outerRing.add(
      RotateEffect.by(-6.28, EffectController(duration: 2.0, infinite: true)),
    );

    // Main wind push tick
    barrier.add(
      TimerComponent(
        period: 0.2,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(
            game.orb.position,
            barrierRadius,
          );

          for (final v in victims) {
            // Push away from orb
            final fromOrb = v.position - game.orb.position;
            final distance = fromOrb.length;

            if (distance > 10) {
              final pushDir = fromOrb.normalized();
              // Stronger push closer to orb (to keep them out)
              final pushMult =
                  1.0 - (distance / barrierRadius).clamp(0.0, 1.0) * 0.5;
              v.position += pushDir * pushStrength * pushMult * 0.2;
            }

            // Damage (rank 2+)
            if (damagePerTick > 0) {
              v.takeDamage(damagePerTick);
            }

            // Rank 3: Also apply brief stagger
            if (isDivine && Random().nextDouble() < 0.1) {
              v.add(
                MoveEffect.by(Vector2.zero(), EffectController(duration: 0.15)),
              );
            }
          }
        },
      ),
    );

    // Periodic whoosh visual
    barrier.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          ImpactVisuals.play(game, game.orb.position, 'Air', scale: 0.6);
        },
      ),
    );

    // Fade and remove
    barrier.add(
      SequenceEffect([
        OpacityEffect.to(
          1.0,
          EffectController(duration: barrierDuration * 0.8),
        ),
        OpacityEffect.fadeOut(
          EffectController(duration: barrierDuration * 0.2),
        ),
        RemoveEffect(),
      ]),
    );

    game.world.add(barrier);

    // Initial burst knockback
    final victims = game.getEnemiesInRange(game.orb.position, radius);
    for (final v in victims) {
      final dir = (v.position - game.orb.position).normalized();
      v.add(
        MoveEffect.by(
          dir * (60.0 + 15.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }

    SurvivalAttackManager.triggerScreenShake(game, 3.0 + rank);
  }

  /// Dust Blessing - Creates persistent blinding dust cloud
  /// Rank 1: Dust cloud that confuses enemies
  /// Rank 2: Larger cloud with damage
  /// Rank 3: SANDSTORM WARD - Massive disorienting storm around orb
  static void _dustBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final rng = Random();
    final isDivine = rank >= 3;

    // Dust cloud parameters
    final cloudRadius = isDivine ? radius * 0.8 : radius * 0.6;
    final cloudDuration = 5.0 + rank * 0.8; // 5.8s, 6.6s, 7.4s
    final jitterStrength = 20.0 + rank * 8.0;
    final damagePerTick = rank >= 2
        ? (attacker.unit.statIntelligence * (0.4 + 0.1 * rank)).toInt().clamp(
            2,
            50,
          )
        : 0;

    // Visual: Dust cloud around orb
    final dustCloud = CircleComponent(
      radius: cloudRadius,
      position: game.orb.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.amber.shade300.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );

    // Swirling dust ring
    final dustRing = CircleComponent(
      radius: cloudRadius * 0.7,
      position: Vector2(cloudRadius, cloudRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.amber.shade600.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    dustCloud.add(dustRing);

    dustRing.add(
      RotateEffect.by(6.28, EffectController(duration: 2.5, infinite: true)),
    );

    // Pulsing effect
    dustCloud.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.1),
          EffectController(duration: 1.0, curve: Curves.easeInOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 1.0, curve: Curves.easeInOut),
        ),
      ], infinite: true),
    );

    // Main confusion tick
    dustCloud.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(
            game.orb.position,
            cloudRadius,
          );

          for (final v in victims) {
            // Confusion jitter
            final jitter = Vector2(
              (rng.nextDouble() - 0.5) * jitterStrength,
              (rng.nextDouble() - 0.5) * jitterStrength,
            );
            v.position += jitter;

            // Damage (rank 2+)
            if (damagePerTick > 0) {
              v.takeDamage(damagePerTick);
            }

            // Rank 3: Occasional heavy disorientation
            if (isDivine && rng.nextDouble() < 0.12) {
              final bigJitter = Vector2(
                (rng.nextDouble() - 0.5) * jitterStrength * 2.5,
                (rng.nextDouble() - 0.5) * jitterStrength * 2.5,
              );
              v.position += bigJitter;
            }
          }
        },
      ),
    );

    // Periodic dust puff
    dustCloud.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          ImpactVisuals.play(game, game.orb.position, 'Dust', scale: 0.5);
        },
      ),
    );

    // Fade and remove
    dustCloud.add(
      SequenceEffect([
        OpacityEffect.to(1.0, EffectController(duration: cloudDuration * 0.75)),
        OpacityEffect.fadeOut(EffectController(duration: cloudDuration * 0.25)),
        RemoveEffect(),
      ]),
    );

    game.world.add(dustCloud);

    // Initial burst confusion
    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      final jitter = Vector2(
        (rng.nextDouble() - 0.5) * (40 + 10 * rank),
        (rng.nextDouble() - 0.5) * (40 + 10 * rank),
      );
      v.position += jitter;
      ImpactVisuals.play(game, v.position, 'Dust', scale: 0.5);
    }
  }

  /// Lightning Blessing - Empowers allies with chain lightning attacks
  static void _lightningBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
  ) {
    final boltDmg = (attacker.unit.statIntelligence * (2.0 + 0.4 * rank))
        .toInt()
        .clamp(5, 150);

    // Strike random enemies
    final victims = game.getEnemiesInRange(center, radius);
    final rng = Random();
    final strikeCount = min(3 + rank, victims.length);

    for (int i = 0; i < strikeCount; i++) {
      if (victims.isEmpty) break;
      final target = victims[rng.nextInt(victims.length)];

      Future.delayed(Duration(milliseconds: i * 100), () {
        if (target.isDead) return;

        target.takeDamage(boltDmg);
        ImpactVisuals.play(game, target.position, 'Lightning', scale: 0.9);

        // Chain
        final nearby = game
            .getEnemiesInRange(target.position, 150)
            .where((e) => e != target)
            .take(2);
        for (final n in nearby) {
          n.takeDamage((boltDmg * 0.4).toInt());
          ImpactVisuals.play(game, n.position, 'Lightning', scale: 0.5);
        }
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SPIRIT / DARK / LIGHT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Spirit Blessing - Drains enemies and heals team over time
  static void _spiritBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
  ) {
    final drainDmg = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(3, 80);

    final victims = game.getEnemiesInRange(center, radius);
    int totalDrained = 0;

    for (final v in victims) {
      v.takeDamage(drainDmg);
      totalDrained += drainDmg;
      ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.5);
    }

    // Distribute healing
    final healPerAlly = (totalDrained * 0.3 / max(1, allies.length)).toInt();
    for (final g in allies) {
      g.unit.heal(healPerAlly);
    }

    // Heal orb
    game.orb.heal((totalDrained * 0.2).toInt());
  }

  /// Dark Blessing - Creates death zone that executes and empowers
  /// Rank 1: Death zone that executes low HP enemies
  /// Rank 2: Higher execute threshold, allies gain lifesteal
  /// Rank 3: REAPER'S DOMAIN - Large death zone with team-wide vampirism
  static void _darkBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final isDivine = rank >= 3;

    // Death zone parameters
    final zoneRadius = isDivine ? radius * 0.7 : radius * 0.5;
    final zoneDuration = 5.0 + rank * 1.0; // 6s, 7s, 8s
    final executeThreshold = 0.15 + 0.04 * rank; // 19%, 23%, 27%
    final damagePerTick = (attacker.unit.statIntelligence * (0.6 + 0.15 * rank))
        .toInt()
        .clamp(3, 80);
    final lifestealPercent = rank >= 2 ? 0.2 + 0.1 * rank : 0; // 0%, 30%, 40%

    // Visual: Dark death zone around orb
    final deathZone = CircleComponent(
      radius: zoneRadius,
      position: game.orb.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.deepPurple.shade900.withOpacity(0.4)
        ..style = PaintingStyle.fill,
    );

    // Inner void core
    final voidCore = CircleComponent(
      radius: zoneRadius * 0.3,
      position: Vector2(zoneRadius, zoneRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.black.withOpacity(0.6)
        ..style = PaintingStyle.fill,
    );
    deathZone.add(voidCore);

    // Pulsing core
    voidCore.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.4),
          EffectController(duration: 0.6, curve: Curves.easeInOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.6, curve: Curves.easeInOut),
        ),
      ], infinite: true),
    );

    // Outer death ring
    final deathRing = CircleComponent(
      radius: zoneRadius * 0.85,
      position: Vector2(zoneRadius, zoneRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.purple.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    deathZone.add(deathRing);

    deathRing.add(
      RotateEffect.by(-6.28, EffectController(duration: 3.0, infinite: true)),
    );

    // Track total damage dealt for lifesteal
    int damageDealtThisTick = 0;

    // Main death zone tick
    deathZone.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          damageDealtThisTick = 0;
          final victims = game.getEnemiesInRange(game.orb.position, zoneRadius);

          for (final v in victims) {
            // Execute check
            if (!v.isBoss && v.unit.hpPercent < executeThreshold) {
              v.takeDamage(99999);
              ImpactVisuals.play(game, v.position, 'Dark', scale: 1.3);

              // Heal attacker per execute
              attacker.unit.heal(40 + 15 * rank);

              // Rank 3: Executed enemies explode
              if (isDivine) {
                final nearby = game
                    .getEnemiesInRange(v.position, 70)
                    .where((e) => e != v);
                for (final n in nearby) {
                  n.takeDamage((damagePerTick * 2).toInt());
                }
              }
            } else {
              // Regular damage
              v.takeDamage(damagePerTick);
              damageDealtThisTick += damagePerTick;
            }
          }

          // Lifesteal for allies (rank 2+)
          if (lifestealPercent > 0 && damageDealtThisTick > 0) {
            final healAmount = (damageDealtThisTick * lifestealPercent).toInt();
            final allies = game.getGuardiansInRange(
              center: game.orb.position,
              range: zoneRadius * 1.5,
            );
            for (final g in allies) {
              g.unit.heal((healAmount / max(1, allies.length)).toInt());
            }
          }
        },
      ),
    );

    // Periodic dark pulse visual
    deathZone.add(
      TimerComponent(
        period: 0.7,
        repeat: true,
        onTick: () {
          ImpactVisuals.play(game, game.orb.position, 'Dark', scale: 0.5);
        },
      ),
    );

    // Fade and remove
    deathZone.add(
      SequenceEffect([
        OpacityEffect.to(1.0, EffectController(duration: zoneDuration * 0.8)),
        OpacityEffect.fadeOut(EffectController(duration: zoneDuration * 0.2)),
        RemoveEffect(),
      ]),
    );

    game.world.add(deathZone);

    // Initial execute sweep
    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      if (!v.isBoss && v.unit.hpPercent < executeThreshold) {
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.2);
        attacker.unit.heal(50);
      }
    }
  }

  /// Light Blessing - Divine heal that heals all guardians and orb
  static void _lightBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardGuardian> allies,
    int baseHeal,
  ) {
    final divineHeal = (baseHeal * (0.5 + 0.1 * rank)).toInt();

    // Heal ALL guardians (not just in range)
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(divineHeal);
        ImpactVisuals.playHeal(game, g.position, scale: 0.8);
      }
    }

    // Big orb heal
    game.orb.heal((divineHeal * 0.8).toInt());
    ImpactVisuals.playHeal(game, game.orb.position, scale: 1.2);

    // Rank 3: Cleanse all debuffs (moved down from old rank 5)
    if (rank >= 3) {
      for (final g in game.guardians) {
        g.unit.statusEffects.clear();
      }
    }

    // Damage nearby enemies
    final victims = game.getEnemiesInRange(center, 200);
    for (final v in victims) {
      v.takeDamage((divineHeal * 0.5).toInt());
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.6);
    }
  }
}
