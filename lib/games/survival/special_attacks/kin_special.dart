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

/// KIN FAMILY - BLESSING MECHANIC
/// Support ability that buffs allies and heals the team
/// Rank 1+: Elemental effects based on type
/// Rank 5 (MAX): Divine blessing with powerful team-wide effects
class KinBlessingMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final color = SurvivalAttackManager.getElementColor(element);

    // Base blessing parameters
    final baseRadius = 200.0 + rank * 25;
    final baseHeal = (attacker.unit.statIntelligence * (3.0 + 0.5 * rank))
        .toInt()
        .clamp(10, 200);

    // Rank 5: Divine blessing
    final isDivine = rank >= 5;
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

    for (final g in allies) {
      // Heal over time
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

    // Extra orb heal
    game.orb.heal((baseHeal * 0.4).toInt());
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

  /// Steam Blessing - Speed boost and evasion for allies
  static void _steamBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardGuardian> allies,
  ) {
    // Damage nearby enemies with steam burst
    final steamDmg = (attacker.unit.statIntelligence * (1.2 + 0.25 * rank))
        .toInt()
        .clamp(3, 80);
    final victims = game.getEnemiesInRange(center, radius);

    for (final v in victims) {
      v.takeDamage(steamDmg);
      ImpactVisuals.play(game, v.position, 'Steam', scale: 0.5);
    }

    // Steam cloud visual
    final cloud = CircleComponent(
      radius: radius * 0.6,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.blueGrey.shade300.withOpacity(0.25),
    );
    cloud.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.3), EffectController(duration: 0.5)),
        OpacityEffect.fadeOut(EffectController(duration: 0.5)),
        RemoveEffect(),
      ]),
    );
    game.world.add(cloud);
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
          final target = game.getNearestEnemy(g.position, g.unit.attackRange);
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

  /// Air Blessing - Knockback wave that pushes all enemies away from orb
  static void _airBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final victims = game.getEnemiesInRange(game.orb.position, radius);

    for (final v in victims) {
      final dir = (v.position - game.orb.position).normalized();
      v.add(
        MoveEffect.by(
          dir * (80.0 + 20.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }

    SurvivalAttackManager.triggerScreenShake(game, 4.0 + rank);
  }

  /// Dust Blessing - Blinds all enemies in range
  static void _dustBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final rng = Random();
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

  /// Dark Blessing - Execute weak enemies and empower allies
  static void _darkBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final executeThreshold = 0.15 + 0.04 * rank;

    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      if (!v.isBoss && v.unit.hpPercent < executeThreshold) {
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.2);

        // Heal attacker per execute
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

    // Rank 5: Cleanse all debuffs
    if (rank >= 5) {
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
