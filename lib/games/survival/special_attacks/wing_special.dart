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

class WingPierceMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);

    double dmgMult = 2.0 + (0.2 * rank);
    double width = 40.0 + (5.0 * rank);

    // Rank 5: Hyper Beam
    if (rank >= 5) {
      width = 120.0;
      dmgMult *= 1.5;
      SurvivalAttackManager.triggerScreenShake(game, 4.0);
    }

    final direction = (target.position - attacker.position).normalized();
    final start = attacker.position.clone();
    final end = start + (direction * 900);
    final color = SurvivalAttackManager.getElementColor(element);

    final baseDamage = (calcDmg(attacker, target) * dmgMult).toInt().clamp(
      1,
      99999,
    );

    // Spawn the visual + hit-registration projectile
    final speed = 1200.0;
    final travelTime = start.distanceTo(end) / speed;

    final lance = PiercingProjectile(
      start: start,
      end: end,
      speed: speed,
      width: width,
      damage: baseDamage,
      color: color,
      game: game,
      attacker: attacker,
      rank: rank, // still used by projectile for its own logic
    );

    game.world.add(lance);

    // After the beam has passed, apply the elemental augment along its path
    Future.delayed(Duration(milliseconds: (travelTime * 1000).round()), () {
      _applyElementalWingAugment(
        game: game,
        attacker: attacker,
        element: element,
        rank: rank,
        start: start,
        end: end,
        baseDamage: baseDamage,
        beamWidth: width,
      );
    });
  }

  // ─────────────────────────────
  //  ELEMENT ROUTER
  // ─────────────────────────────

  static void _applyElementalWingAugment({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 start,
    required Vector2 end,
    required int baseDamage,
    required double beamWidth,
  }) {
    // Approximate a “corridor” by sampling along the line
    final enemiesInCorridor = _sampleEnemiesAlongLine(
      game: game,
      start: start,
      end: end,
      radius: beamWidth / 2 + 25.0,
      samples: 6 + rank, // more samples at higher rank
    );

    if (enemiesInCorridor.isEmpty) return;

    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireWing(
          game,
          attacker,
          rank,
          start,
          end,
          beamWidth,
          enemiesInCorridor,
        );
        break;
      case 'Lava':
        _lavaWing(game, attacker, rank, start, end, enemiesInCorridor);
        break;
      case 'Blood':
        _bloodWing(game, attacker, rank, enemiesInCorridor, baseDamage);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterWing(game, attacker, rank, start, end, enemiesInCorridor);
        break;
      case 'Ice':
        _iceWing(game, attacker, rank, start, end, enemiesInCorridor);
        break;
      case 'Steam':
        _steamWing(game, attacker, rank, start, end, enemiesInCorridor);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantWing(game, attacker, rank, start, end);
        break;
      case 'Poison':
        _poisonWing(game, attacker, rank, enemiesInCorridor);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthWing(game, attacker, rank, enemiesInCorridor);
        break;
      case 'Mud':
        _mudWing(game, attacker, rank, start, end);
        break;
      case 'Crystal':
        _crystalWing(game, attacker, rank, start, end, enemiesInCorridor);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airWing(game, attacker, rank, enemiesInCorridor);
        break;
      case 'Dust':
        _dustWing(game, attacker, rank, enemiesInCorridor);
        break;
      case 'Lightning':
        _lightningWing(game, attacker, rank, enemiesInCorridor);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritWing(game, attacker, rank, start, end, enemiesInCorridor);
        break;
      case 'Dark':
        _darkWing(game, attacker, rank, enemiesInCorridor);
        break;
      case 'Light':
        _lightWing(game, attacker, rank, start, end, enemiesInCorridor);
        break;

      default:
        break;
    }
  }

  // Simple corridor sampler: sample points along the beam and union enemy sets
  static List<HoardEnemy> _sampleEnemiesAlongLine({
    required SurvivalHoardGame game,
    required Vector2 start,
    required Vector2 end,
    required double radius,
    required int samples,
  }) {
    final result = <HoardEnemy>{};
    final dir = end - start;
    for (int i = 0; i <= samples; i++) {
      final t = i / samples;
      final pos = start + dir * t;
      result.addAll(game.getEnemiesInRange(pos, radius));
    }
    return result.toList();
  }

  // ─────────────────────────────
  //  FIRE / LAVA / BLOOD
  // ─────────────────────────────

  /// Fire Wing – “Flame Line”: leaves a burning line that damages over time
  static void _fireWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
    double width,
    List<HoardEnemy> corridorEnemies,
  ) {
    final color = SurvivalAttackManager.getElementColor('Fire');
    final duration = 3.0 + 0.4 * (rank - 1);
    final dps = (attacker.unit.statIntelligence * (1.5 + 0.2 * rank))
        .toInt()
        .clamp(3, 180);

    final line = RectangleComponent(
      size: Vector2(start.distanceTo(end), width * 1.2),
      position: start,
      anchor: Anchor.centerLeft,
      paint: Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    line.angle = (end - start).angleToSigned(Vector2(1, 0));

    line.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = _sampleEnemiesAlongLine(
            game: game,
            start: start,
            end: end,
            radius: width / 2 + 20,
            samples: 8,
          );
          for (final v in victims) {
            v.takeDamage(dps);
            ImpactVisuals.play(game, v.position, 'Fire', scale: 0.4);
          }
        },
      ),
    );

    line.add(RemoveEffect(delay: duration));
    game.world.add(line);
  }

  /// Lava Wing – “Magma Impact”: explosion at the end of the beam
  static void _lavaWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
    List<HoardEnemy> corridorEnemies,
  ) {
    final radius = 110.0 + rank * 10;
    final dmg = (calcDmg(attacker, null) * (1.2 + 0.2 * rank)).toInt().clamp(
      10,
      300,
    );
    final victims = game.getEnemiesInRange(end, radius);
    for (final v in victims) {
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Lava', scale: 0.9);
    }
    ImpactVisuals.playExplosion(game, end, 'Lava', radius);
  }

  /// Blood Wing – “Hemorrhage Lance”: corridor damage → team lifesteal
  static void _bloodWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> corridorEnemies,
    int baseDamage,
  ) {
    if (corridorEnemies.isEmpty) return;
    final total = (baseDamage * corridorEnemies.length);
    final selfHeal = (total * (0.3 + 0.05 * (rank - 1))).toInt();
    final teamHeal = (total * 0.25).toInt();
    attacker.unit.heal(selfHeal);
    for (final g in game.guardians) {
      if (!g.isDead && g != attacker) {
        g.unit.heal((teamHeal / (game.guardians.length - 1)).round());
      }
    }
    ImpactVisuals.play(game, attacker.position, 'Blood', scale: 1.0);
  }

  // ─────────────────────────────
  //  WATER / ICE / STEAM
  // ─────────────────────────────

  /// Water Wing – “Riptide Beam”: heals guardians near the path, nudges enemies
  static void _waterWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
    List<HoardEnemy> corridorEnemies,
  ) {
    final healEach = (attacker.unit.statIntelligence * (1.6 + 0.2 * rank))
        .toInt()
        .clamp(4, 120);
    final guardians = game.guardians;
    for (final g in guardians) {
      if (g.isDead) continue;
      // rough check: if guardian is somewhat close to the beam line
      final near = _sampleEnemiesAlongLine(
        game: game,
        start: start,
        end: end,
        radius: 120,
        samples: 4,
      ).map((e) => e.position).any((pos) => g.position.distanceTo(pos) < 90);
      if (near) {
        g.unit.heal(healEach);
        ImpactVisuals.play(game, g.position, 'Water', scale: 0.5);
      }
    }

    // small push-back on enemies away from orb
    for (final v in corridorEnemies) {
      final pushBack = (v.targetOrb.position - v.position).normalized() * -8.0;
      v.position += pushBack;
    }
  }

  /// Ice Wing – “Frost Line”: enemies along the path are heavily slowed
  static void _iceWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
    List<HoardEnemy> corridorEnemies,
  ) {
    for (final v in corridorEnemies) {
      final pushBack = (v.targetOrb.position - v.position).normalized() * -10.0;
      v.position += pushBack;
      ImpactVisuals.play(game, v.position, 'Ice', scale: 0.5);
    }
  }

  /// Steam Wing – “Fog Beam”: creates a short-lived fog corridor that slows
  static void _steamWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
    List<HoardEnemy> corridorEnemies,
  ) {
    final color = SurvivalAttackManager.getElementColor('Steam');
    final width = 120.0 + rank * 10;
    final duration = 3.5 + 0.4 * (rank - 1);

    final fog = RectangleComponent(
      size: Vector2(start.distanceTo(end), width),
      position: start,
      anchor: Anchor.centerLeft,
      paint: Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );
    fog.angle = (end - start).angleToSigned(Vector2(1, 0));

    fog.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final victims = _sampleEnemiesAlongLine(
            game: game,
            start: start,
            end: end,
            radius: width / 2,
            samples: 6,
          );
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -7.0;
            v.position += pushBack;
          }
        },
      ),
    );

    fog.add(RemoveEffect(delay: duration));
    game.world.add(fog);
  }

  // ─────────────────────────────
  //  PLANT / POISON
  // ─────────────────────────────

  /// Plant Wing – “Vine Shot”: leaves thorn patches along the beam
  static void _plantWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
  ) {
    final segments = 3 + rank;
    final color = SurvivalAttackManager.getElementColor('Plant');
    final dps = (attacker.unit.statIntelligence * (1.6 + 0.2 * rank))
        .toInt()
        .clamp(3, 180);

    for (int i = 1; i <= segments; i++) {
      final t = i / (segments + 1);
      final pos = start + (end - start) * t;

      final zone = CircleComponent(
        radius: 60.0 + rank * 4,
        position: pos,
        anchor: Anchor.center,
        paint: Paint()
          ..color = color.withOpacity(0.25)
          ..style = PaintingStyle.fill,
      );

      zone.add(
        TimerComponent(
          period: 0.6,
          repeat: true,
          onTick: () {
            final victims = game.getEnemiesInRange(pos, zone.radius);
            for (final v in victims) {
              v.takeDamage(dps);
            }
          },
        ),
      );

      zone.add(RemoveEffect(delay: 4.0));
      game.world.add(zone);
    }
  }

  /// Poison Wing – “Toxic Ray”: applies poison DoT to corridor enemies
  static void _poisonWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> corridorEnemies,
  ) {
    for (final v in corridorEnemies) {
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

  /// Earth Wing – “Stone Lance”: extra knockback + small shield for attacker
  static void _earthWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> corridorEnemies,
  ) {
    for (final v in corridorEnemies) {
      final dir = (v.position - attacker.position).normalized();
      v.add(
        MoveEffect.by(
          dir * (60.0 + rank * 10.0),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
    }

    final shield = (attacker.unit.maxHp * (0.06 + 0.02 * (rank - 1)))
        .toInt()
        .clamp(10, 300);
    attacker.unit.heal(shield);
    ImpactVisuals.play(game, attacker.position, 'Earth', scale: 0.9);
  }

  /// Mud Wing – “Gutter Beam”: leaves a sticky slow line
  static void _mudWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
  ) {
    final color = SurvivalAttackManager.getElementColor('Mud');
    final width = 120.0;
    final duration = 4.5 + 0.4 * (rank - 1);

    final gutter = RectangleComponent(
      size: Vector2(start.distanceTo(end), width),
      position: start,
      anchor: Anchor.centerLeft,
      paint: Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );
    gutter.angle = (end - start).angleToSigned(Vector2(1, 0));

    gutter.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final victims = _sampleEnemiesAlongLine(
            game: game,
            start: start,
            end: end,
            radius: width / 2,
            samples: 6,
          );
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -10.0;
            v.position += pushBack;
          }
        },
      ),
    );

    gutter.add(RemoveEffect(delay: duration));
    game.world.add(gutter);
  }

  /// Crystal Wing – “Prism Ray”: spawns shard bolts from enemies hit
  static void _crystalWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
    List<HoardEnemy> corridorEnemies,
  ) {
    final color = SurvivalAttackManager.getElementColor('Crystal');
    final rng = Random();

    for (final src in corridorEnemies) {
      final nearby = game
          .getEnemiesInRange(src.position, 220)
          .where((e) => e != src);
      final list = nearby.toList();
      if (list.isEmpty) continue;

      final count = min(1 + rank, list.length);
      for (int i = 0; i < count; i++) {
        final target = list[rng.nextInt(list.length)];
        final dmg = (calcDmg(attacker, target) * (0.7 + 0.1 * rank))
            .toInt()
            .clamp(4, 150);

        game.spawnAlchemyProjectile(
          start: src.position,
          target: target,
          damage: dmg,
          color: color,
          shape: ProjectileShape.shard,
          speed: 2.6,
          isEnemy: false,
          onHit: () {
            target.takeDamage(dmg);
            ImpactVisuals.play(game, target.position, 'Crystal', scale: 0.6);
          },
        );
      }
    }
  }

  // ─────────────────────────────
  //  AIR / DUST / LIGHTNING
  // ─────────────────────────────

  /// Air Wing – “Gale Lance”: blows enemies away from the orb strongly
  static void _airWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> corridorEnemies,
  ) {
    for (final v in corridorEnemies) {
      final dir = (v.position - game.orb.position).normalized();
      v.add(
        MoveEffect.by(
          dir * (150.0 + 20.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }
    SurvivalAttackManager.triggerScreenShake(game, 2.0 + rank * 0.4);
  }

  /// Dust Wing – “Sandline”: confuse + jitter enemies along path
  static void _dustWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> corridorEnemies,
  ) {
    final rng = Random();
    for (final v in corridorEnemies) {
      final offset = Vector2(
        (rng.nextDouble() - 0.5) * (20 + 3 * rank),
        (rng.nextDouble() - 0.5) * (20 + 3 * rank),
      );
      v.position += offset;
    }
  }

  /// Lightning Wing – “Railstorm”: small chains from each hit enemy
  static void _lightningWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> corridorEnemies,
  ) {
    final rng = Random();
    final maxChains = 1 + rank;

    for (final src in corridorEnemies) {
      final nearby = game
          .getEnemiesInRange(src.position, 220)
          .where((e) => e != src);
      final list = nearby.toList();
      if (list.isEmpty) continue;

      final chains = min(maxChains, list.length);
      for (int i = 0; i < chains; i++) {
        final target = list[rng.nextInt(list.length)];
        final dmg = (calcDmg(attacker, target) * (0.6 + 0.1 * rank))
            .toInt()
            .clamp(4, 150);

        game.spawnAlchemyProjectile(
          start: src.position,
          target: target,
          damage: dmg,
          color: SurvivalAttackManager.getElementColor('Lightning'),
          shape: ProjectileShape.bolt,
          speed: 3.2,
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

  /// Spirit Wing – “Phantom Trace”: delayed ghost explosions along the path
  static void _spiritWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
    List<HoardEnemy> corridorEnemies,
  ) {
    final delayMs = (500 - 40 * (rank - 1)).clamp(200, 500);
    final radius = 70.0 + rank * 6;
    final dmg = (calcDmg(attacker, null) * (0.7 + 0.15 * rank)).toInt().clamp(
      5,
      180,
    );

    Future.delayed(Duration(milliseconds: delayMs), () {
      final victims = _sampleEnemiesAlongLine(
        game: game,
        start: start,
        end: end,
        radius: radius,
        samples: 6,
      );
      for (final v in victims) {
        v.takeDamage(dmg);
        ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.8);
      }
    });
  }

  /// Dark Wing – “Umbral Beam”: extra chip + self lifesteal
  static void _darkWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> corridorEnemies,
  ) {
    int total = 0;
    final dmgFactor = (0.5 + 0.1 * rank);
    for (final v in corridorEnemies) {
      final dmg = (calcDmg(attacker, v) * dmgFactor).toInt().clamp(4, 150);
      v.takeDamage(dmg);
      total += dmg;
      ImpactVisuals.play(game, v.position, 'Dark', scale: 0.7);
    }
    if (total > 0) {
      attacker.unit.heal((total * (0.3 + 0.05 * rank)).toInt());
    }
  }

  /// Light Wing – “Radiant Beam”: buffs allies near the line & scorches enemies
  static void _lightWing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 start,
    Vector2 end,
    List<HoardEnemy> corridorEnemies,
  ) {
    final guardians = game.guardians;
    final healEach = (attacker.unit.statIntelligence * (1.4 + 0.2 * rank))
        .toInt()
        .clamp(4, 140);

    for (final g in guardians) {
      if (g.isDead) continue;
      final distToLine = _distanceToSegment(g.position, start, end);
      if (distToLine <= 140) {
        g.unit.heal(healEach);
        ImpactVisuals.play(game, g.position, 'Light', scale: 0.6);
      }
    }

    for (final v in corridorEnemies) {
      final dmg = (calcDmg(attacker, v) * (0.8 + 0.1 * rank)).toInt().clamp(
        4,
        150,
      );
      v.takeDamage(dmg);
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.8);
    }
  }

  // Helper for approximate distance from point to segment (for Light buff)
  static double _distanceToSegment(Vector2 p, Vector2 a, Vector2 b) {
    final ab = b - a;
    final t = ((p - a).dot(ab) / ab.length2).clamp(0.0, 1.0);
    final proj = a + ab * t;
    return p.distanceTo(proj);
  }
}
