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

/// MASK FAMILY - TRAP FIELD MECHANIC
/// Deploy strategic elemental traps that trigger on enemy contact
/// Rank 1+: Elemental trap effects
/// Rank 5 (MAX): Interconnected trap grid with devastating effects
class MaskTrapMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final color = SurvivalAttackManager.getElementColor(element);

    // Base trap parameters
    final baseTrapCount = 2 + rank;
    final trapRadius = 60.0 + rank * 8;
    final trapDuration = 8.0 + rank * 1.5;

    // Rank 5: Grid formation
    final isGrid = rank >= 5;
    final trapCount = isGrid ? baseTrapCount * 2 : baseTrapCount;

    // Deploy traps in strategic positions
    final deployPos = target?.position ?? (attacker.position + Vector2(150, 0));

    if (isGrid) {
      // Grid formation for rank 5
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
      // Spread formation
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
    for (int i = 0; i < count; i++) {
      final angle = (2 * pi * i) / count;
      final offset = Vector2(cos(angle), sin(angle)) * (120 + rank * 20);
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
    // Base damage
    final baseDmg = (calcDmg(attacker, null) * (1.4 + 0.25 * rank)).toInt();

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
        _airTrap(game, attacker, rank, position, victims);
        break;
      case 'Dust':
        _dustTrap(game, attacker, rank, position, victims);
        break;
      case 'Lightning':
        _lightningTrap(game, attacker, rank, position, victims, baseDamage);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritTrap(game, attacker, rank, position, victims, baseDamage);
        break;
      case 'Dark':
        _darkTrap(game, attacker, rank, position, victims);
        break;
      case 'Light':
        _lightTrap(game, attacker, rank, position, radius);
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  FIRE / LAVA / BLOOD
  // ═══════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════
  //  WATER / ICE / STEAM
  // ═══════════════════════════════════════════════════════════════════════

  /// Water Trap - Launches enemies upward then heals allies
  static void _waterTrap(
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
          dir * (40.0 + 8.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }

    // Heal allies in area
    final healAmount = (attacker.unit.statIntelligence * (2.0 + 0.4 * rank))
        .toInt()
        .clamp(5, 100);

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

  // ═══════════════════════════════════════════════════════════════════════
  //  PLANT / POISON
  // ═══════════════════════════════════════════════════════════════════════

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
    if (rank >= 3) {
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

  // ═══════════════════════════════════════════════════════════════════════
  //  EARTH / MUD / CRYSTAL
  // ═══════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════
  //  AIR / DUST / LIGHTNING
  // ═══════════════════════════════════════════════════════════════════════

  /// Air Trap - Creates tornado that pulls then launches
  static void _airTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    List<HoardEnemy> victims,
  ) {
    for (final v in victims) {
      final dir = (v.position - position).normalized();
      v.add(
        MoveEffect.by(
          dir * (100.0 + 20.0 * rank),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }
  }

  /// Dust Trap - Blinding dust cloud
  static void _dustTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();

    for (final v in victims) {
      final jitter = Vector2(
        (rng.nextDouble() - 0.5) * (40 + 8 * rank),
        (rng.nextDouble() - 0.5) * (40 + 8 * rank),
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

  // ═══════════════════════════════════════════════════════════════════════
  //  SPIRIT / DARK / LIGHT
  // ═══════════════════════════════════════════════════════════════════════

  /// Spirit Trap - Spawns attacking spirits
  static void _spiritTrap(
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

    // Heal attacker
    attacker.unit.heal((totalDrain * 0.5).toInt());
  }

  /// Dark Trap - Mini black hole with execute
  static void _darkTrap(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 position,
    List<HoardEnemy> victims,
  ) {
    final executeThreshold = 0.20 + 0.05 * rank;

    for (final v in victims) {
      if (!v.isBoss && v.unit.hpPercent < executeThreshold) {
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.3);
      } else {
        // Pull toward center
        final pull = (position - v.position).normalized() * (40 + rank * 8);
        v.position += pull;
      }
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
