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

class HornNovaMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);

    // Base nova numbers
    double radius = 200.0 + (10.0 * rank);
    double knockbackForce = 150.0 + (30.0 * rank);
    double dmgMult = 1.5 + (0.15 * rank);

    // Rank 5: “Seismic Slam” – bigger, nastier nova
    if (rank >= 5) {
      radius *= 1.3;
      knockbackForce *= 1.4;
      dmgMult *= 1.3;
      SurvivalAttackManager.triggerScreenShake(game, 8.0);
    }

    final color = SurvivalAttackManager.getElementColor(element);

    // Visual ring
    final ring = CircleComponent(
      radius: 10,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (rank >= 5) ? 10 : 5
        ..color = color.withOpacity(0.8),
      anchor: Anchor.center,
      position: attacker.size / 2,
    );

    attacker.add(ring);

    ring.add(
      ScaleEffect.to(
        Vector2.all(radius / 10),
        EffectController(duration: 0.35, curve: Curves.easeOutQuad),
      ),
    );
    ring.add(OpacityEffect.fadeOut(EffectController(duration: 0.35)));
    ring.add(RemoveEffect(delay: 0.35));

    // Base nova damage + knockback
    final enemies = game.getEnemiesInRange(attacker.position, radius);
    final dmg = (calcDmg(attacker, null) * dmgMult).toInt();

    for (var e in enemies) {
      e.takeDamage(dmg);
      final dir = (e.position - attacker.position).normalized();
      e.add(
        MoveEffect.by(
          dir * knockbackForce,
          EffectController(duration: 0.2, curve: Curves.decelerate),
        ),
      );
    }

    // Elemental augment (powers on at rank 1)
    if (rank >= 1) {
      _applyElementalNovaAugment(
        game: game,
        attacker: attacker,
        element: element,
        rank: rank,
        center: attacker.position.clone(),
        radius: radius,
        baseDamage: dmg,
        enemiesHit: enemies,
      );
    }
  }

  // ─────────────────────────────
  //  ELEMENT ROUTER
  // ─────────────────────────────

  static void _applyElementalNovaAugment({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 center,
    required double radius,
    required int baseDamage,
    required List<HoardEnemy> enemiesHit,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD – aggressive frontline
      case 'Fire':
        _fireNova(game, attacker, rank, center, radius);
        break;
      case 'Lava':
        _lavaNova(game, attacker, rank, center, radius);
        break;
      case 'Blood':
        _bloodNova(game, attacker, rank, center, radius, baseDamage);
        break;

      // 💧 WATER / ICE / STEAM – sustain & control
      case 'Water':
        _waterNova(game, attacker, rank, center, radius);
        break;
      case 'Ice':
        _iceNova(game, attacker, rank, center, radius);
        break;
      case 'Steam':
        _steamNova(game, attacker, rank, center, radius);
        break;

      // 🌿 PLANT / POISON – thorns & rot
      case 'Plant':
        _plantNova(game, attacker, rank, center, radius);
        break;
      case 'Poison':
        _poisonNova(game, attacker, rank, center, radius);
        break;

      // 🌍 EARTH / MUD / CRYSTAL – armor & terrain
      case 'Earth':
        _earthNova(game, attacker, rank, center, radius);
        break;
      case 'Mud':
        _mudNova(game, attacker, rank, center, radius);
        break;
      case 'Crystal':
        _crystalNova(game, attacker, rank, center, radius);
        break;

      // 🌬️ AIR / DUST – disruption & control
      case 'Air':
        _airNova(game, attacker, rank, center, radius);
        break;
      case 'Dust':
        _dustNova(game, attacker, rank, center, radius);
        break;
      case 'Lightning':
        _lightningNova(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌗 SPIRIT / DARK / LIGHT – holy / soul / shadow twists
      case 'Spirit':
        _spiritNova(game, attacker, rank, center, radius);
        break;
      case 'Dark':
        _darkNova(game, attacker, rank, center, radius);
        break;
      case 'Light':
        _lightNova(game, attacker, rank, center, radius);
        break;

      default:
        break;
    }
  }

  // ─────────────────────────────
  //  FIRE / LAVA / BLOOD
  // ─────────────────────────────

  /// Fire Horn – “Blazing Ring”: leave a short fire ring after knockback
  static void _fireNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final color = SurvivalAttackManager.getElementColor('Fire');
    final ringRadius = radius * 1.05;
    final duration = 3.0 + 0.4 * (rank - 1);
    final dps = (attacker.unit.statIntelligence * (1.5 + 0.2 * rank))
        .toInt()
        .clamp(3, 180);

    final zone = CircleComponent(
      radius: ringRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, ringRadius + 8);
          for (final v in victims) {
            v.takeDamage(dps);
            ImpactVisuals.play(game, v.position, 'Fire', scale: 0.4);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Lava Horn – “Magma Shock”: extra stun-ish knockback near the caster
  static void _lavaNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final color = SurvivalAttackManager.getElementColor('Lava');
    final innerRadius = radius * 0.6;
    final victims = game.getEnemiesInRange(center, innerRadius);

    for (final v in victims) {
      final dir = (v.position - center).normalized();
      v.add(
        MoveEffect.by(
          dir * (80.0 + rank * 10.0),
          EffectController(duration: 0.15, curve: Curves.easeOut),
        ),
      );
      // brief jitter to simulate “stagger”
      v.add(
        ScaleEffect.by(
          Vector2(1.05, 0.95),
          EffectController(duration: 0.15, alternate: true, repeatCount: 1),
        ),
      );
    }

    game.world.add(
      CircleComponent(
        radius: innerRadius,
        position: center,
        anchor: Anchor.center,
        paint: Paint()
          ..color = color.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      )..add(RemoveEffect(delay: 0.4)),
    );
  }

  /// Blood Horn – “Crimson Crash”: damage → lifesteal for self + orb
  static void _bloodNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    int baseDamage,
  ) {
    final victims = game.getEnemiesInRange(center, radius);
    int total = baseDamage * victims.length;
    if (total <= 0) return;

    final selfHeal = (total * (0.25 + 0.05 * (rank - 1))).toInt();
    final orbHeal = (total * 0.2).toInt();

    attacker.unit.heal(selfHeal);
    game.orb.heal(orbHeal);
    ImpactVisuals.play(game, attacker.position, 'Blood', scale: 1.0);
  }

  // ─────────────────────────────
  //  WATER / ICE / STEAM
  // ─────────────────────────────

  /// Water Horn – “Tidal Shock”: pushes enemies further & heals nearby allies
  static void _waterNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final heal = (attacker.unit.statIntelligence * (2.0 + 0.2 * rank))
        .toInt()
        .clamp(5, 160);

    for (final g in game.guardians) {
      if (!g.isDead && g.position.distanceTo(center) <= radius * 1.1) {
        g.unit.heal(heal);
        ImpactVisuals.play(game, g.position, 'Water', scale: 0.6);
      }
    }

    // Mild extra splash push on enemies
    final victims = game.getEnemiesInRange(center, radius * 1.1);
    for (final v in victims) {
      final dir = (v.position - center).normalized();
      v.position += dir * (30.0 + 8.0 * rank);
    }
  }

  /// Ice Horn – “Glacial Slam”: strong slow near the edge
  static void _iceNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final ringRadius = radius * 1.0;
    final duration = 3.0 + 0.5 * (rank - 1);
    final color = SurvivalAttackManager.getElementColor('Ice');

    final zone = CircleComponent(
      radius: ringRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    zone.add(
      TimerComponent(
        period: 0.35,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, ringRadius + 8);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -10;
            v.position += pushBack;
            ImpactVisuals.play(game, v.position, 'Ice', scale: 0.4);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Steam Horn – “Scalding Burst”: chips and tiny orb regen
  static void _steamNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final color = SurvivalAttackManager.getElementColor('Steam');
    final victims = game.getEnemiesInRange(center, radius * 1.1);
    final chip = (attacker.unit.statIntelligence * (1.2 + 0.15 * rank))
        .toInt()
        .clamp(3, 120);

    for (final v in victims) {
      v.takeDamage(chip);
    }
    if (victims.isNotEmpty) {
      game.orb.heal(2 + rank);
    }

    game.world.add(
      CircleComponent(
        radius: radius * 1.1,
        position: center,
        anchor: Anchor.center,
        paint: Paint()
          ..color = color.withOpacity(0.25)
          ..style = PaintingStyle.fill,
      )..add(RemoveEffect(delay: 0.3)),
    );
  }

  // ─────────────────────────────
  //  PLANT / POISON
  // ─────────────────────────────

  /// Plant Horn – “Thorn Shock”: spawn thorny ring that damages crossing enemies
  static void _plantNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final color = SurvivalAttackManager.getElementColor('Plant');
    final ringRadius = radius * 1.05;
    final duration = 5.0 + 0.3 * (rank - 1);
    final dps = (attacker.unit.statIntelligence * (1.7 + 0.2 * rank))
        .toInt()
        .clamp(3, 180);

    final zone = CircleComponent(
      radius: ringRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, ringRadius + 4);
          for (final v in victims) {
            v.takeDamage(dps);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Poison Horn – “Toxic Pulse”: apply poison to nova victims
  static void _poisonNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick:
              (attacker.unit.statIntelligence * (0.8 + 0.15 * rank)).toInt() +
              2,
          ticksRemaining: 6 + rank,
          tickInterval: 0.5,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Poison', scale: 0.5);
    }
  }

  // ─────────────────────────────
  //  EARTH / MUD / CRYSTAL
  // ─────────────────────────────

  /// Earth Horn – “Stoneguard Nova”: extra shield for the caster
  static void _earthNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final shield = (attacker.unit.maxHp * (0.10 + 0.03 * (rank - 1)))
        .toInt()
        .clamp(10, 400);
    attacker.unit.heal(shield);
    ImpactVisuals.play(game, attacker.position, 'Earth', scale: 1.0);

    // Slight extra pull-back on nearby enemies
    final victims = game.getEnemiesInRange(center, radius * 0.9);
    for (final v in victims) {
      final pushBack = (v.targetOrb.position - v.position).normalized() * -8.0;
      v.position += pushBack;
    }
  }

  /// Mud Horn – “Quagmire Slam”: creates a sticky inner zone
  static void _mudNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final color = SurvivalAttackManager.getElementColor('Mud');
    final innerRadius = radius * 0.7;
    final duration = 5.0 + 0.4 * (rank - 1);

    final zone = CircleComponent(
      radius: innerRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.35,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, innerRadius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -12.0;
            v.position += pushBack;
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Crystal Horn – “Shard Armor”: shards explode outward after nova
  static void _crystalNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final color = SurvivalAttackManager.getElementColor('Crystal');
    final shardCount = 5 + rank;
    final dmg = (calcDmg(attacker, null) * (0.8 + 0.15 * rank)).toInt().clamp(
      5,
      220,
    );

    for (int i = 0; i < shardCount; i++) {
      final angle = (2 * pi * i) / shardCount;
      final targetPos =
          center + Vector2(cos(angle), sin(angle)) * (radius + 60);
      // Wrap static position in a temporary PositionComponent since the API expects a PositionComponent target.
      final tempTarget = PositionComponent(position: targetPos);

      game.spawnAlchemyProjectile(
        start: center,
        target: tempTarget,
        damage: dmg,
        color: color,
        shape: ProjectileShape.shard,
        speed: 2.2,
        isEnemy: false,
        onHit: () {
          final victims = game.getEnemiesInRange(targetPos, 45);
          for (final v in victims) {
            v.takeDamage(dmg);
            ImpactVisuals.play(game, v.position, 'Crystal', scale: 0.6);
          }
        },
      );
    }
  }

  // ─────────────────────────────
  //  AIR / DUST / LIGHTNING
  // ─────────────────────────────

  /// Air Horn – “Gale Nova”: huge knockback + clear space
  static void _airNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final victims = game.getEnemiesInRange(center, radius * 1.1);
    for (final v in victims) {
      final dir = (v.position - center).normalized();
      v.add(
        MoveEffect.by(
          dir * (160.0 + 20.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }
    ImpactVisuals.play(game, center, 'Air', scale: 1.2);
  }

  /// Dust Horn – “Dustburst”: confuse enemies nearby
  static void _dustNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final rng = Random();
    final victims = game.getEnemiesInRange(center, radius);
    for (final v in victims) {
      final offset = Vector2(
        (rng.nextDouble() - 0.5) * (18 + 3 * rank),
        (rng.nextDouble() - 0.5) * (18 + 3 * rank),
      );
      v.position += offset;
    }
  }

  /// Lightning Horn – “Thundercrash”: extra chain lightning after nova
  static void _lightningNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> enemiesHit,
  ) {
    final rng = Random();
    final maxChains = 2 + rank;

    for (final src in enemiesHit) {
      final nearby = game
          .getEnemiesInRange(src.position, radius * 0.9)
          .where((e) => e != src);
      final candidates = nearby.toList();
      if (candidates.isEmpty) continue;

      final chains = min(maxChains, candidates.length);
      for (int i = 0; i < chains; i++) {
        final target = candidates[rng.nextInt(candidates.length)];
        final dmg = (calcDmg(attacker, target) * (0.7 + 0.15 * rank))
            .toInt()
            .clamp(4, 180);
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

  // ─────────────────────────────
  //  SPIRIT / DARK / LIGHT
  // ─────────────────────────────

  /// Spirit Horn – “Echoing Slam”: delayed ghostly echo nova
  static void _spiritNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final delayMs = (600 - 50 * (rank - 1)).clamp(300, 600);
    Future.delayed(Duration(milliseconds: delayMs), () {
      final victims = game.getEnemiesInRange(center, radius * 0.9);
      final dmg = (calcDmg(attacker, null) * (0.6 + 0.15 * rank)).toInt().clamp(
        5,
        220,
      );
      for (final v in victims) {
        v.takeDamage(dmg);
        ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.8);
      }
    });
  }

  /// Dark Horn – “Shadowquake”: drains enemies, heals orb
  static void _darkNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final victims = game.getEnemiesInRange(center, radius);
    int total = 0;
    final dmg = (calcDmg(attacker, null) * (0.9 + 0.2 * rank)).toInt().clamp(
      5,
      220,
    );
    for (final v in victims) {
      v.takeDamage(dmg);
      total += dmg;
      ImpactVisuals.play(game, v.position, 'Dark', scale: 0.7);
    }
    if (total > 0) {
      final orbHeal = (total * 0.25).toInt();
      game.orb.heal(orbHeal);
    }
  }

  /// Light Horn – “Radiant Shock”: nova that also buffs nearby allies
  static void _lightNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final victims = game.getEnemiesInRange(center, radius);
    final dmg = (calcDmg(attacker, null) * (0.8 + 0.15 * rank)).toInt().clamp(
      5,
      220,
    );
    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.8);
    }

    // Simulate a short “defensive buff” as bonus healing
    for (final g in game.guardians) {
      if (!g.isDead && g.position.distanceTo(center) <= radius * 1.1) {
        final heal = (g.unit.maxHp * (0.04 + 0.01 * rank)).toInt().clamp(
          5,
          200,
        );
        g.unit.heal(heal);
        ImpactVisuals.play(game, g.position, 'Light', scale: 0.6);
      }
    }
  }
}
