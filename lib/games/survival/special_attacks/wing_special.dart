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

/// WING FAMILY - PIERCE MECHANIC (3-RANK VERSION)
/// Fires a fast, piercing beam that hits all enemies in a line
/// Rank 0: Base beam (no elemental rider)
/// Rank 1: Unlocks elemental rider for this element
/// Rank 2: Stronger numbers / secondary effects
/// Rank 3 (MAX): Devastating wide beam + ultimate elemental effect
class WingPierceMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    // Clamp to new 3-rank system
    final int rawRank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final int rank = rawRank.clamp(0, 3) as int;

    // Base beam parameters scale with rank (0–3)
    final baseWidth = 50.0 + rank * 6;
    final baseRange = 1000.0 + rank * 200;
    final baseDmg = (calcDmg(attacker, target) * (1.6 + 0.25 * rank)).toInt();

    // Rank 3: Devastating beam
    final isDevastating = rank >= 3;
    final width = isDevastating ? baseWidth * 3.0 : baseWidth;
    final range = isDevastating ? baseRange * 2.0 : baseRange;
    final damage = isDevastating ? (baseDmg * 3.4).toInt() : baseDmg;

    // Calculate beam path
    final direction = (target.position - attacker.position).normalized();
    final endPos = attacker.position + direction * range;

    // Visual beam effect
    ImpactVisuals.playBeamTrail(
      game,
      attacker.position,
      endPos,
      element,
      width,
    );

    // Get all enemies in path FIRST
    final pathVictims = _getEnemiesInPath(
      game,
      attacker.position,
      endPos,
      width * 0.7,
    );

    // Deal base damage to all enemies in path
    for (final victim in pathVictims) {
      victim.takeDamage(damage);
      ImpactVisuals.play(game, victim.position, element, scale: 0.7);
    }

    // Elemental rider only really matters once we’ve unlocked the element
    if (rank >= 1) {
      _applyElementalPierce(
        game: game,
        attacker: attacker,
        element: element,
        rank: rank,
        victims: pathVictims,
        damage: damage,
        startPos: attacker.position,
        endPos: endPos,
      );
    }

    // Debug
    // ignore: avoid_print
    print(
      'Wing Pierce: element=$element rank=$rank victims=${pathVictims.length} damage=$damage',
    );
  }

  static List<HoardEnemy> _getEnemiesInPath(
    SurvivalHoardGame game,
    Vector2 start,
    Vector2 end,
    double width,
  ) {
    final result = <HoardEnemy>[];
    final direction = (end - start).normalized();
    final perpendicular = Vector2(-direction.y, direction.x);
    final length = start.distanceTo(end);

    for (final enemy in game.enemies) {
      if (enemy.isDead) continue;

      // Project enemy position onto beam line
      final toEnemy = enemy.position - start;
      final alongBeam = toEnemy.dot(direction);
      final perpDist = (toEnemy.dot(perpendicular)).abs();

      if (alongBeam >= 0 && alongBeam <= length && perpDist <= width) {
        result.add(enemy);
      }
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ELEMENT ROUTER
  // ═══════════════════════════════════════════════════════════════════════════

  static void _applyElementalPierce({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required List<HoardEnemy> victims,
    required int damage,
    required Vector2 startPos,
    required Vector2 endPos,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _firePierce(game, attacker, rank, victims);
        break;
      case 'Lava':
        _lavaPierce(game, attacker, rank, victims, startPos, endPos);
        break;
      case 'Blood':
        _bloodPierce(game, attacker, rank, victims, damage);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterPierce(game, attacker, rank, victims, startPos);
        break;
      case 'Ice':
        _icePierce(game, attacker, rank, victims);
        break;
      case 'Steam':
        _steamPierce(game, attacker, rank, victims);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantPierce(game, attacker, rank, victims);
        break;
      case 'Poison':
        _poisonPierce(game, attacker, rank, victims);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthPierce(game, attacker, rank, victims, damage);
        break;
      case 'Mud':
        _mudPierce(game, attacker, rank, victims);
        break;
      case 'Crystal':
        _crystalPierce(game, attacker, rank, victims, damage);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airPierce(game, attacker, rank, victims, startPos);
        break;
      case 'Dust':
        _dustPierce(game, attacker, rank, victims);
        break;
      case 'Lightning':
        _lightningPierce(game, attacker, rank, victims, damage);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritPierce(game, attacker, rank, victims, damage);
        break;
      case 'Dark':
        _darkPierce(game, attacker, rank, victims, damage);
        break;
      case 'Light':
        _lightPierce(game, attacker, rank, victims);
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FIRE / LAVA / BLOOD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fire Pierce - Ignites all pierced enemies
  static void _firePierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final burnDmg = (attacker.unit.statIntelligence * (2.0 + 0.35 * rank))
        .toInt()
        .clamp(3, 120);

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Burn',
          damagePerTick: burnDmg,
          ticksRemaining: 4 + rank,
          tickInterval: 0.5,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Fire', scale: 0.6);
    }

    // Rank 3: Enemies that die from the beam cause small explosions
    if (rank >= 3) {
      for (final v in victims) {
        if (v.isDead) {
          final nearby = game.getEnemiesInRange(v.position, 80);
          for (final n in nearby) {
            n.takeDamage((burnDmg * 2).toInt());
          }
          ImpactVisuals.playExplosion(game, v.position, 'Fire', 80);
        }
      }
    }
  }

  /// Lava Pierce - Leaves fire trail along beam path
  static void _lavaPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    Vector2 startPos,
    Vector2 endPos,
  ) {
    final trailDps = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 80);
    final trailDuration = 2.0 + 0.3 * rank;

    // Create fire trail along beam path
    final direction = (endPos - startPos).normalized();
    final length = startPos.distanceTo(endPos);
    final segmentCount = (length / 80).floor();

    for (int i = 0; i < segmentCount; i++) {
      final segmentPos = startPos + direction * (i * 80 + 40);

      final fireSegment = CircleComponent(
        radius: 30,
        position: segmentPos,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.orange.shade800.withOpacity(0.25),
      );

      fireSegment.add(
        TimerComponent(
          period: 0.4,
          repeat: true,
          onTick: () {
            final segVictims = game.getEnemiesInRange(segmentPos, 35);
            for (final v in segVictims) {
              v.takeDamage(trailDps);
            }
          },
        ),
      );

      fireSegment.add(RemoveEffect(delay: trailDuration));
      game.world.add(fireSegment);
    }
  }

  /// Blood Pierce - Heavy lifesteal from all pierced enemies
  static void _bloodPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    int totalDrained = 0;

    for (final v in victims) {
      final drain = (damage * (0.2 + 0.05 * rank)).toInt();
      v.takeDamage(drain);
      totalDrained += drain;
    }

    // Heal self
    attacker.unit.heal((totalDrained * 0.5).toInt());
    ImpactVisuals.playHeal(game, attacker.position, scale: 0.8);

    // Heal orb
    game.orb.heal((totalDrained * 0.25).toInt());

    // Rank 3: Also heal nearby allies
    if (rank >= 3) {
      final allies = game.getGuardiansInRange(
        center: attacker.position,
        range: 200,
      );
      for (final g in allies) {
        if (g != attacker) {
          g.unit.heal((totalDrained * 0.1).toInt());
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  WATER / ICE / STEAM
  // ═══════════════════════════════════════════════════════════════════════════

  /// Water Pierce - Pushes enemies along beam direction
  static void _waterPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    Vector2 startPos,
  ) {
    for (final v in victims) {
      final pushDir = (v.position - startPos).normalized();
      v.add(
        MoveEffect.by(
          pushDir * (40.0 + 10.0 * rank),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
    }

    // Heal attacker
    final healAmount = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(3, 60);
    attacker.unit.heal(healAmount * victims.length.clamp(1, 5));
  }

  /// Ice Pierce - Freezing ray that slows/freezes
  static void _icePierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final slowStrength = 15.0 + 3.0 * rank;

    for (final v in victims) {
      // Push back (slow effect)
      final pushBack =
          (v.targetOrb.position - v.position).normalized() * -slowStrength;
      v.position += pushBack;
      ImpactVisuals.play(game, v.position, 'Ice', scale: 0.5);
    }

    // Rank 3: Briefly freeze the first enemy hit
    if (rank >= 3 && victims.isNotEmpty) {
      victims.first.add(
        MoveEffect.by(Vector2.zero(), EffectController(duration: 1.0)),
      );
    }
  }

  /// Steam Pierce - Scalding beam with splash damage
  static void _steamPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final splashDmg = (attacker.unit.statIntelligence * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(2, 60);

    for (final v in victims) {
      // Splash to nearby
      final nearby = game
          .getEnemiesInRange(v.position, 60)
          .where((e) => !victims.contains(e));
      for (final n in nearby) {
        n.takeDamage(splashDmg);
        ImpactVisuals.play(game, n.position, 'Steam', scale: 0.4);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PLANT / POISON
  // ═══════════════════════════════════════════════════════════════════════════

  /// Plant Pierce - Thorn lance with DoT
  static void _plantPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final thornDmg = (attacker.unit.statIntelligence * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(2, 60);

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Bleed',
          damagePerTick: thornDmg,
          ticksRemaining: 5 + rank,
          tickInterval: 0.4,
        ),
      );
    }
  }

  /// Poison Pierce - Toxic beam that spreads poison
  static void _poisonPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final poisonDmg = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 80);

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick: poisonDmg,
          ticksRemaining: 8 + rank,
          tickInterval: 0.4,
        ),
      );

      // Spread to nearby (Rank 2+)
      if (rank >= 2) {
        final nearby = game
            .getEnemiesInRange(v.position, 80)
            .where((e) => !victims.contains(e))
            .take(2);
        for (final n in nearby) {
          n.unit.applyStatusEffect(
            SurvivalStatusEffect(
              type: 'Poison',
              damagePerTick: (poisonDmg * 0.5).toInt(),
              ticksRemaining: 4,
              tickInterval: 0.5,
            ),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EARTH / MUD / CRYSTAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Earth Pierce - Heavy impact with armor shred
  static void _earthPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    final bonusDmg = (damage * (0.2 + 0.05 * rank)).toInt();

    for (final v in victims) {
      v.takeDamage(bonusDmg);
      v.unit.applyStatModifier(
        SurvivalStatModifier(
          type: 'defense_down',
          remainingSeconds: 3.0 + 0.5 * rank,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Earth', scale: 0.6);
    }

    // Shield self
    final shieldAmount = (attacker.unit.maxHp * (0.05 + 0.02 * rank)).toInt();
    attacker.unit.shieldHp = (attacker.unit.shieldHp ?? 0) + shieldAmount;
  }

  /// Mud Pierce - Sticky beam that heavily slows
  static void _mudPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final slowStrength = 25.0 + 5.0 * rank;

    for (final v in victims) {
      final pushBack =
          (v.targetOrb.position - v.position).normalized() * -slowStrength;
      v.position += pushBack;
    }
  }

  /// Crystal Pierce - Shatters on each hit, spawning shards
  static void _crystalPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    final shardDmg = (damage * (0.3 + 0.06 * rank)).toInt();
    final rng = Random();

    for (final v in victims) {
      // Spawn shards to nearby enemies
      final nearby = game
          .getEnemiesInRange(v.position, 200)
          .where((e) => !victims.contains(e))
          .toList();

      final shardCount = min(2 + (rank ~/ 2), nearby.length);
      for (int i = 0; i < shardCount; i++) {
        if (nearby.isEmpty) break;
        final target = nearby[rng.nextInt(nearby.length)];

        game.spawnAlchemyProjectile(
          start: v.position,
          target: target,
          damage: shardDmg,
          color: Colors.tealAccent,
          shape: ProjectileShape.shard,
          speed: 3.0,
          isEnemy: false,
          onHit: () {
            target.takeDamage(shardDmg);
            ImpactVisuals.play(game, target.position, 'Crystal', scale: 0.4);
          },
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  AIR / DUST / LIGHTNING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Air Pierce - Sonic boom with heavy knockback
  static void _airPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    Vector2 startPos,
  ) {
    for (final v in victims) {
      final dir = (v.position - startPos).normalized();
      v.add(
        MoveEffect.by(
          dir * (80.0 + 20.0 * rank),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
    }

    SurvivalAttackManager.triggerScreenShake(game, 3.0 + rank * 0.5);
  }

  /// Dust Pierce - Blinding ray
  static void _dustPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();

    for (final v in victims) {
      // Confusion
      final jitter = Vector2(
        (rng.nextDouble() - 0.5) * (30 + 6 * rank),
        (rng.nextDouble() - 0.5) * (30 + 6 * rank),
      );
      v.position += jitter;
    }
  }

  /// Lightning Pierce - Chain lightning from each pierced enemy
  static void _lightningPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    final chainDmg = (damage * (0.4 + 0.08 * rank)).toInt();
    final rng = Random();

    for (final v in victims) {
      final nearby = game
          .getEnemiesInRange(v.position, 180)
          .where((e) => e != v && !victims.contains(e))
          .toList();

      final chainCount = min(1 + (rank ~/ 2), nearby.length);
      for (int i = 0; i < chainCount; i++) {
        if (nearby.isEmpty) break;
        final target = nearby[rng.nextInt(nearby.length)];

        game.spawnAlchemyProjectile(
          start: v.position,
          target: target,
          damage: chainDmg,
          color: Colors.yellow,
          shape: ProjectileShape.bolt,
          speed: 4.5,
          isEnemy: false,
          onHit: () {
            target.takeDamage(chainDmg);
            ImpactVisuals.play(game, target.position, 'Lightning', scale: 0.6);
          },
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SPIRIT / DARK / LIGHT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Spirit Pierce - Draining beam
  static void _spiritPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    int totalDrained = 0;

    for (final v in victims) {
      final drain = (damage * (0.25 + 0.05 * rank)).toInt();
      v.takeDamage(drain);
      totalDrained += drain;
      ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.6);
    }

    // Heal self
    attacker.unit.heal((totalDrained * 0.4).toInt());
  }

  /// Dark Pierce - Executes low HP enemies along path
  static void _darkPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    final executeThreshold = 0.2 + 0.05 * rank;
    final bonusDmg = (damage * (0.5 + 0.1 * rank)).toInt();

    for (final v in victims) {
      if (!v.isBoss && v.unit.hpPercent < executeThreshold) {
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.2);
      } else if (v.unit.hpPercent < 0.5) {
        v.takeDamage(bonusDmg);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 0.7);
      }
    }
  }

  /// Light Pierce - Holy ray that heals allies along path
  static void _lightPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final healAmount = (attacker.unit.statIntelligence * (2.0 + 0.4 * rank))
        .toInt()
        .clamp(5, 120);

    // Heal all guardians
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healAmount);
        ImpactVisuals.playHeal(game, g.position, scale: 0.5);
      }
    }

    // Extra damage visual
    for (final v in victims) {
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.8);
    }

    // Rank 3: Heal orb too
    if (rank >= 3) {
      game.orb.heal((healAmount * 0.5).toInt());
    }
  }
}
