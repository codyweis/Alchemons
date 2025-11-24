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

class PipRicochetMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);

    // Max Level Check
    int bounces = (rank >= 5) ? (6 + rank) : (3 + rank);
    double speed = (rank >= 5) ? 5.0 : 2.5;

    double dmgMult = 1.2 + (0.1 * rank);

    _chainRecursive(
      game: game,
      source: attacker,
      currentTarget: target,
      element: element,
      bouncesLeft: bounces,
      dmgMult: dmgMult,
      hitHistory: [],
      rank: rank,
      speed: speed,
      hitIndex: 0,
    );
  }

  static void _chainRecursive({
    required SurvivalHoardGame game,
    required HoardGuardian source,
    required HoardEnemy currentTarget,
    required String element,
    required int bouncesLeft,
    required double dmgMult,
    required List<HoardEnemy> hitHistory,
    required int rank,
    required double speed,
    required int hitIndex,
  }) {
    if (bouncesLeft <= 0 || currentTarget.isDead) return;

    final dmg = (calcDmg(source, currentTarget) * dmgMult).toInt();
    final color = SurvivalAttackManager.getElementColor(element);

    final Vector2 startPos = (hitHistory.isEmpty)
        ? source.position
        : hitHistory.last.position;

    game.spawnAlchemyProjectile(
      start: startPos,
      target: currentTarget,
      damage: dmg,
      color: color,
      shape: ProjectileShape.bolt,
      speed: speed,
      isEnemy: false,
      onHit: () {
        currentTarget.takeDamage(dmg);
        ImpactVisuals.play(game, currentTarget.position, element, scale: 0.8);
        hitHistory.add(currentTarget);

        // 🔹 NEW: elemental augment on each hit (starts at rank 1)
        _applyElementalRicochetAugmentOnHit(
          game: game,
          attacker: source,
          element: element,
          rank: rank,
          hitTarget: currentTarget,
          hitIndex: hitIndex,
        );

        // Find next target
        final nextTarget = _findNearestExcluding(
          game,
          currentTarget.position,
          400, // Range
          hitHistory,
        );

        if (nextTarget != null) {
          Future.delayed(const Duration(milliseconds: 50), () {
            _chainRecursive(
              game: game,
              source: source,
              currentTarget: nextTarget,
              element: element,
              bouncesLeft: bouncesLeft - 1,
              dmgMult: dmgMult * 0.9,
              hitHistory: hitHistory,
              rank: rank,
              speed: speed,
              hitIndex: hitIndex + 1,
            );
          });
        }
      },
    );
  }

  static HoardEnemy? _findNearestExcluding(
    SurvivalHoardGame game,
    Vector2 pos,
    double range,
    List<HoardEnemy> exclude,
  ) {
    final candidates = game
        .getEnemiesInRange(pos, range)
        .where((e) => !exclude.contains(e))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => a.position
          .distanceToSquared(pos)
          .compareTo(b.position.distanceToSquared(pos)),
    );
    return candidates.first;
  }

  // ─────────────────────────────
  //  ELEMENTAL AUGMENTS PER HIT
  // ─────────────────────────────

  static void _applyElementalRicochetAugmentOnHit({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required HoardEnemy hitTarget,
    required int hitIndex,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD → aggressive, splashy, lifesteal-ish
      case 'Fire':
        _fireRicochet(game, attacker, rank, hitTarget);
        break;
      case 'Lava':
        _lavaRicochet(game, attacker, rank, hitTarget);
        break;
      case 'Blood':
        _bloodRicochet(game, attacker, rank, hitTarget);
        break;

      // 💧 WATER / ICE / STEAM → sustain & control
      case 'Water':
        _waterRicochet(game, attacker, rank, hitTarget);
        break;
      case 'Ice':
        _iceRicochet(game, attacker, rank, hitTarget);
        break;
      case 'Steam':
        _steamRicochet(game, attacker, rank, hitTarget);
        break;

      // 🌿 PLANT / POISON → DoT & hazards
      case 'Plant':
        _plantRicochet(game, attacker, rank, hitTarget, hitIndex);
        break;
      case 'Poison':
        _poisonRicochet(game, attacker, rank, hitTarget);
        break;

      // 🌍 EARTH / MUD / CRYSTAL → knockback & shard splits
      case 'Earth':
        _earthRicochet(game, attacker, rank, hitTarget);
        break;
      case 'Mud':
        _mudRicochet(game, attacker, rank, hitTarget);
        break;
      case 'Crystal':
        _crystalRicochet(game, attacker, rank, hitTarget);
        break;

      // 🌬️ AIR / DUST → disruption, wave shaping
      case 'Air':
        _airRicochet(game, attacker, rank, hitTarget);
        break;
      case 'Dust':
        _dustRicochet(game, attacker, rank, hitTarget);
        break;

      // ⚡ LIGHTNING → extra micro-chains
      case 'Lightning':
        _lightningRicochet(game, attacker, rank, hitTarget);
        break;

      // 🌗 SPIRIT / DARK / LIGHT → holy/soul twists
      case 'Spirit':
        _spiritRicochet(game, attacker, rank, hitTarget);
        break;
      case 'Dark':
        _darkRicochet(game, attacker, rank, hitTarget);
        break;
      case 'Light':
        _lightRicochet(game, attacker, rank, hitTarget);
        break;
      default:
        break;
    }
  }

  // ─────────────────────────────
  //  ELEMENT-SPECIFIC HELPERS
  // ─────────────────────────────

  // FIRE – small splash around each hit
  static void _fireRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final radius = 60.0 + rank * 6;
    final dmg = (calcDmg(attacker, target) * (0.4 + 0.1 * rank)).toInt().clamp(
      3,
      120,
    );
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      if (e == target) continue;
      e.takeDamage(dmg);
      ImpactVisuals.play(game, e.position, 'Fire', scale: 0.5);
    }
  }

  // LAVA – mini ground crack that damages over a short time
  static void _lavaRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final radius = 50.0 + rank * 5;
    final duration = 2.5 + rank * 0.3;
    final dps = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 80);

    final zone = CircleComponent(
      radius: radius,
      position: target.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor('Lava').withOpacity(0.3)
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
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // BLOOD – lifesteal per hit (team vamp)
  static void _bloodRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final stealBase = (calcDmg(attacker, target) * (0.2 + 0.05 * rank))
        .toInt()
        .clamp(2, 120);

    final stealForOrb = (stealBase * 0.3).toInt();
    final stealForTeam = (stealBase * 0.7).toInt();

    game.orb.heal(stealForOrb);
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal((stealForTeam / game.guardians.length).round());
      }
    }
    ImpactVisuals.play(game, target.position, 'Blood', scale: 0.8);
  }

  // WATER – small orb heal & push enemies slightly away from orb
  static void _waterRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final heal = (attacker.unit.statIntelligence * (1.5 + 0.2 * rank))
        .toInt()
        .clamp(3, 80);
    game.orb.heal(heal);

    final radius = 70.0 + rank * 5;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final dir = (v.position - game.orb.position).normalized();
      v.position += dir * (20 + rank * 4);
    }
    ImpactVisuals.play(game, target.position, 'Water', scale: 0.7);
  }

  // ICE – heavy slow by nudging them back toward their previous spot
  static void _iceRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final radius = 70.0 + rank * 5;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final pushBack =
          (v.targetOrb.position - v.position).normalized() *
          -6 *
          (1 + 0.3 * rank);
      v.position += pushBack;
      ImpactVisuals.play(game, v.position, 'Ice', scale: 0.4);
    }
  }

  // STEAM – fog: mild slow + tiny orb regen if multiple hit
  static void _steamRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final radius = 70.0 + rank * 6;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final pushBack =
          (v.targetOrb.position - v.position).normalized() *
          -4 *
          (1 + 0.2 * rank);
      v.position += pushBack;
    }
    if (victims.length >= 2) {
      game.orb.heal(2 + rank); // small sustain
    }
  }

  // PLANT – drops tiny thorn patches on early bounces
  static void _plantRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
    int hitIndex,
  ) {
    // only create a few patches, e.g., first 2–3 hits
    if (hitIndex > 2) return;

    final radius = 55.0 + rank * 5;
    final duration = 3.0 + rank * 0.4;
    final dps = (attacker.unit.statIntelligence * (1.2 + 0.2 * rank))
        .toInt()
        .clamp(2, 70);

    final zone = CircleComponent(
      radius: radius,
      position: target.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor(
          'Plant',
        ).withOpacity(0.25)
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

  // POISON – poison DoT on hit target
  static void _poisonRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final dot = SurvivalStatusEffect(
      type: 'Poison',
      damagePerTick:
          (attacker.unit.statIntelligence * (0.7 + 0.1 * rank)).toInt() + 2,
      ticksRemaining: 6 + rank,
      tickInterval: 0.5,
    );
    target.unit.applyStatusEffect(dot);
    ImpactVisuals.play(game, target.position, 'Poison', scale: 0.5);
  }

  // EARTH – knock enemies slightly back & small “armor” heal on the guardian
  static void _earthRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final radius = 65.0 + rank * 5;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final dir = (v.position - target.position).normalized();
      v.position += dir * (25 + rank * 4);
    }

    final shield = (attacker.unit.maxHp * (0.02 + 0.01 * rank)).toInt();
    attacker.unit.heal(shield);
    ImpactVisuals.play(game, attacker.position, 'Earth', scale: 0.7);
  }

  // MUD – sticky slow zone on hit
  static void _mudRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final radius = 60.0 + rank * 5;
    final duration = 3.5 + rank * 0.4;

    final zone = CircleComponent(
      radius: radius,
      position: target.position.clone(),
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
          final victims = game.getEnemiesInRange(zone.position, radius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() * -8;
            v.position += pushBack;
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  // CRYSTAL – mini split shot to another nearby enemy
  static void _crystalRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final nearby = game
        .getEnemiesInRange(target.position, 200)
        .where((e) => e != target);
    final candidates = nearby.toList();
    if (candidates.isEmpty) return;

    final other = candidates[Random().nextInt(candidates.length)];
    final dmg = (calcDmg(attacker, other) * (0.8 + 0.1 * rank)).toInt().clamp(
      3,
      120,
    );

    game.spawnAlchemyProjectile(
      start: target.position,
      target: other,
      damage: dmg,
      color: SurvivalAttackManager.getElementColor('Crystal'),
      shape: ProjectileShape.shard,
      speed: 2.4,
      isEnemy: false,
      onHit: () {
        other.takeDamage(dmg);
        ImpactVisuals.play(game, other.position, 'Crystal', scale: 0.6);
      },
    );
  }

  // AIR – pushes enemies along the chain direction (wave shaping)
  static void _airRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final radius = 75.0 + rank * 5;
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final dir = (v.position - game.orb.position).normalized();
      v.add(
        MoveEffect.by(
          dir * (40 + rank * 6),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
    }
    ImpactVisuals.play(game, target.position, 'Air', scale: 0.8);
  }

  // DUST – jitter/confuse hit pack
  static void _dustRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final radius = 70.0 + rank * 5;
    final rng = Random();
    final victims = game.getEnemiesInRange(target.position, radius);
    for (final v in victims) {
      final offset = Vector2(
        (rng.nextDouble() - 0.5) * (10 + rank * 2),
        (rng.nextDouble() - 0.5) * (10 + rank * 2),
      );
      v.position += offset;
    }
  }

  // LIGHTNING – extra micro-chains from hit target
  static void _lightningRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final rng = Random();
    final nearby = game
        .getEnemiesInRange(target.position, 220)
        .where((e) => e != target);
    final candidates = nearby.toList();
    if (candidates.isEmpty) return;

    final chains = min(1 + rank, candidates.length);
    for (int i = 0; i < chains; i++) {
      final next = candidates[rng.nextInt(candidates.length)];
      final dmg = (calcDmg(attacker, next) * (0.7 + 0.1 * rank)).toInt().clamp(
        3,
        120,
      );

      game.spawnAlchemyProjectile(
        start: target.position,
        target: next,
        damage: dmg,
        color: SurvivalAttackManager.getElementColor('Lightning'),
        shape: ProjectileShape.bolt,
        speed: 3.0,
        isEnemy: false,
        onHit: () {
          next.takeDamage(dmg);
          ImpactVisuals.play(game, next.position, 'Lightning', scale: 0.7);
        },
      );
    }
  }

  // SPIRIT – ghost mark: small delayed blast around the hit target
  static void _spiritRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final delayMs = 500 - (rank * 40).clamp(0, 250);
    final radius = 60.0 + rank * 6;
    final dmg = (calcDmg(attacker, target) * (0.6 + 0.1 * rank)).toInt().clamp(
      3,
      100,
    );

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (target.isDead) return;
      final victims = game.getEnemiesInRange(target.position, radius);
      for (final v in victims) {
        v.takeDamage(dmg);
        ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.6);
      }
    });
  }

  // DARK – chip + tiny lifesteal to attacker
  static void _darkRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final extra = (calcDmg(attacker, target) * (0.4 + 0.1 * rank))
        .toInt()
        .clamp(3, 120);
    target.takeDamage(extra);
    final heal = (extra * (0.3 + 0.05 * rank)).toInt();
    attacker.unit.heal(heal);
    ImpactVisuals.play(game, target.position, 'Dark', scale: 0.7);
  }

  // LIGHT – small team sustain on hit
  static void _lightRicochet(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    HoardEnemy target,
  ) {
    final healEach = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 60);

    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healEach);
        ImpactVisuals.play(game, g.position, 'Light', scale: 0.4);
      }
    }
  }
}
