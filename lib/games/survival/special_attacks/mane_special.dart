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

/// MANE FAMILY - BARRAGE MECHANIC
/// Unleashes rapid-fire elemental volleys in a cone
/// Rank 1+: Elemental effects based on type
/// Rank 5 (MAX): Massive barrage with devastating effects
class ManeBarrageMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final color = SurvivalAttackManager.getElementColor(element);

    // Slightly higher base damage; Mane is your "spell gunner".
    final baseProjectiles = 8 + rank * 3;
    final dmgMult = 0.75 + 0.15 * rank; // rank 1: 0.9, rank 5: 1.5
    final baseDmg = (calcDmg(attacker, null) * dmgMult).toInt();

    // How wide the cone feels
    final spreadAngleDeg = 40.0 + rank * 6; // ~64° at rank 4, 70° at 5
    final spreadRad = spreadAngleDeg * pi / 180.0;

    // Rank 5: Massive barrage
    final isMassive = rank >= 5;
    final projectiles = isMassive ? baseProjectiles * 2 : baseProjectiles;
    final damage = isMassive ? (baseDmg * 1.2).toInt() : baseDmg;

    // Pick a primary target (where the cone is centered)
    HoardEnemy? primaryTarget =
        target ??
        game.getNearestEnemy(attacker.position, attacker.unit.attackRange) ??
        game.getNearestEnemy(attacker.position, 700);

    if (primaryTarget == null) {
      // No enemies - nothing to shoot.
      return;
    }

    final baseDir = (primaryTarget.position - attacker.position).normalized();

    // Pre-fetch enemies for cone targeting
    final candidates = game
        .getEnemiesInRange(attacker.position, attacker.unit.attackRange)
        .where((e) => !e.isDead)
        .toList();

    HoardEnemy? _pickEnemyInCone(double angleOffset) {
      if (candidates.isEmpty) return primaryTarget;

      final rotCos = cos(angleOffset);
      final rotSin = sin(angleOffset);
      final coneDir = Vector2(
        baseDir.x * rotCos - baseDir.y * rotSin,
        baseDir.x * rotSin + baseDir.y * rotCos,
      );

      final double cosHalf = cos(spreadRad * 0.5);

      HoardEnemy? best;
      double bestDot = cosHalf; // need to be at least inside the cone

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
      // Sequence them quickly; massive barrage is denser
      final delayMs = i * (isMassive ? 25 : 40);

      Future.delayed(Duration(milliseconds: delayMs), () {
        if (attacker.isDead) return;

        // Evenly spread projectiles across the cone
        final t = projectiles == 1 ? 0.5 : i / (projectiles - 1); // 0..1
        final angleOffset = (t - 0.5) * spreadRad; // -spread/2 .. +spread/2

        final targetEnemy = _pickEnemyInCone(angleOffset);
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

            // Core hit damage
            targetEnemy.takeDamage(damage);
            ImpactVisuals.play(
              game,
              targetEnemy.position,
              element,
              scale: isMassive ? 0.7 : 0.5,
            );

            // Elemental rider
            _applyElementalBarrage(
              game: game,
              attacker: attacker,
              element: element,
              rank: rank,
              victim: targetEnemy,
              damage: damage,
              projectileIndex: i,
            );
          },
        );
      });
    }

    // Screen shake scales with barrage size
    SurvivalAttackManager.triggerScreenShake(game, isMassive ? 5.0 : 3.0);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ELEMENT ROUTER
  // ═══════════════════════════════════════════════════════════════════════

  static void _applyElementalBarrage({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
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

  // ═══════════════════════════════════════════════════════════════════════
  //  FIRE / LAVA / BLOOD
  // ═══════════════════════════════════════════════════════════════════════

  /// Fire Barrage - Burns stack on each hit
  static void _fireBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final burnDmg = (attacker.unit.statIntelligence * (1.2 + 0.25 * rank))
        .toInt()
        .clamp(3, 100);

    victim.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Burn',
        damagePerTick: burnDmg,
        ticksRemaining: 3 + rank,
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
    final dir = (victim.position - attacker.position).normalized();
    victim.add(
      MoveEffect.by(dir * (18.0 + 3.5 * rank), EffectController(duration: 0.1)),
    );
  }

  /// Blood Barrage - Lifesteal on each hit
  static void _bloodBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
    int damage,
  ) {
    final heal = (damage * (0.18 + 0.03 * rank)).toInt();
    attacker.unit.heal(heal);
    ImpactVisuals.playHeal(game, attacker.position, scale: 0.4);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  WATER / ICE / STEAM
  // ═══════════════════════════════════════════════════════════════════════

  /// Water Barrage - Push enemies away from orb
  static void _waterBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final dir = (victim.position - game.orb.position).normalized();
    victim.add(
      MoveEffect.by(
        dir * (10.0 + 3.0 * rank),
        EffectController(duration: 0.12),
      ),
    );
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
        -(6.0 + rank * 1.8);
    victim.position += pushBack;
  }

  /// Steam Barrage - Confusion on hit
  static void _steamBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final rng = Random();
    final jitter = Vector2(
      (rng.nextDouble() - 0.5) * (10 + rank * 3),
      (rng.nextDouble() - 0.5) * (10 + rank * 3),
    );
    victim.position += jitter;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PLANT / POISON
  // ═══════════════════════════════════════════════════════════════════════

  /// Plant Barrage - Bleed DoT
  static void _plantBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final bleedDmg = (attacker.unit.statIntelligence * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(2, 70);

    victim.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Thorns',
        damagePerTick: bleedDmg,
        ticksRemaining: 4 + rank,
        tickInterval: 0.4,
      ),
    );
  }

  /// Poison Barrage - Poison application
  static void _poisonBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final poisonDmg = (attacker.unit.statIntelligence * (0.9 + 0.18 * rank))
        .toInt()
        .clamp(3, 80);

    victim.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Poison',
        damagePerTick: poisonDmg,
        ticksRemaining: 6 + rank,
        tickInterval: 0.5,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  EARTH / MUD / CRYSTAL
  // ═══════════════════════════════════════════════════════════════════════

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
        dir * (22.0 + 4.0 * rank),
        EffectController(duration: 0.12),
      ),
    );
  }

  /// Mud Barrage - Heavy slow (pseudo-root)
  static void _mudBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final pushBack =
        (victim.targetOrb.position - victim.position).normalized() *
        -(9.0 + rank * 2.2);
    victim.position += pushBack;
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
    // FIX: use projectileIndex instead of weird time-based modulo.
    if ((projectileIndex + 1) % 3 != 0) return;

    final shardDmg = (damage * (0.5 + 0.05 * rank)).toInt();
    final nearby = game
        .getEnemiesInRange(victim.position, 170)
        .where((e) => e != victim && !e.isDead)
        .take(2);

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

  // ═══════════════════════════════════════════════════════════════════════
  //  AIR / DUST / LIGHTNING
  // ═══════════════════════════════════════════════════════════════════════

  /// Air Barrage - Strong knockback
  static void _airBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final dir = (victim.position - game.orb.position).normalized();
    victim.add(
      MoveEffect.by(
        dir * (26.0 + 5.0 * rank),
        EffectController(duration: 0.15, curve: Curves.easeOut),
      ),
    );
  }

  /// Dust Barrage - Confusion
  static void _dustBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final rng = Random();
    final offset = Vector2(
      (rng.nextDouble() - 0.5) * (14 + rank * 3),
      (rng.nextDouble() - 0.5) * (14 + rank * 3),
    );
    victim.position += offset;
  }

  /// Lightning Barrage - Chain to 1 nearby
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
        .take(1);

    for (final n in nearby) {
      final chainDmg = (damage * (0.55 + 0.08 * rank)).toInt();
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

  // ═══════════════════════════════════════════════════════════════════════
  //  SPIRIT / DARK / LIGHT
  // ═══════════════════════════════════════════════════════════════════════

  /// Spirit Barrage - Small drain
  static void _spiritBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    final drain = (attacker.unit.statIntelligence * (0.6 + 0.12 * rank))
        .toInt()
        .clamp(2, 50);
    victim.takeDamage(drain);
    attacker.unit.heal((drain * 0.35).toInt());
  }

  /// Dark Barrage - Damage amp on low HP
  static void _darkBarrage(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy victim,
  ) {
    if (victim.unit.hpPercent < 0.5) {
      final bonusDmg = (calcDmg(attacker, victim) * (0.35 + 0.07 * rank))
          .toInt()
          .clamp(3, 80);
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
    final heal = (attacker.unit.statIntelligence * (1.0 + 0.18 * rank))
        .toInt()
        .clamp(4, 80);
    attacker.unit.heal(heal);
    ImpactVisuals.playHeal(game, attacker.position, scale: 0.45);
  }
}
