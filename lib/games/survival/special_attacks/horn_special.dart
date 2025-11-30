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

/// HORN FAMILY - NOVA MECHANIC
/// Rank tiers (from getSpecialAbilityRank):
///   0 = base non-elemental nova only
///   1 = unlock elemental rider
///   2 = stronger rider (via scaling numbers)
///   3 = cataclysmic / massive nova + big rider upgrades
class HornNovaMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    // rank is now 0–3
    final rank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final color = SurvivalAttackManager.getElementColor(element);

    // Slightly lower damage (since Horn = tank / CC),
    // but still scales.
    final baseRadius = 200.0 + rank * 20;
    final baseDmg = (calcDmg(attacker, null) * (1.6 + 0.25 * rank)).toInt();

    // Much stronger base knockback
    final baseKnockback = 200.0 + rank * 30;

    final isCataclysmic = rank >= 3;
    final radius = isCataclysmic ? baseRadius * 2 : baseRadius;
    final damage = isCataclysmic ? (baseDmg * 1.5).toInt() : baseDmg;

    // Slightly stronger knockback for cataclysmic
    double knockback = isCataclysmic ? baseKnockback * 1.7 : baseKnockback;

    // Earthhorn special: extra shove
    if (element == 'Earth') {
      knockback *= 1.25;
    }

    // Visual: Expanding ring, but keep the radius as the gameplay radius
    final ring = CircleComponent(
      radius: radius,
      position: attacker.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = color.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCataclysmic ? 12 : 8,
    );

    // Just a subtle pulse instead of scaling 2.5x the radius
    ring.add(
      ScaleEffect.to(
        Vector2.all(1.15),
        EffectController(duration: 0.25, curve: Curves.easeOut),
      ),
    );
    ring.add(OpacityEffect.fadeOut(EffectController(duration: 0.3)));
    ring.add(RemoveEffect(delay: 0.31));
    game.world.add(ring);

    // Screen shake
    SurvivalAttackManager.triggerScreenShake(game, isCataclysmic ? 10.0 : 5.0);

    final victims = game.getEnemiesInRange(attacker.position, radius);
    print('[HORN] victims in radius=$radius -> ${victims.length}');
    for (final v in victims) {
      final dist = v.position
          .distanceTo(attacker.position)
          .clamp(0.001, radius);
      final t = dist / radius; // 0 at center, 1 at edge

      // Damage falloff (kept soft)
      final dmgFalloff = 1.0 - t * 0.3;

      // ✅ New: clamp knockback falloff so even edge enemies move visibly.
      //  - Close enemies: huge shove
      //  - Edge enemies: still at least 30–40% of the base
      final rawFalloff = (1.0 - t) * (1.0 - t);
      final knockFalloff = max(rawFalloff, 0.35);

      v.takeDamage((damage * dmgFalloff).toInt());

      var dir = (v.position - attacker.position);
      if (dir.length2 < 0.0001) {
        dir = Vector2(1, 0);
      }
      dir.normalize();

      v.add(
        MoveEffect.by(
          dir * knockback * knockFalloff,
          EffectController(
            duration: 0.2, // a bit snappier
            curve: Curves.easeOut,
          ),
        ),
      );

      ImpactVisuals.play(game, v.position, element, scale: 0.6);
    }

    // Tanky shield (still good, maybe even a hair stronger)
    final shieldAmount = (attacker.unit.maxHp * (0.18 + 0.05 * rank))
        .toInt()
        .clamp(40, 600);
    attacker.unit.shieldHp = (attacker.unit.shieldHp ?? 0) + shieldAmount;

    // Elemental riders from rank 1+
    if (rank >= 1) {
      _applyElementalNova(
        game: game,
        attacker: attacker,
        element: element,
        rank: rank,
        center: attacker.position,
        radius: radius,
        enemiesHit: victims,
        baseDamage: damage,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ELEMENT ROUTER
  // ═══════════════════════════════════════════════════════════════════════════

  static void _applyElementalNova({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int rank, // 1–3 when called
    required Vector2 center,
    required double radius,
    required List<HoardEnemy> enemiesHit,
    required int baseDamage,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireNova(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Lava':
        _lavaNova(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Blood':
        _bloodNova(game, attacker, rank, center, enemiesHit, baseDamage);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterNova(game, attacker, rank, center, radius);
        break;
      case 'Ice':
        _iceNova(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Steam':
        _steamNova(game, attacker, rank, center, radius, enemiesHit);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantNova(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Poison':
        _poisonNova(game, attacker, rank, center, enemiesHit);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthNova(game, attacker, rank, center, radius);
        break;
      case 'Mud':
        _mudNova(game, attacker, rank, center, radius);
        break;
      case 'Crystal':
        _crystalNova(game, attacker, rank, center, enemiesHit);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airNova(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Dust':
        _dustNova(game, attacker, rank, center, radius, enemiesHit);
        break;
      case 'Lightning':
        _lightningNova(game, attacker, rank, center, enemiesHit);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritNova(game, attacker, rank, center, enemiesHit, baseDamage);
        break;
      case 'Dark':
        _darkNova(game, attacker, rank, center, enemiesHit);
        break;
      case 'Light':
        _lightNova(game, attacker, rank, center, radius);
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FIRE / LAVA / BLOOD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fire Nova - Ignites all enemies hit
  static void _fireNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final burnDmg = (attacker.unit.statIntelligence * (2.0 + 0.3 * rank))
        .toInt()
        .clamp(3, 120);

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Burn',
          damagePerTick: burnDmg,
          ticksRemaining: 4 + rank,
          tickInterval: 0.5,
        ),
      );
    }

    // Tier 3: Leave fire ring (was rank >= 5)
    if (rank >= 3) {
      final fireRing = CircleComponent(
        radius: radius * 0.8,
        position: center,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.deepOrange.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      fireRing.add(
        TimerComponent(
          period: 0.5,
          repeat: true,
          onTick: () {
            final ringVictims = game.getEnemiesInRange(center, radius * 0.8);
            for (final v in ringVictims) {
              v.takeDamage(burnDmg);
            }
          },
        ),
      );

      fireRing.add(RemoveEffect(delay: 3.0));
      game.world.add(fireRing);
    }
  }

  /// Lava Nova - Massive damage and extended knockback
  static void _lavaNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Extra knockback
    for (final v in victims) {
      final dir = (v.position - center).normalized();
      v.add(
        MoveEffect.by(
          dir * (50.0 + 15.0 * rank),
          EffectController(duration: 0.15),
        ),
      );
    }

    // Extra damage
    final extraDmg = (calcDmg(attacker, null) * (0.4 + 0.1 * rank)).toInt();
    for (final v in victims) {
      v.takeDamage(extraDmg);
    }
  }

  /// Blood Nova - Massive lifesteal from all enemies
  static void _bloodNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
    int baseDamage,
  ) {
    int totalDrained = 0;

    for (final v in victims) {
      final drain = (baseDamage * (0.2 + 0.05 * rank)).toInt();
      v.takeDamage(drain);
      totalDrained += drain;
    }

    // Heal self heavily
    attacker.unit.heal((totalDrained * 0.5).toInt());
    ImpactVisuals.playHeal(game, attacker.position);

    // Heal orb
    game.orb.heal((totalDrained * 0.25).toInt());

    // Tier 3: Also heal nearby guardians (was rank >= 5)
    if (rank >= 3) {
      final allies = game.getGuardiansInRange(center: center, range: 300);
      for (final g in allies) {
        if (g != attacker) {
          g.unit.heal((totalDrained * 0.15).toInt());
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  WATER / ICE / STEAM
  // ═══════════════════════════════════════════════════════════════════════════

  /// Water Nova - Tidal burst that heals allies
  static void _waterNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final healAmount = (attacker.unit.statIntelligence * (3.0 + 0.6 * rank))
        .toInt()
        .clamp(10, 200);

    // Heal all guardians in range
    final allies = game.getGuardiansInRange(center: center, range: radius);
    for (final g in allies) {
      g.unit.heal(healAmount);
      ImpactVisuals.playHeal(game, g.position, scale: 0.7);
    }

    // Heal orb if in range
    if (game.orb.position.distanceTo(center) <= radius) {
      game.orb.heal((healAmount * 0.5).toInt());
    }
  }

  /// Ice Nova - Freezing burst with heavy slow
  static void _iceNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Apply slow zone
    final slowDuration = 10.0 + 0.4 * rank;
    final slowStrength = 50.0 + 4.0 * rank;

    final slowZone = CircleComponent(
      radius: radius * 0.9,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.cyanAccent.withOpacity(0.2),
    );

    slowZone.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final zoneVictims = game.getEnemiesInRange(center, radius * 0.9);
          for (final v in zoneVictims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    slowZone.add(RemoveEffect(delay: slowDuration));
    game.world.add(slowZone);

    // Tier 3: Brief freeze on initial hit (was rank >= 5)
    if (rank >= 3) {
      for (final v in victims) {
        v.add(MoveEffect.by(Vector2.zero(), EffectController(duration: 1.0)));
      }
    }
  }

  /// Steam Nova - Scalding burst with confusion
  static void _steamNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();
    final scaldDmg = (calcDmg(attacker, null) * (0.3 + 0.08 * rank)).toInt();

    for (final v in victims) {
      v.takeDamage(scaldDmg);

      // Confusion: scatter movement
      final randomDir = Vector2(
        (rng.nextDouble() - 0.5) * 2,
        (rng.nextDouble() - 0.5) * 2,
      ).normalized();

      v.add(
        MoveEffect.by(
          randomDir * (40.0 + 10.0 * rank),
          EffectController(duration: 0.3),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PLANT / POISON
  // ═══════════════════════════════════════════════════════════════════════════

  /// Plant Nova - Thorn burst with root effect
  static void _plantNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final thornDmg = (attacker.unit.statIntelligence * (1.0 + 0.2 * rank))
        .toInt()
        .clamp(2, 80);

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

    // Root zone
    final rootDuration = 2.0 + 0.3 * rank;
    final rootStrength = 12.0 + 3.0 * rank;

    final rootZone = CircleComponent(
      radius: radius * 0.7,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green.withOpacity(0.2),
    );

    rootZone.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final zoneVictims = game.getEnemiesInRange(center, radius * 0.7);
          for (final v in zoneVictims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -rootStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    rootZone.add(RemoveEffect(delay: rootDuration));
    game.world.add(rootZone);
  }

  /// Poison Nova - Spreads heavy poison
  static void _poisonNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final poisonDmg = (attacker.unit.statIntelligence * (1.2 + 0.25 * rank))
        .toInt()
        .clamp(3, 100);

    for (final v in victims) {
      v.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick: poisonDmg,
          ticksRemaining: 8 + rank,
          tickInterval: 0.4,
        ),
      );
      ImpactVisuals.play(game, v.position, 'Poison', scale: 0.7);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EARTH / MUD / CRYSTAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Earth Nova - Extra tough shield and AoE
  static void _earthNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    // Extra shield
    final extraShield = (attacker.unit.maxHp * (0.1 + 0.03 * rank)).toInt();
    attacker.unit.shieldHp = (attacker.unit.shieldHp ?? 0) + extraShield;

    // Shield nearby guardians
    final allies = game.getGuardiansInRange(center: center, range: radius);
    for (final g in allies) {
      g.unit.shieldHp = (g.unit.shieldHp ?? 0) + (extraShield * 0.4).toInt();
    }

    // Tier 3: Taunt effect (visual for now) (was rank >= 5)
    if (rank >= 3) {
      final tauntRing = CircleComponent(
        radius: 50,
        position: attacker.position.clone(),
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.brown.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      tauntRing.add(RemoveEffect(delay: 3.0));
      game.world.add(tauntRing);
    }
  }

  /// Mud Nova - Heavy slow explosion
  static void _mudNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final slowDuration = 4.0 + 0.5 * rank;
    final slowStrength = 25.0 + 5.0 * rank;

    final mudZone = CircleComponent(
      radius: radius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.brown.shade600.withOpacity(0.3),
    );

    mudZone.add(
      TimerComponent(
        period: 0.2,
        repeat: true,
        onTick: () {
          final victims = game.getEnemiesInRange(center, radius);
          for (final v in victims) {
            final pushBack =
                (v.targetOrb.position - v.position).normalized() *
                -slowStrength;
            v.position += pushBack;
          }
        },
      ),
    );

    mudZone.add(RemoveEffect(delay: slowDuration));
    game.world.add(mudZone);
  }

  /// Crystal Nova - Shatters into homing shards
  static void _crystalNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final shardCount = 6 + rank * 2;
    final shardDmg = (calcDmg(attacker, null) * (0.4 + 0.08 * rank)).toInt();

    final rng = Random();
    final allEnemies = game.getEnemiesInRange(center, 500);

    for (int i = 0; i < shardCount; i++) {
      if (allEnemies.isEmpty) break;
      final target = allEnemies[rng.nextInt(allEnemies.length)];

      Future.delayed(Duration(milliseconds: i * 50), () {
        if (target.isDead) return;

        game.spawnAlchemyProjectile(
          start: center,
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  AIR / DUST / LIGHTNING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Air Nova - Massive knockback with second pulse
  static void _airNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    // Extra knockback
    for (final v in victims) {
      final dir = (v.position - center).normalized();
      v.add(
        MoveEffect.by(
          dir * (80.0 + 20.0 * rank),
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );
    }

    // Tier 3: Second pulse (was rank >= 5)
    if (rank >= 3) {
      Future.delayed(const Duration(milliseconds: 400), () {
        final secondVictims = game.getEnemiesInRange(center, radius * 1.3);
        for (final v in secondVictims) {
          final dir = (v.position - center).normalized();
          v.add(MoveEffect.by(dir * 60.0, EffectController(duration: 0.15)));
        }
        ImpactVisuals.playExplosion(game, center, 'Air', radius * 1.3);
      });
    }
  }

  /// Dust Nova - Blinding burst
  static void _dustNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
    List<HoardEnemy> victims,
  ) {
    final rng = Random();

    for (final v in victims) {
      // Heavy confusion
      final jitter = Vector2(
        (rng.nextDouble() - 0.5) * (40 + 10 * rank),
        (rng.nextDouble() - 0.5) * (40 + 10 * rank),
      );
      v.position += jitter;
    }

    // Dust cloud
    final cloud = CircleComponent(
      radius: radius * 0.8,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.amber.shade300.withOpacity(0.3),
    );

    cloud.add(
      TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          final cloudVictims = game.getEnemiesInRange(center, radius * 0.8);
          for (final v in cloudVictims) {
            final jitter = Vector2(
              (rng.nextDouble() - 0.5) * 15,
              (rng.nextDouble() - 0.5) * 15,
            );
            v.position += jitter;
          }
        },
      ),
    );

    cloud.add(RemoveEffect(delay: 2.0 + 0.3 * rank));
    game.world.add(cloud);
  }

  /// Lightning Nova - Chain lightning from attacker
  static void _lightningNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final chainDmg = (calcDmg(attacker, null) * (0.5 + 0.1 * rank)).toInt();

    for (final v in victims) {
      // Chain from each victim
      final nearby = game
          .getEnemiesInRange(v.position, 200)
          .where((e) => e != v && !victims.contains(e))
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  SPIRIT / DARK / LIGHT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Spirit Nova - Draining burst with lifesteal
  static void _spiritNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
    int baseDamage,
  ) {
    int totalDrained = 0;

    for (final v in victims) {
      final drain = (baseDamage * (0.25 + 0.05 * rank)).toInt();
      v.takeDamage(drain);
      totalDrained += drain;
      ImpactVisuals.play(game, v.position, 'Spirit', scale: 0.7);
    }

    // Heal self
    attacker.unit.heal((totalDrained * 0.4).toInt());
  }

  /// Dark Nova - Execute and bonus vs low HP
  static void _darkNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    List<HoardEnemy> victims,
  ) {
    final executeThreshold = 0.2 + 0.05 * rank;

    for (final v in victims) {
      if (!v.isBoss && v.unit.hpPercent < executeThreshold) {
        v.takeDamage(99999);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 1.3);
      } else if (v.unit.hpPercent < 0.5) {
        // Bonus damage to wounded
        final bonusDmg = (calcDmg(attacker, v) * (0.5 + 0.1 * rank)).toInt();
        v.takeDamage(bonusDmg);
        ImpactVisuals.play(game, v.position, 'Dark', scale: 0.8);
      }
    }
  }

  /// Light Nova - Holy burst that heals team
  static void _lightNova(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int rank,
    Vector2 center,
    double radius,
  ) {
    final healAmount = (attacker.unit.statIntelligence * (4.0 + 0.8 * rank))
        .toInt()
        .clamp(15, 300);

    // Heal all guardians
    for (final g in game.guardians) {
      if (!g.isDead) {
        g.unit.heal(healAmount);
        ImpactVisuals.playHeal(game, g.position, scale: 0.7);
      }
    }

    // Heal orb
    game.orb.heal((healAmount * 0.5).toInt());

    // Tier 3: Cleanse debuffs (was rank >= 5)
    if (rank >= 3) {
      for (final g in game.guardians) {
        g.unit.statusEffects.clear();
      }
    }
  }
}
