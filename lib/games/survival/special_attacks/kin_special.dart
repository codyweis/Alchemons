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

/// Rank 1+: Elemental blessing behavior based on element
/// Rank 5 (MAX): Strongest version of that blessing
class KinBlessingMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);

    // Base heal: always heal orb + self
    final baseMult = 1.0 + 0.15 * (rank - 1);
    int baseHeal = ((attacker.unit.statIntelligence * 10 + 20) * baseMult)
        .toInt()
        .clamp(10, 9999);

    game.orb.heal(baseHeal);
    attacker.unit.heal(baseHeal);
    ImpactVisuals.play(game, attacker.position, element, scale: 0.8);

    // Elemental augment kicks in at rank 1
    if (rank >= 1) {
      _applyElementalBlessing(
        game: game,
        attacker: attacker,
        element: element,
        rank: rank,
        baseHeal: baseHeal,
      );
    }
  }

  // ─────────────────────────────
  //  ELEMENT ROUTER
  // ─────────────────────────────

  static void _applyElementalBlessing({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank,
    required int baseHeal,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD – aggressive support
      case 'Fire':
        _fireBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Lava':
        _lavaBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Blood':
        _bloodBlessing(game, attacker, rank, baseHeal);
        break;

      // 💧 WATER / ICE / STEAM – regen + control
      case 'Water':
        _waterBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Ice':
        _iceBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Steam':
        _steamBlessing(game, attacker, rank, baseHeal);
        break;

      // 🌿 PLANT / POISON – regen + offensive debuffs
      case 'Plant':
        _plantBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Poison':
        _poisonBlessing(game, attacker, rank, baseHeal);
        break;

      // 🌍 EARTH / MUD / CRYSTAL – defensive blessings
      case 'Earth':
        _earthBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Mud':
        _mudBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Crystal':
        _crystalBlessing(game, attacker, rank, baseHeal);
        break;

      // 🌬️ AIR / DUST / LIGHTNING – disruptive / high tempo
      case 'Air':
        _airBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Dust':
        _dustBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Lightning':
        _lightningBlessing(game, attacker, rank, baseHeal);
        break;

      // 🌗 SPIRIT / DARK / LIGHT – spiritual / holy / shadow support
      case 'Spirit':
        _spiritBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Dark':
        _darkBlessing(game, attacker, rank, baseHeal);
        break;
      case 'Light':
        _lightBlessing(game, attacker, rank, baseHeal);
        break;

      default:
        _genericBlessing(game, attacker, rank, baseHeal);
        break;
    }
  }

  // ─────────────────────────────
  //  FIRE / LAVA / BLOOD
  // ─────────────────────────────

  /// Fire Kin – "Rallying Flame":
  /// Extra heal to front-row guardians + small burn around them.
  static void _fireBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final frontBonus = (baseHeal * (0.6 + 0.1 * (rank - 1))).toInt();
    for (final g in game.guardians) {
      if (g.isDead) continue;
      final isFront = g.position.y < attacker.position.y + 40;
      if (isFront) {
        g.unit.heal(frontBonus);
        ImpactVisuals.play(game, g.position, 'Fire', scale: 0.5);

        final enemies = game.getEnemiesInRange(g.position, 160);
        for (final e in enemies) {
          e.takeDamage(
            (attacker.unit.statIntelligence * (0.6 + 0.1 * rank)).toInt().clamp(
              2,
              80,
            ),
          );
        }
      }
    }
  }

  /// Lava Kin – "Molten Vow":
  /// Stronger heal to the lowest HP guardian, blast around them.
  static void _lavaBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final living = game.guardians.where((g) => !g.isDead).toList();
    if (living.isEmpty) return;

    living.sort((a, b) => a.unit.hpPercent.compareTo(b.unit.hpPercent));
    final focus = living.first;

    final heal = (baseHeal * (1.2 + 0.1 * (rank - 1))).toInt();
    focus.unit.heal(heal);
    ImpactVisuals.play(game, focus.position, 'Lava', scale: 0.9);

    final enemies = game.getEnemiesInRange(focus.position, 200);
    final dmg = (calcDmg(attacker, null) * (1.0 + 0.2 * rank)).toInt().clamp(
      5,
      300,
    );
    for (final e in enemies) {
      e.takeDamage(dmg);
    }
    ImpactVisuals.playExplosion(game, focus.position, 'Lava', 200);
  }

  /// Blood Kin – "Blood Covenant":
  /// Converts healing into damage: corridor around guardians.
  static void _bloodBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    int totalHeal = 0;
    for (final g in game.guardians) {
      if (g.isDead) continue;
      final h = (baseHeal * 0.5).toInt();
      g.unit.heal(h);
      totalHeal += h;
      ImpactVisuals.play(game, g.position, 'Blood', scale: 0.6);
    }

    if (totalHeal <= 0) return;

    final dmg = (totalHeal * (0.25 + 0.05 * (rank - 1))).toInt();
    final enemies = game.getEnemiesInRange(game.orb.position, 280);
    for (final e in enemies) {
      e.takeDamage((dmg / max(1, enemies.length)).toInt());
    }
  }

  // ─────────────────────────────
  //  WATER / ICE / STEAM
  // ─────────────────────────────

  /// Water Kin – "Tide of Mercy":
  /// Heal-over-time around the orb.
  static void _waterBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final totalDuration = 4.0 + 0.5 * (rank - 1);
    final ticks = (totalDuration / 0.8).round();
    final healPerTick = (baseHeal * (0.4 + 0.08 * rank)).toInt().clamp(4, 160);

    final orbPos = game.orb.position.clone();
    final zoneRadius = 260.0;

    game.world.add(
      TimerComponent(
        period: 0.8,
        repeat: true,
        onTick: () {
          for (final g in game.guardians) {
            if (g.isDead) continue;
            if (g.position.distanceTo(orbPos) <= zoneRadius) {
              g.unit.heal(healPerTick);
              ImpactVisuals.play(game, g.position, 'Water', scale: 0.5);
            }
          }
        },
        removeOnFinish: true,
      )..timer.limit = totalDuration,
    );
  }

  /// Ice Kin – "Sanctified Frost":
  /// Heal + strong slow near orb.
  static void _iceBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final orbPos = game.orb.position.clone();
    final radius = 260.0;
    final healBonus = (baseHeal * 0.5).toInt();

    for (final g in game.guardians) {
      if (g.isDead) continue;
      if (g.position.distanceTo(orbPos) <= radius) {
        g.unit.heal(healBonus);
        ImpactVisuals.play(game, g.position, 'Ice', scale: 0.7);
      }
    }

    final slowDuration = 3.0 + 0.4 * (rank - 1);
    final slowZone = CircleComponent(
      radius: radius,
      position: orbPos,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor('Ice').withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    slowZone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          final enemies = game.getEnemiesInRange(orbPos, radius);
          for (final e in enemies) {
            final pushBack =
                (e.targetOrb.position - e.position).normalized() * -10.0;
            e.position += pushBack;
          }
        },
      ),
    );

    slowZone.add(RemoveEffect(delay: slowDuration));
    game.world.add(slowZone);
  }

  /// Steam Kin – "Soothing Vapors":
  /// Mild heal + soft knockback around orb.
  static void _steamBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final orbPos = game.orb.position.clone();
    final healEach = (baseHeal * 0.6).toInt();
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal(healEach);
      ImpactVisuals.play(game, g.position, 'Steam', scale: 0.6);
    }

    final radius = 260.0;
    final duration = 3.5 + 0.3 * (rank - 1);
    final zone = CircleComponent(
      radius: radius,
      position: orbPos,
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor(
          'Steam',
        ).withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          final enemies = game.getEnemiesInRange(orbPos, radius);
          for (final e in enemies) {
            final pushBack =
                (e.targetOrb.position - e.position).normalized() * -6.0;
            e.position += pushBack;
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

  /// Plant Kin – "Verdant Blessing":
  /// Heal + HoT on all guardians.
  static void _plantBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final initial = (baseHeal * 0.6).toInt();
    final hotPerTick = (attacker.unit.statIntelligence * (1.2 + 0.2 * rank))
        .toInt()
        .clamp(4, 120);
    final duration = 4.0 + 0.5 * (rank - 1);

    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal(initial);
      ImpactVisuals.play(game, g.position, 'Plant', scale: 0.6);
    }

    game.world.add(
      TimerComponent(
        period: 0.8,
        repeat: true,
        onTick: () {
          for (final g in game.guardians) {
            if (g.isDead) continue;
            g.unit.heal(hotPerTick);
          }
        },
        removeOnFinish: true,
      )..timer.limit = duration,
    );
  }

  /// Poison Kin – "Toxic Benediction":
  /// Heal team, poison enemies near orb.
  static void _poisonBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal((baseHeal * 0.7).toInt());
      ImpactVisuals.play(game, g.position, 'Poison', scale: 0.5);
    }

    final orbPos = game.orb.position.clone();
    final enemies = game.getEnemiesInRange(orbPos, 260.0);
    for (final e in enemies) {
      e.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick:
              (attacker.unit.statIntelligence * (1.0 + 0.2 * rank)).toInt() + 3,
          ticksRemaining: 8 + rank,
          tickInterval: 0.5,
        ),
      );
    }
  }

  // ─────────────────────────────
  //  EARTH / MUD / CRYSTAL
  // ─────────────────────────────

  /// Earth Kin – "Bulwark Prayer":
  /// Big heal to lowest HP + decent heal to others.
  static void _earthBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final living = game.guardians.where((g) => !g.isDead).toList();
    if (living.isEmpty) return;

    living.sort((a, b) => a.unit.hpPercent.compareTo(b.unit.hpPercent));
    final focus = living.first;

    final focusHeal = (baseHeal * (1.4 + 0.1 * (rank - 1))).toInt();
    final othersHeal = (baseHeal * 0.6).toInt();

    focus.unit.heal(focusHeal);
    ImpactVisuals.play(game, focus.position, 'Earth', scale: 0.8);

    for (final g in living) {
      if (g == focus) continue;
      g.unit.heal(othersHeal);
    }
  }

  /// Mud Kin – "Marsh Shelter":
  /// Heal + slow zone around orb.
  static void _mudBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal((baseHeal * 0.7).toInt());
      ImpactVisuals.play(game, g.position, 'Mud', scale: 0.5);
    }

    final orbPos = game.orb.position.clone();
    final radius = 260.0;
    final duration = 4.5 + 0.4 * (rank - 1);

    final zone = CircleComponent(
      radius: radius,
      position: orbPos,
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
          final enemies = game.getEnemiesInRange(orbPos, radius);
          for (final e in enemies) {
            final pushBack =
                (e.targetOrb.position - e.position).normalized() * -10.0;
            e.position += pushBack;
          }
        },
      ),
    );

    zone.add(RemoveEffect(delay: duration));
    game.world.add(zone);
  }

  /// Crystal Kin – "Prismatic Aegis":
  /// Heal + shard pulses from orb.
  static void _crystalBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal((baseHeal * 0.8).toInt());
      ImpactVisuals.play(game, g.position, 'Crystal', scale: 0.7);
    }

    final center = game.orb.position.clone();
    final color = SurvivalAttackManager.getElementColor('Crystal');
    final pulses = 2 + rank;

    for (int p = 0; p < pulses; p++) {
      Future.delayed(Duration(milliseconds: p * 250), () {
        final shardCount = 5 + rank;
        final dmg = (calcDmg(attacker, null) * (0.6 + 0.1 * rank))
            .toInt()
            .clamp(4, 180);
        for (int i = 0; i < shardCount; i++) {
          final angle = (2 * pi * i) / shardCount;
          final targetPos =
              center + Vector2(cos(angle), sin(angle)) * (220.0 + 20.0 * rank);

          final staticTarget = PositionComponent(position: targetPos);
          game.world.add(staticTarget);
          game.spawnAlchemyProjectile(
            start: center,
            target: staticTarget,
            damage: dmg,
            color: color,
            shape: ProjectileShape.shard,
            speed: 2.2,
            isEnemy: false,
            onHit: () {
              final victims = game.getEnemiesInRange(staticTarget.position, 45);
              for (final v in victims) {
                v.takeDamage(dmg);
              }
              staticTarget.removeFromParent();
            },
          );
        }
      });
    }
  }

  // ─────────────────────────────
  //  AIR / DUST / LIGHTNING
  // ─────────────────────────────

  /// Air Kin – "Wind of Retreat":
  /// Heal + push enemies away from orb.
  static void _airBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal((baseHeal * 0.7).toInt());
      ImpactVisuals.play(game, g.position, 'Air', scale: 0.7);
    }

    final center = game.orb.position.clone();
    final radius = 260.0;
    final enemies = game.getEnemiesInRange(center, radius);
    for (final e in enemies) {
      final dir = (e.position - center).normalized();
      e.add(
        MoveEffect.by(
          dir * (150.0 + 20.0 * rank),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
    }
  }

  /// Dust Kin – "Dust of Confusion":
  /// Heal + jitter enemies near orb.
  static void _dustBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final rng = Random();
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal((baseHeal * 0.6).toInt());
      ImpactVisuals.play(game, g.position, 'Dust', scale: 0.6);
    }

    final center = game.orb.position.clone();
    final radius = 260.0;
    final enemies = game.getEnemiesInRange(center, radius);
    for (final e in enemies) {
      final offset = Vector2(
        (rng.nextDouble() - 0.5) * (24 + 4 * rank),
        (rng.nextDouble() - 0.5) * (24 + 4 * rank),
      );
      e.position += offset;
    }
  }

  /// Lightning Kin – "Thunder Blessing":
  /// Heal + chain lightning from orb.
  static void _lightningBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal((baseHeal * 0.7).toInt());
      ImpactVisuals.play(game, g.position, 'Lightning', scale: 0.6);
    }

    final center = game.orb.position.clone();
    final enemies = game.getEnemiesInRange(center, 260.0);
    final rng = Random();
    final maxChains = 2 + rank;

    for (final src in enemies) {
      final nearby = game
          .getEnemiesInRange(src.position, 220)
          .where((e) => e != src);
      final list = nearby.toList();
      if (list.isEmpty) continue;

      final chains = min(maxChains, list.length);
      for (int i = 0; i < chains; i++) {
        final target = list[rng.nextInt(list.length)];
        final dmg = (calcDmg(attacker, target) * (0.7 + 0.1 * rank))
            .toInt()
            .clamp(4, 180);

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

  /// Spirit Kin – "Soul Chorus":
  /// Heal + extra damage around each guardian.
  static void _spiritBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final dmg = (calcDmg(attacker, null) * (0.7 + 0.1 * rank)).toInt().clamp(
      4,
      200,
    );
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal((baseHeal * 0.7).toInt());
      ImpactVisuals.play(game, g.position, 'Spirit', scale: 0.7);

      final enemies = game.getEnemiesInRange(g.position, 200);
      for (final e in enemies) {
        e.takeDamage(dmg);
      }
    }
  }

  /// Dark Kin – "Shadow Pact":
  /// Big heal to caster + orb, small to others; damages enemies near orb.
  static void _darkBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final selfBoost = (baseHeal * (1.3 + 0.1 * (rank - 1))).toInt();
    attacker.unit.heal(selfBoost);
    game.orb.heal(selfBoost);
    ImpactVisuals.play(game, attacker.position, 'Dark', scale: 1.0);

    final othersHeal = (baseHeal * 0.4).toInt();
    for (final g in game.guardians) {
      if (g.isDead || g == attacker) continue;
      g.unit.heal(othersHeal);
    }

    final center = game.orb.position.clone();
    final enemies = game.getEnemiesInRange(center, 260.0);
    final dmg = (calcDmg(attacker, null) * (0.8 + 0.15 * rank)).toInt().clamp(
      4,
      220,
    );
    for (final e in enemies) {
      e.takeDamage(dmg);
      ImpactVisuals.play(game, e.position, 'Dark', scale: 0.8);
    }
  }

  /// Light Kin – "Holy Nova":
  /// Full team heal + big orb heal + AoE damage around orb.
  static void _lightBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    final teamHeal = (baseHeal * (1.2 + 0.1 * (rank - 1))).toInt().clamp(
      10,
      9999,
    );
    final orbHeal = (baseHeal * (1.4 + 0.1 * (rank - 1))).toInt().clamp(
      10,
      9999,
    );

    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal(teamHeal);
      ImpactVisuals.play(game, g.position, 'Light', scale: 0.8);
    }
    game.orb.heal(orbHeal);

    final enemies = game.getEnemiesInRange(game.orb.position, 400);
    final dmg = (calcDmg(attacker, null) * (1.4 + 0.2 * rank)).toInt().clamp(
      10,
      400,
    );
    for (final e in enemies) {
      e.takeDamage(dmg);
      ImpactVisuals.play(game, e.position, 'Light', scale: 1.2);
    }
    SurvivalAttackManager.triggerScreenShake(game, 5.0 + rank * 0.5);
  }

  // Fallback generic
  static void _genericBlessing(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    int baseHeal,
  ) {
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.heal((baseHeal * 0.8).toInt());
    }
  }
}
