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

/// "Let" Family: METEOR STRIKE
/// Rank 1+: Lifesteal (Heals attacker for % of damage)
/// Rank 3+: ELEMENTAL AUGMENT (based on element type)
/// Rank 5 (MAX): APOCALYPSE (Drops 3 Meteors)
class LetMeteorMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);

    // Max Level Check
    final isMaxLevel = rank >= 5;
    final int meteorCount = isMaxLevel ? 3 : 1;

    for (int i = 0; i < meteorCount; i++) {
      // Offset subsequent meteors if max level
      final offset = i == 0
          ? Vector2.zero()
          : Vector2(
              (Random().nextDouble() - 0.5) * 100,
              (Random().nextDouble() - 0.5) * 100,
            );

      _spawnMeteor(
        game: game,
        attacker: attacker,
        center: target.position + offset,
        element: element,
        rank: rank,
      );

      // Slight delay between multi-meteors (visual staggering only)
      if (i > 0) {
        Future.delayed(Duration(milliseconds: i * 200));
      }
    }
  }

  static void _spawnMeteor({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required Vector2 center,
    required String element,
    required int rank,
  }) {
    double dmgMult = 2.5 + (0.3 * rank);
    double radius = 80.0 + (10.0 * rank);
    final color = SurvivalAttackManager.getElementColor(element);

    final meteor = CircleComponent(
      radius: 10,
      paint: Paint()..color = color,
      position: attacker.position,
      anchor: Anchor.center,
      priority: 100,
    );

    // Simple trail particles
    meteor.add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 5,
          lifespan: 0.5,
          generator: (i) => CircleParticle(
            radius: 3,
            paint: Paint()..color = color.withOpacity(0.5),
          ),
        ),
      ),
    );

    meteor.add(
      MoveEffect.to(
        center,
        EffectController(duration: 0.6, curve: Curves.easeIn),
      ),
    );
    meteor.add(
      ScaleEffect.to(
        Vector2.all(3.0),
        EffectController(duration: 0.6, curve: Curves.easeIn),
      ),
    );

    game.world.add(meteor);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (meteor.parent != null) meteor.removeFromParent();

      SurvivalAttackManager.triggerScreenShake(game, 5.0 + rank);
      ImpactVisuals.playExplosion(game, center, element, radius);

      final enemies = game.getEnemiesInRange(center, radius);
      final baseDmg = (calcDmg(attacker, null) * dmgMult).toInt();

      int totalDamageDealt = 0;

      for (var e in enemies) {
        e.takeDamage(baseDmg);
        totalDamageDealt += baseDmg;

        // Knockback away from center
        final dir = (e.position - center).normalized();
        e.position += dir * (40.0 + rank * 5);
      }

      // RANK 1+ ELEMENTAL AUGMENT
      if (rank >= 1 && enemies.isNotEmpty) {
        _applyElementalMeteorAugment(
          game: game,
          attacker: attacker,
          element: element,
          rank: rank,
          center: center,
          enemiesHit: enemies,
          totalDamageDealt: totalDamageDealt,
        );
      }
    });
  }

  /// Elemental augments for powered Let meteors (rank >= 3).
  /// Applies unique behavior based on the meteor's element.
  static void _applyElementalMeteorAugment({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 center,
    required List<HoardEnemy> enemiesHit,
    required int totalDamageDealt,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD – lingering burn & blood magic
      case 'Fire':
        _fireMeteor(game, attacker, rank, center);
        break;
      case 'Lava':
        _lavaMeteor(game, attacker, rank, center);
        break;
      case 'Blood':
        _bloodMeteor(game, attacker, rank, center, totalDamageDealt);
        break;

      // 💧 WATER / ICE / STEAM – control & sustain
      case 'Water':
        _waterMeteor(game, attacker, rank, center, enemiesHit);
        break;
      case 'Ice':
        _iceMeteor(game, attacker, rank, center, enemiesHit);
        break;
      case 'Steam':
        _steamMeteor(game, attacker, rank, center);
        break;

      // 🌿 PLANT / POISON – DoT & control zones
      case 'Plant':
        _plantMeteor(game, attacker, rank, center);
        break;
      case 'Poison':
        _poisonMeteor(game, attacker, rank, center);
        break;

      // 🌍 EARTH / MUD / CRYSTAL – terrain & armor
      case 'Earth':
        _earthMeteor(game, attacker, rank, center, enemiesHit);
        break;
      case 'Mud':
        _mudMeteor(game, attacker, rank, center);
        break;
      case 'Crystal':
        _crystalMeteor(game, attacker, rank, center);
        break;

      // 🌬️ AIR / DUST – knockback & disruption
      case 'Air':
        _airMeteor(game, attacker, rank, center);
        break;
      case 'Dust':
        _dustMeteor(game, attacker, rank, center);
        break;

      // ⚡ LIGHTNING – chain hits
      case 'Lightning':
        _lightningMeteor(game, attacker, rank, enemiesHit);
        break;

      // 🌗 SPIRIT / DARK / LIGHT – soul/holy twists
      case 'Spirit':
        _spiritMeteor(game, attacker, rank, center, enemiesHit);
        break;
      case 'Dark':
        _darkMeteor(game, attacker, rank, center, enemiesHit);
        break;
      case 'Light':
        _lightMeteor(game, attacker, rank, center);
        break;
      default:
        break;
    }
  }

  // ─────────────────────────────
  //  ELEMENT-SPECIFIC HELPERS
  // ─────────────────────────────

  // FIRE – burning ground zone
  static void _fireMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final burnRadius = 90.0 + rank * 10;
    final burnDuration = 4.0 + rank * 0.5;
    final burnDps = (attacker.unit.statIntelligence * (2 + rank * 0.3)).toInt();

    final color = SurvivalAttackManager.getElementColor('Fire');

    final zone = CircleComponent(
      radius: burnRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.7,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, burnRadius);
          for (final v in victims) {
            v.takeDamage((burnDps * 0.7).round());
            ImpactVisuals.play(game, v.position, 'Fire', scale: 0.4);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: burnDuration));
    game.world.add(zone);
  }

  // LAVA – extra mini-explosions around center
  static void _lavaMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final color = SurvivalAttackManager.getElementColor('Lava');
    final miniCount = 2 + (rank ~/ 2);

    for (int i = 0; i < miniCount; i++) {
      final angle = (2 * pi * i) / miniCount;
      final offset = Vector2(cos(angle), sin(angle)) * (70 + rank * 5);
      final pos = center + offset;

      game.world.add(
        CircleComponent(
          radius: 20,
          anchor: Anchor.center,
          position: pos,
          paint: Paint()
            ..color = color.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        )..add(
          SequenceEffect([
            ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 0.15)),
            RemoveEffect(),
          ]),
        ),
      );

      final dmg = (calcDmg(attacker, null) * (1.0 + rank * 0.2)).toInt();
      final victims = game.getEnemiesInRange(pos, 60 + rank * 5);
      for (final v in victims) {
        v.takeDamage(dmg);
        ImpactVisuals.play(game, v.position, 'Lava', scale: 0.8);
      }
    }
  }

  // BLOOD – big lifesteal based on damage dealt
  static void _bloodMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    int totalDamageDealt,
  ) {
    final steal = (totalDamageDealt * (0.15 + 0.05 * (rank - 3))).toInt();
    if (steal <= 0) return;

    // Heal the whole team a bit + orb slightly
    game.orb.heal((steal * 0.3).toInt());
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal((steal * 0.2).toInt());
        ImpactVisuals.play(game, g.position, 'Blood', scale: 0.6);
      }
    }

    ImpactVisuals.play(game, center, 'Blood', scale: 1.2);
  }

  // WATER – splash wave that also heals orb/guardian per enemy hit
  static void _waterMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> enemiesHit,
  ) {
    final healPerEnemy = (attacker.unit.statIntelligence * (2 + rank * 0.3))
        .toInt()
        .clamp(3, 50);
    final totalHeal = healPerEnemy * enemiesHit.length;

    game.orb.heal((totalHeal * 0.5).toInt());
    attacker.unit.heal((totalHeal * 0.5).toInt());

    // radial outward wave push
    for (final e in enemiesHit) {
      final dir = (e.position - center).normalized();
      e.add(
        MoveEffect.by(
          dir * (70 + rank * 10),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }
  }

  // ICE – heavy slow / pseudo-freeze
  static void _iceMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> enemiesHit,
  ) {
    final radius = 90.0 + rank * 10;
    final slowDuration = 2.0 + rank * 0.3;

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor('Ice').withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            // push them slightly AWAY from their movement direction: pseudo slow
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -8;
            v.position += pushBack;
            ImpactVisuals.play(game, v.position, 'Ice', scale: 0.3);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: slowDuration));
    game.world.add(zone);
  }

  // STEAM – fog zone: enemies slowed, orb lightly healed over time
  static void _steamMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final radius = 100.0 + rank * 10;
    final duration = 4.0 + rank * 0.5;
    final orbHealPerTick = (3 + rank).clamp(3, 25);

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor(
          'Steam',
        ).withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.7,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            // mild slow: nudge them slightly back from orb
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -5;
            v.position += pushBack;
          }
          if (victims.isNotEmpty) {
            game.orb.heal(orbHealPerTick);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // PLANT – thorn garden DoT + root chance
  static void _plantMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final radius = 90.0 + rank * 10;
    final duration = 5.0 + rank * 0.4;
    final dmg = (attacker.unit.statIntelligence * (1.5 + 0.3 * rank)).toInt();
    final rng = Random();

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor(
          'Plant',
        ).withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            v.takeDamage(dmg);
            // small chance to "root" by jittering them in place
            if (rng.nextDouble() < 0.2 + 0.05 * (rank - 3)) {
              final jitter =
                  Vector2(
                    (rng.nextDouble() - 0.5) * 10,
                    (rng.nextDouble() - 0.5) * 10,
                  ) *
                  -1;
              v.position += jitter;
            }
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // POISON – toxic cloud with stacking chip
  static void _poisonMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final radius = 90.0 + rank * 10;
    final duration = 6.0 + rank * 0.5;
    final dps = (attacker.unit.statIntelligence * (1.2 + 0.2 * rank)).toInt();

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor(
          'Poison',
        ).withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            v.takeDamage(dps);
            ImpactVisuals.play(game, v.position, 'Poison', scale: 0.3);
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // EARTH – armor buff for attacker + small slow field
  static void _earthMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> enemiesHit,
  ) {
    // simulate armor by healing a small chunk now
    final shield = (attacker.unit.maxHp * (0.08 + 0.03 * (rank - 3))).toInt();
    attacker.unit.heal(shield);
    ImpactVisuals.play(game, attacker.position, 'Earth', scale: 0.8);

    final radius = 80.0 + rank * 10;
    final duration = 4.0;

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor(
          'Earth',
        ).withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -6;
            v.position += pushBack;
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // MUD – sticky bog field
  static void _mudMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final radius = 90.0 + rank * 10;
    final duration = 5.0 + rank * 0.4;

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor('Mud').withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            // stronger backwards push → heavy slow
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -10;
            v.position += pushBack;
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // CRYSTAL – shard ring that hits farther out
  static void _crystalMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final shardCount = 6 + rank;
    final baseDamage = (calcDmg(attacker, null) * (1.0 + 0.2 * rank)).toInt();

    for (int i = 0; i < shardCount; i++) {
      final angle = (2 * pi * i) / shardCount;
      final targetPos =
          center + Vector2(cos(angle), sin(angle)) * (140 + rank * 10);

      // Wrap the target position in a PositionComponent to satisfy the parameter type.
      final dummyTarget = PositionComponent(position: targetPos);
      game.world.add(dummyTarget);

      game.spawnAlchemyProjectile(
        start: center,
        target: dummyTarget,
        damage: baseDamage,
        color: SurvivalAttackManager.getElementColor('Crystal'),
        shape: ProjectileShape.shard,
        speed: 1.6,
        isEnemy: false,
        onHit: () {
          final victims = game.getEnemiesInRange(targetPos, 40);
          for (final v in victims) {
            v.takeDamage(baseDamage);
            ImpactVisuals.play(game, v.position, 'Crystal', scale: 0.6);
          }
          dummyTarget.removeFromParent();
        },
      );
    }
  }

  // AIR – massive radial knockback
  static void _airMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final radius = 140.0 + rank * 10;
    final victims = game.getEnemiesInRange(center, radius);

    for (final v in victims) {
      final dir = (v.position - center).normalized();
      v.add(
        MoveEffect.by(
          dir * (140 + rank * 15),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }

    ImpactVisuals.play(game, center, 'Air', scale: 1.2);
  }

  // DUST – confusion cloud (jitter)
  static void _dustMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final radius = 100.0 + rank * 10;
    final duration = 4.0 + rank * 0.3;
    final rng = Random();

    final zone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor('Dust').withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            final offset = Vector2(
              (rng.nextDouble() - 0.5) * 14,
              (rng.nextDouble() - 0.5) * 14,
            );
            v.position += offset; // “confused” wobble
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // LIGHTNING – chain lightning from hit enemies
  static void _lightningMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> enemiesHit,
  ) {
    final rng = Random();
    final maxChains = 1 + rank;

    for (final src in enemiesHit) {
      final nearby = game
          .getEnemiesInRange(src.position, 220)
          .where((e) => e != src);
      final candidates = nearby.toList();
      if (candidates.isEmpty) continue;

      final chains = min(maxChains, candidates.length);
      for (int i = 0; i < chains; i++) {
        final target = candidates[rng.nextInt(candidates.length)];
        final dmg = (calcDmg(attacker, target) * (1.1 + 0.1 * rank)).toInt();

        game.spawnAlchemyProjectile(
          start: src.position,
          target: target,
          damage: dmg,
          color: SurvivalAttackManager.getElementColor('Lightning'),
          shape: ProjectileShape.bolt,
          speed: 2.8,
          isEnemy: false,
          onHit: () {
            target.takeDamage(dmg);
            ImpactVisuals.play(game, target.position, 'Lightning', scale: 0.7);
          },
        );
      }
    }
  }

  // SPIRIT – marks enemies; marked enemies explode on death
  static void _spiritMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> enemiesHit,
  ) {
    final markDmg = (calcDmg(attacker, null) * (0.6 + 0.2 * rank))
        .toInt()
        .clamp(5, 300);
    final radius = 90.0 + rank * 10;

    for (final e in enemiesHit) {
      // Visual mark
      ImpactVisuals.play(game, e.position, 'Spirit', scale: 0.8);

      // Simple implementation: small delayed explosion around each marked enemy
      Future.delayed(const Duration(milliseconds: 800), () {
        if (e.isDead) return;
        final victims = game.getEnemiesInRange(e.position, radius);
        for (final v in victims) {
          v.takeDamage(markDmg);
          ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.5);
        }
      });
    }
  }

  // DARK – extra damage & execute very low HP enemies near impact
  static void _darkMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> enemiesHit,
  ) {
    final radius = 120.0 + rank * 10;
    final victims = game.getEnemiesInRange(center, radius);

    for (final v in victims) {
      if (!v.isBoss && v.unit.hpPercent < 0.15 + 0.05 * (rank - 3)) {
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.4);
      } else {
        final extra = (calcDmg(attacker, v) * (0.8 + 0.2 * rank)).toInt().clamp(
          5,
          400,
        );
        v.takeDamage(extra);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 0.8);
      }
    }
  }

  // LIGHT – holy shockwave + brief team buff flavor
  static void _lightMeteor(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
  ) {
    final radius = 130.0 + rank * 10;
    final victims = game.getEnemiesInRange(center, radius);
    final dmg = (calcDmg(attacker, null) * (1.2 + 0.2 * rank)).toInt().clamp(
      10,
      500,
    );

    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.9);
    }

    // Tiny attack-speed-ish buff simulated as small heal burst on guardians
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal((g.unit.maxHp * 0.03 * rank).toInt());
      }
    }
  }
}
