import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/components/survival_attacks.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

class ManeHazardMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final spawnPos =
        target?.position.clone() ?? attacker.position + Vector2(50, 0);
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);

    switch (element) {
      case 'Fire':
        _fireHazard(game, attacker, spawnPos, rank);
        break;
      case 'Lava':
        _lavaHazard(game, attacker, spawnPos, rank);
        break;
      case 'Blood':
        _bloodHazard(game, attacker, spawnPos, rank);
        break;

      case 'Water':
        _waterHazard(game, attacker, spawnPos, rank);
        break;
      case 'Ice':
        _iceHazard(game, attacker, spawnPos, rank);
        break;
      case 'Steam':
        _steamHazard(game, attacker, spawnPos, rank);
        break;

      case 'Plant':
        _plantHazard(game, attacker, spawnPos, rank);
        break;
      case 'Poison':
        _poisonHazard(game, attacker, spawnPos, rank);
        break;

      case 'Earth':
        _earthHazard(game, attacker, spawnPos, rank);
        break;
      case 'Mud':
        _mudHazard(game, attacker, spawnPos, rank);
        break;
      case 'Crystal':
        _crystalHazard(game, attacker, spawnPos, rank);
        break;

      case 'Air':
        _airHazard(game, attacker, spawnPos, rank);
        break;
      case 'Dust':
        _dustHazard(game, attacker, spawnPos, rank);
        break;
      case 'Lightning':
        _lightningHazard(game, attacker, spawnPos, rank);
        break;

      case 'Spirit':
        _spiritHazard(game, attacker, spawnPos, rank);
        break;
      case 'Dark':
        _darkHazard(game, attacker, spawnPos, rank);
        break;
      case 'Light':
        _lightHazard(game, attacker, spawnPos, rank);
        break;

      default:
        _genericHazard(game, attacker, spawnPos, rank, element);
        break;
    }
  }

  // ─────────────────────────────
  //  FIRE / LAVA / BLOOD
  // ─────────────────────────────

  /// Fire Mane – "Firewall": short, high-damage line-ish zone
  static void _fireHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Fire');
    final radius = 80.0 + rank * 8;
    final duration = 5.0;
    final dps = (attacker.unit.statIntelligence * (2.2 + 0.3 * rank))
        .toInt()
        .clamp(5, 200);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.28)
        ..style = PaintingStyle.fill,
    );

    // Flicker “flames”
    zone.add(
      ScaleEffect.by(
        Vector2(1.05, 0.95),
        EffectController(duration: 0.4, alternate: true, infinite: true),
      ),
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            v.takeDamage((dps * 0.5).round());
            ImpactVisuals.play(game, v.position, 'Fire', scale: 0.5);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Lava Mane – “Magma Pool”: stronger DoT, a bit slower
  static void _lavaHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Lava');
    final radius = 90.0 + rank * 8;
    final duration = 5.0 + rank * 0.5;
    final dps = (attacker.unit.statIntelligence * (2.5 + 0.4 * rank))
        .toInt()
        .clamp(6, 250);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.32)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage((dps * 0.6).round());
            // mild slow
            final back =
                (v.targetOrb.position - v.position).normalized() * -6.0;
            v.position += back;
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Blood Mane – “Bloodfield”: damage → strong lifesteal for caster & team
  static void _bloodHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Blood');
    final radius = 75.0 + rank * 6;
    final duration = 5.0 + rank * 0.5;
    final dps = (attacker.unit.statIntelligence * (1.6 + 0.3 * rank))
        .toInt()
        .clamp(4, 180);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          int total = 0;
          for (final v in victims) {
            v.takeDamage(dps);
            total += dps;
          }
          if (total > 0) {
            final selfHeal = (total * 0.3).toInt();
            final teamHeal = (total * 0.2).toInt();
            attacker.unit.heal(selfHeal);
            for (final g in game.guardians) {
              if (!g.isDead && g != attacker) {
                g.unit.heal((teamHeal / (game.guardians.length - 1)).round());
              }
            }
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // ─────────────────────────────
  //  WATER / ICE / STEAM
  // ─────────────────────────────

  /// Water Mane – “Healing Pool”: heals allies, chips enemies
  static void _waterHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Water');
    final radius = 90.0 + rank * 6;
    final duration = 6.0 + rank * 0.5;
    final healPerTick = (attacker.unit.statIntelligence * (1.2 + 0.2 * rank))
        .toInt()
        .clamp(4, 80);
    final enemyDmg = (attacker.unit.statIntelligence * (0.6 + 0.1 * rank))
        .toInt();

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          // heal nearby guardians
          for (final g in game.guardians) {
            if (g.isDead) continue;
            if (g.position.distanceTo(zone.position) <= radius) {
              g.unit.heal(healPerTick);
              ImpactVisuals.play(game, g.position, 'Water', scale: 0.5);
            }
          }

          // chip enemies
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(enemyDmg);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Ice Mane – “Permafrost”: heavy slow/near root
  static void _iceHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Ice');
    final radius = 85.0 + rank * 6;
    final duration = 5.0 + rank * 0.4;
    final dps = (attacker.unit.statIntelligence * (1.4 + 0.2 * rank))
        .toInt()
        .clamp(3, 140);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.22)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dps);
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -10;
            v.position += pushBack; // strong slow
            ImpactVisuals.play(game, v.position, 'Ice', scale: 0.4);
          }
        },
      ),
    );

    // rank 5: icy pulsing visuals
    if (rank >= 5) {
      zone.add(
        ScaleEffect.by(
          Vector2.all(1.1),
          EffectController(duration: 0.5, alternate: true, infinite: true),
        ),
      );
    }

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Steam Mane – “Mist Field”: mild slow, orb regen when many enemies inside
  static void _steamHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Steam');
    final radius = 100.0 + rank * 8;
    final duration = 6.0 + rank * 0.4;

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -6;
            v.position += pushBack;
          }
          if (victims.length >= 3) {
            game.orb.heal(2 + rank); // small sustain
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // ─────────────────────────────
  //  PLANT / POISON
  // ─────────────────────────────

  /// Plant Mane – “Thorn Garden”: DoT + occasional mini-root
  static void _plantHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Plant');
    final radius = 80.0 + rank * 6;
    final duration = 6.0 + rank * 0.4;
    final dps = (attacker.unit.statIntelligence * (1.8 + 0.2 * rank))
        .toInt()
        .clamp(3, 160);
    final rng = Random();

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.28)
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
            // small chance to jitter in place (mini-root feel)
            if (rng.nextDouble() < 0.2 + 0.05 * (rank - 1)) {
              final jitter = Vector2(
                (rng.nextDouble() - 0.5) * 10,
                (rng.nextDouble() - 0.5) * 10,
              );
              v.position += jitter * -1;
            }
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Poison Mane – “Toxic Swamp”: strong DoT, some heal for caster
  static void _poisonHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Poison');
    final radius = 85.0 + rank * 6;
    final duration = 6.0 + rank * 0.5;
    final dps = (attacker.unit.statIntelligence * (2.0 + 0.3 * rank))
        .toInt()
        .clamp(4, 200);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          int total = 0;
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dps);
            total += dps;
          }
          if (total > 0) {
            attacker.unit.heal((total * 0.15).toInt());
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // ─────────────────────────────
  //  EARTH / MUD / CRYSTAL
  // ─────────────────────────────

  /// Earth Mane – “Fortified Ground”: enemies slowed, guardian gains shield
  static void _earthHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Earth');
    final radius = 80.0 + rank * 6;
    final duration = 6.0;
    final dps = (attacker.unit.statIntelligence * (1.4 + 0.2 * rank))
        .toInt()
        .clamp(3, 140);
    final shield = (attacker.unit.maxHp * (0.08 + 0.02 * (rank - 1))).toInt();

    attacker.unit.heal(shield);
    ImpactVisuals.play(game, attacker.position, 'Earth', scale: 0.9);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dps);
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -7;
            v.position += pushBack;
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Mud Mane – “Bog”: super slow, low damage
  static void _mudHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Mud');
    final radius = 90.0 + rank * 6;
    final duration = 6.0 + rank * 0.5;
    final dps = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 120);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dps);
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -12;
            v.position += pushBack; // very strong slow
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Crystal Mane – “Shard Bloom”: hazard that periodically fires shards out
  static void _crystalHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Crystal');
    final radius = 80.0 + rank * 6;
    final duration = 6.0;
    final shardDmg = (calcDmg(attacker, null) * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(5, 200);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    zone.add(
      TimerComponent(
        period: 0.8,
        repeat: true,
        onTick: () {
          final shardCount = 4 + rank;
          for (int i = 0; i < shardCount; i++) {
            final angle = (2 * pi * i) / shardCount;
            final targetPos =
                center + Vector2(cos(angle), sin(angle)) * (radius + 60);

            game.spawnAlchemyProjectile(
              start: center,
              target: PositionComponent(position: targetPos),
              damage: shardDmg,
              color: color,
              shape: ProjectileShape.shard,
              speed: 2.0,
              isEnemy: false,
              onHit: () {
                final victims = game.getEnemiesInRange(targetPos, 40);
                for (final v in victims) {
                  v.takeDamage(shardDmg);
                }
              },
            );
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // ─────────────────────────────
  //  AIR / DUST / LIGHTNING
  // ─────────────────────────────

  /// Air Mane – “Gale Zone”: constant outward push, low dmg
  static void _airHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Air');
    final radius = 95.0 + rank * 6;
    final duration = 5.0 + rank * 0.4;
    final dps = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 120);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dps);
            final dir = (v.position - center).normalized();
            v.add(
              MoveEffect.by(
                dir * (30 + rank * 5),
                EffectController(duration: 0.2, curve: Curves.easeOut),
              ),
            );
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Dust Mane – “Sandstorm”: confusion & minor slow
  static void _dustHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Dust');
    final radius = 90.0 + rank * 6;
    final duration = 5.0 + rank * 0.4;
    final dps = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 120);
    final rng = Random();

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dps);
            final offset = Vector2(
              (rng.nextDouble() - 0.5) * (10 + rank * 2),
              (rng.nextDouble() - 0.5) * (10 + rank * 2),
            );
            v.position += offset;
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Lightning Mane – “Static Field”: random zaps inside the zone
  static void _lightningHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Lightning');
    final radius = 95.0 + rank * 6;
    final duration = 5.0 + rank * 0.4;
    final rng = Random();

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(zone.position, radius);
          if (victims.isEmpty) return;

          final zaps = min(victims.length, 1 + rank);
          for (int i = 0; i < zaps; i++) {
            final v = victims[rng.nextInt(victims.length)];
            final dmg = (calcDmg(attacker, v) * (0.7 + 0.15 * rank))
                .toInt()
                .clamp(3, 150);
            v.takeDamage(dmg);
            ImpactVisuals.play(game, v.position, 'Lightning', scale: 0.8);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // ─────────────────────────────
  //  SPIRIT / DARK / LIGHT
  // ─────────────────────────────

  /// Spirit Mane – “Haunting Ground”: delayed blasts from spirits
  static void _spiritHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Spirit');
    final radius = 85.0 + rank * 6;
    final duration = 6.0 + rank * 0.4;
    final dps = (attacker.unit.statIntelligence * (1.4 + 0.2 * rank))
        .toInt()
        .clamp(3, 150);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.3)
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
            ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.6);
          }
        },
      ),
    );

    // occasional delayed mini-explosions
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (zone.parent == null) return;
      final victims = game.getEnemiesInRange(zone.position, radius);
      for (final v in victims) {
        final blastDmg = (calcDmg(attacker, v) * (0.6 + 0.1 * rank))
            .toInt()
            .clamp(4, 160);
        v.takeDamage(blastDmg);
        ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.9);
      }
    });

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Dark Mane – “Shadow Pit”: drains enemies, heals orb
  static void _darkHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Dark');
    final radius = 85.0 + rank * 6;
    final duration = 6.0 + rank * 0.4;
    final dps = (attacker.unit.statIntelligence * (1.8 + 0.3 * rank))
        .toInt()
        .clamp(4, 200);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          int total = 0;
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dps);
            total += dps;
          }
          if (total > 0) {
            final orbHeal = (total * 0.25).toInt();
            game.orb.heal(orbHeal);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Light Mane – “Sanctified Ground”: heals allies, burns enemies
  static void _lightHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
  ) {
    final color = SurvivalAttackManager.getElementColor('Light');
    final radius = 90.0 + rank * 6;
    final duration = 6.0 + rank * 0.4;
    final heal = (attacker.unit.statIntelligence * (1.6 + 0.2 * rank))
        .toInt()
        .clamp(4, 160);
    final dmg = (attacker.unit.statIntelligence * (1.2 + 0.2 * rank))
        .toInt()
        .clamp(3, 140);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          // heal allies
          for (final g in game.guardians) {
            if (g.isDead) continue;
            if (g.position.distanceTo(zone.position) <= radius) {
              g.unit.heal(heal);
              ImpactVisuals.play(game, g.position, 'Light', scale: 0.6);
            }
          }

          // damage enemies
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            v.takeDamage(dmg);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // ─────────────────────────────
  //  GENERIC FALLBACK
  // ─────────────────────────────

  static void _genericHazard(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    Vector2 center,
    int rank,
    String element,
  ) {
    final color = SurvivalAttackManager.getElementColor(element);
    final radius = 80.0 + rank * 5;
    final duration = 5.0 + rank * 0.3;
    final dps = (attacker.unit.statIntelligence * (1.5 + 0.2 * rank))
        .toInt()
        .clamp(3, 150);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.28)
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
}
