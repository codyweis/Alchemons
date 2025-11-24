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

/// Rank 1+: Elemental pull + unique detonation per element
/// Rank 5 (MAX): Strongest version (Dark gets execute-style finisher)
class MaskVoidMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final center =
        target?.position.clone() ?? attacker.position + Vector2(100, 0);
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);

    double radius = 150.0 + (15.0 * rank);
    double pullStrength = 5.0 + rank * 1.5;
    double duration = 1.5 + 0.2 * rank;

    final color = SurvivalAttackManager.getElementColor(element);

    final voidZone = CircleComponent(
      radius: 5,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.black
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Visual growth + pulse
    final endScale = 4.0 + rank * 0.4;
    voidZone.add(
      ScaleEffect.to(Vector2.all(endScale), EffectController(duration: 0.25)),
    );
    voidZone.add(
      SequenceEffect([
        ScaleEffect.by(
          Vector2.all(0.9),
          EffectController(duration: 0.5, alternate: true, repeatCount: 3),
        ),
        RemoveEffect(delay: duration),
      ]),
    );

    game.world.add(voidZone);

    // Core pull + elemental tick
    voidZone.add(
      TimerComponent(
        period: 0.1,
        repeat: true,
        onTick: () {
          // if removed early, bail
          if (voidZone.parent == null) return;

          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            final pull = (center - v.position).normalized() * pullStrength;
            v.position += pull;

            _applyElementalMaskTick(
              game: game,
              attacker: attacker,
              element: element,
              rank: rank,
              center: center,
              enemy: v,
            );
          }
        },
      ),
    );

    // Final detonation after duration
    Future.delayed(Duration(milliseconds: (duration * 1000).round()), () {
      if (voidZone.parent == null) return;

      final victims = game.getEnemiesInRange(center, radius * 0.9);
      _applyElementalMaskDetonation(
        game: game,
        attacker: attacker,
        element: element,
        rank: rank,
        center: center,
        radius: radius * 0.9,
        victims: victims,
      );

      SurvivalAttackManager.triggerScreenShake(game, 3.0 + rank * 0.4);
      voidZone.removeFromParent();
    });
  }

  // ─────────────────────────────
  //  TICK EFFECTS WHILE PULLING
  // ─────────────────────────────

  static void _applyElementalMaskTick({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 center,
    required HoardEnemy enemy,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireTick(game, attacker, rank, enemy);
        break;
      case 'Lava':
        _lavaTick(game, attacker, rank, enemy);
        break;
      case 'Blood':
        _bloodTick(game, attacker, rank, enemy);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterTick(game, attacker, rank, enemy);
        break;
      case 'Ice':
        _iceTick(game, attacker, rank, enemy, center);
        break;
      case 'Steam':
        _steamTick(game, attacker, rank, enemy);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantTick(game, attacker, rank, enemy);
        break;
      case 'Poison':
        _poisonTick(game, attacker, rank, enemy);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthTick(game, attacker, rank, enemy, center);
        break;
      case 'Mud':
        _mudTick(game, attacker, rank, enemy, center);
        break;
      case 'Crystal':
        _crystalTick(game, attacker, rank, enemy, center);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airTick(game, attacker, rank, enemy, center);
        break;
      case 'Dust':
        _dustTick(game, attacker, rank, enemy);
        break;
      case 'Lightning':
        _lightningTick(game, attacker, rank, enemy, center);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritTick(game, attacker, rank, enemy);
        break;
      case 'Dark':
        _darkTick(game, attacker, rank, enemy);
        break;
      case 'Light':
        _lightTick(game, attacker, rank, enemy, center);
        break;
      default:
        break;
    }
  }

  // ─────────────────────────────
  //  FINAL DETONATION EFFECTS
  // ─────────────────────────────

  static void _applyElementalMaskDetonation({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 center,
    required double radius,
    required List<HoardEnemy> victims,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Lava':
        _lavaDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Blood':
        _bloodDetonate(game, attacker, rank, center, radius, victims);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Ice':
        _iceDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Steam':
        _steamDetonate(game, attacker, rank, center, radius, victims);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Poison':
        _poisonDetonate(game, attacker, rank, center, radius, victims);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Mud':
        _mudDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Crystal':
        _crystalDetonate(game, attacker, rank, center, radius, victims);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Dust':
        _dustDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Lightning':
        _lightningDetonate(game, attacker, rank, center, radius, victims);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Dark':
        _darkDetonate(game, attacker, rank, center, radius, victims);
        break;
      case 'Light':
        _lightDetonate(game, attacker, rank, center, radius, victims);
        break;
      default:
        _genericDetonate(game, attacker, rank, center, radius, victims);
        break;
    }
  }

  // ─────────────────────────────
  //  TICK IMPLEMENTATIONS
  // ─────────────────────────────

  // FIRE – small burn per tick
  static void _fireTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    final burn = (attacker.unit.statIntelligence * (0.4 + 0.1 * rank))
        .toInt()
        .clamp(1, 40);
    enemy.takeDamage(burn);
  }

  // LAVA – slightly stronger burn
  static void _lavaTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    final burn = (attacker.unit.statIntelligence * (0.6 + 0.12 * rank))
        .toInt()
        .clamp(1, 60);
    enemy.takeDamage(burn);
  }

  // BLOOD – small drain → heal attacker
  static void _bloodTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    final dmg = (attacker.unit.statIntelligence * (0.4 + 0.08 * rank))
        .toInt()
        .clamp(1, 40);
    enemy.takeDamage(dmg);
    attacker.unit.heal((dmg * 0.4).toInt());
  }

  // WATER – chip + little orb heal over time if something inside
  static void _waterTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    final dmg = (attacker.unit.statIntelligence * 0.3).toInt().clamp(0, 30);
    if (dmg > 0) enemy.takeDamage(dmg);
    game.orb.heal(1); // trickle sustain
  }

  // ICE – slows by nudging back slightly from orb side
  static void _iceTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
    Vector2 center,
  ) {
    final push = (enemy.targetOrb.position - enemy.position).normalized() * -4;
    enemy.position += push;
  }

  // STEAM – very light chip, almost no damage
  static void _steamTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    final dmg = (attacker.unit.statIntelligence * 0.2).toInt().clamp(0, 20);
    if (dmg > 0) enemy.takeDamage(dmg);
  }

  // PLANT – small thorny chip
  static void _plantTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    final dmg = (attacker.unit.statIntelligence * (0.35 + 0.08 * rank))
        .toInt()
        .clamp(1, 40);
    enemy.takeDamage(dmg);
  }

  // POISON – apply/refresh poison status
  static void _poisonTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    enemy.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Poison',
        damagePerTick:
            (attacker.unit.statIntelligence * (0.5 + 0.1 * rank)).toInt() + 1,
        ticksRemaining: 2 + rank,
        tickInterval: 0.4,
      ),
    );
  }

  // EARTH – chip + tiny push-away from orb (more control)
  static void _earthTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
    Vector2 center,
  ) {
    final dmg = (attacker.unit.statIntelligence * 0.35).toInt().clamp(0, 35);
    if (dmg > 0) enemy.takeDamage(dmg);
  }

  // MUD – extra slow: slightly stronger drag
  static void _mudTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
    Vector2 center,
  ) {
    // pulling is already happening – we just add a bit of sticky feel (no extra dmg)
    enemy.position += (center - enemy.position).normalized() * 0.5;
  }

  // CRYSTAL – small shard chip
  static void _crystalTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
    Vector2 center,
  ) {
    final dmg = (attacker.unit.statIntelligence * 0.4).toInt().clamp(0, 40);
    if (dmg > 0) enemy.takeDamage(dmg);
  }

  // AIR – slightly “floaty” jitter inward
  static void _airTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
    Vector2 center,
  ) {
    // The main pull does the work; here we just give a tiny extra wobble
  }

  // DUST – jitter/confuse
  static void _dustTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    final rng = Random();
    final offset = Vector2(
      (rng.nextDouble() - 0.5) * 4,
      (rng.nextDouble() - 0.5) * 4,
    );
    enemy.position += offset;
  }

  // LIGHTNING – tiny zap every tick
  static void _lightningTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
    Vector2 center,
  ) {
    final dmg = (attacker.unit.statIntelligence * (0.4 + 0.1 * rank))
        .toInt()
        .clamp(1, 40);
    enemy.takeDamage(dmg);
  }

  // SPIRIT – chip + visual ghost feel
  static void _spiritTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    final dmg = (attacker.unit.statIntelligence * 0.4).toInt().clamp(0, 35);
    if (dmg > 0) enemy.takeDamage(dmg);
  }

  // DARK – entropy-like constant chip
  static void _darkTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
  ) {
    final dmg = (attacker.unit.statIntelligence * (0.5 + 0.1 * rank))
        .toInt()
        .clamp(1, 40);
    enemy.takeDamage(dmg);
  }

  // LIGHT – purifying chip
  static void _lightTick(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy enemy,
    Vector2 center,
  ) {
    final dmg = (attacker.unit.statIntelligence * 0.4).toInt().clamp(0, 35);
    if (dmg > 0) enemy.takeDamage(dmg);
  }

  // ─────────────────────────────
  //  DETONATION IMPLEMENTATIONS
  // ─────────────────────────────

  // SHARED helper: base detonation dmg
  static int _baseDetonationDamage(HoardGuardian attacker, int rank) {
    return (calcDmg(attacker, null) * (2.0 + 0.3 * rank)).toInt().clamp(
      5,
      9999,
    );
  }

  // FIRE – big burn blast
  static void _fireDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = _baseDetonationDamage(attacker, rank);
    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Fire', scale: 1.0);
    }
    ImpactVisuals.playExplosion(game, center, 'Fire', radius);
  }

  // LAVA – higher dmg, more knockback
  static void _lavaDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = (_baseDetonationDamage(attacker, rank) * 1.2).toInt();
    for (final v in victims) {
      v.takeDamage(dmg);
      final dir = (v.position - center).normalized();
      v.position += dir * (60.0 + 10.0 * rank);
      ImpactVisuals.play(game, v.position, 'Lava', scale: 1.2);
    }
    ImpactVisuals.playExplosion(game, center, 'Lava', radius);
  }

  // BLOOD – moderate dmg → big lifesteal to team & orb
  static void _bloodDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = _baseDetonationDamage(attacker, rank);
    int total = 0;
    for (final v in victims) {
      v.takeDamage(dmg);
      total += dmg;
      ImpactVisuals.play(game, v.position, 'Blood', scale: 1.0);
    }
    if (total > 0) {
      final selfHeal = (total * (0.3 + 0.05 * (rank - 1))).toInt();
      final teamHeal = (total * 0.25).toInt();
      final orbHeal = (total * 0.25).toInt();

      attacker.unit.heal(selfHeal);
      for (final g in game.guardians) {
        if (!g.isDead && g != attacker) {
          g.unit.heal((teamHeal / (game.guardians.length - 1)).round());
        }
      }
      game.orb.heal(orbHeal);
    }
  }

  // WATER – heal allies near center, dmg enemies
  static void _waterDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = (_baseDetonationDamage(attacker, rank) * 0.8).toInt();
    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Water', scale: 0.9);
    }

    final heal = (attacker.unit.statIntelligence * (5 + 1.5 * rank))
        .toInt()
        .clamp(10, 200);
    for (final g in game.guardians) {
      if (!g.isDead && g.position.distanceTo(center) <= radius * 1.1) {
        g.unit.heal(heal);
        ImpactVisuals.play(game, g.position, 'Water', scale: 0.7);
      }
    }
  }

  // ICE – strong root-ish slow & decent dmg
  static void _iceDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = _baseDetonationDamage(attacker, rank);
    for (final v in victims) {
      v.takeDamage(dmg);
      final pushBack = (v.targetOrb.position - v.position).normalized() * -15.0;
      v.position += pushBack;
      ImpactVisuals.play(game, v.position, 'Ice', scale: 1.0);
    }
    ImpactVisuals.playExplosion(game, center, 'Ice', radius);
  }

  // STEAM – light dmg, good orb heal if many inside
  static void _steamDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = (_baseDetonationDamage(attacker, rank) * 0.7).toInt();
    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Steam', scale: 0.9);
    }
    if (victims.isNotEmpty) {
      game.orb.heal((victims.length * (8 + 2 * rank)).toInt());
    }
  }

  // PLANT – seeds a lingering thorn hazard
  static void _plantDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = _baseDetonationDamage(attacker, rank);
    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Plant', scale: 1.0);
    }

    // Thorn hazard stays after
    final hazardRadius = radius * 0.9;
    final dps = (attacker.unit.statIntelligence * (1.6 + 0.2 * rank))
        .toInt()
        .clamp(3, 200);
    final duration = 4.0 + 0.4 * (rank - 1);

    final zone = CircleComponent(
      radius: hazardRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor(
          'Plant',
        ).withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          final victims2 = game.getEnemiesInRange(center, hazardRadius);
          for (final v in victims2) {
            v.takeDamage(dps);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // POISON – heavy poison application, ok dmg
  static void _poisonDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = (_baseDetonationDamage(attacker, rank) * 0.8).toInt();
    for (final v in victims) {
      v.takeDamage(dmg ~/ 2);
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick:
              (attacker.unit.statIntelligence * (1.0 + 0.2 * rank)).toInt() + 4,
          ticksRemaining: 8 + rank,
          tickInterval: 0.5,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Poison', scale: 1.0);
    }
  }

  // EARTH – decent dmg + shield to allies near center
  static void _earthDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = _baseDetonationDamage(attacker, rank);
    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Earth', scale: 1.0);
    }

    final shield = (attacker.unit.maxHp * (0.08 + 0.02 * (rank - 1)))
        .toInt()
        .clamp(10, 400);
    for (final g in game.guardians) {
      if (!g.isDead && g.position.distanceTo(center) <= radius * 1.1) {
        g.unit.heal(shield);
        ImpactVisuals.play(game, g.position, 'Earth', scale: 0.8);
      }
    }
  }

  // MUD – big slow puddle after detonate
  static void _mudDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = (_baseDetonationDamage(attacker, rank) * 0.9).toInt();
    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Mud', scale: 1.0);
    }

    final slowRadius = radius;
    final duration = 4.5 + 0.4 * (rank - 1);
    final zone = CircleComponent(
      radius: slowRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor('Mud').withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims2 = game.getEnemiesInRange(center, slowRadius);
          for (final v in victims2) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -10.0;
            v.position += pushBack;
          }
        },
      ),
    );
    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // CRYSTAL – shards explode outward from center
  static void _crystalDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final baseDmg = _baseDetonationDamage(attacker, rank);
    for (final v in victims) {
      v.takeDamage((baseDmg * 0.6).toInt());
      ImpactVisuals.play(game, v.position, 'Crystal', scale: 0.9);
    }

    final color = SurvivalAttackManager.getElementColor('Crystal');
    final shardCount = 6 + rank;
    final shardDmg = (baseDmg * 0.7).toInt();

    for (int i = 0; i < shardCount; i++) {
      final angle = (2 * pi * i) / shardCount;
      final targetPos =
          center + Vector2(cos(angle), sin(angle)) * (radius + 60);

      // Wrap target position in a PositionComponent as spawnAlchemyProjectile expects a PositionComponent.
      final targetComponent = PositionComponent(position: targetPos.clone());
      game.world.add(targetComponent);

      game.spawnAlchemyProjectile(
        start: center,
        target: targetComponent,
        damage: shardDmg,
        color: color,
        shape: ProjectileShape.shard,
        speed: 2.4,
        isEnemy: false,
        onHit: () {
          final victims2 = game.getEnemiesInRange(targetComponent.position, 50);
          for (final v in victims2) {
            v.takeDamage(shardDmg);
          }
          // Clean up temporary target component
          targetComponent.removeFromParent();
        },
      );
    }
  }

  // AIR – big outward blow after pull
  static void _airDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = (_baseDetonationDamage(attacker, rank) * 0.9).toInt();
    for (final v in victims) {
      v.takeDamage(dmg);
      final dir = (v.position - center).normalized();
      v.add(
        MoveEffect.by(
          dir * (120.0 + 15.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
      ImpactVisuals.play(game, v.position, 'Air', scale: 1.0);
    }
  }

  // DUST – confuse burst
  static void _dustDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = (_baseDetonationDamage(attacker, rank) * 0.7).toInt();
    final rng = Random();
    for (final v in victims) {
      v.takeDamage(dmg);
      final offset = Vector2(
        (rng.nextDouble() - 0.5) * (40 + 5 * rank),
        (rng.nextDouble() - 0.5) * (40 + 5 * rank),
      );
      v.position += offset;
      ImpactVisuals.play(game, v.position, 'Dust', scale: 0.9);
    }
  }

  // LIGHTNING – arcs between victims inside
  static void _lightningDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final base = (_baseDetonationDamage(attacker, rank) * 0.8).toInt();
    final rng = Random();
    for (final v in victims) {
      v.takeDamage(base);
    }

    // small chain arcs
    for (final src in victims) {
      final nearby = game
          .getEnemiesInRange(src.position, radius * 0.7)
          .where((e) => e != src);
      final list = nearby.toList();
      if (list.isEmpty) continue;

      final chains = min(1 + rank, list.length);
      for (int i = 0; i < chains; i++) {
        final target = list[rng.nextInt(list.length)];
        final dmg = (base * 0.8).toInt();

        game.spawnAlchemyProjectile(
          start: src.position,
          target: target,
          damage: dmg,
          color: SurvivalAttackManager.getElementColor('Lightning'),
          shape: ProjectileShape.bolt,
          speed: 3.0,
          isEnemy: false,
          onHit: () {
            target.takeDamage(dmg);
            ImpactVisuals.play(game, target.position, 'Lightning', scale: 0.7);
          },
        );
      }
    }
  }

  // SPIRIT – spectral execute-style burst (but softer than Dark)
  static void _spiritDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = _baseDetonationDamage(attacker, rank);
    for (final v in victims) {
      var finalDmg = dmg;
      if (v.unit.hpPercent < 0.25) {
        finalDmg = (finalDmg * 1.5).toInt();
      }
      v.takeDamage(finalDmg);
      ImpactVisuals.play(game, v.position, 'Spirit', scale: 1.2);
    }
  }

  // DARK – the true EVENT HORIZON; rank 5 execute lives here
  static void _darkDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = _baseDetonationDamage(attacker, rank);

    for (final v in victims) {
      if (rank >= 5 && !v.isBoss && v.unit.hpPercent < 0.30) {
        // Event Horizon: execute non-boss under 30% HP
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Blood', scale: 2.0);
      } else {
        v.takeDamage(dmg);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.5);
      }
    }
  }

  // LIGHT – purifying implosion: heal allies near center, damage enemies
  static void _lightDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = (_baseDetonationDamage(attacker, rank) * 0.9).toInt();
    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Light', scale: 1.2);
    }

    final heal = (attacker.unit.statIntelligence * (6 + 1.5 * rank))
        .toInt()
        .clamp(20, 260);
    for (final g in game.guardians) {
      if (!g.isDead && g.position.distanceTo(center) <= radius * 1.1) {
        g.unit.heal(heal);
        ImpactVisuals.play(game, g.position, 'Light', scale: 1.0);
      }
    }
  }

  // Fallback, in case we somehow hit a weird element string
  static void _genericDetonate(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final dmg = _baseDetonationDamage(attacker, rank);
    for (final v in victims) {
      v.takeDamage(dmg);
    }
    ImpactVisuals.playExplosion(game, center, 'Dark', radius);
  }
}
