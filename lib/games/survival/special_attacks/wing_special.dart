import 'dart:math';

import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/components/survival_attacks.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/enemies/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

/// WING FAMILY - PIERCE MECHANIC (3-RANK VERSION)
/// Fires a fast, piercing beam that hits all enemies in a line
/// Rank 0: Base beam (no elemental rider)
/// Rank 1: Unlocks elemental rider for this element
/// Rank 2: Stronger numbers / secondary effects
/// Rank 3 (MAX): Element-specific ultimate pierce patterns
class WingPierceMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int rawRank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final int rank = rawRank.clamp(0, 3);

    bool hasUltimate = false;
    if (rank >= 3) {
      hasUltimate = _executeRank3Ultimate(
        game: game,
        attacker: attacker,
        target: target,
        element: element,
      );
    }

    final baseWidth = 50.0 + rank * 6;
    final baseRange = 1000.0 + rank * 200;
    final int baseDmg = (calcDmg(attacker, target) * (1.6 + 0.25 * rank))
        .toInt();

    // OPTION A: devastating only for non-special elements
    final isDevastating = rank >= 3 && !hasUltimate;

    // OPTION B: devastating for *all* rank 3
    // final isDevastating = rank >= 3;

    final width = isDevastating ? baseWidth * 3.0 : baseWidth;
    final range = isDevastating ? baseRange * 2.0 : baseRange;
    final int damage = isDevastating ? (baseDmg * 2.0).toInt() : baseDmg;

    final direction = (target.position - attacker.position).normalized();
    final endPos = attacker.position + direction * range;

    ImpactVisuals.playBeamTrail(
      game,
      attacker.position,
      endPos,
      element,
      width,
    );

    final pathVictims = _getEnemiesInPath(
      game,
      attacker.position,
      endPos,
      width * 0.7,
    );

    for (final victim in pathVictims) {
      victim.takeDamage(damage);
      ImpactVisuals.play(game, victim.position, element, scale: 0.7);
    }

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

    debugPrint(
      'Wing Pierce: element=$element rank=$rank victims=${pathVictims.length} damage=$damage ultimate=$hasUltimate',
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
  //  RANK 3 ULTIMATE ROUTER
  // ═══════════════════════════════════════════════════════════════════════════

  static bool _executeRank3Ultimate({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required HoardEnemy target,
    required String element,
  }) {
    switch (element) {
      case 'Fire':
        _fireSweepingBeam(game, attacker, target, element);
        return true;
      case 'Lightning':
        _lightningChainWeb(game, attacker, target, element);
        return true;
      case 'Ice':
        _iceLanceBurst(game, attacker, target, element);
        return true;
      case 'Crystal':
        _crystalPrismRefraction(game, attacker, target, element);
        return true;
      case 'Plant':
        _plantGrowingVineBeam(game, attacker, target, element);
        return true;
      case 'Dark':
        _darkVoidSlash(game, attacker, target, element);
        return true;
      case 'Light':
        _lightHealingBeam(game, attacker, target, element);
        return true;
      case 'Air':
        _airTornadoDrill(game, attacker, target, element);
        return true;
      case 'Blood':
        _bloodCrimsonLance(game, attacker, target, element);
        return true;
      case 'Earth':
        _earthBoulderBeam(game, attacker, target, element);
        return true;
      case 'Steam':
        _steamPressureBeam(game, attacker, target, element);
        return true;
      case 'Poison':
        _poisonVenomTrail(game, attacker, target, element);
        return true;
      case 'Water':
        _waterTidalBeam(game, attacker, target, element);
        return true;
      case 'Lava':
        _lavaEruptionTrench(game, attacker, target, element);
        return true;
      case 'Mud':
        _mudQuicksandTrail(game, attacker, target, element);
        return true;
      case 'Dust':
        _dustSandstormBeam(game, attacker, target, element);
        return true;
      case 'Spirit':
        _spiritReaperBeam(game, attacker, target, element);
        return true;
      default:
        return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RANK 3 SPECIALS
  // ═══════════════════════════════════════════════════════════════════════════

  // 🔥 FIRE - Sweeping Flamebeam
  static void _fireSweepingBeam(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int tickDmg = (calcDmg(attacker, target) * 0.22)
        .toInt(); // 20 * 0.22 ≈ 4.4x
    final baseDir = (target.position - attacker.position).normalized();
    const double range = 800.0;

    const int ticks = 20;
    const int tickMs = 65; // ≈ 1.3s total

    for (int i = 0; i < ticks; i++) {
      Future.delayed(Duration(milliseconds: i * tickMs), () {
        if (attacker.isDead) return;

        final t = i / (ticks - 1); // 0..1
        final angle = (t - 0.5) * (pi / 2); // -45°..+45°

        final rotatedDir = Vector2(
          baseDir.x * cos(angle) - baseDir.y * sin(angle),
          baseDir.x * sin(angle) + baseDir.y * cos(angle),
        );

        final endPos = attacker.position + rotatedDir * range;

        ImpactVisuals.playBeamTrail(
          game,
          attacker.position,
          endPos,
          element,
          40.0,
        );

        final victims = _getEnemiesInPath(
          game,
          attacker.position,
          endPos,
          40.0,
        );

        for (final v in victims) {
          v.takeDamage(tickDmg);
          ImpactVisuals.play(game, v.position, 'Fire', scale: 0.6);
        }
      });
    }
  }

  // ⚡ LIGHTNING - Chain Lightning Web
  static void _lightningChainWeb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.0).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 900.0;
    final endPos = attacker.position + dir * range;

    ImpactVisuals.playBeamTrail(game, attacker.position, endPos, element, 45.0);

    final rng = Random();

    // Primary beam hits
    final primaryVictims = _getEnemiesInPath(
      game,
      attacker.position,
      endPos,
      45.0,
    );

    for (final v in primaryVictims) {
      v.takeDamage(baseDmg);
      ImpactVisuals.play(game, v.position, 'Lightning', scale: 0.7);
    }

    // Helper: spawn branching chains from a list of sources
    void spawnChains(
      List<HoardEnemy> sources,
      int damage,
      int chainsPerSource,
      double radius,
    ) {
      for (final src in sources) {
        if (src.isDead) continue;
        final nearby = game
            .getEnemiesInRange(src.position, radius)
            .where((e) => e != src && !e.isDead)
            .toList();
        if (nearby.isEmpty) continue;

        nearby.shuffle(rng);
        final count = min(chainsPerSource, nearby.length);
        for (int i = 0; i < count; i++) {
          final targetEnemy = nearby[i];
          game.spawnAlchemyProjectile(
            start: src.position,
            target: targetEnemy,
            damage: damage,
            color: SurvivalAttackManager.getElementColor(element),
            shape: ProjectileShape.bolt,
            speed: 6.0,
            isEnemy: false,
            onHit: () {
              if (!targetEnemy.isDead) {
                targetEnemy.takeDamage(damage);
                ImpactVisuals.play(
                  game,
                  targetEnemy.position,
                  'Lightning',
                  scale: 0.6,
                );
              }
            },
          );
        }
      }
    }

    // Level 1 chains (≈50–60%)
    spawnChains(primaryVictims, (baseDmg * 0.5).toInt(), 2, 260);

    // Level 2 chains (weaker)
    spawnChains(primaryVictims, (baseDmg * 0.35).toInt(), 2, 260);
  }

  // ❄️ ICE - Frozen Lance Burst (pierce + backward shards)
  static void _iceLanceBurst(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int beamDmg = (calcDmg(attacker, target) * 1.0).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 900.0;
    final endPos = attacker.position + dir * range;

    ImpactVisuals.playBeamTrail(game, attacker.position, endPos, element, 40.0);

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 35.0);

    for (final v in victims) {
      v.takeDamage(beamDmg);
      ImpactVisuals.play(game, v.position, 'Ice', scale: 0.7);
    }

    // At tip: 8 shards shooting back, homing
    final int shardDmg = (beamDmg * 0.4).toInt();
    final rng = Random();

    for (int i = 0; i < 8; i++) {
      Future.delayed(Duration(milliseconds: i * 70), () {
        final enemies = game.getEnemiesInRange(endPos, 500);
        if (enemies.isEmpty) return;

        final targetEnemy = enemies[rng.nextInt(enemies.length)];
        if (targetEnemy.isDead) return;

        game.spawnAlchemyProjectile(
          start: endPos,
          target: targetEnemy,
          damage: shardDmg,
          color: SurvivalAttackManager.getElementColor(element),
          shape: ProjectileShape.blade,
          speed: 3.0,
          isEnemy: false,
          onHit: () {
            if (!targetEnemy.isDead) {
              targetEnemy.takeDamage(shardDmg);
              // Push them slightly away from orb
              final pushDir = (targetEnemy.position - game.orb.position)
                  .normalized();
              targetEnemy.position += pushDir * 30;
              ImpactVisuals.play(game, targetEnemy.position, 'Ice', scale: 0.6);
            }
          },
        );
      });
    }
  }

  // 💎 CRYSTAL - Prism Refraction
  static void _crystalPrismRefraction(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.0).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 900.0;
    final endPos = attacker.position + dir * range;

    ImpactVisuals.playBeamTrail(game, attacker.position, endPos, element, 35.0);

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 35.0);
    if (victims.isEmpty) return;

    // First hit is closest along beam
    victims.sort((a, b) {
      final da = a.position.distanceTo(attacker.position);
      final db = b.position.distanceTo(attacker.position);
      return da.compareTo(db);
    });

    final primary = victims.first;
    primary.takeDamage(baseDmg);
    ImpactVisuals.play(game, primary.position, 'Crystal', scale: 0.9);

    // Split into 6 rainbow shards
    final shardDmg = (baseDmg * 0.6).toInt();
    final basePos = primary.position;
    final enemiesAround = game.getEnemiesInRange(basePos, 450);

    for (int i = 0; i < 6; i++) {
      final angle = (i / 6.0) * 2 * pi;
      final dirOut = Vector2(cos(angle), sin(angle));

      // pick enemy roughly in this direction
      HoardEnemy? best;
      double bestDot = 0.85;
      for (final e in enemiesAround) {
        if (e == primary || e.isDead) continue;
        final toE = (e.position - basePos).normalized();
        final dot = toE.dot(dirOut);
        if (dot > bestDot) {
          bestDot = dot;
          best = e;
        }
      }

      if (best == null) continue;

      final color =
          Colors.primaries[i % Colors.primaries.length]; // disco beams

      game.spawnAlchemyProjectile(
        start: basePos,
        target: best,
        damage: shardDmg,
        color: color,
        shape: ProjectileShape.shard,
        speed: 4.0,
        isEnemy: false,
        onHit: () {
          if (!best!.isDead) {
            best.takeDamage(shardDmg);
            ImpactVisuals.play(game, best.position, 'Crystal', scale: 0.7);
          }
        },
      );
    }
  }

  // 🌿 PLANT - Growing Vine Beam
  static void _plantGrowingVineBeam(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.2).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 900.0;
    final endPos = attacker.position + dir * range;

    // Visual: thickening beam
    for (int i = 0; i < 5; i++) {
      final t = i / 4.0; // 0..1
      final width = 30.0 + t * 90.0; // 30→120

      Future.delayed(Duration(milliseconds: i * 70), () {
        ImpactVisuals.playBeamTrail(
          game,
          attacker.position,
          endPos,
          element,
          width,
        );
      });
    }

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 60.0);

    for (final v in victims) {
      final dist = v.position.distanceTo(attacker.position);
      final proximity = (1.0 - (dist / range)).clamp(0.3, 1.5); // closer = more
      final dmg = (baseDmg * proximity).toInt();
      v.takeDamage(dmg);
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Thorns',
          damagePerTick: max(2, (dmg * 0.15).toInt()),
          ticksRemaining: 5,
          tickInterval: 0.4,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Plant', scale: 0.7);
    }
  }

  // 🌑 DARK - Void Slash (instant beam + lingering trail)
  static void _darkVoidSlash(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.2).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 950.0;
    final endPos = attacker.position + dir * range;

    // Instant beam
    ImpactVisuals.playBeamTrail(game, attacker.position, endPos, element, 40.0);

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 40.0);
    for (final v in victims) {
      v.takeDamage(baseDmg);
      ImpactVisuals.play(game, v.position, 'Dark', scale: 1.0);
    }

    // Lingering void line for 2s
    final double trailDuration = 2.0;
    final double tickInterval = 0.3;
    final int ticks = (trailDuration / tickInterval).ceil();

    for (int i = 0; i < ticks; i++) {
      Future.delayed(
        Duration(milliseconds: (i * tickInterval * 1000).toInt()),
        () {
          final dotVictims = _getEnemiesInPath(
            game,
            attacker.position,
            endPos,
            30.0,
          );
          for (final v in dotVictims) {
            v.takeDamage(20); // flat trail damage
          }
        },
      );
    }
  }

  // ☀️ LIGHT - Healing Beam
  static void _lightHealingBeam(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.0).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 900.0;
    final endPos = attacker.position + dir * range;

    ImpactVisuals.playBeamTrail(game, attacker.position, endPos, element, 40.0);

    // Damage enemies
    final victims = _getEnemiesInPath(game, attacker.position, endPos, 40.0);
    int totalDealt = 0;
    for (final v in victims) {
      v.takeDamage(baseDmg);
      totalDealt += baseDmg;
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.8);
    }

    // Heal allies roughly along path
    double distanceToLine(Vector2 p) {
      final ab = endPos - attacker.position;
      final ap = p - attacker.position;
      final t = (ap.dot(ab) / ab.length2).clamp(0.0, 1.0);
      final closest = attacker.position + ab * t;
      return p.distanceTo(closest);
    }

    final int healPerUnit = (totalDealt * 0.5).toInt();
    for (final g in game.guardians) {
      if (g.isDead) continue;
      if (distanceToLine(g.position) <= 60.0) {
        final heal = max(10, (healPerUnit * 0.5).toInt());
        g.unit.heal(heal);
        ImpactVisuals.playHeal(game, g.position, scale: 0.7);
        // (Optional: debuff cleanse / shield can be added here
        // if you have those systems exposed.)
      }
    }

    // Tiny orb heal
    game.orb.heal(max(5, (healPerUnit * 0.25).toInt()));
  }

  // 🌪️ AIR - Tornado Drill (rotating oscillating beam)
  static void _airTornadoDrill(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int tickDmg = (calcDmg(attacker, target) * 0.2).toInt();
    final baseDir = (target.position - attacker.position).normalized();
    const double range = 850.0;

    const int ticks = 30;
    const int tickMs = 60; // ≈ 1.8s total

    for (int i = 0; i < ticks; i++) {
      Future.delayed(Duration(milliseconds: i * tickMs), () {
        if (attacker.isDead) return;

        final t = i / (ticks - 1); // 0..1
        final rotations = 3.0;
        final angle = (t * rotations * 2 * pi); // 0→3 full spins

        final rotatedDir = Vector2(
          baseDir.x * cos(angle) - baseDir.y * sin(angle),
          baseDir.x * sin(angle) + baseDir.y * cos(angle),
        );

        final endPos = attacker.position + rotatedDir * range;

        ImpactVisuals.playBeamTrail(
          game,
          attacker.position,
          endPos,
          element,
          35.0,
        );

        final victims = _getEnemiesInPath(
          game,
          attacker.position,
          endPos,
          35.0,
        );

        for (final v in victims) {
          v.takeDamage(tickDmg);
          final dirKnock = (v.position - attacker.position).normalized();
          v.add(
            MoveEffect.by(
              dirKnock * 60,
              EffectController(duration: 0.15, curve: Curves.easeOut),
            ),
          );
          ImpactVisuals.play(game, v.position, 'Air', scale: 0.6);
        }
      });
    }
  }

  // 🩸 BLOOD - Crimson Lance
  static void _bloodCrimsonLance(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    double range = 800.0;
    double dmgMult = 0.8;
    final dir = (target.position - attacker.position).normalized();

    List<HoardEnemy> allKilled = [];

    for (int step = 0; step < 4; step++) {
      final int damage = (calcDmg(attacker, target) * dmgMult).toInt();
      final endPos = attacker.position + dir * range;

      ImpactVisuals.playBeamTrail(
        game,
        attacker.position,
        endPos,
        element,
        35.0,
      );

      final victims = _getEnemiesInPath(game, attacker.position, endPos, 35.0);

      int killsThisStep = 0;
      for (final v in victims) {
        if (v.isDead) continue;
        v.takeDamage(damage);
        ImpactVisuals.play(game, v.position, 'Blood', scale: 0.7);
        if (v.isDead) {
          killsThisStep++;
          allKilled.add(v);
        }
      }

      // Each kill extends lance and buffs damage
      if (killsThisStep == 0) break;
      range += 200.0 * killsThisStep;
      dmgMult += 0.15 * killsThisStep;
    }

    // Lifesteal on total kills
    final healSelf = allKilled.length * 40;
    if (healSelf > 0) {
      attacker.unit.heal(healSelf);
      ImpactVisuals.playHeal(game, attacker.position, scale: 0.7);
    }
  }

  // 🗿 EARTH - Boulder Beam
  static void _earthBoulderBeam(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.3).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 800.0;
    final endPos = attacker.position + dir * range;

    // Wide, heavy beam
    ImpactVisuals.playBeamTrail(
      game,
      attacker.position,
      endPos,
      element,
      120.0,
    );

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 60.0);
    for (final v in victims) {
      v.takeDamage(baseDmg);
      ImpactVisuals.play(game, v.position, 'Earth', scale: 0.8);
    }

    // Rock debris along path that pushes enemies (pseudo-block)
    final length = attacker.position.distanceTo(endPos);
    final segmentCount = (length / 120).floor();

    for (int i = 0; i < segmentCount; i++) {
      final pos = attacker.position + dir * (i * 120 + 60);

      final rock = CircleComponent(
        radius: 30,
        position: pos,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.brown.shade700.withValues(alpha: 0.7),
      );

      rock.add(
        TimerComponent(
          period: 0.25,
          repeat: true,
          onTick: () {
            final nearby = game.getEnemiesInRange(pos, 45);
            for (final e in nearby) {
              final pushDir = (e.position - pos).normalized();
              e.position += pushDir * 12;
            }
          },
        ),
      );

      rock.add(RemoveEffect(delay: 5.0));
      game.world.add(rock);
    }
  }

  // 🌫️ STEAM - Pressure Washer (pulsing beam)
  static void _steamPressureBeam(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int pulseDmg = (calcDmg(attacker, target) * 0.55).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 850.0;
    final endPos = attacker.position + dir * range;

    const int pulses = 8;
    const int pulseMs = 150;

    for (int i = 0; i < pulses; i++) {
      Future.delayed(Duration(milliseconds: i * pulseMs), () {
        if (attacker.isDead) return;

        ImpactVisuals.playBeamTrail(
          game,
          attacker.position,
          endPos,
          element,
          35.0,
        );

        final victims = _getEnemiesInPath(
          game,
          attacker.position,
          endPos,
          35.0,
        );
        for (final v in victims) {
          v.takeDamage(pulseDmg);
          final pushDir = (v.position - attacker.position).normalized();
          v.add(
            MoveEffect.by(
              pushDir * 100,
              EffectController(duration: 0.15, curve: Curves.easeOut),
            ),
          );
          ImpactVisuals.play(game, v.position, 'Steam', scale: 0.6);
        }
      });
    }
  }

  // ☠️ POISON - Venom Trail
  static void _poisonVenomTrail(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int beamDmg = (calcDmg(attacker, target) * 1.4).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 900.0;
    final endPos = attacker.position + dir * range;

    ImpactVisuals.playBeamTrail(game, attacker.position, endPos, element, 25.0);

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 25.0);
    for (final v in victims) {
      v.takeDamage(beamDmg);
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick: max(5, (beamDmg * 0.2).toInt()),
          ticksRemaining: 6,
          tickInterval: 0.5,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Poison', scale: 0.7);
    }

    // Poison cloud trail along path
    final length = attacker.position.distanceTo(endPos);
    final segmentCount = (length / 120).floor();
    final double cloudDuration = 8.0;

    for (int i = 0; i < segmentCount; i++) {
      final pos = attacker.position + dir * (i * 120 + 60);

      final cloud = CircleComponent(
        radius: 60,
        position: pos,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.green.withValues(alpha: 0.25),
      );

      cloud.add(
        TimerComponent(
          period: 0.5,
          repeat: true,
          onTick: () {
            final victims = game.getEnemiesInRange(pos, 60);
            for (final v in victims) {
              v.unit.applyStatusEffect(
                SurvivalStatusEffect(
                  type: 'Poison',
                  damagePerTick: 15,
                  ticksRemaining: 2,
                  tickInterval: 0.5,
                ),
              );
            }
          },
        ),
      );

      cloud.add(RemoveEffect(delay: cloudDuration));
      game.world.add(cloud);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RANK 3 ULTIMATE BEAMS — ADDITIONAL ELEMENTS
  // ═══════════════════════════════════════════════════════════════════════════

  // 💧 WATER - Tidal Beam (sideways-scattering pressure wave + attacker heal per hit)
  static void _waterTidalBeam(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.8).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 950.0;
    final endPos = attacker.position + dir * range;

    // Wide slow-pulsing beam (3 sweeps)
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 120), () {
        ImpactVisuals.playBeamTrail(
          game,
          attacker.position,
          endPos,
          element,
          55.0 - i * 8,
        );
      });
    }

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 65.0);
    int healTotal = 0;
    for (final v in victims) {
      final dist = v.position.distanceTo(attacker.position);
      final falloff = (1.0 - dist / range).clamp(0.3, 1.2);
      final dmg = (baseDmg * falloff).toInt();
      v.takeDamage(dmg);
      healTotal += dmg;

      // Push enemies perpendicular to beam (scatter sideways like a water jet)
      final perpDir = Vector2(-dir.y, dir.x);
      final side = (v.position - attacker.position).dot(perpDir) >= 0
          ? 1.0
          : -1.0;
      v.add(
        MoveEffect.by(
          perpDir * side * 110,
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
      ImpactVisuals.play(game, v.position, element, scale: 0.7);
    }

    // Heal attacker based on total damage dealt
    if (healTotal > 0) {
      attacker.unit.heal((healTotal * 0.3).toInt().clamp(5, 300));
      ImpactVisuals.playHeal(game, attacker.position);
    }

    SurvivalAttackManager.triggerScreenShake(game, 5.0);
  }

  // 🌋 LAVA - Eruption Trench (beam burns a persistent lava path, heavy DoT zones)
  static void _lavaEruptionTrench(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.5).toInt();
    final color = SurvivalAttackManager.getElementColor('Lava');
    final dir = (target.position - attacker.position).normalized();
    const double range = 900.0;
    final endPos = attacker.position + dir * range;

    ImpactVisuals.playBeamTrail(game, attacker.position, endPos, element, 45.0);

    // Immediate damage
    final victims = _getEnemiesInPath(game, attacker.position, endPos, 50.0);
    for (final v in victims) {
      v.takeDamage(baseDmg);
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Burn',
          damagePerTick: (baseDmg * 0.15).toInt().clamp(3, 60),
          ticksRemaining: 6,
          tickInterval: 0.5,
        ),
      );
      ImpactVisuals.play(game, v.position, element, scale: 0.8);
    }

    // Leave 6 lava crack zones along the beam path
    for (int i = 0; i < 6; i++) {
      final t = (i + 0.5) / 6.0;
      final crackPos = attacker.position + dir * (range * t);
      final crack = CircleComponent(
        radius: 55,
        position: crackPos,
        anchor: Anchor.center,
        paint: Paint()..color = color.withValues(alpha: 0.35),
      );
      crack.add(
        TimerComponent(
          period: 0.45,
          repeat: true,
          onTick: () {
            for (final v in game.getEnemiesInRange(crackPos, 55)) {
              v.takeDamage(max(2, baseDmg ~/ 8));
              v.unit.applyStatusEffect(
                SurvivalStatusEffect(
                  type: 'Burn',
                  damagePerTick: max(1, baseDmg ~/ 15),
                  ticksRemaining: 2,
                  tickInterval: 0.5,
                ),
              );
            }
          },
        ),
      );
      crack.add(RemoveEffect(delay: 5.5));
      game.world.add(crack);
    }

    SurvivalAttackManager.triggerScreenShake(game, 8.0);
  }

  // 🟤 MUD - Quicksand Trail (beam leaves sticky mud strip, pulling enemies back)
  static void _mudQuicksandTrail(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.6).toInt();
    final color = SurvivalAttackManager.getElementColor('Mud');
    final dir = (target.position - attacker.position).normalized();
    const double range = 880.0;
    final endPos = attacker.position + dir * range;

    ImpactVisuals.playBeamTrail(game, attacker.position, endPos, element, 50.0);

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 55.0);
    for (final v in victims) {
      v.takeDamage(baseDmg);
      ImpactVisuals.play(game, v.position, element, scale: 0.7);
    }

    // 5 quicksand patches along the beam — each continuously pulls enemies in
    for (int i = 0; i < 5; i++) {
      final t = (i + 0.5) / 5.0;
      final patchPos = attacker.position + dir * (range * t);
      final patch = CircleComponent(
        radius: 60,
        position: patchPos,
        anchor: Anchor.center,
        paint: Paint()..color = color.withValues(alpha: 0.3),
      );
      patch.add(
        TimerComponent(
          period: 0.35,
          repeat: true,
          onTick: () {
            for (final v in game.getEnemiesInRange(patchPos, 60)) {
              // Pull enemies toward patch center
              final pullDir = (patchPos - v.position).normalized();
              v.add(
                MoveEffect.by(pullDir * 22, EffectController(duration: 0.2)),
              );
              v.unit.applyStatusEffect(
                SurvivalStatusEffect(
                  type: 'Slow',
                  damagePerTick: 0,
                  ticksRemaining: 2,
                  tickInterval: 0.35,
                ),
              );
            }
          },
        ),
      );
      patch.add(RemoveEffect(delay: 5.0));
      game.world.add(patch);
    }

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  // 🌪️ DUST - Sandstorm Beam (wide-arc confusion field along beam path for 3s)
  static void _dustSandstormBeam(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.7).toInt();
    final color = SurvivalAttackManager.getElementColor('Dust');
    final dir = (target.position - attacker.position).normalized();
    const double range = 920.0;
    final endPos = attacker.position + dir * range;

    // Wide visual sweep
    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        ImpactVisuals.playBeamTrail(
          game,
          attacker.position,
          endPos,
          element,
          60.0 - i * 8,
        );
      });
    }

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 65.0);
    for (final v in victims) {
      v.takeDamage(baseDmg);
      ImpactVisuals.play(game, v.position, element, scale: 0.7);
    }

    // Sandstorm cloud segments along the beam
    const int segments = 5;
    final rng = Random();
    for (int i = 0; i < segments; i++) {
      final t = (i + 0.5) / segments;
      final segPos = attacker.position + dir * (range * t);
      final storm = CircleComponent(
        radius: 70,
        position: segPos,
        anchor: Anchor.center,
        paint: Paint()..color = color.withValues(alpha: 0.2),
      );
      storm.add(
        TimerComponent(
          period: 0.18,
          repeat: true,
          onTick: () {
            for (final v in game.getEnemiesInRange(segPos, 70)) {
              final jitter = Vector2(
                rng.nextDouble() * 70 - 35,
                rng.nextDouble() * 70 - 35,
              );
              v.add(MoveEffect.by(jitter, EffectController(duration: 0.12)));
            }
          },
        ),
      );
      storm.add(RemoveEffect(delay: 3.0));
      game.world.add(storm);
    }

    SurvivalAttackManager.triggerScreenShake(game, 7.0);
  }

  // 👻 SPIRIT - Reaper Beam (spectral harvest, drains HP and heals all guardians)
  static void _spiritReaperBeam(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy target,
    String element,
  ) {
    final int baseDmg = (calcDmg(attacker, target) * 1.6).toInt();
    final dir = (target.position - attacker.position).normalized();
    const double range = 1000.0;
    final endPos = attacker.position + dir * range;

    // Ghostly fading beam
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        ImpactVisuals.playBeamTrail(
          game,
          attacker.position,
          endPos,
          element,
          50.0 - i * 10,
        );
      });
    }

    final victims = _getEnemiesInPath(game, attacker.position, endPos, 55.0);
    int totalDrained = 0;
    for (final v in victims) {
      final dist = v.position.distanceTo(attacker.position);
      final falloff = (1.0 - dist / range).clamp(0.3, 1.2);
      final dmg = (baseDmg * falloff).toInt();
      v.takeDamage(dmg);
      totalDrained += dmg;
      ImpactVisuals.play(game, v.position, element, scale: 0.8);
    }

    // Distribute drained life to all living guardians and orb
    if (totalDrained > 0) {
      final guardianCount = max(1, game.guardians.length);
      final healPerGuardian = max(
        1,
        (totalDrained * 0.35).toInt() ~/ guardianCount,
      );
      for (final g in game.guardians) {
        if (!g.isDead) {
          g.unit.heal(healPerGuardian);
          ImpactVisuals.playHeal(game, g.position, scale: 0.6);
        }
      }
      game.orb.heal(max(1, (totalDrained * 0.15).toInt()));
    }

    SurvivalAttackManager.triggerScreenShake(game, 6.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EXISTING ELEMENTAL RIDERS (Ranks 1–3, used by base beam)
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

  // ─── FIRE / LAVA / BLOOD RIDERS ────────────────────────────────────────────

  static void _firePierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final int burnDmg = (attacker.unit.statIntelligence * (2.0 + 0.35 * rank))
        .toInt()
        .clamp(3, 120)
        .toInt();

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

  static void _lavaPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    Vector2 startPos,
    Vector2 endPos,
  ) {
    final int trailDps = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 80)
        .toInt();
    final double trailDuration = 2.0 + 0.3 * rank;

    final direction = (endPos - startPos).normalized();
    final length = startPos.distanceTo(endPos);
    final segmentCount = (length / 80).floor();

    for (int i = 0; i < segmentCount; i++) {
      final segmentPos = startPos + direction * (i * 80 + 40);

      final fireSegment = CircleComponent(
        radius: 30,
        position: segmentPos,
        anchor: Anchor.center,
        paint: Paint()..color = Colors.orange.shade800.withValues(alpha: 0.25),
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

  static void _bloodPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    int totalDrained = 0;

    for (final v in victims) {
      final int drain = (damage * (0.2 + 0.05 * rank)).toInt();
      v.takeDamage(drain);
      totalDrained += drain;
    }

    attacker.unit.heal((totalDrained * 0.5).toInt());
    ImpactVisuals.playHeal(game, attacker.position, scale: 0.8);

    game.orb.heal((totalDrained * 0.25).toInt());

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

  // ─── WATER / ICE / STEAM RIDERS ────────────────────────────────────────────

  static void _waterPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    Vector2 startPos,
  ) {
    // Water pressure scatters enemies PERPENDICULAR to the beam (sideways spray),
    // contrasting with Air's straight-forward shockwave.
    if (victims.isNotEmpty) {
      final beamDir = (victims.first.position - startPos).normalized();
      final perpDir = Vector2(-beamDir.y, beamDir.x);

      for (int i = 0; i < victims.length; i++) {
        final v = victims[i];
        final side = (i % 2 == 0) ? 1.0 : -1.0;
        v.add(
          MoveEffect.by(
            perpDir * side * (45.0 + 11.0 * rank),
            EffectController(duration: 0.2, curve: Curves.easeOut),
          ),
        );
      }
    }

    final int healAmount = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(3, 60);
    final int targetCount = victims.length.clamp(1, 5);
    attacker.unit.heal(healAmount * targetCount);
  }

  static void _icePierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final double slowStrength = 15.0 + 3.0 * rank;

    for (final v in victims) {
      final pushBack =
          (v.targetOrb.position - v.position).normalized() * -slowStrength;
      v.position += pushBack;
      ImpactVisuals.play(game, v.position, 'Ice', scale: 0.5);
    }

    if (rank >= 3 && victims.isNotEmpty) {
      victims.first.add(
        MoveEffect.by(Vector2.zero(), EffectController(duration: 1.0)),
      );
    }
  }

  static void _steamPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final int splashDmg = (attacker.unit.statIntelligence * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(2, 60)
        .toInt();

    for (final v in victims) {
      final nearby = game
          .getEnemiesInRange(v.position, 60)
          .where((e) => !victims.contains(e));
      for (final n in nearby) {
        n.takeDamage(splashDmg);
        ImpactVisuals.play(game, n.position, 'Steam', scale: 0.4);
      }
    }
  }

  // ─── PLANT / POISON RIDERS ─────────────────────────────────────────────────

  static void _plantPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final int thornDmg = (attacker.unit.statIntelligence * (0.8 + 0.15 * rank))
        .toInt()
        .clamp(2, 60)
        .toInt();

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Thorns',
          damagePerTick: thornDmg,
          ticksRemaining: 5 + rank,
          tickInterval: 0.4,
        ),
      );
    }
  }

  static void _poisonPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final int poisonDmg = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 80)
        .toInt();

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick: poisonDmg,
          ticksRemaining: 8 + rank,
          tickInterval: 0.4,
        ),
      );

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

  // ─── EARTH / MUD / CRYSTAL RIDERS ──────────────────────────────────────────

  static void _earthPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    final int bonusDmg = (damage * (0.2 + 0.05 * rank)).toInt();

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

    final int shieldAmount = (attacker.unit.maxHp * (0.05 + 0.02 * rank))
        .toInt();
    attacker.unit.shieldHp = (attacker.unit.shieldHp ?? 0) + shieldAmount;
  }

  static void _mudPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final double slowStrength = 25.0 + 5.0 * rank;

    for (final v in victims) {
      final pushBack =
          (v.targetOrb.position - v.position).normalized() * -slowStrength;
      v.position += pushBack;
    }
  }

  static void _crystalPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    final int shardDmg = (damage * (0.3 + 0.06 * rank)).toInt();
    final rng = Random();

    for (final v in victims) {
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

  // ─── AIR / DUST / LIGHTNING RIDERS ─────────────────────────────────────────

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

  static void _dustPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();

    for (final v in victims) {
      final jitter = Vector2(
        (rng.nextDouble() - 0.5) * (30 + 6 * rank),
        (rng.nextDouble() - 0.5) * (30 + 6 * rank),
      );
      v.position += jitter;
    }
  }

  static void _lightningPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    final int chainDmg = (damage * (0.4 + 0.08 * rank)).toInt();
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

  // ─── SPIRIT / DARK / LIGHT RIDERS ──────────────────────────────────────────

  static void _spiritPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    int totalDrained = 0;

    for (final v in victims) {
      final int drain = (damage * (0.25 + 0.05 * rank)).toInt();
      v.takeDamage(drain);
      totalDrained += drain;
      ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.6);
    }

    attacker.unit.heal((totalDrained * 0.4).toInt());
  }

  static void _darkPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
    int damage,
  ) {
    final double executeThreshold = 0.2 + 0.05 * rank;
    final int bonusDmg = (damage * (0.5 + 0.1 * rank)).toInt();

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

  static void _lightPierce(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    List<HoardEnemy> victims,
  ) {
    final int healAmount = (attacker.unit.statIntelligence * (2.0 + 0.4 * rank))
        .toInt()
        .clamp(5, 120)
        .toInt();

    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healAmount);
        ImpactVisuals.playHeal(game, g.position, scale: 0.5);
      }
    }

    for (final v in victims) {
      ImpactVisuals.play(game, v.position, 'Light', scale: 0.8);
    }

    if (rank >= 3) {
      game.orb.heal((healAmount * 0.5).toInt());
    }
  }
}
