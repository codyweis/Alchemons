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
    // T1: 3 orbs, T2: 5 orbs, T3: 7 → doubled for swarm = 14
    final int baseCount;
    switch (tier) {
      case 1:
        baseCount = 3;
        break;
      case 2:
        baseCount = 5;
        break;
      default: // tier 3+
        baseCount = 7;
        break;
    }

    final int count = isSwarm ? baseCount * 2 : baseCount;

    // Spawn them around attacker in a wider ring for visual clarity
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi;

      // Faster stagger on higher tiers
      final int delayStep;
      switch (tier) {
        case 1:
          delayStep = 180;
          break;
        case 2:
          delayStep = 100;
          break;
        default: // tier 3+
          delayStep = 50;
          break;
      }

      final delayMs = i * delayStep;

      _spawnOrbital(
        game: game,
        attacker: attacker,
        element: element,
        tier: tier,
        initialAngle: angle,
        launchDelaySecs: delayMs / 1000.0,
      );
    }
  }

  static void _spawnOrbital({
    required SurvivalHoardGame game,
    required HoardGuardian attacker,
    required String element,
    required int tier,
    required double initialAngle,
    required double launchDelaySecs,
  }) {
    game.world.add(
      _MysticOrb(
        game: game,
        attacker: attacker,
        element: element,
        tier: tier,
        initialAngle: initialAngle,
        launchDelaySecs: launchDelaySecs,
      ),
    );
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
  /// Fire Mystic – Ignite Field: leaves a persistent burning ground zone
  static void _fireOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final zoneRadius = 70.0 + 10.0 * tier;
    final tickDmg = (attacker.unit.statIntelligence * (1.0 + 0.3 * tier))
        .toInt()
        .clamp(4, 120);
    final duration = 2.5 + 0.5 * tier;
    final center = target.position.clone();

    // Persistent fire zone visual
    final zone = CircleComponent(
      radius: zoneRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.orange.withOpacity(0.35),
    );

    int ticks = 0;
    final maxTicks = (duration / 0.4).ceil();
    zone.add(
      TimerComponent(
        period: 0.4,
        repeat: true,
        onTick: () {
          ticks++;
          if (ticks > maxTicks) {
            zone.removeFromParent();
            return;
          }
          final victims = game.getEnemiesInRange(center, zoneRadius);
          for (final e in victims) {
            e.takeDamage(tickDmg);
            e.unit.applyStatusEffect(
              SurvivalStatusEffect(
                type: 'Burn',
                damagePerTick: (tickDmg * 0.4).toInt(),
                ticksRemaining: 2,
                tickInterval: 0.5,
              ),
            );
          }
          ImpactVisuals.play(game, center, 'Fire', scale: 0.6);
        },
      ),
    );
    game.world.add(zone);
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

  /// Blood Mystic – Blood Frenzy: drains life AND boosts all allies' attack speed
  static void _bloodOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    // Lifesteal back to caster
    final heal = (baseDamage * (0.4 + 0.08 * tier)).toInt();
    attacker.unit.heal(heal);
    ImpactVisuals.play(game, attacker.position, 'Blood', scale: 0.9);

    // Frenzy buff: boost ALL allies' attack speed (cooldown_down = faster attacks)
    final buffDuration = 3.0 + 0.5 * tier;
    for (final g in game.guardians) {
      if (g.isDead) continue;
      g.unit.applyStatModifier(
        SurvivalStatModifier(
          type: 'cooldown_down',
          remainingSeconds: buffDuration,
        ),
      );
      ImpactVisuals.play(game, g.position, 'Blood', scale: 0.45);
    }
  }

  // ─────────────────────────────
  //  WATER / ICE / STEAM
  // ─────────────────────────────

  /// Water Mystic – Tidal Pull: yanks all nearby enemies toward the impact point
  /// then heals allies who are close to the vortex center
  static void _waterOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final center = target.position.clone();
    final pullRadius = 200.0 + 20.0 * tier;
    final pullStrength = 130.0 + 20.0 * tier;

    // Pull enemies inward toward center
    final enemies = game.getEnemiesInRange(center, pullRadius);
    for (final e in enemies) {
      final diff = center - e.position;
      final dist = diff.length.clamp(1.0, double.infinity);
      final pull = diff.normalized() * pullStrength * (1.0 - dist / pullRadius);
      e.add(
        MoveEffect.by(
          pull,
          EffectController(duration: 0.3, curve: Curves.easeIn),
        ),
      );
    }
    ImpactVisuals.play(game, center, 'Water', scale: 1.0);

    // Heal allies in range
    final heal = (attacker.unit.statIntelligence * (2.8 + 0.6 * tier))
        .toInt()
        .clamp(5, 160);
    for (final g in game.guardians) {
      if (g.isDead) continue;
      if (g.position.distanceTo(center) <= pullRadius) {
        g.unit.heal(heal);
        ImpactVisuals.playHeal(game, g.position, scale: 0.5);
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
  /// Crystal Mystic – Crystallize: encases target+nearby in a slow cage;
  /// erupts a ring of crystal shards outward damaging anything they pass through
  static void _crystalOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final color = SurvivalAttackManager.getElementColor('Crystal');
    final center = target.position.clone();
    final cageRadius = 100.0 + 12.0 * tier;
    final shardDmg = (baseDamage * (0.6 + 0.1 * tier)).toInt().clamp(4, 150);
    final shardCount = 8 + tier * 2;

    // Heavy slow on all enemies in cage radius
    final caged = game.getEnemiesInRange(center, cageRadius);
    for (final e in caged) {
      e.unit.applyStatusEffect(
        SurvivalStatusEffect(
          type: 'Mudded',
          damagePerTick: (16 + 4 * tier),
          ticksRemaining: 6 + tier,
          tickInterval: 0.25,
        ),
      );
      ImpactVisuals.play(game, e.position, 'Crystal', scale: 0.6);
    }

    // Erupting outward crystal shard ring
    for (int i = 0; i < shardCount; i++) {
      final angle = (i / shardCount) * 2 * pi;
      final dir = Vector2(cos(angle), sin(angle));
      final endPos = center + dir * (cageRadius * 2.5);

      final shard = CircleComponent(
        radius: 5,
        position: center.clone(),
        anchor: Anchor.center,
        paint: Paint()..color = color,
      );
      shard.add(
        MoveEffect.to(
          endPos,
          EffectController(duration: 0.4, curve: Curves.easeOut),
          onComplete: () => shard.removeFromParent(),
        ),
      );

      // Damage any enemy near the shard's path midpoint
      final midPos = center + dir * cageRadius;
      final nearby = game.getEnemiesInRange(midPos, 28);
      for (final e in nearby) {
        e.takeDamage(shardDmg);
      }

      game.world.add(shard);
    }
    ImpactVisuals.play(game, center, 'Crystal', scale: 0.9);
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

  /// Lightning Mystic – Storm Node: drops an overcharge node that fires
  /// rapid lightning bolts at nearby enemies for several seconds
  static void _lightningOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final center = target.position.clone();
    final nodeRadius = 220.0 + 20.0 * tier;
    final boltDmg = (baseDamage * (0.5 + 0.1 * tier)).toInt().clamp(4, 160);
    final nodeLifetime = 3.0 + 0.5 * tier;
    final color = SurvivalAttackManager.getElementColor('Lightning');

    // Visual node
    final node = CircleComponent(
      radius: 10,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = color.withOpacity(0.9),
    );
    node.add(
      ScaleEffect.by(
        Vector2.all(1.3),
        EffectController(duration: 0.15, reverseDuration: 0.15, infinite: true),
      ),
    );

    double elapsed = 0;
    node.add(
      TimerComponent(
        period: 0.35,
        repeat: true,
        onTick: () {
          elapsed += 0.35;
          if (elapsed >= nodeLifetime) {
            node.removeFromParent();
            return;
          }
          final victims = game.getEnemiesInRange(center, nodeRadius);
          if (victims.isEmpty) return;

          // Strike up to (2 + tier) enemies per tick
          final strikes = min(2 + tier, victims.length);
          for (int i = 0; i < strikes; i++) {
            final t2 = victims[i];
            game.spawnAlchemyProjectile(
              start: center,
              target: t2,
              damage: boltDmg,
              color: color,
              shape: ProjectileShape.bolt,
              speed: 4.5,
              isEnemy: false,
              onHit: () {
                t2.takeDamage(boltDmg);
                ImpactVisuals.play(game, t2.position, 'Lightning', scale: 0.6);
              },
            );
          }
        },
      ),
    );
    game.world.add(node);
    ImpactVisuals.play(game, center, 'Lightning', scale: 0.9);
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

  /// Dark Mystic – Soul Fracture: debuffs target's defenses AND scatters
  /// nearby enemies away from the impact in a fear burst
  static void _darkOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    // Drain + lifesteal on the direct target
    final drain = (baseDamage * (0.45 + 0.1 * tier)).toInt();
    target.takeDamage(drain);
    attacker.unit.heal((drain * 0.9).toInt());

    // Defense debuff on the target — takes more damage from all sources
    target.unit.applyStatModifier(
      SurvivalStatModifier(
        type: 'defense_down',
        remainingSeconds: 4.0 + 0.5 * tier,
      ),
    );

    // Fear burst: scatter nearby enemies outward
    final fearRadius = 160.0 + 15.0 * tier;
    final center = target.position.clone();
    final nearby = game.getEnemiesInRange(center, fearRadius);
    for (final e in nearby) {
      if (e == target) continue;
      final dir = (e.position - center).normalized();
      e.add(
        MoveEffect.by(
          dir * (90.0 + 15.0 * tier),
          EffectController(duration: 0.3, curve: Curves.easeOut),
        ),
      );
    }
    ImpactVisuals.play(game, center, 'Dark', scale: 0.9);
  }

  /// Light Mystic – Consecrate: places a persistent holy ground zone that
  /// continuously heals allies standing inside it (HoT zone)
  static void _lightOrb(
    SurvivalHoardGame game,
    HoardGuardian attacker,
    int tier,
    HoardEnemy target,
    int baseDamage,
  ) {
    final center = target.position.clone();
    final zoneRadius = 110.0 + 12.0 * tier;
    final healPerTick = (attacker.unit.statIntelligence * (2.0 + 0.5 * tier))
        .toInt()
        .clamp(5, 150);
    final duration = 4.0 + 0.5 * tier;
    final color = SurvivalAttackManager.getElementColor('Light');

    // Holy ground visual
    final zone = CircleComponent(
      radius: zoneRadius,
      position: center,
      anchor: Anchor.center,
      paint: Paint()..color = color.withOpacity(0.18),
    );
    // Pulsing ring
    final ring = CircleComponent(
      radius: zoneRadius,
      paint: Paint()
        ..color = color.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
      anchor: Anchor.center,
    );
    ring.add(
      ScaleEffect.by(
        Vector2.all(1.08),
        EffectController(duration: 0.6, reverseDuration: 0.6, infinite: true),
      ),
    );
    zone.add(ring);

    int ticks = 0;
    final maxTicks = (duration / 0.5).ceil();
    zone.add(
      TimerComponent(
        period: 0.5,
        repeat: true,
        onTick: () {
          ticks++;
          if (ticks > maxTicks) {
            zone.removeFromParent();
            return;
          }
          for (final g in game.guardians) {
            if (g.isDead) continue;
            if (g.position.distanceTo(center) <= zoneRadius) {
              g.unit.heal(healPerTick);
              ImpactVisuals.playHeal(game, g.position, scale: 0.4);
            }
          }
          // Also applies defense_up buff to guardians in zone
          for (final g in game.guardians) {
            if (g.isDead) continue;
            if (g.position.distanceTo(center) <= zoneRadius) {
              g.unit.applyStatModifier(
                SurvivalStatModifier(type: 'defense_up', remainingSeconds: 1.2),
              );
            }
          }
        },
      ),
    );
    game.world.add(zone);
    ImpactVisuals.play(game, center, 'Light', scale: 1.0);
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

// ─────────────────────────────────────────────────────────────────
//  _MysticOrb — self-steering Flame component
//  Phase 1 (orbit): circles the attacker until launchDelaySecs
//  Phase 2 (flight): homes onto the nearest enemy at high speed
//  On arrival: deals damage + triggers elemental orbital hit
// ─────────────────────────────────────────────────────────────────

class _MysticOrb extends PositionComponent {
  final SurvivalHoardGame game;
  final HoardGuardian attacker;
  final String element;
  final int tier;
  final double launchDelaySecs;

  double _orbitAngle;
  double _age = 0;
  bool _launched = false;
  HoardEnemy? _target;
  int _remainingDamage = -1; // -1 = not yet computed; tracks piercing pool
  final Set<HoardEnemy> _hitTargets = {}; // avoid re-hitting same enemy

  static const double _orbitRadius = 80.0;
  static const double _seekRange = 800.0;
  static const double _moveSpeed = 550.0;

  _MysticOrb({
    required this.game,
    required this.attacker,
    required this.element,
    required this.tier,
    required double initialAngle,
    required this.launchDelaySecs,
  }) : _orbitAngle = initialAngle,
       super(anchor: Anchor.center, size: Vector2.all(20));

  @override
  Future<void> onLoad() async {
    final color = SurvivalAttackManager.getElementColor(element);
    switch (element) {
      case 'Fire':
        _buildFireOrb(color);
        break;
      case 'Lava':
        _buildLavaOrb(color);
        break;
      case 'Blood':
        _buildBloodOrb(color);
        break;
      case 'Water':
        _buildWaterOrb(color);
        break;
      case 'Ice':
        _buildIceOrb(color);
        break;
      case 'Steam':
        _buildSteamOrb(color);
        break;
      case 'Plant':
        _buildPlantOrb(color);
        break;
      case 'Poison':
        _buildPoisonOrb(color);
        break;
      case 'Earth':
        _buildEarthOrb(color);
        break;
      case 'Mud':
        _buildMudOrb(color);
        break;
      case 'Crystal':
        _buildCrystalOrb(color);
        break;
      case 'Air':
        _buildAirOrb(color);
        break;
      case 'Dust':
        _buildDustOrb(color);
        break;
      case 'Lightning':
        _buildLightningOrb(color);
        break;
      case 'Spirit':
        _buildSpiritOrb(color);
        break;
      case 'Dark':
        _buildDarkOrb(color);
        break;
      case 'Light':
        _buildLightOrb(color);
        break;
      default:
        _buildDefaultOrb(color);
        break;
    }
  }

  // ── helpers ──────────────────────────────────────────────────

  /// Large fast-spinning ring, pulsing scale — looks like a fireball
  void _buildFireOrb(Color color) {
    _addGlow(color, 13, 0.7);
    _addCore(Colors.orangeAccent, 5);
    final ring = _addRing(color, 12, 2.0);
    ring.add(
      RotateEffect.by(pi * 2, EffectController(duration: 0.45, infinite: true)),
    );
    add(
      ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(duration: 0.3, reverseDuration: 0.3, infinite: true),
      ),
    );
  }

  /// Huge slow blob, no ring, heavy pulse — molten
  void _buildLavaOrb(Color color) {
    _addGlow(color, 16, 0.65);
    _addGlow(Colors.deepOrange, 9, 0.5);
    _addCore(Colors.yellow.shade700, 4);
    add(
      ScaleEffect.by(
        Vector2.all(1.35),
        EffectController(duration: 0.5, reverseDuration: 0.5, infinite: true),
      ),
    );
  }

  /// Dark with drip-ring — slow counter-rotation
  void _buildBloodOrb(Color color) {
    _addGlow(color, 11, 0.8);
    _addCore(Colors.red.shade900, 5);
    final ring = _addRing(Colors.red.shade900, 10, 2.0);
    ring.add(
      RotateEffect.by(-pi * 2, EffectController(duration: 1.4, infinite: true)),
    );
    add(
      ScaleEffect.by(
        Vector2.all(1.1),
        EffectController(duration: 0.6, reverseDuration: 0.6, infinite: true),
      ),
    );
  }

  /// Gentle ripple — two slow rings expanding
  void _buildWaterOrb(Color color) {
    _addGlow(color, 11, 0.5);
    _addCore(Colors.lightBlue.shade200, 4);
    final r1 = _addRing(color, 9, 1.5);
    r1.add(
      ScaleEffect.by(
        Vector2.all(1.3),
        EffectController(duration: 0.7, reverseDuration: 0.7, infinite: true),
      ),
    );
    final r2 = _addRing(color.withOpacity(0.4), 13, 1.0);
    r2.add(
      ScaleEffect.by(
        Vector2.all(1.2),
        EffectController(duration: 1.0, reverseDuration: 1.0, infinite: true),
      ),
    );
  }

  /// Sharp crystal — fast thin ring, white-blue core
  void _buildIceOrb(Color color) {
    _addGlow(color, 10, 0.5);
    _addCore(Colors.white, 6);
    final ring = _addRing(Colors.white70, 10, 1.2);
    ring.add(
      RotateEffect.by(pi * 2, EffectController(duration: 0.55, infinite: true)),
    );
    final ring2 = _addRing(color, 7, 1.0);
    ring2.add(
      RotateEffect.by(-pi * 2, EffectController(duration: 0.9, infinite: true)),
    );
  }

  /// Hazy large glow, very soft, double fade rings
  void _buildSteamOrb(Color color) {
    _addGlow(color, 16, 0.25);
    _addGlow(Colors.white, 9, 0.3);
    _addCore(Colors.white54, 4);
    final ring = _addRing(Colors.white38, 13, 1.0);
    ring.add(
      RotateEffect.by(pi * 2, EffectController(duration: 1.8, infinite: true)),
    );
    add(
      ScaleEffect.by(
        Vector2.all(1.2),
        EffectController(duration: 0.8, reverseDuration: 0.8, infinite: true),
      ),
    );
  }

  /// Four small petals around the core, slow rotation
  void _buildPlantOrb(Color color) {
    _addGlow(color, 10, 0.5);
    _addCore(Colors.green.shade200, 4);
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2;
      final petal = CircleComponent(
        radius: 4,
        paint: Paint()..color = color.withOpacity(0.8),
        anchor: Anchor.center,
        position: Vector2(cos(angle), sin(angle)) * 9,
      );
      final wrapper = PositionComponent(anchor: Anchor.center);
      wrapper.add(petal);
      wrapper.add(
        RotateEffect.by(
          pi * 2,
          EffectController(duration: 2.0, infinite: true),
        ),
      );
      add(wrapper);
    }
  }

  /// Dark green core, two counter-rotating rings
  void _buildPoisonOrb(Color color) {
    _addGlow(color, 11, 0.65);
    _addCore(Colors.green.shade900, 5);
    final r1 = _addRing(color, 10, 1.8);
    r1.add(
      RotateEffect.by(pi * 2, EffectController(duration: 0.6, infinite: true)),
    );
    final r2 = _addRing(color.withOpacity(0.4), 7, 1.0);
    r2.add(
      RotateEffect.by(-pi * 2, EffectController(duration: 1.1, infinite: true)),
    );
  }

  /// Square outer ring — earthy chunky look
  void _buildEarthOrb(Color color) {
    _addGlow(color, 11, 0.6);
    _addCore(Colors.brown.shade200, 5);
    final box = RectangleComponent(
      size: Vector2.all(18),
      paint: Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
      anchor: Anchor.center,
    );
    box.add(
      RotateEffect.by(pi * 2, EffectController(duration: 2.5, infinite: true)),
    );
    add(box);
  }

  /// Dark, heavy, droopy slow pulse — no ring, just glow
  void _buildMudOrb(Color color) {
    _addGlow(color, 13, 0.7);
    _addGlow(Colors.brown.shade900, 7, 0.8);
    _addCore(Colors.brown.shade900, 5);
    add(
      ScaleEffect.by(
        Vector2.all(1.2),
        EffectController(duration: 0.9, reverseDuration: 0.9, infinite: true),
      ),
    );
  }

  /// Three fast thin rings at different radii — prismatic
  void _buildCrystalOrb(Color color) {
    _addGlow(color, 9, 0.45);
    _addCore(Colors.white, 4);
    for (int i = 0; i < 3; i++) {
      final ring = _addRing(
        color.withOpacity(0.7 - i * 0.15),
        6.0 + i * 4,
        1.0,
      );
      ring.add(
        RotateEffect.by(
          i.isEven ? pi * 2 : -(pi * 2),
          EffectController(duration: 0.4 + i * 0.2, infinite: true),
        ),
      );
    }
  }

  /// Very fast thin ring, nearly transparent — barely visible
  void _buildAirOrb(Color color) {
    _addGlow(color, 13, 0.2);
    _addCore(Colors.white60, 3);
    for (double r in [7.0, 11.0, 15.0]) {
      final ring = _addRing(color.withOpacity(0.25), r, 0.8);
      ring.add(
        RotateEffect.by(
          pi * 2,
          EffectController(duration: 0.35, infinite: true),
        ),
      );
    }
  }

  /// Six tiny orbs spiraling — scattered dust
  void _buildDustOrb(Color color) {
    _addGlow(color, 9, 0.4);
    _addCore(Colors.amber.shade100, 3);
    final spinner = PositionComponent(anchor: Anchor.center);
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      spinner.add(
        CircleComponent(
          radius: 2.5,
          paint: Paint()..color = color.withOpacity(0.7),
          anchor: Anchor.center,
          position: Vector2(cos(angle), sin(angle)) * 10,
        ),
      );
    }
    spinner.add(
      RotateEffect.by(pi * 2, EffectController(duration: 0.7, infinite: true)),
    );
    add(spinner);
  }

  /// Bright yellow, fast pulsing scale + double rings
  void _buildLightningOrb(Color color) {
    _addGlow(color, 12, 0.7);
    _addCore(Colors.yellow, 5);
    final r1 = _addRing(color, 10, 2.0);
    r1.add(
      RotateEffect.by(pi * 2, EffectController(duration: 0.25, infinite: true)),
    );
    add(
      ScaleEffect.by(
        Vector2.all(1.3),
        EffectController(duration: 0.15, reverseDuration: 0.15, infinite: true),
      ),
    );
  }

  /// Translucent, large soft glow — ethereal fade pulse
  void _buildSpiritOrb(Color color) {
    _addGlow(color, 15, 0.3);
    _addGlow(Colors.white, 8, 0.3);
    _addCore(Colors.white70, 4);
    final ring = _addRing(color.withOpacity(0.3), 12, 1.0);
    ring.add(
      RotateEffect.by(pi * 2, EffectController(duration: 2.2, infinite: true)),
    );
    add(
      ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(duration: 1.0, reverseDuration: 1.0, infinite: true),
      ),
    );
  }

  /// Near-black core, purple glow, slow counter-spin
  void _buildDarkOrb(Color color) {
    _addGlow(color, 12, 0.7);
    _addGlow(Colors.black, 7, 0.9);
    _addCore(Colors.purple.shade900, 4);
    final ring = _addRing(color, 11, 1.5);
    ring.add(
      RotateEffect.by(-pi * 2, EffectController(duration: 1.2, infinite: true)),
    );
  }

  /// Bright radiating rings, golden core
  void _buildLightOrb(Color color) {
    _addCore(Colors.white, 6);
    for (double r in [8.0, 12.0, 16.0]) {
      final ring = _addRing(
        color.withOpacity(0.9 - r * 0.04),
        r,
        1.5 - r * 0.04,
      );
      ring.add(
        ScaleEffect.by(
          Vector2.all(1.25),
          EffectController(
            duration: 0.5 + r * 0.03,
            reverseDuration: 0.5 + r * 0.03,
            infinite: true,
          ),
        ),
      );
    }
    add(
      ScaleEffect.by(
        Vector2.all(1.2),
        EffectController(duration: 0.4, reverseDuration: 0.4, infinite: true),
      ),
    );
  }

  void _buildDefaultOrb(Color color) {
    _addGlow(color, 10, 0.55);
    _addCore(Colors.white, 5);
    final ring = _addRing(color, 9, 1.5);
    ring.add(
      RotateEffect.by(pi * 2, EffectController(duration: 0.8, infinite: true)),
    );
  }

  CircleComponent _addGlow(Color color, double radius, double opacity) {
    final c = CircleComponent(
      radius: radius,
      paint: Paint()..color = color.withOpacity(opacity),
      anchor: Anchor.center,
    );
    add(c);
    return c;
  }

  CircleComponent _addCore(Color color, double radius) {
    final c = CircleComponent(
      radius: radius,
      paint: Paint()..color = color,
      anchor: Anchor.center,
    );
    add(c);
    return c;
  }

  CircleComponent _addRing(Color color, double radius, double strokeWidth) {
    final c = CircleComponent(
      radius: radius,
      paint: Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
      anchor: Anchor.center,
    );
    add(c);
    return c;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;

    if (!_launched) {
      // Orbit phase: spin around attacker
      _orbitAngle += dt * 2.8;
      if (attacker.parent == null) {
        removeFromParent();
        return;
      }
      position =
          attacker.position +
          Vector2(cos(_orbitAngle), sin(_orbitAngle)) * _orbitRadius;

      if (_age >= launchDelaySecs) {
        _launched = true;
        _target = game.getNearestEnemy(attacker.position, _seekRange);
        if (_target == null) {
          removeFromParent();
          return;
        }
      }
    } else {
      // Flight phase: home toward target
      if (_target == null || _target!.isDead || _target!.parent == null) {
        _target = game.getNearestEnemy(position, _seekRange);
        if (_target == null) {
          removeFromParent();
          return;
        }
      }

      final diff = _target!.position - position;
      final dist = diff.length;

      if (dist <= 24.0) {
        _onHit(_target!);
        return; // _onHit decides whether to pierce or die
      }

      position += diff.normalized() * (_moveSpeed * dt).clamp(0, dist);
    }
  }

  void _onHit(HoardEnemy target) {
    // Guard: already hit this enemy, seek the next one
    if (_hitTargets.contains(target)) {
      _target = null;
      return;
    }

    // Compute damage pool on first hit
    if (_remainingDamage < 0) {
      final double dmgMult;
      switch (tier) {
        case 1:
          dmgMult = 1.6;
          break;
        case 2:
          dmgMult = 2.0;
          break;
        default: // tier 3+
          dmgMult = 2.6;
          break;
      }
      _remainingDamage = (calcDmg(attacker, target) * dmgMult).toInt().clamp(
        5,
        999,
      );
    }

    _hitTargets.add(target);

    // Pierce logic: if we have more damage than the target's remaining HP, kill
    // it and keep going; otherwise deplort the full pool and die.
    final bool willKill = _remainingDamage > target.unit.currentHp;
    final int dealt = willKill ? target.unit.currentHp : _remainingDamage;

    target.takeDamage(dealt);
    ImpactVisuals.play(game, target.position, element);

    MysticOrbitalMechanic._applyElementalOrbitalHit(
      game: game,
      attacker: attacker,
      element: element,
      tier: tier,
      target: target,
      baseDamage: dealt,
    );

    if (willKill) {
      _remainingDamage -= dealt;
      if (_remainingDamage <= 0) {
        removeFromParent();
      } else {
        _target = null; // force retarget toward next enemy
      }
    } else {
      removeFromParent();
    }
  }
}
