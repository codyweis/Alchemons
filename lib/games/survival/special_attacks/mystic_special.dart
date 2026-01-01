import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/components/survival_attacks.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/enemies/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// MYSTIC FAMILY - ORBITAL SWARM MECHANIC
/// Tier 0: Locked
/// Tier 1: Summon a few orbitals that seek enemies
/// Tier 2: More orbitals, stronger hits
/// Tier 3+: SWARM – many orbitals, big damage
class MysticOrbitalMechanic {
  static void execute(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    HoardEnemy? target,
    String element,
  ) {
    final rawRank = game.getSpecialAbilityRank(attacker.unit.id, element);
    final int tier = rawRank.clamp(0, 3);

    // Tier 0 → locked
    if (tier <= 0) return;

    final bool isSwarm = tier >= 3;

    // Orbital count per tier:
    // T1: 2, T2: 3, T3+: 4 (then doubled for swarm)
    final int baseCount;
    switch (tier) {
      case 1:
        baseCount = 2;
        break;
      case 2:
        baseCount = 3;
        break;
      default: // tier 3+
        baseCount = 4;
        break;
    }

    final int count = isSwarm ? baseCount * 2 : baseCount;

    // Spawn them around attacker in a ring
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi;
      final offset = Vector2(cos(angle), sin(angle)) * 60;

      // Faster stagger on higher tiers
      final int delayStep;
      switch (tier) {
        case 1:
          delayStep = 200;
          break;
        case 2:
          delayStep = 120;
          break;
        default: // tier 3+
          delayStep = 60;
          break;
      }

      final delayMs = i * delayStep;

      _spawnOrbital(
        game: game,
        attacker: attacker,
        element: element,
        tier: tier,
        offset: offset,
        delayMs: delayMs,
      );
    }
  }

  static void _spawnOrbital({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int tier,
    required Vector2 offset,
    required int delayMs,
  }) {
    final color = SurvivalAttackManager.getElementColor(element);

    final orb = AlchemyProjectile(
      start: attacker.position + offset,
      end: attacker.position + offset,
      color: color,
      onHit: () {},
      shape: ProjectileShape.star,
    );

    game.world.add(orb);

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (orb.parent == null) return;

      final t = game.getNearestEnemy(orb.position, 600);
      if (t == null) {
        orb.removeFromParent();
        return;
      }

      // Damage scales with tier
      final double dmgMult;
      switch (tier) {
        case 1:
          dmgMult = 1.2;
          break;
        case 2:
          dmgMult = 1.5;
          break;
        default: // tier 3+
          dmgMult = 1.9;
          break;
      }

      final dmg = (calcDmg(attacker, t) * dmgMult).toInt().clamp(5, 400);

      orb.add(
        MoveEffect.to(
          t.position,
          EffectController(duration: 0.4, curve: Curves.easeIn),
          onComplete: () {
            if (t.isDead) {
              orb.removeFromParent();
              return;
            }

            t.takeDamage(dmg);
            ImpactVisuals.play(game, t.position, element);

            _applyElementalOrbitalHit(
              game: game,
              attacker: attacker,
              element: element,
              tier: tier,
              target: t,
              baseDamage: dmg,
            );

            orb.removeFromParent();
          },
        ),
      );
    });
  }

  // ─────────────────────────────
  //  ELEMENT ROUTER
  // ─────────────────────────────

  static void _applyElementalOrbitalHit({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int tier,
    required HoardEnemy target,
    required int baseDamage,
  }) {
    switch (element) {
      // 🔥 FIRE / LAVA / BLOOD
      case 'Fire':
        _fireOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Lava':
        _lavaOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Blood':
        _bloodOrb(game, attacker, tier, target, baseDamage);
        break;

      // 💧 WATER / ICE / STEAM
      case 'Water':
        _waterOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Ice':
        _iceOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Steam':
        _steamOrb(game, attacker, tier, target, baseDamage);
        break;

      // 🌿 PLANT / POISON
      case 'Plant':
        _plantOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Poison':
        _poisonOrb(game, attacker, tier, target, baseDamage);
        break;

      // 🌍 EARTH / MUD / CRYSTAL
      case 'Earth':
        _earthOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Mud':
        _mudOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Crystal':
        _crystalOrb(game, attacker, tier, target, baseDamage);
        break;

      // 🌬️ AIR / DUST / LIGHTNING
      case 'Air':
        _airOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Dust':
        _dustOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Lightning':
        _lightningOrb(game, attacker, tier, target, baseDamage);
        break;

      // 🌗 SPIRIT / DARK / LIGHT
      case 'Spirit':
        _spiritOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Dark':
        _darkOrb(game, attacker, tier, target, baseDamage);
        break;
      case 'Light':
        _lightOrb(game, attacker, tier, target, baseDamage);
        break;

      default:
        _genericOrb(game, attacker, tier, target, baseDamage);
        break;
    }
  }

  // ─────────────────────────────
  //  FIRE / LAVA / BLOOD
  // ─────────────────────────────

  /// Fire Mystic – small burn AoE on hit
  static void _fireOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 80.0 + 8.0 * tier;
    final burn = (attacker.unit.statIntelligence * (1.4 + 0.3 * tier))
        .toInt()
        .clamp(4, 180);
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      e.takeDamage(burn);
      ImpactVisuals.play(game, e.position, 'Fire', scale: 0.7);
    }
  }

  /// Lava Mystic – big explosion with knockback
  static void _lavaOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 100.0 + 10.0 * tier;
    final dmg = (baseDamage * (1.2 + 0.15 * tier)).toInt();
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      e.takeDamage(dmg);
      final dir = (e.position - target.position).normalized();
      e.position += dir * (50.0 + 10.0 * tier);
    }
    ImpactVisuals.playExplosion(game, target.position, 'Lava', radius);
  }

  /// Blood Mystic – heavy lifesteal on hit
  static void _bloodOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final heal = (baseDamage * (0.35 + 0.07 * tier)).toInt();
    attacker.unit.heal(heal);
    ImpactVisuals.play(game, attacker.position, 'Blood', scale: 0.9);
  }

  // ─────────────────────────────
  //  WATER / ICE / STEAM
  // ─────────────────────────────

  /// Water Mystic – heal nearby allies on hit
  static void _waterOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final heal = (attacker.unit.statIntelligence * (2.8 + 0.6 * tier))
        .toInt()
        .clamp(5, 160);
    for (final g in game.guardians) {
      if (g.isDead) continue;
      if (g.position.distanceTo(target.position) <= 180) {
        g.unit.heal(heal);
        ImpactVisuals.play(game, g.position, 'Water', scale: 0.6);
      }
    }
  }

  /// Ice Mystic – strong slow around hit
  static void _iceOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 90.0 + 8.0 * tier;
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      final pushBack = (e.targetOrb.position - e.position).normalized() * -12.0;
      e.position += pushBack;
      ImpactVisuals.play(game, e.position, 'Ice', scale: 0.5);
    }
  }

  /// Steam Mystic – chip dmg + orb heal
  static void _steamOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 80.0 + 6.0 * tier;
    final dmg = (attacker.unit.statIntelligence * (1.0 + 0.25 * tier))
        .toInt()
        .clamp(3, 120);
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      e.takeDamage(dmg);
    }
    if (enemies.isNotEmpty) {
      game.orb.heal(3 + tier); // small sustain
    }
  }

  // ─────────────────────────────
  //  PLANT / POISON
  // ─────────────────────────────

  /// Plant Mystic – seeds a small thorn zone at impact
  static void _plantOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 70.0 + 6.0 * tier;
    final dps = (attacker.unit.statIntelligence * (1.3 + 0.25 * tier))
        .toInt()
        .clamp(3, 160);
    final duration = 3.5 + 0.5 * (tier - 1);

    final zone = CircleComponent(
      radius: radius,
      position: target.position.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..color = SurvivalAttackManager.getElementColor(
          'Plant',
        ).withOpacity(0.3)
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

  /// Poison Mystic – heavy poison on hit target + mild AoE
  static void _poisonOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    target.unit.applyStatusEffect(
      SurvivalStatusEffect(
        type: 'Poison',
        damagePerTick:
            (attacker.unit.statIntelligence * (1.0 + 0.25 * tier)).toInt() + 4,
        ticksRemaining: 6 + tier,
        tickInterval: 0.5,
      ),
    );

    final radius = 80.0 + 5.0 * tier;
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      if (e == target) continue;
      e.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Poison',
          damagePerTick:
              (attacker.unit.statIntelligence * (0.7 + 0.15 * tier)).toInt() +
              2,
          ticksRemaining: 4 + tier,
          tickInterval: 0.5,
        ),
      );
    }
  }

  // ─────────────────────────────
  //  EARTH / MUD / CRYSTAL
  // ─────────────────────────────

  /// Earth Mystic – small AoE dmg + shield-like heal to attacker
  static void _earthOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 80.0 + 6.0 * tier;
    final dmg = (attacker.unit.statIntelligence * (1.3 + 0.25 * tier))
        .toInt()
        .clamp(4, 180);
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      e.takeDamage(dmg);
    }

    final shield = (attacker.unit.maxHp * (0.05 + 0.03 * (tier - 1)))
        .toInt()
        .clamp(10, 260);
    attacker.unit.heal(shield);
    ImpactVisuals.play(game, attacker.position, 'Earth', scale: 0.8);
  }

  /// Mud Mystic – small slow puddle at impact
  static void _mudOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 80.0 + 8.0 * tier;
    final duration = 3.0 + 0.5 * (tier - 1);

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
          final enemies = game.getEnemiesInRange(zone.position, radius);
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

  /// Crystal Mystic – mini-chain shards from hit target
  static void _crystalOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final color = SurvivalAttackManager.getElementColor('Crystal');
    final nearby = game
        .getEnemiesInRange(target.position, 220)
        .where((e) => e != target);
    final list = nearby.toList();
    if (list.isEmpty) return;

    final rng = Random();
    final chains = min(2 + tier, list.length);
    for (int i = 0; i < chains; i++) {
      final t2 = list[rng.nextInt(list.length)];
      final dmg = (baseDamage * (0.7 + 0.1 * tier)).toInt().clamp(4, 160);

      game.spawnAlchemyProjectile(
        start: target.position,
        target: t2,
        damage: dmg,
        color: color,
        shape: ProjectileShape.shard,
        speed: 2.6,
        isEnemy: false,
        onHit: () {
          t2.takeDamage(dmg);
          ImpactVisuals.play(game, t2.position, 'Crystal', scale: 0.7);
        },
      );
    }
  }

  // ─────────────────────────────
  //  AIR / DUST / LIGHTNING
  // ─────────────────────────────

  /// Air Mystic – strong knockback from hit target
  static void _airOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 90.0 + 8.0 * tier;
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      final dir = (e.position - target.position).normalized();
      e.add(
        MoveEffect.by(
          dir * (100.0 + 25.0 * tier),
          EffectController(duration: 0.25, curve: Curves.easeOut),
        ),
      );
    }
  }

  /// Dust Mystic – confuse enemies at impact
  static void _dustOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final rng = Random();
    final radius = 80.0 + 6.0 * tier;
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      final offset = Vector2(
        (rng.nextDouble() - 0.5) * (24 + 4 * tier),
        (rng.nextDouble() - 0.5) * (24 + 4 * tier),
      );
      e.position += offset;
    }
  }

  /// Lightning Mystic – chain lightning from impact target
  static void _lightningOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final nearby = game
        .getEnemiesInRange(target.position, 260)
        .where((e) => e != target);
    final list = nearby.toList();
    if (list.isEmpty) return;

    final rng = Random();
    final chains = min(2 + tier, list.length);
    for (int i = 0; i < chains; i++) {
      final t2 = list[rng.nextInt(list.length)];
      final dmg = (baseDamage * (0.7 + 0.1 * tier)).toInt().clamp(4, 180);

      game.spawnAlchemyProjectile(
        start: target.position,
        target: t2,
        damage: dmg,
        color: SurvivalAttackManager.getElementColor('Lightning'),
        shape: ProjectileShape.bolt,
        speed: 3.0,
        isEnemy: false,
        onHit: () {
          t2.takeDamage(dmg);
          ImpactVisuals.play(game, t2.position, 'Lightning', scale: 0.7);
        },
      );
    }
  }

  // ─────────────────────────────
  //  SPIRIT / DARK / LIGHT
  // ─────────────────────────────

  /// Spirit Mystic – spectral splash dmg + small heal to caster
  static void _spiritOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 90.0 + 8.0 * tier;
    final dmg = (baseDamage * (0.8 + 0.1 * tier)).toInt().clamp(4, 200);
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      e.takeDamage(dmg);
      ImpactVisuals.play(game, e.position, 'Spirit', scale: 0.9);
    }

    final heal = (dmg * 0.3).toInt();
    attacker.unit.heal(heal);
  }

  /// Dark Mystic – extra drain on hit
  static void _darkOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final drain = (baseDamage * (0.4 + 0.1 * tier)).toInt();
    target.takeDamage(drain);
    attacker.unit.heal((drain * 0.8).toInt());
    ImpactVisuals.play(game, target.position, 'Dark', scale: 0.9);
  }

  /// Light Mystic – splash heal + burn to enemies
  static void _lightOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 100.0 + 8.0 * tier;
    final heal = (attacker.unit.statIntelligence * (3.2 + 0.6 * tier))
        .toInt()
        .clamp(5, 200);
    final enemies = game.getEnemiesInRange(target.position, radius);

    for (final g in game.guardians) {
      if (g.isDead) continue;
      if (g.position.distanceTo(target.position) <= radius) {
        g.unit.heal(heal);
        ImpactVisuals.play(game, g.position, 'Light', scale: 0.7);
      }
    }

    final burn = (attacker.unit.statIntelligence * (1.3 + 0.25 * tier))
        .toInt()
        .clamp(4, 180);
    for (final e in enemies) {
      e.takeDamage(burn);
    }
  }

  // Fallback
  static void _genericOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final radius = 80.0;
    final enemies = game.getEnemiesInRange(target.position, radius);
    for (final e in enemies) {
      e.takeDamage((baseDamage * 0.7).toInt());
    }
  }
}
