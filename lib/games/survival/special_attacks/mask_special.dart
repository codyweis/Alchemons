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

/// MASK FAMILY - TRAP FIELD MECHANIC (3-RANK VERSION)
///
/// Rank 0: no special
/// Rank 1: basic traps in a spread
/// Rank 2: stronger traps (more / bigger / longer)
/// Rank 3+: “GRID” ultimate – dense field of traps
class MaskTrapMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final rawRank = game.getSpecialAbilityRank(attacker.unit.id, element);

    // No upgrades yet → no special
    if (rawRank <= 0) {
      return;
    }

    // Clamp to our new 3-rank system (3+ all behave as max)
    final rank = rawRank.clamp(1, 3);
    final color = SurvivalAttackManager.getElementColor(element);

    // Base trap parameters scale modestly with rank
    final baseTrapCount = 1 + rank; // 2, 3, 4
    final baseTrapRadius = 55.0 + rank * 10; // grows with rank
    final baseTrapDuration = 6.0 + rank * 1.5;

    // Rank 3 → GRID “massive update”
    final isGrid = rank >= 3;
    final trapCount = isGrid ? baseTrapCount * 2 : baseTrapCount;
    final trapRadius = isGrid ? baseTrapRadius * 1.2 : baseTrapRadius;
    final trapDuration = isGrid ? baseTrapDuration * 1.25 : baseTrapDuration;

    // Pick deployment center:
    //  - Prefer current target
    //  - Otherwise drop a bit in front of the caster
    final Vector2 deployPos;
    if (target != null && !target.isDead) {
      deployPos = target.position.clone();
    } else {
      deployPos = attacker.position + Vector2(180, 0);
    }

    if (isGrid) {
      // Rank 3+: grid of traps (ultimate)
      _deployTrapGrid(
        game: game,
        attacker: attacker,
        element: element,
        rank: rank,
        center: deployPos,
        count: trapCount,
        radius: trapRadius,
        duration: trapDuration,
        color: color,
      );
    } else {
      // Rank 1–2: ring/spread of traps
      _deployTrapSpread(
        game: game,
        attacker: attacker,
        element: element,
        rank: rank,
        center: deployPos,
        count: trapCount,
        radius: trapRadius,
        duration: trapDuration,
        color: color,
      );
    }
  }

  static void _deployTrapSpread({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 center,
    required int count,
    required double radius,
    required double duration,
    required Color color,
  }) {
    final double spreadDistance = 120 + rank * 20;

    for (int i = 0; i < count; i++) {
      final angle = (2 * pi * i) / count;
      final offset = Vector2(cos(angle), sin(angle)) * spreadDistance;
      final trapPos = center + offset;

      _createTrap(
        game: game,
        attacker: attacker,
        element: element,
        rank: rank,
        position: trapPos,
        radius: radius,
        duration: duration,
        color: color,
      );
    }
  }

  static void _deployTrapGrid({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 center,
    required int count,
    required double radius,
    required double duration,
    required Color color,
  }) {
    final gridSize = sqrt(count).ceil();
    final spacing = 140.0;
    final offset = (gridSize - 1) * spacing / 2;

    int placed = 0;
    for (int x = 0; x < gridSize && placed < count; x++) {
      for (int y = 0; y < gridSize && placed < count; y++) {
        final trapPos =
            center + Vector2(x * spacing - offset, y * spacing - offset);

        _createTrap(
          game: game,
          attacker: attacker,
          element: element,
          rank: rank,
          position: trapPos,
          radius: radius,
          duration: duration,
          color: color,
        );
        placed++;
      }
    }
  }

  static void _createTrap({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 position,
    required double radius,
    required double duration,
    required Color color,
  }) {
    final trap = CircleComponent(
      radius: radius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    // Visual ring
    trap.add(
      CircleComponent(
        radius: radius,
        anchor: Anchor.center,
        position: Vector2(radius, radius),
        paint: Paint()
          ..color = color.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      ),
    );

    bool hasTriggered = false;

    // Check for enemy contact
    trap.add(
      TimerComponent(
        period: 0.1,
        repeat: true,
        onTick: () {
          if (hasTriggered) return;

          final victims = game.getEnemiesInRange(position, radius);
          if (victims.isNotEmpty) {
            hasTriggered = true;
            _triggerTrap(
              game: game,
              attacker: attacker,
              element: element,
              rank: rank,
              position: position,
              radius: radius,
              victims: victims,
            );
            trap.removeFromParent();
          }
        },
      ),
    );

    // Fade and remove after duration
    trap.add(
      SequenceEffect([
        OpacityEffect.to(0.2, EffectController(duration: duration * 0.7)),
        OpacityEffect.fadeOut(EffectController(duration: duration * 0.3)),
        RemoveEffect(),
      ]),
    );

    game.world.add(trap);
  }

  static void _triggerTrap({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 position,
    required double radius,
    required List<HoardEnemy> victims,
  }) {
    // Base damage scales with rank (1–3)
    final baseDmg = (calcDmg(attacker, null) * (1 + 0.25 * rank)).toInt();

    for (final v in victims) {
      v.takeDamage(baseDmg);
      ImpactVisuals.play(game, v.position, element, scale: 0.9);
    }

    // Apply elemental effect
    _applyElementalTrap(
      game: game,
      attacker: attacker,
      element: element,
      rank: rank,
      position: position,
      radius: radius,
      victims: victims,
      baseDamage: baseDmg,
    );

    // Visual explosion
    ImpactVisuals.playExplosion(game, position, element, radius);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ELEMENT ROUTER
  // ═══════════════════════════════════════════════════════════════════════

  static void _applyElementalTrap({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required Vector2 position,
    required double radius,
    required List<HoardEnemy> victims,
    required int baseDamage,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Lava':
        _lavaTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Blood':
        _bloodTrap(game, attacker, rank, position, victims, baseDamage);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Ice':
        _iceTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Steam':
        _steamTrap(game, attacker, rank, position, radius, victims);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Poison':
        _poisonTrap(game, attacker, rank, position, victims);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Mud':
        _mudTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Crystal':
        _crystalTrap(game, attacker, rank, position, victims, baseDamage);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Dust':
        _dustTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Lightning':
        _lightningTrap(game, attacker, rank, position, victims, baseDamage);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritTrap(
          game,
          attacker,
          rank,
          position,
          radius,
          victims,
          baseDamage,
        );
        break;
      case 'Dark':
        _darkTrap(game, attacker, rank, position, radius, victims);
        break;
      case 'Light':
        _lightTrap(game, attacker, rank, position, radius);
        break;

      default:
        break;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  //  FIRE / LAVA / BLOOD
  // ────────────────────────────────────────────────────────────────────────

  /// Fire Trap - Ignites and leaves burning zone
  static void _fireTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final burnDmg = (attacker.unit.statIntelligence * (1.5 + 0.3 * rank))
        .toInt()
        .clamp(3, 100);

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Burn',
          damagePerTick: burnDmg,
          ticksRemaining: 5 + rank,
          tickInterval: 0.5,
        ),
      );
    }

    // Leave fire zone
    final fireZone = CircleComponent(
      radius: radius * 0.8,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.deepOrange.withOpacity(0.25),
    );

    fireZone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final zoneVictims = game.getEnemiesInRange(position, radius * 0.8);
          for (final v in zoneVictims) {
            v.takeDamage((burnDmg * 0.5).toInt());
          }
        },
      ),
    );

    fireZone.add(RemoveEffect(delay: 3.0 + rank * 0.4));
    game.world.add(fireZone);
  }

  /// Lava Trap - Knockback explosion with lava pool
  static void _lavaTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    for (final v in victims) {
      final dir = (v.position - position).normalized();
      v.add(
        MoveEffect.by(
          dir * (60.0 + 12.0 * rank),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
    }

    // Lava pool
    final pool = CircleComponent(
      radius: radius * 0.7,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.orange.shade800.withOpacity(0.35),
    );

    pool.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final poolVictims = game.getEnemiesInRange(position, radius * 0.7);
          for (final v in poolVictims) {
            v.takeDamage(
              (attacker.unit.statIntelligence * (1.2 + 0.2 * rank))
                  .toInt()
                  .clamp(3, 80),
            );
          }
        },
      ),
    );

    pool.add(RemoveEffect(delay: 2.5 + rank * 0.3));
    game.world.add(pool);
  }

  /// Blood Trap - Drains enemies and heals team
  static void _bloodTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    List<HoardEnemy> victims,
    int baseDamage,
  ) {
    int totalDrain = 0;

    for (final v in victims) {
      final drain = (baseDamage * (0.3 + 0.06 * rank)).toInt();
      v.takeDamage(drain);
      totalDrain += drain;
    }

    // Heal team
    final healPerAlly = (totalDrain * 0.4 / max(1, game.guardians.length))
        .toInt();
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healPerAlly);
      }
    }

    // Heal orb
    game.orb.heal((totalDrain * 0.2).toInt());
  }

  // ────────────────────────────────────────────────────────────────────────
  //  WATER / ICE / STEAM
  // ────────────────────────────────────────────────────────────────────────

  /// Water Trap - Persistent geyser that periodically erupts
  /// Rank 1: Geyser erupts every few seconds, launching enemies and healing allies
  /// Rank 2: Faster eruptions with stronger knockup and more healing
  /// Rank 3: FOUNTAIN GRID - Field of geysers juggling enemies and pulsing heavy heals
  static void _waterTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final isGrid = rank >= 3;

    // Geyser parameters
    final geyserRadius = isGrid ? radius * 1.2 : radius;
    final geyserDuration = 5.0 + rank * 1.0; // 6s, 7s, 8s
    final eruptInterval = 1.8 - rank * 0.3; // 1.5s, 1.2s, 0.9s
    final launchStrength = 70.0 + rank * 20.0;
    final healAmount = (attacker.unit.statIntelligence * (1.5 + 0.4 * rank))
        .toInt()
        .clamp(5, 80);

    // Visual: Water pool base
    final geyserPool = CircleComponent(
      radius: geyserRadius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.blue.shade300.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    // Inner ripple ring
    final rippleRing = CircleComponent(
      radius: geyserRadius * 0.5,
      position: Vector2(geyserRadius, geyserRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.cyan.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    geyserPool.add(rippleRing);

    // Ripple animation (pulsing outward)
    rippleRing.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.8),
          EffectController(
            duration: eruptInterval * 0.8,
            curve: Curves.easeOut,
          ),
        ),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.1)),
      ], infinite: true),
    );

    // Ripple opacity (fades as it expands)
    rippleRing.add(
      SequenceEffect([
        OpacityEffect.to(0.1, EffectController(duration: eruptInterval * 0.8)),
        OpacityEffect.to(0.4, EffectController(duration: 0.1)),
      ], infinite: true),
    );

    // Track eruption count for visual variety
    int eruptionCount = 0;

    // Main geyser eruption timer
    geyserPool.add(
      TimerComponent(
        period: eruptInterval,
        repeat: true,
        onTick: () {
          eruptionCount++;

          // Get all enemies in range
          final zoneVictims = game.getEnemiesInRange(position, geyserRadius);

          // Launch enemies upward (knockback away from center + brief stun)
          for (final v in zoneVictims) {
            final dir = (v.position - position);
            final distance = dir.length;

            // Normalize direction, default to random if at center
            final launchDir = distance > 5
                ? dir.normalized()
                : Vector2(
                    (eruptionCount % 2 == 0 ? 1 : -1).toDouble(),
                    -1,
                  ).normalized();

            // Stronger launch near center
            final distanceMult =
                1.0 - (distance / geyserRadius).clamp(0.0, 1.0) * 0.5;

            v.add(
              MoveEffect.by(
                launchDir * launchStrength * distanceMult,
                EffectController(duration: 0.3, curve: Curves.easeOut),
              ),
            );

            // Brief stun (can't move during launch)
            v.add(
              MoveEffect.by(Vector2.zero(), EffectController(duration: 0.35)),
            );
          }

          // Heal allies in range
          final allies = game.getGuardiansInRange(
            center: position,
            range: geyserRadius * 1.2,
          );
          for (final g in allies) {
            g.unit.heal(healAmount);
            ImpactVisuals.playHeal(game, g.position, scale: 0.5);
          }

          // Heal orb if in range
          if (game.orb.position.distanceTo(position) <= geyserRadius * 1.5) {
            game.orb.heal((healAmount * 0.5).toInt());
          }

          // Eruption visual
          ImpactVisuals.play(game, position, 'Water', scale: 1.0);

          // Rank 3: Secondary splash damage
          if (isGrid) {
            final splashDmg = (attacker.unit.statIntelligence * 0.5)
                .toInt()
                .clamp(3, 50);
            for (final v in zoneVictims) {
              v.takeDamage(splashDmg);
            }
          }
        },
      ),
    );

    // Ambient bubble effect between eruptions
    geyserPool.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          // Small visual bubbles
          if (Random().nextDouble() < 0.5) {
            ImpactVisuals.play(
              game,
              position +
                  Vector2(
                    (Random().nextDouble() - 0.5) * geyserRadius,
                    (Random().nextDouble() - 0.5) * geyserRadius,
                  ),
              'Water',
              scale: 0.3,
            );
          }
        },
      ),
    );

    // Fade and remove
    geyserPool.add(
      SequenceEffect([
        OpacityEffect.to(1.0, EffectController(duration: geyserDuration * 0.8)),
        OpacityEffect.fadeOut(EffectController(duration: geyserDuration * 0.2)),
        RemoveEffect(),
      ]),
    );

    game.world.add(geyserPool);

    // Initial eruption on placement
    for (final v in victims) {
      final dir = (v.position - position).normalized();
      v.add(
        MoveEffect.by(
          dir * (50.0 + 10.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }

    // Initial ally heal
    final allies = game.getGuardiansInRange(center: position, range: radius);
    for (final g in allies) {
      g.unit.heal(healAmount);
      ImpactVisuals.playHeal(game, g.position, scale: 0.6);
    }
  }

  /// Ice Trap - Freezes and creates ice walls
  static void _iceTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final freezeDuration = 1.0 + rank * 0.3;

    for (final v in victims) {
      v.add(
        MoveEffect.by(
          Vector2.zero(),
          EffectController(duration: freezeDuration),
        ),
      );
    }

    // Slow zone after freeze
    final slowZone = CircleComponent(
      radius: radius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.cyanAccent.withOpacity(0.2),
    );

    slowZone.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final zoneVictims = game.getEnemiesInRange(position, radius);
          for (final v in zoneVictims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -(12.0 + rank * 2);
            v.position += pushBack;
          }
        },
      ),
    );

    slowZone.add(RemoveEffect(delay: 3.0 + rank * 0.5));
    game.world.add(slowZone);
  }

  /// Steam Trap - Pressure explosion with confusion
  static void _steamTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();

    for (final v in victims) {
      final randomDir = Vector2(
        (rng.nextDouble() - 0.5) * 2,
        (rng.nextDouble() - 0.5) * 2,
      ).normalized();

      v.add(
        MoveEffect.by(
          randomDir * (30.0 + 6.0 * rank),
          EffectController(duration: 0.2),
        ),
      );
    }

    // Heal allies who pass through steam
    final allies = game.getGuardiansInRange(center: position, range: radius);
    for (final g in allies) {
      g.unit.heal(
        (attacker.unit.statIntelligence * (1.0 + 0.2 * rank)).toInt().clamp(
          3,
          60,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  //  PLANT / POISON
  // ────────────────────────────────────────────────────────────────────────

  /// Plant Trap - Roots enemies and creates thorn zone
  static void _plantTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final thornDmg = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 70);

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Thorns',
          damagePerTick: thornDmg,
          ticksRemaining: 6 + rank,
          tickInterval: 0.4,
        ),
      );
    }

    // Root zone
    final rootZone = CircleComponent(
      radius: radius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green.withOpacity(0.25),
    );

    rootZone.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final zoneVictims = game.getEnemiesInRange(position, radius);
          for (final v in zoneVictims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -(10.0 + rank * 2);
            v.position += pushBack;
          }
        },
      ),
    );

    rootZone.add(RemoveEffect(delay: 3.0 + rank * 0.5));
    game.world.add(rootZone);
  }

  /// Poison Trap - Releases spreading poison cloud
  static void _poisonTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    List<HoardEnemy> victims,
  ) {
    final poisonDmg = (attacker.unit.statIntelligence * (1.2 + 0.25 * rank))
        .toInt()
        .clamp(3, 90);

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick: poisonDmg,
          ticksRemaining: 8 + rank,
          tickInterval: 0.4,
        ),
      );
    }

    // Spreading poison cloud
    if (rank >= 2) {
      for (final v in victims) {
        final nearby = game
            .getEnemiesInRange(v.position, 100)
            .where((e) => !victims.contains(e));
        for (final n in nearby) {
          n.unit.applyStatusEffect(
            SurvivalStatusEffect(
              type: 'Poison',
              damagePerTick: (poisonDmg * 0.6).toInt(),
              ticksRemaining: 5,
              tickInterval: 0.5,
            ),
          );
        }
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  //  EARTH / MUD / CRYSTAL
  // ────────────────────────────────────────────────────────────────────────

  /// Earth Trap - Creates spike pillars and barriers
  static void _earthTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    for (final v in victims) {
      // Brief stun
      v.add(
        MoveEffect.by(
          Vector2.zero(),
          EffectController(duration: 0.5 + rank * 0.1),
        ),
      );
    }

    // Grant shield to nearby allies
    final allies = game.getGuardiansInRange(
      center: position,
      range: radius * 1.2,
    );
    final shieldAmount = (attacker.unit.maxHp * (0.08 + 0.02 * rank))
        .toInt()
        .clamp(20, 300);
    for (final g in allies) {
      g.unit.shieldHp = (g.unit.shieldHp ?? 0) + shieldAmount;
    }
  }

  /// Mud Trap - Slowing quicksand pit
  static void _mudTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final mudZone = CircleComponent(
      radius: radius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.brown.shade600.withOpacity(0.35),
    );

    mudZone.add(
      TimerComponent(
        period: 0.2,
        repeat: true,
        onTick: () {
          final zoneVictims = game.getEnemiesInRange(position, radius);
          for (final v in zoneVictims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -(20.0 + rank * 4);
            v.position += pushBack;
          }
        },
      ),
    );

    mudZone.add(RemoveEffect(delay: 4.0 + rank * 0.6));
    game.world.add(mudZone);
  }

  /// Crystal Trap - Shoots homing shards at enemies
  static void _crystalTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    List<HoardEnemy> victims,
    int baseDamage,
  ) {
    final shardCount = 4 + rank * 2;
    final shardDmg = (baseDamage * (0.5 + 0.1 * rank)).toInt();

    final rng = Random();
    final allEnemies = game.getEnemiesInRange(position, 400);

    for (int i = 0; i < min(shardCount, allEnemies.length); i++) {
      final target = allEnemies[rng.nextInt(allEnemies.length)];

      Future.delayed(Duration(milliseconds: i * 60), () {
        if (target.isDead) return;

        game.spawnAlchemyProjectile(
          start: position,
          target: target,
          damage: shardDmg,
          color: Colors.tealAccent,
          shape: ProjectileShape.shard,
          speed: 3.0,
          isEnemy: false,
          onHit: () {
            target.takeDamage(shardDmg);
            ImpactVisuals.play(game, target.position, 'Crystal', scale: 0.5);
          },
        );
      });
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  //  AIR / DUST / LIGHTNING
  // ────────────────────────────────────────────────────────────────────────

  // ════════════════════════════════════════════════════════════════════════════
  // AIR TRAP - Persistent Tornado
  // ════════════════════════════════════════════════════════════════════════════

  /// Air Trap - Creates a persistent tornado that pushes enemies away
  /// Rank 1: Basic tornado with knockback
  /// Rank 2: Larger tornado with stronger push and damage
  /// Rank 3: HURRICANE GRID - Multiple large tornados dragging enemies into deadly storm zones
  static void _airTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final isGrid = rank >= 3;

    // Tornado parameters
    final tornadoRadius = isGrid ? radius * 1.2 : radius;
    final tornadoDuration = 4.0 + rank * 0.8; // 4.8s, 5.6s, 6.4s
    final pushStrength = 40.0 + rank * 15.0;
    final damagePerTick = (attacker.unit.statIntelligence * (0.6 + 0.15 * rank))
        .toInt()
        .clamp(3, 80);

    // Visual: Swirling tornado
    final tornado = CircleComponent(
      radius: tornadoRadius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.cyan.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    // Inner swirl ring
    final innerRing = CircleComponent(
      radius: tornadoRadius * 0.6,
      position: Vector2(tornadoRadius, tornadoRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.cyan.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    tornado.add(innerRing);

    // Outer swirl ring
    final outerRing = CircleComponent(
      radius: tornadoRadius * 0.85,
      position: Vector2(tornadoRadius, tornadoRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    tornado.add(outerRing);

    // Rotate the rings in opposite directions
    innerRing.add(
      RotateEffect.by(6.28, EffectController(duration: 1.0, infinite: true)),
    );
    outerRing.add(
      RotateEffect.by(-6.28, EffectController(duration: 1.5, infinite: true)),
    );

    // Main tornado tick - pushes enemies outward and deals damage
    tornado.add(
      TimerComponent(
        period: 0.2,
        repeat: true,
        onTick: () {
          final zoneVictims = game.getEnemiesInRange(position, tornadoRadius);

          for (final v in zoneVictims) {
            // Push away from center
            final fromCenter = v.position - position;
            final distance = fromCenter.length;

            if (distance > 5) {
              final pushDir = fromCenter.normalized();
              // Stronger push near center (to expel enemies)
              final pushMult =
                  1.0 - (distance / tornadoRadius).clamp(0.0, 1.0) * 0.5;
              v.position += pushDir * pushStrength * pushMult * 0.2;
            }

            // Damage
            v.takeDamage(damagePerTick);

            // Rank 3: Also apply a spinning motion (perpendicular push)
            if (isGrid && distance > 10) {
              final perpDir = Vector2(-fromCenter.y, fromCenter.x).normalized();
              v.position += perpDir * 15.0 * 0.2;
            }
          }
        },
      ),
    );

    // Periodic whoosh visual
    tornado.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          ImpactVisuals.play(game, position, 'Air', scale: 0.7);
        },
      ),
    );

    // Fade and remove
    tornado.add(
      SequenceEffect([
        OpacityEffect.to(
          1.0,
          EffectController(duration: tornadoDuration * 0.75),
        ),
        OpacityEffect.fadeOut(
          EffectController(duration: tornadoDuration * 0.25),
        ),
        RemoveEffect(),
      ]),
    );

    game.world.add(tornado);

    // Initial burst knockback
    for (final v in victims) {
      final dir = (v.position - position).normalized();
      v.add(
        MoveEffect.by(
          dir * (60.0 + 15.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DUST TRAP - Persistent Blinding Cloud
  // ════════════════════════════════════════════════════════════════════════════

  /// Dust Trap - Creates a persistent dust cloud that blinds and confuses enemies
  /// Rank 1: Basic dust cloud with confusion
  /// Rank 2: Larger cloud with damage over time
  /// Rank 3: SANDSTORM GRID - Large areas covered in debilitating sandstorms
  static void _dustTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();
    final isGrid = rank >= 3;

    // Dust cloud parameters
    final cloudRadius = isGrid ? radius * 1.3 : radius;
    final cloudDuration = 4.0 + rank * 0.8; // 4.8s, 5.6s, 6.4s
    final jitterStrength = 25.0 + rank * 8.0;
    final damagePerTick = (attacker.unit.statIntelligence * (0.4 + 0.1 * rank))
        .toInt()
        .clamp(2, 50);

    // Visual: Dusty cloud
    final dustCloud = CircleComponent(
      radius: cloudRadius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.amber.shade300.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );

    // Swirling dust particles (inner ring)
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

    // Rotate for swirling effect
    dustRing.add(
      RotateEffect.by(6.28, EffectController(duration: 2.0, infinite: true)),
    );

    // Pulsing size effect
    dustCloud.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.1),
          EffectController(duration: 0.8, curve: Curves.easeInOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.8, curve: Curves.easeInOut),
        ),
      ], infinite: true),
    );

    // Main confusion tick - jitters enemies and deals damage
    dustCloud.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final zoneVictims = game.getEnemiesInRange(position, cloudRadius);

          for (final v in zoneVictims) {
            // Random jitter (confusion)
            final jitter = Vector2(
              (rng.nextDouble() - 0.5) * jitterStrength,
              (rng.nextDouble() - 0.5) * jitterStrength,
            );
            v.position += jitter;

            // Damage over time (rank 2+)
            if (rank >= 2) {
              v.takeDamage(damagePerTick);
            }

            // Rank 3: Occasionally heavy disorientation burst
            if (isGrid && rng.nextDouble() < 0.15) {
              final bigJitter = Vector2(
                (rng.nextDouble() - 0.5) * jitterStrength * 2,
                (rng.nextDouble() - 0.5) * jitterStrength * 2,
              );
              v.position += bigJitter;
            }
          }
        },
      ),
    );

    // Periodic dust puff visual
    dustCloud.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          ImpactVisuals.play(game, position, 'Dust', scale: 0.5);
        },
      ),
    );

    // Fade and remove
    dustCloud.add(
      SequenceEffect([
        OpacityEffect.to(1.0, EffectController(duration: cloudDuration * 0.7)),
        OpacityEffect.fadeOut(EffectController(duration: cloudDuration * 0.3)),
        RemoveEffect(),
      ]),
    );

    game.world.add(dustCloud);

    // Initial burst confusion
    for (final v in victims) {
      final jitter = Vector2(
        (rng.nextDouble() - 0.5) * (50 + 10 * rank),
        (rng.nextDouble() - 0.5) * (50 + 10 * rank),
      );
      v.position += jitter;
    }
  }

  /// Lightning Trap - Electric fence with chains
  static void _lightningTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    List<HoardEnemy> victims,
    int baseDamage,
  ) {
    final chainDmg = (baseDamage * (0.6 + 0.1 * rank)).toInt();

    for (final v in victims) {
      // Stun
      v.add(
        MoveEffect.by(
          Vector2.zero(),
          EffectController(duration: 0.4 + rank * 0.1),
        ),
      );

      // Chain to nearby
      final nearby = game
          .getEnemiesInRange(v.position, 150)
          .where((e) => e != v)
          .take(2);

      for (final n in nearby) {
        game.spawnAlchemyProjectile(
          start: v.position,
          target: n,
          damage: chainDmg,
          color: Colors.yellow,
          shape: ProjectileShape.bolt,
          speed: 4.0,
          isEnemy: false,
          onHit: () {
            n.takeDamage(chainDmg);
            ImpactVisuals.play(game, n.position, 'Lightning', scale: 0.6);
          },
        );
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  //  SPIRIT / DARK / LIGHT
  // ────────────────────────────────────────────────────────────────────────

  // ════════════════════════════════════════════════════════════════════════════
  // SPIRIT TRAP - Summons Attacking Ghost Orbitals
  // ════════════════════════════════════════════════════════════════════════════

  /// Spirit Trap - Summons ghost spirits that attack nearby enemies
  /// Rank 1: Summons 2 spirits that seek and damage enemies
  /// Rank 2: More spirits with longer duration and lifesteal
  /// Rank 3: HAUNTED GRID - Maintains a spirit army that harasses enemies
  static void _spiritTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
    int baseDamage,
  ) {
    final isGrid = rank >= 3;

    // Spirit parameters
    final spiritCount = isGrid ? 4 + rank : 2 + rank; // 3, 4, 7+
    final spiritDuration = 4.0 + rank * 1.0; // 5s, 6s, 7s
    final spiritDamage = (baseDamage * (0.3 + 0.08 * rank)).toInt().clamp(
      5,
      100,
    );
    final attackInterval = 0.8 - rank * 0.1; // 0.7s, 0.6s, 0.5s

    // Create the spirit spawner zone (visual anchor)
    final spiritZone = CircleComponent(
      radius: radius * 0.5,
      position: position,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.deepPurple.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    // Ghostly ring effect
    final ghostRing = CircleComponent(
      radius: radius * 0.4,
      position: Vector2(radius * 0.5, radius * 0.5),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.purple.shade200.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    spiritZone.add(ghostRing);

    ghostRing.add(
      RotateEffect.by(-6.28, EffectController(duration: 3.0, infinite: true)),
    );

    // Spawn spirits around the trap
    for (int i = 0; i < spiritCount; i++) {
      final angle = (i / spiritCount) * 2 * pi;
      final spiritOffset = Vector2(cos(angle), sin(angle)) * (radius * 0.6);
      final spiritPos = position + spiritOffset;

      // Delay each spirit spawn slightly
      Future.delayed(Duration(milliseconds: i * 150), () {
        _spawnGhostSpirit(
          game: game,
          attacker: attacker,
          homePosition: position,
          startPosition: spiritPos,
          damage: spiritDamage,
          duration: spiritDuration,
          attackInterval: attackInterval,
          searchRadius: radius * 2.5,
          rank: rank,
          isGrid: isGrid,
        );
      });
    }

    // Fade and remove the zone visual
    spiritZone.add(
      SequenceEffect([
        OpacityEffect.to(1.0, EffectController(duration: spiritDuration * 0.7)),
        OpacityEffect.fadeOut(EffectController(duration: spiritDuration * 0.3)),
        RemoveEffect(),
      ]),
    );

    game.world.add(spiritZone);

    // Initial drain from victims
    int totalDrain = 0;
    for (final v in victims) {
      final drain = (baseDamage * 0.2).toInt();
      v.takeDamage(drain);
      totalDrain += drain;
      ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.6);
    }

    // Heal attacker from initial drain
    attacker.unit.heal((totalDrain * 0.4).toInt());
  }

  /// Helper: Spawns an individual ghost spirit that seeks and attacks enemies
  static void _spawnGhostSpirit({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required Vector2 homePosition,
    required Vector2 startPosition,
    required int damage,
    required double duration,
    required double attackInterval,
    required double searchRadius,
    required int rank,
    required bool isGrid,
  }) {
    // Create ghost visual
    final ghost = CircleComponent(
      radius: 12,
      position: startPosition,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.purple.shade200.withOpacity(0.7)
        ..style = PaintingStyle.fill,
    );

    // Inner glow
    final ghostCore = CircleComponent(
      radius: 6,
      position: Vector2(12, 12),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.fill,
    );
    ghost.add(ghostCore);

    // Bobbing animation
    ghost.add(
      SequenceEffect([
        MoveByEffect(
          Vector2(0, -8),
          EffectController(duration: 0.5, curve: Curves.easeInOut),
        ),
        MoveByEffect(
          Vector2(0, 8),
          EffectController(duration: 0.5, curve: Curves.easeInOut),
        ),
      ], infinite: true),
    );

    // Pulsing opacity
    ghost.add(
      SequenceEffect([
        OpacityEffect.to(0.5, EffectController(duration: 0.4)),
        OpacityEffect.to(0.9, EffectController(duration: 0.4)),
      ], infinite: true),
    );

    // Attack timer - seeks and damages enemies
    ghost.add(
      TimerComponent(
        period: attackInterval,
        repeat: true,
        onTick: () {
          // Find nearest enemy
          final target = game.getNearestEnemy(ghost.position, searchRadius);
          if (target == null) return;

          // Dash toward target
          final dashDir = (target.position - ghost.position).normalized();
          ghost.add(
            MoveByEffect(
              dashDir * 40,
              EffectController(duration: 0.15, curve: Curves.easeOut),
            ),
          );

          // Deal damage
          target.takeDamage(damage);
          ImpactVisuals.play(game, target.position, 'Spirit', scale: 0.5);

          // Lifesteal (rank 2+)
          if (rank >= 2) {
            final heal = (damage * 0.2).toInt();
            attacker.unit.heal(heal);
          }

          // Rank 3: Weaken enemy (slow them briefly)
          if (isGrid) {
            final pushBack =
                (target.targetOrb.position - target.position).normalized() *
                -15;
            target.position += pushBack;
          }
        },
      ),
    );

    // Drift back toward home position slowly
    ghost.add(
      TimerComponent(
        period: 1.0,
        repeat: true,
        onTick: () {
          final toHome = homePosition - ghost.position;
          if (toHome.length > 80) {
            ghost.position += toHome.normalized() * 20;
          }
        },
      ),
    );

    // Remove after duration
    ghost.add(
      SequenceEffect([
        // Stay for most of duration
        OpacityEffect.to(0.9, EffectController(duration: duration * 0.85)),
        // Fade out
        OpacityEffect.fadeOut(EffectController(duration: duration * 0.15)),
        RemoveEffect(),
      ]),
    );

    game.world.add(ghost);
  }

  /// Dark Trap - Mini black hole with execute
  /// Dark Trap - Persistent black hole that pulls and damages enemies
  /// Rank 1: Basic void zone with pull and execute
  /// Rank 2: Stronger pull, larger radius, more damage over time
  /// Rank 3: SINGULARITY GRID - Massive gravity wells that shred clustered enemies
  static void _darkTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final isGrid = rank >= 3;

    // Black hole parameters scale with rank
    final voidRadius = isGrid ? radius * 1.3 : radius;
    final voidDuration = 4.0 + rank * 1.0; // 5s, 6s, 7s
    final pullStrength = 35.0 + rank * 12.0; // How hard it pulls per tick
    final executeThreshold = 0.18 + 0.04 * rank; // 22%, 26%, 30%
    final damagePerTick = (attacker.unit.statIntelligence * (0.8 + 0.2 * rank))
        .toInt()
        .clamp(5, 100);

    // Visual: Dark swirling void
    final voidZone = CircleComponent(
      radius: voidRadius,
      position: position,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.deepPurple.shade900.withOpacity(0.5)
        ..style = PaintingStyle.fill,
    );

    // Inner core (darker center)
    final voidCore = CircleComponent(
      radius: voidRadius * 0.3,
      position: Vector2(voidRadius, voidRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.black.withOpacity(0.8)
        ..style = PaintingStyle.fill,
    );
    voidZone.add(voidCore);

    // Swirling ring effect
    final voidRing = CircleComponent(
      radius: voidRadius * 0.7,
      position: Vector2(voidRadius, voidRadius),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.purple.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    voidZone.add(voidRing);

    // Rotation animation for the ring
    voidRing.add(
      RotateEffect.by(
        6.28, // Full rotation
        EffectController(duration: 2.0, infinite: true),
      ),
    );

    // Pulsing effect on the core
    voidCore.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.3),
          EffectController(duration: 0.5, curve: Curves.easeInOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.5, curve: Curves.easeInOut),
        ),
      ], infinite: true),
    );

    // Main gravity tick - pulls enemies, damages them, and executes low HP
    voidZone.add(
      TimerComponent(
        period: 0.25,
        repeat: true,
        onTick: () {
          final zoneVictims = game.getEnemiesInRange(position, voidRadius);

          for (final v in zoneVictims) {
            // Calculate distance to center
            final toCenter = position - v.position;
            final distance = toCenter.length;

            // Pull toward center (stronger near the edge to suck them in)
            if (distance > 10) {
              final pullDir = toCenter.normalized();
              final pullMult =
                  0.5 + (distance / voidRadius).clamp(0.0, 1.0) * 0.5;
              v.position += pullDir * pullStrength * pullMult * 0.25;
            }

            // Damage over time (more damage near center)
            final centerMult =
                1.0 + (1.0 - (distance / voidRadius).clamp(0.0, 1.0)) * 0.5;
            v.takeDamage((damagePerTick * centerMult).toInt());

            // Execute check for low HP enemies (non-boss)
            if (!v.isBoss && v.unit.hpPercent < executeThreshold) {
              v.takeDamage(99999);
              ImpactVisuals.play(game, v.position, 'Dark', scale: 1.4);

              // Rank 3: Executed enemies explode, damaging nearby
              if (isGrid) {
                final nearby = game
                    .getEnemiesInRange(v.position, 80)
                    .where((e) => e != v);
                for (final n in nearby) {
                  n.takeDamage((damagePerTick * 2).toInt());
                }
              }
            }
          }
        },
      ),
    );

    // Periodic visual effect - dark tendrils
    voidZone.add(
      TimerComponent(
        period: 0.6,
        repeat: true,
        onTick: () {
          ImpactVisuals.play(game, position, 'Dark', scale: 0.6);
        },
      ),
    );

    // Fade out and remove
    voidZone.add(
      SequenceEffect([
        // Stay solid for most of duration
        OpacityEffect.to(1.0, EffectController(duration: voidDuration * 0.7)),
        // Fade out at the end
        OpacityEffect.fadeOut(EffectController(duration: voidDuration * 0.3)),
        RemoveEffect(),
      ]),
    );

    game.world.add(voidZone);

    // Initial burst damage to enemies already in the zone
    for (final v in victims) {
      final initialDmg = (damagePerTick * 2).toInt();
      v.takeDamage(initialDmg);
      ImpactVisuals.play(game, v.position, 'Dark', scale: 0.8);
    }
  }

  /// Light Trap - Blinds and heals allies
  static void _lightTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    double radius,
  ) {
    // Heal allies in range
    final healAmount = (attacker.unit.statIntelligence * (3.0 + 0.6 * rank))
        .toInt()
        .clamp(10, 150);

    final allies = game.getGuardiansInRange(
      center: position,
      range: radius * 1.3,
    );
    for (final g in allies) {
      g.unit.heal(healAmount);
      ImpactVisuals.playHeal(game, g.position, scale: 0.7);
    }

    // Heal orb
    game.orb.heal((healAmount * 0.5).toInt());
  }
}
